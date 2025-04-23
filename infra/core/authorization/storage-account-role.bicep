targetScope = 'resourceGroup'

@description('The principal (service principal or managed identity) to grant the role to')
param principalId string

@description('Name of the existing Storage Account')
param storageAccountName string

@description('Role Definition ID or well‑known role name (e.g. "Storage Blob Data Contributor")')
param roleDefinitionIdOrName string

// Fully‑qualified Role Definition resource ID
var roleDefResourceId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  roleDefinitionIdOrName
)

// Reference the existing Storage Account
resource existingSA 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: storageAccountName
}

// Create the role assignment
resource saRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(existingSA.id, principalId, roleDefinitionIdOrName)
  scope: existingSA
  properties: {
    principalId     : principalId
    roleDefinitionId: roleDefResourceId
  }
}
