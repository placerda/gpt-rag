@description('Location for the AI Foundry Hub')
param location string

@description('Tags to apply to resources')
param tags object

@description('Name of the AI Foundry Hub')
param hubName string

@description('Key Vault name to associate with the Hub')
param keyVaultName string

@description('Storage Account name to associate with the Hub')
param storageAccountName string

@description('Application Insights resource name')
param applicationInsightsName string

resource hub 'Microsoft.MachineLearningServices/workspaces@2025-01-01-preview' = {
  name: hubName
  location: location
  tags: tags  
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: hubName
    storageAccount: resourceId('Microsoft.Storage/storageAccounts', storageAccountName)
    keyVault: resourceId('Microsoft.KeyVault/vaults', keyVaultName)
    applicationInsights: resourceId('Microsoft.Insights/components', applicationInsightsName)
    hbiWorkspace: false
    managedNetwork: {
      isolationMode: 'Disabled'
    }
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
    discoveryUrl: 'https://${location}.api.azureml.ms/discovery'
  }
}

output hubName string = hub.name
output hubId string = hub.id
output hubDiscoveryUrl string = hub.properties.discoveryUrl
output systemAssignedMIPrincipalId string = hub.identity.principalId
