@description('Location for the resources')
param location string 

@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@description('Indicates if the Azure Cognitive Services account already exists')
param accountExists bool

@description('Client ID of the Azure AD application')
param clientId string

@description('Client Secret of the Azure AD application')
@secure()
param clientSecret string

// Contributor role definition ID
var contributorRoleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var searchDataReaderId = '1407120a-92aa-4202-b7e9-c0e197c71c8f'

@description('Resource token for naming consistency')
var resourceToken = toLower(uniqueString(resourceGroup().id, environmentName, location))

// Azure Cognitive Search
resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: 'mysearch-${resourceToken}'
  location: location
  sku: {
    name: 'basic'
  }
  properties: {
    hostingMode: 'default'
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: 'asp-UUF-Solver-${resourceToken}'
  location: location
  sku: {
    name: 'B2'
    capacity: 1
  }
  properties: {
    reserved: true // This sets the plan to use Linux
  }
}

// Reference the Key Vault as an existing resource
resource keyVaultExisting 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: 'key-vault-${resourceToken}'
}

// Web App
resource appServiceWebApp 'Microsoft.Web/sites@2021-02-01' = {
  name: 'UUF-Solver-${resourceToken}'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11' // Set runtime stack to Python 3.11
      appCommandLine: 'python3 -m gunicorn --workers 1 --threads 16 app:app' // Set startup command
      appSettings: [
        {
          name: 'AZURE_OPENAI_KEY'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultExisting.name};SecretName=openai-key)'
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultExisting.name};SecretName=openai-endpoint)'
        }
        {
          name: 'AZURE_OPENAI_MODEL'
          value: 'content-openai-${resourceToken}' // Directly set the deployment name
        }
        {
          name: 'AZURE_OPENAI_SYSTEM_MESSAGE'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultExisting.name};SecretName=azure-openai-system-message)' // Reference the new secret
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned, UserAssigned' // Enable both system-assigned and user-assigned identities
    userAssignedIdentities: {
      '${userManagedIdentity.id}': {}
    }
  }
}

// Authentication Settings
resource siteAuthSettingsV2 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: appServiceWebApp
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'AzureActiveDirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: clientId
          clientSecretSettingName: 'AAD_CLIENT_SECRET'
          openIdIssuer: 'https://sts.windows.net/${tenant().tenantId}/'
        }
        login: {
          loginParameters: [
            'response_type=id_token'
            'scope=openid profile User.Read'
          ]
        }
      }
    }
  }
}

// Managed Identity resource
resource userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'uuf-solver-identity-${resourceToken}'
  location: location
}

// Azure OpenAI resource
resource openAi 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: 'DeepSearchUUF-${resourceToken}'
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    publicNetworkAccess: 'Enabled'
    restore: accountExists ? true : null
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userManagedIdentity.id}': {}
    }
  }
}

// Azure OpenAI deployment resource
resource openAiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openAi
  name: 'content-openai-${resourceToken}' // Deployment name under the OpenAI account
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini' // Model name
      version: '2024-07-18' // Model version
    }
  }
    sku: {
      name: 'Standard'
      capacity: 5 // Adjusted down to meet the quota
    }
  }


// Key Vault resource
resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: 'key-vault-${resourceToken}' // Unique name for the Key Vault
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      // Access policy for the system-assigned managed identity
      {
        tenantId: subscription().tenantId
        objectId: appServiceWebApp.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
      // Access policy for the user-assigned managed identity
      {
        tenantId: subscription().tenantId
        objectId: userManagedIdentity.properties.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
    enableSoftDelete: true
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    environment: environmentName
    project: 'DeepSearchAI'
  }
}

// Add a Key Vault secret for the OpenAI key
resource openAiKeySecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'openai-key'
  properties: {
    value: openAi.listKeys().key1 // Replace with the actual value you want to store
  }
}

// Add a Key Vault secret for the OpenAI endpoint
resource openAiEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'openai-endpoint'
  properties: {
    value: openAi.properties.endpoint // Use the OpenAI endpoint from the resource
  }
}

// Add a Key Vault secret for AZURE_OPENAI_SYSTEM_MESSAGE
resource openAiSystemMessageSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'azure-openai-system-message'
  properties: {
    value: 'You assist content developers and writers in implementing improvements to their articles on https://learn.microsoft.com based on customer feedback on the articles. You will be prompted with an Article, which is the URL of the article in question, and Feedback, which is the customer feedback. Propose updates to the article to address the feedback. Include detailed reference links with footnotes for all your statements so the content developers can validate ground truth before making any changes to their articles. Answer their follow-up questions to help them understand better as necessary, searching when necessary to always document your technical suggestions with external references that you confirm in searches you can perform. In your initial response, remind them to validate ground truth as a central duty of their role. Entitle the chat with the title of the article in question. When the user provides you the required details, format your output like this markdown template, use active voice and replace "this" with the correct noun:\n\n## IMPORTANT\n\nWhen using the tool, be sure to:\n\n* Validate the ground truth of the response before using it in your work as per [guidance in the Docs Contributors Guide](https://review.learn.microsoft.com/en-us/help/contribute/guidance-for-ai-generated-content?branch=main#how-to-add-ai-usage-metadata-to-ai-generated-content)\n\n* Add the following tag to your UUF item in Azure DevOps: **used-uuf-solver**\n\n* Add the following attribute to your article metadata: **ai-usage: ai-assisted**\n\n## Article\n<Title of the article, formatted as a link to it>\n## Feedback\n<The user feedback>\n### Proposed updates\n<Here include full proposal with examples and references and quotes from reference material (being sure to use at least 3-6 references from your previously gathered background information). Use subsections with H3s (###) and H4s (####), and any other formatting necessary to clearly present the proposed changes and your reasoning for proposing them.>\n## Additional considerations/Examples/etc. (optional)\nYou can call this section whatever is appropriate for it if you need another section for any reason at the end.)\n## References\n<include links for all the references made in the sections above, each assigned to the relevant footnote number(s) where it was referenced in the answer. This should be a bibliography of links to sources referenced in the proposed changes.>'
  }
}

// Outputs
output keyVault resource = keyVault
output keyVaultId string = keyVault.id
output systemAssignedPrincipalId string = appServiceWebApp.identity.principalId
output userAssignedPrincipalId string = userManagedIdentity.properties.principalId
output webAppName string = appServiceWebApp.name
output resourceToken string = resourceToken
output managedIdentityClientId string = userManagedIdentity.properties.clientId
