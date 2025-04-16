@description('Location for AI environment resources')
param location string

@description('Tags to apply to resources')
param tags object = {}

@description('The AI Hub resource name')
param hubName string

@description('The AI Project resource name')
param projectName string

@description('The Key Vault resource name')
param keyVaultName string

@description('The Storage Account resource name to use in the AI Hub')
param storageAccountName string

@description('The AI Services account name')
param aiServicesName string

@description('The AI Services connection name')
param aiServicesConnectionName string

@description('The AI Services content safety connection name')
param aiServicesContentSafetyConnectionName string

@description('The Log Analytics workspace resource name')
param logAnalyticsName string

@description('The Application Insights resource name')
param applicationInsightsName string

@description('The Azure Search service name')
param searchServiceName string

@description('The Azure Search connection name')
param searchConnectionName string

// Call the dependencies module from the correct relative path.
// (Assumes that hub-dependencies.bicep is located in ../ai/)
module hubDependencies '../ai/hub-dependencies.bicep' = {
  name: 'hubDependencies'
  params: {
    location: location
    tags: tags
    keyVaultName: keyVaultName
    storageAccountName: storageAccountName
    aiServicesName: aiServicesName
    aiServiceModelDeployments: [] // Pass deployments as needed.
    logAnalyticsName: logAnalyticsName
    applicationInsightsName: applicationInsightsName
    searchServiceName: searchServiceName
  }
}

// Deploy the AI Hub using the outputs of the dependencies module.
// (Assumes hub.bicep is located in ../ai/)
module hub '../ai/hub.bicep' = {
  name: 'hub'
  params: {
    location: location
    tags: tags
    name: hubName
    displayName: hubName
    keyVaultId: hubDependencies.outputs.keyVaultId
    storageAccountId: hubDependencies.outputs.storageAccountId
    applicationInsightsId: hubDependencies.outputs.applicationInsightsId
    aiServicesName: aiServicesName
    aiServicesConnectionName: aiServicesConnectionName
    aiServicesContentSafetyConnectionName: aiServicesContentSafetyConnectionName
    aiSearchName: hubDependencies.outputs.searchServiceName
    aiSearchConnectionName: searchConnectionName
  }
}

// Create the AI project within the hub.
// (Assumes project.bicep is located in ../ai/)
module project '../ai/project.bicep' = {
  name: 'project'
  params: {
    location: location
    tags: tags
    name: projectName
    displayName: projectName
    hubName: hub.outputs.name
    keyVaultName: hubDependencies.outputs.keyVaultName
  }
}

output hubId string = hub.outputs.id
output discoveryUrl string = project.outputs.discoveryUrl
