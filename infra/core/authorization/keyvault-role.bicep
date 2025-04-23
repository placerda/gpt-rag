targetScope = 'resourceGroup'

@description('The principal (service principal or managed identity) to grant the role to')
param principalId string

@description('Name of the existing Key Vault')
param vaultName string

@description('Role Definition ID or well‑known role name (e.g. "Key Vault Secrets User")')
param roleDefinitionIdOrName string

// Fully‑qualified Role Definition resource ID
var roleDefResourceId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  roleDefinitionIdOrName
)

// Reference the existing Key Vault
resource existingKV 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: vaultName
}

// Create the role assignment
resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(existingKV.id, principalId, roleDefinitionIdOrName)
  scope: existingKV
  properties: {
    principalId     : principalId
    roleDefinitionId: roleDefResourceId
  }
}
