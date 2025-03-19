@description('Key Vault name')
param keyVaultName string

@description('Resource group name where the Key Vault is located')
param keyVaultResourceGroup string

@description('System-assigned managed identity principal ID')
param systemAssignedPrincipalId string

@description('User-assigned managed identity principal ID')
param userAssignedPrincipalId string

// Reference the existing Key Vault as a resource
resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroup)
}

// Role assignment for system-assigned managed identity
resource keyVaultAccessSystemAssigned 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyVault.id, systemAssignedPrincipalId, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets User role
    principalId: systemAssignedPrincipalId
  }
}

// Role assignment for user-assigned managed identity
resource keyVaultAccessUserAssigned 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyVault.id, userAssignedPrincipalId, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets User role
    principalId: userAssignedPrincipalId
  }
}
