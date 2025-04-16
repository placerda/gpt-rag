@description('Creates an Azure App Service Plan.')
param name string
param location string = resourceGroup().location
param tags object = {}

@description('Kind of App Service Plan (e.g., linux)')
param kind string = 'linux'
@description('Whether the plan is reserved (Linux)')
param reserved bool = true
@description('SKU details for the App Service Plan')
param sku object

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  sku: sku
  properties: {
    reserved: reserved
  }
}

output id string = appServicePlan.id
output name string = appServicePlan.name
