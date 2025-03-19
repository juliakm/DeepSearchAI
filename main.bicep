@description('Location for the resources')
param location string 

@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@description('Indicates if the Azure Cognitive Services account already exists')
param accountExists bool

@description('Client ID of the Azure AD application')
param clientId string

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
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=openai-key)'
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=openai-endpoint)'
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
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
resource openAi 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
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
    accessPolicies: [] // Leave empty if using RBAC for access control
    enablePurgeProtection: false
    enableSoftDelete: true
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    environment: environmentName
    project: 'DeepSearchAI'
  }
}

// Add a Key Vault secret
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

// Grant App Service access to Key Vault
resource keyVaultAccess 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyVault.id, userManagedIdentity.id, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets User role
    principalId: userManagedIdentity.properties.principalId
  }
  // Removed unnecessary dependsOn entry
}

// Key Vault outputs
output keyVaultName string = keyVault.name
output keyVaultResourceId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri

// App Service and identity outputs
output webAppName string = 'UUF-Solver-${resourceToken}'
output webAppUrl string = 'https://${appServiceWebApp.name}.azurewebsites.net'
output resourceToken string = resourceToken
output managedIdentityClientId string = userManagedIdentity.properties.clientId
