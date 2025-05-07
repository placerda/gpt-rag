@allowed([
  'aiservices'
  'appconfig'
  'keyvault'
  'storage'
])
param resourceType       string
param resourceName       string
param resourceGroupName  string = resourceGroup().name
param principalId        string
param roleDefinitionGuid string

// Fully-qualified Role Definition
var roleDefId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionGuid)

// Declare the existing targets
resource ais 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = if (resourceType == 'aiservices') {
  name: resourceName
  scope: resourceGroup(resourceGroupName)
}
resource cfg 'Microsoft.AppConfiguration/configurationStores@2022-05-01' existing = if (resourceType == 'appconfig') {
  name: resourceName
  scope: resourceGroup(resourceGroupName)
}
resource kv 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (resourceType == 'keyvault') {
  name: resourceName
  scope: resourceGroup(resourceGroupName)
}
resource sa 'Microsoft.Storage/storageAccounts@2021-04-01' existing = if (resourceType == 'storage') {
  name: resourceName
  scope: resourceGroup(resourceGroupName)
}

// Single, idempotent role assignment
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  // Pick the right target id inline—Bicep sees `ais.id`, `cfg.id`, etc. directly.
  name: guid(
    resourceType == 'aiservices' ? ais.id
  : resourceType == 'appconfig'  ? cfg.id
  : resourceType == 'keyvault'   ? kv.id
                                 : sa.id,
    principalId,
    roleDefId
  )

  // Scope it to the very same resource
  scope: resourceType == 'aiservices' ? ais
        : resourceType == 'appconfig' ? cfg
        : resourceType == 'keyvault'  ? kv
                                      : sa

  properties: {
    principalId     : principalId
    roleDefinitionId: roleDefId
  }
}
