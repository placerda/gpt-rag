@description('Creates an Azure App Service in an existing App Service Plan.')
param name string
param location string = resourceGroup().location
param tags object = {}

@description('Startup command for the app (e.g., uvicorn line for FastAPI)')
param appCommandLine string = ''

@description('Set to true to enable build during deployment (SCM_DO_BUILD_DURING_DEPLOYMENT)')
param scmDoBuildDuringDeployment bool = true


@description('Application Insights resource name (optional).')
param applicationInsightsName string = ''

@description('The App Service Plan ID for the App Service.')
param appServicePlanId string

@description('Key Vault name (optional).')
param keyVaultName string = ''

@description('Runtime name (e.g., python)')
param runtimeName string
@description('Runtime version (e.g., 3.12)')
param runtimeVersion string
var runtimeNameAndVersion = '${runtimeName}|${runtimeVersion}'

@description('Custom app settings for the App Service.')
@secure()
param appSettings object = {}

@description('Allowed origins for CORS.')
param allowedOrigins array = []

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      linuxFxVersion: runtimeNameAndVersion
      alwaysOn: true
      appSettings: union(appSettings, {
        'SCM_DO_BUILD_DURING_DEPLOYMENT': string(scmDoBuildDuringDeployment)
      })
      cors: {
        allowedOrigins: allowedOrigins
      }
      appCommandLine: appCommandLine
    }
    httpsOnly: true
  }
}

output id string = appService.id
output name string = appService.name
output uri string = 'https://${appService.properties.defaultHostName}'
output identityPrincipalId string = appService.identity.principalId
