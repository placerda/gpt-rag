@description('The AI Foundry Hub resource name')
param name string
@description('The display name of the AI Foundry Hub')
param displayName string = name
@description('The Storage Account ID to use for the Hub')
param storageAccountId string
@description('The Key Vault ID to use for the Hub')
param keyVaultId string
@description('Application Insights ID (optional)')
param applicationInsightsId string = ''
@description('The AI Services account name')
param aiServicesName string
@description('The AI Services connection name')
param aiServicesConnectionName string
@description('The AI Services content safety connection name')
param aiServicesContentSafetyConnectionName string
@description('The Azure Cognitive Search service name')
param aiSearchName string = ''
@description('The Azure Cognitive Search connection name')
param aiSearchConnectionName string
@description('SKU name to use for the Hub')
param skuName string = 'Basic'
@description('SKU tier to use for the Hub')
@allowed(['Basic', 'Free', 'Premium', 'Standard'])
param skuTier string = 'Basic'
@description('Public network access setting')
@allowed(['Enabled','Disabled'])
param publicNetworkAccess string = 'Enabled'
param location string = resourceGroup().location
param tags object = {}

resource hub 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: displayName
    storageAccount: storageAccountId
    keyVault: keyVaultId
    applicationInsights: empty(applicationInsightsId) ? null : applicationInsightsId
    containerRegistry: null
    hbiWorkspace: false
    managedNetwork: {
      isolationMode: 'Disabled'
    }
    v1LegacyMode: false
    publicNetworkAccess: publicNetworkAccess
  }
  
  resource aiServiceConnection 'connections' = {
    name: aiServicesConnectionName
    properties: {
      category: 'AIServices'
      authType: 'ApiKey'
      isSharedToAll: true
      target: 'REPLACE_WITH_AI_SERVICE_ENDPOINT'
      metadata: {
        ApiVersion: '2023-07-01-preview'
        ApiType: 'azure'
        ResourceId: 'REPLACE_WITH_AI_SERVICE_ID'
      }
      credentials: {
        key: 'REPLACE_WITH_AI_SERVICE_KEY'
      }
    }
  }
  
  resource contentSafetyConnection 'connections' = {
    name: aiServicesContentSafetyConnectionName
    properties: {
      category: 'AzureOpenAI'
      authType: 'ApiKey'
      isSharedToAll: true
      target: 'REPLACE_WITH_CONTENT_SAFETY_ENDPOINT'
      metadata: {
        ApiVersion: '2023-07-01-preview'
        ApiType: 'azure'
        ResourceId: 'REPLACE_WITH_AI_SERVICE_ID'
      }
      credentials: {
        key: 'REPLACE_WITH_AI_SERVICE_KEY'
      }
    }
  }
  
  resource searchConnection 'connections' = if (!empty(aiSearchName)) {
    name: aiSearchConnectionName
    properties: {
      category: 'CognitiveSearch'
      authType: 'ApiKey'
      isSharedToAll: true
      target: 'https://${aiSearchName}.search.windows.net/'
      credentials: {
        key: 'REPLACE_WITH_SEARCH_KEY'
      }
    }
  }
}

output id string = hub.id
output name string = hub.name
output principalId string = hub.identity.principalId
