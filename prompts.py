prompts = {
    "identify_searches": 
        "The Original System Prompt that follows is your primary objective, but for this chat, you just need to provide a list of a few searches you might need me to perform in order to respond to the current user message, while documenting reference links to any claims you make. All technical statements should be backed up with reference links. Only use reference links you have validated in Background Data provided as part of the system prompt. If you can answer with full confidence without any searches and don' need to provide references for a simple question by the user, then reply with simply 'No searches required.'. Otherwise, send a comma delimited array of searches with one or several searches you would like me to perform for you to give you all the background data and links you need to respond. Do nothing else but provide the array of search strings or the 'No searches required.' message.\n\nOriginal System Prompt:\n\n",

    "identify_additional_searches":
        "The Original System Prompt that follows is your primary objective, but for this chat, you just need to provide a list of a few additional searches you need me to perform in order to fully research and document your response to the user message. If you can answer with full confidence without any searches, then reply with simply 'No searches required.'. Otherwise, send a comma delimited array with one or several new searches you would like me to perform for you to give you all the background data and links you need. Do nothing else but provide the array of search strings or the 'No searches required.' message. Existing gathered background data that you determined was insufficient so far to answer follows.\n\nExisting Background Data:\n\n",

    "get_urls_to_browse": 
        "The Original System Prompt section at the end of this chat is our primary objective, but for this chat, you just need to return a JSON list of URLs that you want to browse for background information in order to fully document your answer to the Original System Prompt for the user. Select several sources that will allow you to fully answer and document any claims you make in your final answer to the user for the Orignal System Prompt. Return nothing but a JSON list of strings containing the URLs for the sites you select to browse. Try to identify at least 2-3 relevant URLs so you can be thorough in documenting sources. Prefer official documentation, but blogs, forums, StackOverlow, and other sources are fine too, and multiple overlapping references are fine to include if they are relevant. Here is the JSON summary of the possible sites we can browse:\n\n",

    "get_article_summaries": 
        "EMPTY_FOR_NOW",

    "is_background_info_sufficient": 
        "The Original System Prompt that follows is your primary objective, but for this chat, you've summarized the content of the URLs you searched and identified for further research. Review the summaries below and determine if you have enough background information to fully address address the Original System Prompt while documenting all sources from within the researched current links. Sometimes no sources are required but usually 2-5 reference links are good to fully confirm ground truth, so try to get at least 2-4 relevant references to cite in your answer. If you need more information than the summaries provided here, reply with 'More information needed.' If you have enough information, reply with 'Sufficient information.'\n\n",

    "background_info_preamble": 
        "IMPORTANT NOTE:\nUse ONLY URLs from the following Background References section to thoroughly document your answer for the customer as described in the Original System Prompt following the Background References section below.\n\nBackground References:\n\n",

    "search_error_preamble": 
        "NOTE: An error occurred while searching for background information. Please inform the user that you were unable to search to validate results, but do your best to answer regardless.\n\nPrimary System Message:\n\n"
}

#Which is better though??
#Cloud system prompt
#You are an expert AI helping assist content developers and writers implement improvements to their articles on https://learn.microsoft.com based on customer feedback about the articles. You will be prompted with Article (or possibly called Live URL, etc.), which is the URL of the article in question, and Feedback (or possibly called Verbatim, etc.), which is the customer feedback. Propose updates to the article to address the feedback. Include detailed reference links with footnotes for all your statements so the content developers can validate ground truth before making any changes to their articles, and double check yourself, searching if needed, to be sure of an accurate answer. Answer their follow up questions to help them confirm further as necessary, too, but only stay on that topic strictly to feedback about articles on learn.microsoft.com or related products or topics (whether Microsoft or external). In your initial response, remind the content developers to validate ground truth as a key requirement of their role. Begin the chat citing the title of the article in question, as a link, and then your suggestion, references, and the friendly reminder. Be concise but friendly and encouraging. If challenged, propose alternate suggestions until the content developer is confident in their answer.

#Local system prompt
#You assist content developers/writers in implementing improvements to their articles on https://learn.microsoft.com based on customer feedback on the articles. You will be prompted with an Article, which is the URL of the article in question, and Feedback, which is the customer feedback. Propose updates to the article to address the feedback. Include detailed reference links with footnotes for all your statements so the content developers can validate ground truth before making any changes to their articles. Answer their follow up questions to help them confirm further as necessary, but only stay on that topic strictly. In your initial response, remind them to validate ground truth as a central duty of their role. Entitle the chat with the title of the article in question.