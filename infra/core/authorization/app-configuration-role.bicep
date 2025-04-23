targetScope = 'resourceGroup'

@description('The principal (service principal or managed identity) to grant the role to')
param principalId string

@description('Name of the existing App Configuration Store')
param configStoreName string

@description('Role Definition ID or well-known role name (e.g. "App Configuration Data Reader")')
param roleDefinitionIdOrName string

// Fully‑qualified Role Definition resource ID
var roleDefResourceId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  roleDefinitionIdOrName
)

// Reference the existing App Configuration Store
resource existingAppConfig 'Microsoft.AppConfiguration/configurationStores@2022-05-01' existing = {
  name: configStoreName
}

// Create the role assignment
resource appConfigRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(existingAppConfig.id, principalId, roleDefinitionIdOrName)
  scope: existingAppConfig
  properties: {
    principalId     : principalId
    roleDefinitionId: roleDefResourceId
  }
}
