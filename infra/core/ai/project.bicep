@description('The AI Foundry Project resource name')
param name string
@description('Display name of the AI Foundry Project')
param displayName string = name
@description('The AI Hub resource name (or ID) where the project is created')
param hubName string
@description('The Key Vault resource name for the project')
param keyVaultName string

@description('SKU name for the Project')
param skuName string = 'Basic'
@description('SKU tier for the Project')
@allowed(['Basic', 'Free', 'Premium', 'Standard'])
param skuTier string = 'Basic'
@description('Public network access setting')
@allowed(['Enabled','Disabled'])
param publicNetworkAccess string = 'Enabled'
param location string = resourceGroup().location
param tags object = {}

resource project 'Microsoft.MachineLearningServices/workspaces@2024-01-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: displayName
    hbiWorkspace: false
    v1LegacyMode: false
    publicNetworkAccess: publicNetworkAccess
    hubResourceId: hubName
  }
}

module keyVaultAccess '../security/keyvault-access.bicep' = {
  name: 'keyvault-access'
  params: {
    keyVaultName: keyVaultName
    principalId: project.identity.principalId
  }
}

output id string = project.id
output name string = project.name
output principalId string = project.identity.principalId
output discoveryUrl string = project.properties.discoveryUrl
