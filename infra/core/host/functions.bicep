@description('Creates an Azure Function App in an existing App Service Plan.')
param name string
@description('The resource group where the Function App is deployed.')
param functionAppResourceGroupName string
@description('Location for the Function App.')
param location string = resourceGroup().location
param tags object = {}

@description('If true, reuses an existing Function App.')
param functionAppReuse bool = false

@description('The App Service Plan ID for the Function App.')
param appServicePlanId string

@description('Runtime name (e.g., python)')
param runtimeName string
@description('Runtime version (e.g., 3.11)')
param runtimeVersion string
var runtimeNameAndVersion = '${runtimeName}|${runtimeVersion}'

@description('Custom app settings for the Function App.')
param appSettings array = []

resource funcApp 'Microsoft.Web/sites@2022-03-01' = if (!functionAppReuse) {
  name: name
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      linuxFxVersion: runtimeNameAndVersion
      alwaysOn: true
      appSettings: appSettings
    }
    httpsOnly: true
  }
}

resource existingFuncApp 'Microsoft.Web/sites@2022-03-01' existing = if (functionAppReuse) {
  name: name
}

output id string = functionAppReuse ? existingFuncApp.id : funcApp.id
output name string = functionAppReuse ? existingFuncApp.name : funcApp.name
output uri string = functionAppReuse ? 'https://${existingFuncApp.properties.defaultHostName}' : 'https://${funcApp.properties.defaultHostName}'
output identityPrincipalId string = functionAppReuse ? existingFuncApp.identity.principalId : funcApp.identity.principalId
