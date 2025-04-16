@description('Creates an Azure Cognitive Services instance for AI services.')
param name string
param location string = resourceGroup().location
param tags object = {}

@description('Custom subdomain name used to access the API. Defaults to the value of the name parameter.')
param customSubDomainName string = name
@description('Disable local authentication?')
param disableLocalAuth bool = false
@description('Array of model deployments for AI services.')
param deployments array = []
@description('The kind of Cognitive Services account to create. Typically "OpenAI" or "AIServices".')
param kind string = 'OpenAI'
@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'
@description('SKU for the Cognitive Services account.')
param sku object = {
  name: 'S0'
}
@description('Allowed IP rules for network ACLs (optional).')
param allowedIpRules array = []
var networkAcls = empty(allowedIpRules) ? {
  defaultAction: 'Allow'
} : {
  ipRules: allowedIpRules
  defaultAction: 'Deny'
}

resource cognitiveAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    networkAcls: networkAcls
    disableLocalAuth: disableLocalAuth
  }
  sku: sku
}

@batchSize(1)
resource deploymentResources 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for dep in deployments: {
  parent: cognitiveAccount
  name: dep.name
  properties: {
    model: dep.model
    raiPolicyName: contains(dep, 'raiPolicyName') ? dep.raiPolicyName : null
  }
  sku: contains(dep, 'sku') ? dep.sku : {
    name: 'Standard'
    capacity: 20
  }
}]

output endpoint string = cognitiveAccount.properties.endpoint
output endpoints object = cognitiveAccount.properties.endpoints
output id string = cognitiveAccount.id
output name string = cognitiveAccount.name
