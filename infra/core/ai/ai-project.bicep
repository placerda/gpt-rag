@description('Location of the AI Studio Project')
param location string

@description('Tags to apply to the AI Studio Project')
param tags object

@description('Name of the AI Studio Project')
param projectName string

@description('Resource ID of the associated AI Hub')
param hubResourceId string

@description('Discovery URL of the AI Hub (optional)')
param discoveryUrl string = ''

resource AIProject 'Microsoft.MachineLearningServices/workspaces@2025-01-01-preview' = {
  name: projectName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: projectName
    hbiWorkspace: false
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
    discoveryUrl: empty(discoveryUrl) ? 'https://${location}.api.azureml.ms/discovery' : discoveryUrl
    hubResourceId: hubResourceId
    
  }
}

output projectName string = AIProject.name
output projectId string = AIProject.id
output projectDiscoveryUrl string = AIProject.properties.discoveryUrl

var projectEndpoint = replace(replace(AIProject.properties.discoveryUrl, 'https://', ''), '/discovery', '')
output projectConnectionString string = '${projectEndpoint};${subscription().subscriptionId};${resourceGroup().name};${AIProject.name}'
output systemAssignedMIPrincipalId string = AIProject.identity.principalId
