@description('Location for the resources')
param location string 

@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@description('Indicates if the Azure Cognitive Services account already exists')
param accountExists bool

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

// Web App
resource appServiceWebApp 'Microsoft.Web/sites@2021-02-01' = {
  name: 'UUF-Solver-${resourceToken}'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11' // Set runtime stack to Python 3.11
      appCommandLine: 'python3 -m gunicorn --workers 1 --threads 16 app:app' // Set startup command
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userManagedIdentity.id}': {}
    }
  }
}

// Managed Identity resource
resource userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'uuf-solver-identity-${resourceToken}'
  location: location
}

// Assign Search Data Reader role to the identity, scoped to the Cognitive Search resource
resource searchDataReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, userManagedIdentity.name, searchDataReaderId)
  scope: searchService
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', searchDataReaderId)
    principalId: userManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
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

// Role Assignment for Contributor on the App Service
resource contributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appServiceWebApp.name, userManagedIdentity.name, contributorRoleDefinitionId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', contributorRoleDefinitionId)
    principalId: userManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output webAppName string = 'UUF-Solver-${resourceToken}'
output webAppUrl string = 'https://${appServiceWebApp.name}.azurewebsites.net'
