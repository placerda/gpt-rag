// core/authorization/ai-services.bicep
// Module to assign a built-in or custom RBAC role to an existing
// Azure Cognitive Services account in the same resource group.

targetScope = 'resourceGroup'

@description('The principal (service principal or managed identity) to grant the role to')
param principalId string

@description('The name of the existing Cognitive Services account')
param resourceName string

@description('The GUID of the Role Definition to assign (e.g. Cognitive Services User)')
param roleDefinitionGuid string

// Build the fully-qualified Role Definition resource ID
var roleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  roleDefinitionGuid
)

// Reference the existing Cognitive Services account in this RG
resource existingCogSvc 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: resourceName
}

// Create the role assignment scoped to that resource
resource cogRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    existingCogSvc.id,
    principalId,
    roleDefinitionId
  )
  scope: existingCogSvc
  properties: {
    principalId     : principalId
    roleDefinitionId: roleDefinitionId
  }
}
