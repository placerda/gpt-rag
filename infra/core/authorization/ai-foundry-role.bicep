targetScope = 'resourceGroup'

@description('The principal (service principal or managed identity) to grant the role to')
param principalId string

@description('Name of the existing Machine Learning Workspace')
param workspaceName string

@description('Role Definition ID or well-known role name (e.g. "Machine Learning Workspace Contributor")')
param roleDefinitionIdOrName string

// Fully‑qualified Role Definition resource ID
var roleDefResourceId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  roleDefinitionIdOrName
)

// Reference the existing ML Workspace
resource existingMLWorkspace 'Microsoft.MachineLearningServices/workspaces@2025-01-01-preview' existing = {
  name: workspaceName
}

// Create the role assignment
resource mlWorkspaceRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(existingMLWorkspace.id, principalId, roleDefinitionIdOrName)
  scope: existingMLWorkspace
  properties: {
    principalId     : principalId
    roleDefinitionId: roleDefResourceId
  }
}
