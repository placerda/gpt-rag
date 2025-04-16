@description('Creates an Azure AI Search instance.')
param name string
param location string = resourceGroup().location
param tags object = {}

@description('SKU details for the search service.')
param sku object = {
  name: 'standard'
}

@description('Authentication options for the search service.')
param authOptions object = {}

@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'

resource search 'Microsoft.Search/searchServices@2021-04-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    authOptions: authOptions
    publicNetworkAccess: publicNetworkAccess
    partitionCount: 1
    replicaCount: 1
    semanticSearch: 'disabled'
  }
  sku: sku
}

output id string = search.id
output endpoint string = 'https://${name}.search.windows.net/'
output name string = search.name
output principalId string = search.identity != null ? search.identity.principalId : ''
