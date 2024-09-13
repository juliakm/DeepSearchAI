# [Preview] DeepSearchAI

This app is built on the [Sample Chat App with AOAI GitHub project](https://github.com/microsoft/sample-app-aoai-chatGPT) from which it was originally forked. It modifies Answer.tsx, Chat.tsx, and app.py to add URL parsing and enable back end searches for the chat. The "deep search" implementation is in deepsearchai.py. prompts.py contains the prompts used on its internal conversation during the key "deep search" implementation. And chat.py is where the Azure OpenAI API calls are made now, broken out of app.py since it is used there as well as in the deepsearchai implementation.

It automatically starts a conversation with the any contents given to the URL query string, allowing you to embed links with predefined conversation starting points. It then gives its best suggestion to answer the system prompt using that information, searching thoroughly and only responding when it can document everything it says with reference links to live URLs for the user to validate ground truth on its claims.

## Deploy the app

### Deploy from your local machine

#### Local Setup: Basic Chat Experience

1. Copy `.env.sample` to a new file called `.env` and configure the settings as described in the [environment variables](#environment-variables) section.

   These variables are required:
   - `AZURE_OPENAI_RESOURCE` or `AZURE_OPENAI_ENDPOINT`
   - `AZURE_OPENAI_MODEL`
   - `AZURE_OPENAI_KEY` (optional if using Entra ID)

   These variables are optional:
   - `AZURE_OPENAI_TEMPERATURE`
   - `AZURE_OPENAI_TOP_P`
   - `AZURE_OPENAI_MAX_TOKENS`
   - `AZURE_OPENAI_STOP_SEQUENCE`
   - `AZURE_OPENAI_SYSTEM_MESSAGE`

   See the [documentation](https://learn.microsoft.com/en-us/azure/cognitive-services/openai/reference#example-response-2) for more information on these parameters.

2. Start the app with `start.cmd`. This will build the frontend, install backend dependencies, and then start the app. Or, just run the backend in debug mode using the VSCode debug configuration in `.vscode/launch.json`.

3. You can see the local running app at http://127.0.0.1:50505.

NOTE: You may find you need to set: MacOS: `export NODE_OPTIONS="--max-old-space-size=8192"` or Windows: `set NODE_OPTIONS=--max-old-space-size=8192` to avoid running out of memory when building the frontend.

#### Local Setup: Bing searching

These variables are required for DeepSearchAI to work:
    - `BING_SEARCH_KEY=<your-bing-search-key>`
    - `BING_SEARCH_ENDPOINT=<your-bing-search-endpoint>`

#### Local Setup: Enable Chat History

To enable chat history, you will need to set up CosmosDB resources. The ARM template in the `infrastructure` folder can be used to deploy an app service and a CosmosDB with the database and container configured. You will also need to grant access to your Azure Web App's managed system identity to the Cosmos DB resource with the following command:

```azurepowershell
$resourceGroupName = '<your Cosmos DB resource group name' 
$accountName = '<name of your Cosmos DB>'
$subscription = '<your subscription_id>' # of the cosmos db

# <your object_id> is the system assigned identity of your app
# or for debugging on Windows, your user principal object ID in Azure.
$principalId = '<your object_id>' 

# Provides read/write access
$ roleDefinitionId = '00000000-0000-0000-0000-000000000002' 

az cosmosdb sql role assignment create --account-name $accountName --resource-group $resourceGroupName --scope "/" --principal-id $principalId --role-definition-id $roleDefinitionId --subscription $subscription

# *** Optional ***

# These next lines will disable key authentication on Cosmos DB (for maximum security).
# This app uses managed identities with Entra ID to authenticate to Cosmos DB instead of less secure keys.

#$cosmosdb_id="/subscriptions/" + $subscription + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.DocumentDB/databaseAccounts/" + $accountName
#az resource update --ids $cosmosdb_id --set properties.disableLocalAuth=true --latest-include-preview
```

Then specify these additional environment variables: 

- `AZURE_COSMOSDB_ACCOUNT`
- `AZURE_COSMOSDB_DATABASE`
- `AZURE_COSMOSDB_CONVERSATIONS_CONTAINER`

As above, start the app with `start.cmd`, then visit the local running app at http://127.0.0.1:50505. Or, just run the backend in debug mode using the VSCode debug configuration in `.vscode/launch.json`.

#### Local Setup: Enable Message Feedback

To enable message feedback, you will need to set up CosmosDB resources. Then specify this additional environment variable:

- `AZURE_COSMOSDB_ENABLE_FEEDBACK=True`

## Environment variables

Note: settings starting with `AZURE_SEARCH` are only needed when using Azure OpenAI on your data with Azure AI Search. If not connecting to your data, you only need to specify `AZURE_OPENAI` settings.

| App Setting | Value | Note |
| --- | --- | ------------- |
|AZURE_OPENAI_RESOURCE||the name of your Azure OpenAI resource (only one of AZURE_OPENAI_RESOURCE/AZURE_OPENAI_ENDPOINT is required)|
|AZURE_OPENAI_MODEL||The name of your model deployment|
|AZURE_OPENAI_ENDPOINT||The endpoint of your Azure OpenAI resource (only one of AZURE_OPENAI_RESOURCE/AZURE_OPENAI_ENDPOINT is required)|
|AZURE_OPENAI_MODEL_NAME|gpt-35-turbo-16k|The name of the model|
|AZURE_OPENAI_KEY||One of the API keys of your Azure OpenAI resource (optional if using Entra ID)|
|AZURE_OPENAI_TEMPERATURE|0|What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic. A value of 0 is recommended when using your data.|
|AZURE_OPENAI_TOP_P|1.0|An alternative to sampling with temperature, called nucleus sampling, where the model considers the results of the tokens with top_p probability mass. We recommend setting this to 1.0 when using your data.|
|AZURE_OPENAI_MAX_TOKENS|1000|The maximum number of tokens allowed for the generated answer.|
|AZURE_OPENAI_STOP_SEQUENCE||Up to 4 sequences where the API will stop generating further tokens. Represent these as a string joined with "|", e.g. `"stop1|stop2|stop3"`|
|AZURE_OPENAI_SYSTEM_MESSAGE|You are an AI assistant that helps people find information.|A brief description of the role and tone the model should use|
|AZURE_OPENAI_PREVIEW_API_VERSION|2024-02-15-preview|API version when using Azure OpenAI on your data|
|AZURE_OPENAI_STREAM|True|Whether or not to use streaming for the response. Note: Setting this to true prevents the use of prompt flow.|
|BING_SEARCH_KEY||The key for your Bing Search resource.|
|BING_SEARCH_ENDPOINT||The endpoint for your Bing Search resource.|
|UI_TITLE|DeepSearchAI| Chat title (left-top) and page title (HTML)
|UI_LOGO|| Logo (left-top). Defaults to Contoso logo. Configure the URL to your logo image to modify.
|UI_CHAT_LOGO|| Logo (chat window). Defaults to Contoso logo. Configure the URL to your logo image to modify.
|UI_CHAT_TITLE|Start chatting| Title (chat window)
|UI_CHAT_DESCRIPTION|This chatbot is configured to answer your questions| Description (chat window)
|UI_FAVICON|| Defaults to Contoso favicon. Configure the URL to your favicon to modify.
|UI_SHOW_SHARE_BUTTON|True|Share button (right-top)
|UI_SHOW_CHAT_HISTORY_BUTTON|True|Show chat history button (right-top)
|SANITIZE_ANSWER|False|Whether to sanitize the answer from Azure OpenAI. Set to True to remove any HTML tags from the response.|


## Run development container

### Prerequisites

- Docker installed on the host computer
- Visual Studio Code
- VSCode extension: Dev Containers 
- Update `.env` based on setting from dev team

### Run the sample 

1. Remove the venv folder, you don't need this in the dev container. The dev container and venv serve the same purpose of isolating the environment. 
1. At the root, run the following command to install dependencies:

    ```shell
    pip install -r requirements.txt
    pip install --upgrade gunicorn uvicorn
    cd frontend && npm install && cd ..
    ```

1. Run the sample wih the following command:

    ```
    python -m uvicorn app:app  --port 50505 --reload
    ```

## Use UUF solver

Use the following prompt in the chat window to test UUF solver:

```
Article: https://learn.microsoft.com/en-us/azure/data-factory/connector-sap-change-data-capture
Customer Feedback: Not alot of information regarding the override of checkpoint key. Little more information about the actual implementation of a parameterized checkpoint key for the different sources would be nice
```

Use the following URL in the browser address bar to test the UUF solver:

Dev URL

```
http://127.0.0.1:50505/?Article=https://learn.microsoft.com/en-us/azure/data-factory/connector-sap-change-data-capture&Customer%20Feedback=Not%20alot%20of%20information%20regarding%20the%20override%20of%20checkpoint%20key.%20Little%20more%20information%20about%20the%20actual%20implementation%20of%20a%20parameterized%20checkpoint%20key%20for%20the%20different%20sources%20would%20be%20nice
```

Live URL

```
https://uuf-solver.azurewebsites.net/?Article=https://learn.microsoft.com/en-us/azure/data-factory/connector-sap-change-data-capture&Customer%20Feedback=Not%20alot%20of%20information%20regarding%20the%20override%20of%20checkpoint%20key.%20Little%20more%20information%20about%20the%20actual%20implementation%20of%20a%20parameterized%20checkpoint%20key%20for%20the%20different%20sources%20would%20be%20nice
```

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.

