@description('Location for resource deployments.')
param location string = resourceGroup().location
@description('Tags to apply to resources.')
param tags object = {}

@description('Name of the Key Vault')
param keyVaultName string
@description('Name of the Storage Account')
param storageAccountName string
@description('Name of the AI Services account')
param aiServicesName string
@description('Array of AI Service model deployments')
param aiServiceModelDeployments array = []
@description('Name of the Log Analytics workspace')
param logAnalyticsName string = ''
@description('Name of the Application Insights instance')
param applicationInsightsName string = ''
@description('Name of the Azure Search service')
param searchServiceName string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource aiService 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: aiServicesName
}

resource searchService 'Microsoft.Search/searchServices@2021-04-01-preview' existing = {
  name: searchServiceName
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVaultName
output storageAccountId string = storageAccount.id
// For simplicity, Application Insights is handled separately.
output applicationInsightsId string = ''
output aiServicesName string = aiService.name
output searchServiceName string = searchService.name
