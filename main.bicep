@description('Location for the resources')
param location string 

@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@description('Managed Identity name')
param identityName string = 'UUF-Solver-my-identity'

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

// App Service Plan module
module appServicePlan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  name: 'appServicePlanDeploy'
  scope: resourceGroup()
  params: {
    name: 'asp-UUF-Solver-${resourceToken}'
    location: location
    skuName: 'B2'
    skuCapacity: 1
  }
}

// Web App module
module appServiceWebApp 'br/public:avm/res/web/site:0.13.0' = {
  name: 'UUF-Solver'
  scope: resourceGroup()
  params: {
    name: 'UUF-Solver-${resourceToken}'
    location: location
    serverFarmResourceId: appServicePlan.outputs.resourceId
    kind: 'app'
    managedIdentities: {
      userAssignedResourceIds: [
        userManagedIdentity.id
      ]
    }
  }
}

// Managed Identity resource
resource userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
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
