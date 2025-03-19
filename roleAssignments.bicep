@description('Key Vault resource ID')
param keyVaultId string

@description('System-assigned managed identity principal ID')
param systemAssignedPrincipalId string

@description('User-assigned managed identity principal ID')
param userAssignedPrincipalId string

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
