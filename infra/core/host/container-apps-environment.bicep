@description('Creates an Azure Container Apps environment.')
param name string
param location string = resourceGroup().location
param tags object = {}

@description('Name of the Log Analytics workspace.')
param logAnalyticsWorkspaceName string
@description('Name of the Application Insights resource (optional).')
param applicationInsightsName string = ''

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    daprAIInstrumentationKey: empty(applicationInsightsName) ? '' : applicationInsights.properties.InstrumentationKey
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if(!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output id string = containerAppsEnvironment.id
output name string = containerAppsEnvironment.name
