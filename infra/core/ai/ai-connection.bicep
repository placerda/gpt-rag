targetScope = 'resourceGroup'

@description('Name of the existing AI Foundry Project (workspace)')
param projectName string

@description('Connection resource name (3-32 chars, alphanumeric/_/-)')
param connectionName string

@description('Connection category (e.g. "CognitiveSearch", "AzureOpenAI")')
param category string

@description('Resource ID of the target service to connect')
param targetResourceId string

@description('Share this connection across all projects?')
param isSharedToAll bool = false

@description('Authentication type ("ManagedIdentity" or "ServicePrincipal")')
param authType string = 'ManagedIdentity'

@description('Use the workspace\'s managed identity for auth')
param useWorkspaceManagedIdentity bool = true

// Reference the existing AI Foundry Project workspace
resource existingProject 'Microsoft.MachineLearningServices/workspaces@2025-01-01-preview' existing = {
  name: projectName
}

// Create the connection under the project
resource aiConnection 'Microsoft.MachineLearningServices/workspaces/connections@2025-01-01-preview' = {
  parent: existingProject
  name: connectionName
  properties: {
    category: category
    target: targetResourceId
    isSharedToAll: isSharedToAll
    authType: authType
    useWorkspaceManagedIdentity: useWorkspaceManagedIdentity
  }
}
