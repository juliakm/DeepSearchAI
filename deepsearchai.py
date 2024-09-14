import asyncio
import copy
import json
import logging
import uuid
from datetime import datetime, timezone
from prompts import prompts
from quart import make_response
from bs4 import BeautifulSoup
from pprint import pprint
import requests
from backend.settings import app_settings
from backend.utils import format_as_ndjson
from chat import stream_chat_request

# Status handling
status_message = {}
clients = {}

async def set_status_message(message, page_instance_id):
    if page_instance_id in clients:
        websocket_client = clients[page_instance_id]
        try:
            await websocket_client.send(message)
        except Exception as e:
            logging.error(f"Failed to send message to {page_instance_id}: {e}")
    else:
        logging.warning(f"Page instance ID {page_instance_id} not found in clients. Available clients: {clients}")

def process_raw_response(raw_content):
    # Decode the raw content
    decoded_content = raw_content.decode('utf-8')
    lines = decoded_content.split('\n')
    json_response = [json.loads(line) for line in lines if line.strip()]
    
    # Initialize variables to hold properties and message contents
    combined_content = ""
    final_json = {
        "messages": [],
        "model": None,
        "history_metadata": None,
    }
    
    chat_id = ""
    for obj in json_response:
        try:                    
            # Extract and set top-level properties once
            if final_json["model"] == None:
                final_json["model"] = obj.get("model")
                final_json["history_metadata"] = obj.get("history_metadata")
                chat_id = obj.get("id")
            
            # Extract message contents
            choices = obj.get("choices", [])
            for choice in choices:
                messages = choice.get("messages", [])
                for message in messages:
                    content = message.get("content", "")
                    combined_content += content
        
        except json.JSONDecodeError as e:
            logging.error(f"JSON decode error: {e}")
            continue
        except Exception as e:
            logging.error(f"Error processing object: {e}")
            continue
        
    # Add combined content to the final JSON structure
    final_json["messages"].append({
        "id": chat_id,
        "role": "assistant",
        "content": combined_content,
        "date": datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
    })
    
    return final_json

def concatenate_json_arrays(json_array1, json_array2):
    json_array1 = json_array1.rstrip(']\n\r ')
    json_array2 = json_array2.lstrip('[\n\r ')
    concatenated_json = f"{json_array1}, {json_array2}"
    return concatenated_json

async def search_bing(search):
        # Add your Bing Search V7 subscription key and endpoint to your environment variables.
        subscription_key = app_settings.bing.key
        endpoint = app_settings.bing.endpoint + "/v7.0/search"
        mkt = "en-US"
        params = { 'q' : search, 'mkt' : mkt }
        headers = { 'Ocp-Apim-Subscription-Key' : subscription_key }
        ## Call the API
        try:
            response = requests.get(endpoint, headers=headers, params=params)
            response.raise_for_status()
            search_results = response.json().get("webPages", {}).get("value", [])
            return search_results
        except Exception as e:
            logging.error(f"Error: {e}")
            return None
        
async def send_private_chat(request_body, request_headers, system_preamble = None, system_message = None):
        bg_request_body = copy.deepcopy(request_body)
        bg_request_headers = copy.deepcopy(request_headers)
        bg_request_body["history_metadata"] = None
        bg_request_body["conversation_id"] = str(uuid.uuid4())
        bg_request_body["messages"] = bg_request_body["messages"][-1:]
        result = await stream_chat_request(bg_request_body, bg_request_headers, system_preamble, system_message)
        response = await make_response(format_as_ndjson(result))
        response.timeout = None
        response.mimetype = "application/json-lines"
        response_raw = await response.get_data()
        combined_json = process_raw_response(response_raw) 
        return combined_json["messages"][0]["content"]

async def get_search_results(searches):
        allresults = None
        for search in searches:
            results = await search_bing(search);
            if results == None:
                return "Search error."
            else:
                if allresults == None:
                    allresults = results
                else:
                    allresults += results
        # Remove extraneous fields
                proparray = ["dateLastCrawled", "language", "richFacts", "isNavigational", "isFamilyFriendly", "displayUrl", "searchTags", "noCache", "cachedPageUrl", "datePublishedDisplayText", "datePublished", "id", "primaryImageOfPage", "thumbnailUrl"]
                for obj in allresults:
                    for prop in proparray:
                        if prop in obj:
                            del obj[prop]
                return allresults

async def identify_searches(request_body, request_headers, Summaries = None):
        
        if Summaries is None:
            system_preamble = prompts["identify_searches"];
        else:
            system_preamble = prompts["identify_additional_searches"] + json.dumps(Summaries, indent=4) + "\n\nOriginal System Prompt:\n"
        
        searches = await send_private_chat(request_body, request_headers, system_preamble)

        if isinstance(searches, str):
            if searches == "No searches required.": 
                return None
            else:
                if searches[0] != "[":
                    searches = "[" + searches
                if searches[-1] != "]":
                    searches = searches + "]"
                searches = json.loads(searches)
        return searches

async def get_urls_to_browse(request_body, request_headers, searches):
        searchresults = await get_search_results(searches)
        if searchresults == "Search error.":
            return "Search error."
        else:
            strsearchresults = json.dumps(searchresults, indent=4)
            system_preamble = prompts["get_urls_to_browse"] + strsearchresults + "\n\nOriginal System Prompt:\n"
                        
            URLsToBrowse = await send_private_chat(request_body, request_headers, None, system_preamble)
            return URLsToBrowse

async def fetch_and_parse_url(url):
    response = requests.get(url)
    if response.status_code == 200:  # Raise an error for bad status codes
        # Parse the web page
        soup = BeautifulSoup(response.content, 'html.parser')
        # Extract the main content
        paragraphs = soup.find_all('p')
        # Combine the text from the paragraphs
        content = ' '.join(paragraph.get_text() for paragraph in paragraphs)
        return content
    else:
        return None

async def get_article_summaries(request_body, request_headers, URLsToBrowse):
        Summaries = None
        URLsToBrowse = json.loads(URLsToBrowse)
        Pages = None
        
        async def process_url(URL):
            page_content = await fetch_and_parse_url(URL)
            if page_content is not None: 
                system_prompt = (
                    "The Original System Prompt that follows is your primary objective, "
                    "but for this chat you identified the following URL for further research "
                    "to give your answer: " + URL + 
                    ". Your task now is to provide a summary of relevant content on the page "
                    "that will help us address the feedback on the URL provided by the user "
                    "and document current sources. Return nothing except your summary of the "
                    "key points and any important quotes the content on the page in a single string.\n\n"
                    "Page Content:\n\n" + page_content + "\n\nOriginal System Prompt:\n\n"
                )
                summary = await send_private_chat(request_body, request_headers, None, system_prompt)
                summary = json.loads("{\"URL\" : \"" + URL + "\",\n\"summary\" : " + json.dumps(summary) + "}")
                return summary
            return None

        # Create tasks for all URLs
        tasks = [process_url(URL) for URL in URLsToBrowse]
        
        # Run tasks concurrently
        results = await asyncio.gather(*tasks)
        
        # Filter out None results and collect summaries
        Summaries = [summary for summary in results if summary is not None]
        return Summaries

async def is_background_info_sufficient(request_body, request_headers, Summaries):
        strSummaries = json.dumps(Summaries, indent=4)
        system_preamble = prompts["is_background_info_sufficient"] + strSummaries + "\n\nOriginal System Prompt:\n"

        response = await send_private_chat(request_body, request_headers, system_preamble)
        if response == "More information needed.": 
            
            #debug
            logging.warning("\n\nMore information was needed, searching again.\n\n")

            return False
        else:
            return True
        
async def search_and_add_background_references(request_body, request_headers):
        NeedsMoreSummaries = True
        Summaries = None

        page_instance_id = request_body["page_instance_id"]

        while NeedsMoreSummaries:

            searches = await identify_searches(request_body, request_headers, Summaries)

            if searches == None:
                await set_status_message("🔆 Generating answer...", page_instance_id)
                return None
            
            await set_status_message("🔍 Searching...", page_instance_id)
            URLsToBrowse = await get_urls_to_browse(request_body, request_headers, searches)
            if URLsToBrowse == "Search error.": 
                return "Search error."       

            await set_status_message("🕵️‍♂️ Browsing and analyzing...", page_instance_id)
            if (Summaries is None):
                Summaries = await get_article_summaries(request_body, request_headers, URLsToBrowse)
            else:
                newSummaries = await get_article_summaries(request_body, request_headers, URLsToBrowse)
                Summaries += newSummaries
            
            await set_status_message("🤖 Checking research validity...", page_instance_id)
            AreWeDone = await is_background_info_sufficient(request_body, request_headers, Summaries)
            if AreWeDone:
                NeedsMoreSummaries = False

        await set_status_message("🌟 Generating answer...", page_instance_id)
        return prompts["background_info_preamble"] + json.dumps(Summaries, indent=4) + "\n\nOriginal System Prompt:\n\n"