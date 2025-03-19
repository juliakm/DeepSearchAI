@description('Key Vault name')
param keyVaultName string

@description('Resource group name where the Key Vault is located')
param keyVaultResourceGroup string

@description('System-assigned managed identity principal ID')
param systemAssignedPrincipalId string

@description('User-assigned managed identity principal ID')
param userAssignedPrincipalId string

// Construct the Key Vault resource ID
var keyVaultId = resourceId(keyVaultResourceGroup, 'Microsoft.KeyVault/vaults', keyVaultName)

// Grant the system-assigned managed identity access to Key Vault
resource keyVaultAccessSystemAssigned 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyVaultId, systemAssignedPrincipalId, 'KeyVaultSecretsUser')
  scope: keyVaultId
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets User role
    principalId: systemAssignedPrincipalId
  }
}

// Grant the user-assigned managed identity access to Key Vault
resource keyVaultAccessUserAssigned 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyVaultId, userAssignedPrincipalId, 'KeyVaultSecretsUser')
  scope: keyVaultId
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets User role
    principalId: userAssignedPrincipalId
  }
}
