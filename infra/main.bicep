// Deployment Template using Azure Verified Modules (AVM)
// Reference: https://azure.github.io/Azure-Verified-Modules/indexes/bicep/bicep-resource-modules/
targetScope = 'resourceGroup'

//////////////////////////////////////////////////////////////////////////
// PARAMETERS
//////////////////////////////////////////////////////////////////////////

// NOTE: Set parameter values using environment variables defined in main.parameters.json

// ----------------------------------------------------------------------
// General Parameters
// ----------------------------------------------------------------------

param environmentName                      string = '' // Environment name for tagging resources.
param location                             string        // Primary deployment location.
param deploymentTags                       object        // Tags applied to all resources.
param principalId                          string        // Principal ID for role assignments.
param configureRBAC                        string = ''   // Assign RBAC roles to resources.

// ----------------------------------------------------------------------
// Reuse Parameters
// ----------------------------------------------------------------------

// Foundry Hub
param AIFoundryHubReuse                    string = ''
param existingAIFoundryHubResourceGroupName string = ''
param existingAIFoundryHubName             string = ''

// Azure AI Search
param reuseSearch                          string = ''
param existingSearchResourceGroup          string = ''
param existingSearchName                   string = ''

// AI Services
param reuseAIServices                      string = ''
param existingAIServicesResourceGroup      string = ''
param existingAIServicesName               string = ''

// Azure OpenAI
param reuseAOAI                            string = ''
param existingAOAIResourceGroup            string = ''
param existingAOAIName                     string = ''

// API Management
param reuseAPIM                            string = ''
param existingAPIMResourceGroup            string = ''
param existingAPIMName                     string = ''

// ----------------------------------------------------------------------
// Resource Naming (Empty = auto-generated unique name)
// ----------------------------------------------------------------------

param AIFoundryStorageAccountName          string = ''
param AIHubName                            string = ''
param AIProjectName                        string = ''
param AIServicesName                       string = ''
param apimResourceName                     string = ''
param appConfigName                        string = ''
param appInsightsName                      string = ''
param containerEnvName                     string = ''
param containerRegistryName                string = ''
param conversationContainerName            string = ''
param dataIngestContainerAppName           string = ''
param dataIngestContainerImage             string = ''
param datasourcesContainerName             string = ''
param dbAccountName                        string = ''
param dbDatabaseName                       string = ''
param frontEndContainerAppName             string = ''
param frontEndContainerImage               string = ''
param keyVaultName                         string = ''
param logAnalyticsWorkspaceName            string = ''
param orchestratorContainerAppName         string = ''
param orchestratorImage                    string = ''
param searchIndexName                      string = ''
param searchServiceName                    string = ''
param solutionStorageAccountName           string = ''
param storageAccountContainerDocs          string = ''
param storageAccountContainerImages        string = ''

// ----------------------------------------------------------------------
// API Management Configuration
// ----------------------------------------------------------------------

param apimPublisherEmail                   string = ''
param apimPublisherName                    string = ''
param apimSku                              string = ''
param openAIAPIName                        string = ''
param openAIAPIDisplayName                 string = ''
param openAIAPISpecURL                     string = ''
param openAIAPIPath                        string = ''

// ----------------------------------------------------------------------
// API Versions
// ----------------------------------------------------------------------

param documentIntelligenceAPIVersion       string = ''
param openAIAPIVersion                     string = ''
param searchAPIVersion                     string = ''

// ----------------------------------------------------------------------
// Chat Model Configuration
// ----------------------------------------------------------------------

param chatDeploymentCapacity               string = ''
param chatDeploymentName                   string = ''
param chatModelDeploymentType              string = '' // 'Standard', 'ProvisionedManaged', 'GlobalStandard'
param chatModelName                        string = '' // e.g., 'gpt-35-turbo', 'gpt-4', 'gpt-4o'
param chatModelVersion                     string = '' // e.g., '1106', '0125-preview', '2024-11-20'

// ----------------------------------------------------------------------
// Embeddings Model Configuration
// ----------------------------------------------------------------------

param embeddingsDeploymentCapacity         string = ''
param embeddingsDeploymentName             string = ''
param embeddingsDeploymentType             string = ''
param embeddingsModelName                  string = ''
param embeddingsModelVersion               string = '' // e.g., '1', '2'
param embeddingsVectorDimensions           string = ''

// ----------------------------------------------------------------------
// Chunking Configuration
// ----------------------------------------------------------------------

param chunkingMinChunkSize                 string = ''
param chunkingNumTokens                    string = ''
param chunkingTokenOverlap                 string = ''
param chatNumTokens                        string = ''


//////////////////////////////////////////////////////////////////////////
// VARIABLES
//////////////////////////////////////////////////////////////////////////

// Fallback “effective” values for every string parameter

// General variables
var resourceToken       = toLower(uniqueString(subscription().id, environmentName, location))
var tags                = union({ env: _environmentName }, deploymentTags)
var _environmentName    = empty(environmentName)                      ? 'dev'                                    : environmentName
var _location           = empty(location)                             ? 'eastus2'                                : location
var _principalId        = empty(principalId)                          ? ''                                       : principalId
var _configureRBAC      = !empty(configureRBAC) && toLower(configureRBAC)  == 'true'

// Reuse Existing Resources (Optional)
var _reuseSearch        = !empty(reuseSearch)       && toLower(reuseSearch)         == 'true'
var _reuseAIServices    = !empty(reuseAIServices)   && toLower(reuseAIServices)     == 'true'
var _reuseAIFoundryHub  = !empty(AIFoundryHubReuse) && toLower(AIFoundryHubReuse)   == 'true'
var _reuseAPIM          = !empty(reuseAPIM)         && toLower(reuseAPIM)           == 'true'
var _reuseAOAI          = !empty(reuseAOAI)         && toLower(reuseAOAI)           == 'true'

var _existingSearchResourceGroup           = empty(existingSearchResourceGroup)           ? 'set-existing-search-resource-group'           : existingSearchResourceGroup
var _existingSearchName                    = empty(existingSearchName)                    ? 'set-existing-search-name'                     : existingSearchName
var _existingAIServicesResourceGroup       = empty(existingAIServicesResourceGroup)       ? 'set-existing-ai-services-resource-group'      : existingAIServicesResourceGroup
var _existingAIServicesName                = empty(existingAIServicesName)                ? 'set-existing-ai-services-name'                : existingAIServicesName
var _existingAIFoundryHubResourceGroup     = empty(existingAIFoundryHubResourceGroupName) ? 'set-existing-foundry-hub-resource-group-name' : existingAIFoundryHubResourceGroupName
var _existingAIFoundryHubName              = empty(existingAIFoundryHubName)              ? 'set-existing-foundry-hub-name'                : existingAIFoundryHubName
var _existingAPIMResourceGroup             = empty(existingAPIMResourceGroup)             ? 'set-existing-apim-resource-group'             : existingAPIMResourceGroup
var _existingAPIMName                      = empty(existingAPIMName)                      ? 'set-existing-apim-name'                        : existingAPIMName
var _existingAOAIResourceGroup            = empty(existingAOAIResourceGroup)              ? 'set-existing-aoai-resource-group'             : existingAOAIResourceGroup
var _existingAOAIName                     = empty(existingAOAIName)                       ? 'set-existing-aoai-name'                      : existingAOAIName

// AI Services
var _AIHubName                         = empty(AIHubName)                            ? '${abbrs.aiHub}-${resourceToken}'                  : AIHubName
var _AIProjectName                     = empty(AIProjectName)                        ? '${abbrs.aiProject}-${resourceToken}'              : AIProjectName
var _aiServicesName                    = empty(AIServicesName)                       ? '${abbrs.cognitiveServicesAccounts}-${resourceToken}' : AIServicesName
var _aiFoundryStorageAccountName       = empty(AIFoundryStorageAccountName)           ? '${abbrs.storageStorageAccounts}aihub0${resourceToken}' : AIFoundryStorageAccountName

// App Configuration and Infrastructure
var _appConfigName                     = empty(appConfigName)                        ? '${abbrs.appConfigurationStores}-${resourceToken}' : appConfigName
var _solutionStorageAccountName        = empty(solutionStorageAccountName)           ? '${abbrs.storageStorageAccounts}gptrag0${resourceToken}' : solutionStorageAccountName
var _containerRegistryName             = empty(containerRegistryName)                ? '${abbrs.containerRegistries}${resourceToken}' : containerRegistryName
var _containerEnvName                  = empty(containerEnvName)                     ? '${abbrs.containerEnvs}${resourceToken}' : containerEnvName
var _keyVaultName                      = empty(keyVaultName)                         ? '${abbrs.keyVaultVaults}-${resourceToken}' : keyVaultName
var _logAnalyticsWorkspaceName         = empty(logAnalyticsWorkspaceName)            ? '${abbrs.operationalInsightsWorkspaces}-${resourceToken}' : logAnalyticsWorkspaceName
var _appInsightsName                   = empty(appInsightsName)                      ? '${abbrs.insightsComponents}-${resourceToken}' : appInsightsName

// Search Service and Storage
var _searchServiceName                 = empty(searchServiceName)                    ? '${abbrs.searchSearchServices}-${resourceToken}' : searchServiceName
var _searchIndexName                   = empty(searchIndexName)                      ? 'ragindex'                               : searchIndexName
var _storageAccountContainerDocs       = empty(storageAccountContainerDocs)          ? 'documents'                              : storageAccountContainerDocs
var _storageAccountContainerImages     = empty(storageAccountContainerImages)        ? 'documents-images'                       : storageAccountContainerImages

// OpenAI API Configuration
var _openAIAPIName                     = empty(openAIAPIName)                        ? 'openai'                                 : openAIAPIName
var _openAIAPIPath                     = empty(openAIAPIPath)                        ? 'openai'                                 : openAIAPIPath
var _openAIAPIDisplayName              = empty(openAIAPIDisplayName)                 ? 'OpenAI'                                 : openAIAPIDisplayName
var _openAIAPISpecURL                  = empty(openAIAPISpecURL)                     ? 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json' : openAIAPISpecURL
var _openAIAPIVersion                  = empty(openAIAPIVersion)                     ? '2024-10-21'                             : openAIAPIVersion

// APIM Configuration
var _apimSku                           = empty(apimSku)                              ? 'Consumption'                            : apimSku
var _apimPublisherEmail                = empty(apimPublisherEmail)                   ? 'noreply@example.com'                    : apimPublisherEmail
var _apimPublisherName                 = empty(apimPublisherName)                    ? 'MyCompany'                              : apimPublisherName
var _apimResourceName                  = empty(apimResourceName)                     ? '${abbrs.apiManagementService}-${resourceToken}' : apimResourceName

// Cosmos DB Configuration
var _dbAccountName                     = empty(dbAccountName)                        ? '${abbrs.cosmosDbAccount}-${resourceToken}' : dbAccountName
var _dbDatabaseName                    = empty(dbDatabaseName)                       ? '${abbrs.cosmosDbDatabase}-${resourceToken}' : dbDatabaseName
var _conversationContainerName         = empty(conversationContainerName)            ? 'conversations'                          : conversationContainerName
var _datasourcesContainerName          = empty(datasourcesContainerName)             ? 'datasources'                            : datasourcesContainerName

// Container Apps and Images
var _orchestratorContainerAppName      = empty(orchestratorContainerAppName)          ? 'orchestrator-${resourceToken}'           : orchestratorContainerAppName
var _orchestratorImage                 = empty(orchestratorImage)                    ? '${registry.outputs.loginServer}/orchestrator:latest' : orchestratorImage
var _dataIngestContainerAppName        = empty(dataIngestContainerAppName)            ? 'dataingest-${resourceToken}'             : dataIngestContainerAppName
var _dataIngestContainerImage          = empty(dataIngestContainerImage)              ? '${registry.outputs.loginServer}/data-ingest:latest' : dataIngestContainerImage
var _frontEndContainerAppName          = empty(frontEndContainerAppName)              ? 'frontend-${resourceToken}'               : frontEndContainerAppName
var _frontEndContainerImage            = empty(frontEndContainerImage)                ? '${registry.outputs.loginServer}/front-end:latest' : frontEndContainerImage

// Chat Model Configuration
var _chatModelName                     = empty(chatModelName)                        ? 'gpt-4o-mini'                            : chatModelName
var _chatModelDeploymentType           = empty(chatModelDeploymentType)               ? 'GlobalStandard'                         : chatModelDeploymentType
var _chatModelVersion                  = empty(chatModelVersion)                     ? '2024-07-18'                             : chatModelVersion
var _chatDeploymentName                = empty(chatDeploymentName)                   ? 'chat'                                   : chatDeploymentName
var _chatNumTokens                     = empty(chatNumTokens)                        ? '2048'                                   : chatNumTokens
var _chatDeploymentCapacity            = empty(chatDeploymentCapacity)               ? 120                                      : int(chatDeploymentCapacity)

// Embeddings Model Configuration
var _embeddingsModelName               = empty(embeddingsModelName)                   ? 'text-embedding-3-large'                  : embeddingsModelName
var _embeddingsModelVersion            = empty(embeddingsModelVersion)                ? '1'                                       : embeddingsModelVersion
var _embeddingsDeploymentName          = empty(embeddingsDeploymentName)              ? 'text-embedding'                          : embeddingsDeploymentName
var _embeddingsDeploymentType          = empty(embeddingsDeploymentType)              ? 'Standard'                                : embeddingsDeploymentType
var _embeddingsVectorDimensions        = empty(embeddingsVectorDimensions)            ? '3072'                                    : embeddingsVectorDimensions
var _embeddingsDeploymentCapacity      = empty(embeddingsDeploymentCapacity)          ? 120                                       : int(embeddingsDeploymentCapacity)

// Chunking and Search API
var _chunkingMinChunkSize              = empty(chunkingMinChunkSize)                  ? '100'                                     : chunkingMinChunkSize
var _chunkingNumTokens                 = empty(chunkingNumTokens)                     ? '2048'                                    : chunkingNumTokens
var _chunkingTokenOverlap              = empty(chunkingTokenOverlap)                  ? '200'                                     : chunkingTokenOverlap
var _searchAPIVersion                  = empty(searchAPIVersion)                      ? '2024-07-01'                              : searchAPIVersion

// Document Intelligence
var _documentIntelligenceAPIVersion    = empty(documentIntelligenceAPIVersion)        ? '2024-11-30'                              : documentIntelligenceAPIVersion


// Abbreviation dictionary
var abbrs = {
  resourcesResourceGroups: 'rg'
  insightsComponents: 'appins'
  keyVaultVaults: 'kv'
  storageStorageAccounts: 'st'
  operationalInsightsWorkspaces: 'log'
  searchSearchServices: 'search'
  appConfigurationStores: 'appconfig'
  containerRegistries: 'cr'
  containerEnvs: 'ace'
  cognitiveServicesAccounts: 'ai-services'
  aiProject: 'ai-project'
  aiHub: 'ai-hub'
  apiManagementService: 'apim'
  openaiServices: 'oai'
  cosmosDbAccount: 'db-account'
  cosmosDbDatabase: 'database'
}

//////////////////////////////////////////////////////////////////////////
// MODULES 
//////////////////////////////////////////////////////////////////////////

// Log Analytics Workspace
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: 'logAnalyticsModule'
  params: {
    name:          _logAnalyticsWorkspaceName
    location:      _location
    skuName:       'PerGB2018'  // updated
    dataRetention: 30           // updated
    tags:          tags
  }
}

// Application Insights
module appInsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: 'appInsightsModule'
  params: {
    name:                _appInsightsName
    location:            _location
    workspaceResourceId: logAnalytics.outputs.resourceId
    applicationType:     'web'
    kind:                'web'
    disableIpMasking:    false
    tags:                tags
  }
}

// Key Vault
module keyVault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: 'keyVaultModule'
  params: {
    name:                  _keyVaultName
    location:              _location
    sku:                   'standard'
    enableRbacAuthorization: true
    tags:                  tags
    // Role assignment: Principal ← Key Vault Contributor (Key Vault)
    //                  Data Ingest Container App ← Key Vault Secrets User (Key Vault)
    //                  Orchestrator Container App ← Key Vault Secrets User (Key Vault)
    //                  Front End Container App ← Key Vault Secrets User (Key Vault)
    roleAssignments: _configureRBAC ? [
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'Key Vault Contributor'
      }
      {
        principalId           : dataIngestContainerApp.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }      
      {
        principalId           : orchestratorContainerApp.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
      {
        principalId           : frontEndContainerApp.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
    ] : []    
  }
}

// Cosmos DB Account and Database
module databaseAccount 'br/public:avm/res/document-db/database-account:0.12.0' = {
  name: 'databaseAccountModule'
  params: {
    name:                   _dbAccountName  
    location:               _location
    locations: [
      {
        locationName:    _location  
        failoverPriority: 0   
        isZoneRedundant:  false 
      }
    ]
    
    // Role assignment: Orchestrator Container App ← Cosmos DB Built-in Data Contributor (Cosmos DB)
    sqlRoleAssignmentsPrincipalIds: _configureRBAC ? [orchestratorContainerApp.outputs.systemAssignedMIPrincipalId] : []
    sqlRoleDefinitions: _configureRBAC ? [{ name: 'Cosmos DB Built-in Data Contributor' }] : []

    defaultConsistencyLevel:'Session'
    capabilitiesToAdd: [
      'EnableServerless'
    ]
    tags:                   tags
    sqlDatabases: [
      {
        name:       _dbDatabaseName
        throughput: 400
        containers: [
          {
            name:       _conversationContainerName
            paths:      ['/id']
            defaultTtl: -1
            throughput: 400
          }
          {
            name:       _datasourcesContainerName
            paths:      ['/id']
            defaultTtl: -1
            throughput: 400
          }
        ]
      }
    ]
  }
}

// Azure AI Search Service
resource existingSearch 'Microsoft.Search/searchServices@2020-08-01' existing = if (_reuseSearch) {
  name: _existingSearchName
  scope: resourceGroup(_existingSearchResourceGroup)
}
module searchService 'br/public:avm/res/search/search-service:0.9.2' = if (!_reuseSearch) {
  name: 'searchServiceModule'
  params: {
    name: _searchServiceName
    location: _location
    // Tags
    tags: tags
    // SKU & capacity
    sku: 'standard'
    semanticSearch: 'disabled'
    managedIdentities : {
      systemAssigned: true
    }    
    // Role assignment: Data Ingest Container App ← Search Index Data Contributor (Search Service)
    //                  Orchestrator Container App ← Search Index Data Reader (Search Service)
    //                  Principal ← Search Index Data Reader (Search Service)
    roleAssignments: _configureRBAC ? [
      {
        principalId           : dataIngestContainerApp.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Search Index Data Contributor'
      }      
      {
        principalId           : orchestratorContainerApp.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Search Index Data Reader'
      }     
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'Search Index Data Reader'
      }                
    ] : []
  }
}

// AI Services (including OpenAI deployments)
resource existingAi 'Microsoft.CognitiveServices/accounts@2021-10-01' existing = if (_reuseAIServices) {
  name: _existingAIServicesName
  scope: resourceGroup(_existingAIServicesResourceGroup)
}
resource existingAoai 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = if (_reuseAOAI) {
  name: _existingAOAIName
  scope: resourceGroup(_existingAOAIResourceGroup)
}
module aiServices 'br/public:avm/res/cognitive-services/account:0.10.2' = if (!_reuseAIServices && !_reuseAOAI) {
  name: 'aiServicesModule'
  params: {
    kind:     'AIServices'
    name:     _aiServicesName
    location: _location
    sku:      'S0'
    tags:     tags
    deployments: [
      {
        name: _chatDeploymentName       
        model: {
          format:  'OpenAI'
          name:    _chatModelName
          version: _chatModelVersion
        }
        sku: {
          name:     _chatModelDeploymentType
          capacity: _chatDeploymentCapacity
        }
      }
      {
        name: _embeddingsDeploymentName      
        model: {
          format:  'OpenAI'
          name:    _embeddingsModelName
          version: _embeddingsModelVersion
        }
        sku: {
          name:     _embeddingsDeploymentType
          capacity: _embeddingsDeploymentCapacity
        }
      }
    ]
    // Role assignment: Data Ingest Container App ← Cognitive Services OpenAI User (AI Services)
    //                  Orchestrator Container App ← Cognitive Services OpenAI User (AI Services)
    //                  AI Search Container App ← Cognitive Services OpenAI User (AI Services)
    //                  Data Ingest Container App ← Cognitive Services User (AI Services)
    roleAssignments: _configureRBAC ? [
      {
        principalId           : searchService.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
      }
      {
        principalId           : dataIngestContainerApp.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
      }      
      {
        principalId           : orchestratorContainerApp.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
      }      
      {
        principalId           : dataIngestContainerApp.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services User'
      }     
    ] : []    
  }
}

var aoaiEndpoint = _reuseAOAI ? existingAoai.properties.endpoint : aiServices.outputs.endpoint

// Solution Storage Account
module solutionStorageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: 'solutionStorageModule'
  params: {
    name:                     _solutionStorageAccountName
    location:                 _location
    skuName:                  'Standard_LRS'
    kind:                     'StorageV2'
    allowBlobPublicAccess:    false
    supportsHttpsTrafficOnly: true
    tags:                     tags
    // Role assignment: Data Ingest Container App ← Storage Blob Data Contributor (Solution Storage Account)
    //                  Principal ← Storage Blob Data Contributor (Solution Storage Account)
    //                  Front End Container App ← Storage Blob Data Reader (Solution Storage Account)
    //                  Orchestrator Container App ← Storage Blob Data Reader (Solution Storage Account)
    //                  Search Service ← Storage Blob Data Reader (Solution Storage Account)

    roleAssignments: _configureRBAC ? [
      {
        principalId           : dataIngestContainerApp.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }      
      {
        principalId           : frontEndContainerApp.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Reader'
      }  
      {
        principalId           : orchestratorContainerApp.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Reader'
      }  
      {
        principalId           : searchService.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Reader'
      }                  
    ] : []     
  }
}

// API Management: reuse existing or deploy new
resource existingAPIM 'Microsoft.ApiManagement/service@2024-05-01' existing = if (_reuseAPIM) {
  name: _existingAPIMName
  scope: resourceGroup(_existingAPIMResourceGroup)
}

// API Management Service + AI Services API + Policy + Subscription
module apimService 'br/public:avm/res/api-management/service:0.9.1' = if (! _reuseAPIM) {
  name: 'apimModule'
  params: {
    name           : _apimResourceName
    location       : _location
    sku            : apimSku
    publisherName  : apimPublisherName
    publisherEmail : apimPublisherEmail
    tags           : tags

    managedIdentities : {
      systemAssigned: true
    }

    apis: [
      {
        name        : openAIAPIName
        displayName : openAIAPIDisplayName
        path        : openAIAPIPath
        format      : 'openapi-link'
        value       : openAIAPISpecURL
        serviceUrl  : aoaiEndpoint
      }
    ]

    policies: [
      {
        format: 'xml'
        value: loadTextContent('policies/apim-openai-policy.xml')
      }
    ]
  }
}

// AI Foundry Storage Account
module AIFoundryStorageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: 'aiFoundryStorageModule'
  params: {
    name:                     _aiFoundryStorageAccountName
    location:                 _location
    skuName:                  'Standard_LRS'
    kind:                     'StorageV2'
    allowBlobPublicAccess:    false
    supportsHttpsTrafficOnly: true
    tags:                     tags
    // Role assignment: Principal ← Storage Blob Data Contributor (AI Foundry Storage Account)
    roleAssignments: _configureRBAC ? [
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }                
    ] : []      
  }
}

// AI Foundry Hub (custom module)
module AIHub 'core/ai/ai-hub.bicep' = if (!_reuseAIFoundryHub) {
  name: 'aiHubModule'
  scope: resourceGroup()
  params: {
    location:              _location
    tags:                  tags
    hubName:               _AIHubName
    keyVaultName:          keyVault.outputs.name
    storageAccountName:    AIFoundryStorageAccount.outputs.name
    applicationInsightsName: appInsights.outputs.name    
  }
}
resource existingAIHub 'Microsoft.MachineLearningServices/workspaces@2025-01-01-preview' existing = if (_reuseAIFoundryHub) {
  name: _existingAIFoundryHubName
  scope: resourceGroup(_existingAIFoundryHubResourceGroup)
}

var _AIHubId = _reuseAIFoundryHub ? existingAIHub.id : AIHub.outputs.hubId
var _AIHubDiscoveryUrl = _reuseAIFoundryHub ? existingAIHub.properties.discoveryUrl : AIHub.outputs.hubDiscoveryUrl

// AI Foundry Project (custom module)
module AIProject 'core/ai/ai-project.bicep' = {
  name: 'aiProjectModule'
  scope: resourceGroup()
  params: {
    location:        _location
    tags:            tags
    projectName:     _AIProjectName
    hubResourceId:   _AIHubId
    discoveryUrl:    _AIHubDiscoveryUrl    
  }
}

// AI Foundry Connection (custom module): connect to Azure OpenAI *through*  API Management proxy
module connectOpenAIviaAPIM 'core/ai/ai-connection.bicep' = {
  name: 'connectOpenAIviaAPIM'
  params: {
    projectName               : _AIProjectName                    // from your aiProject module
    connectionName            : 'openai-via-apim'                 // must be 3–32 chars, alphanumeric/_/-
    category                  : 'AzureOpenAI'                     // Foundry’s Azure OpenAI category
    targetResourceId          : apimService.outputs.resourceId    // point at your APIM service
    isSharedToAll             : false
    authType                  : 'ManagedIdentity'
    useWorkspaceManagedIdentity: true
  }
}

// AI Foundry Connection (custom module): connect to multi‑service Cognitive (AI Services) account directly
module connectAIServices 'core/ai/ai-connection.bicep' = {
  name: 'connectAIServices'
  params: {
    projectName               : _AIProjectName
    connectionName            : 'aiservices-conn'
    category                  : 'AzureOpenAI'                 // or use the specific service category (e.g. AzureContentSafety, AzureSpeech)
    targetResourceId          : aiServices.outputs.resourceId // your Cognitive Services “AIServices” account
    isSharedToAll             : false
    authType                  : 'ManagedIdentity'
    useWorkspaceManagedIdentity: true
  }
}

// AI Foundry Connection (custom module): connect to Azure AI Search service
module connectSearch 'core/ai/ai-connection.bicep' = {
  name: 'connectSearch'
  params: {
    projectName               : _AIProjectName
    connectionName            : 'cognitive-search-conn'
    category                  : 'CognitiveSearch'
    targetResourceId          : searchService.outputs.resourceId
    isSharedToAll             : false
    authType                  : 'ManagedIdentity'
    useWorkspaceManagedIdentity: true
  }
}

// Container Apps Environment
module containerEnv 'br/public:avm/res/app/managed-environment:0.9.1' = {
  name: 'containerEnvModule'
  params: {
    name:     _containerEnvName
    location: _location
    tags:     tags
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
    zoneRedundant: false
  }
}

// App Configuration Store
module appConfig 'br/public:avm/res/app-configuration/configuration-store:0.6.3' = {
  name: 'appConfigModule'
  params: {
    name:     _appConfigName
    location: _location
    sku:      'Standard'
    tags:     tags
    dataPlaneProxy: {
      authenticationMode: 'Pass-through'
      privateLinkDelegation: 'Disabled'
    }
    // Role assignment: Principal ← App Configuration Data Owner (App Configuration)
    roleAssignments: _configureRBAC ? [
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'App Configuration Data Owner'
      }     
    ] : []    
  }
}

// Container Registry
module registry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: 'containerRegistryModule'
  params: {
    name:     _containerRegistryName
    location: _location
    acrSku:   'Basic'
    tags:     tags
  }
}


// Orchestrator Container App
module orchestratorContainerApp 'br/public:avm/res/app/container-app:0.16.0' = {
  name: 'orchestratorContainerAppModule'
  params: {
    name:                  _orchestratorContainerAppName
    location:              _location
    environmentResourceId: containerEnv.outputs.resourceId

    managedIdentities: {
      systemAssigned: true
    }

    containers: [
      {
        name     : 'orchestrator'
        image    : _orchestratorImage
        resources: {
          cpu    : '0.5'
          memory : '1.0Gi'
        }
        env: [
          {
            name  : 'APPCONFIG_ENDPOINT'
            value : appConfig.outputs.endpoint
          }
        ]
      }
    ]

    tags: tags
  }
}

// Data Ingestion Container App
module dataIngestContainerApp 'br/public:avm/res/app/container-app:0.16.0' = {
  name: 'dataIngestContainerApp'
  params: {
    name:                  _dataIngestContainerAppName
    location:              _location
    environmentResourceId: containerEnv.outputs.resourceId

    managedIdentities: {
      systemAssigned: true
    }

    containers: [
      {
        name     : 'dataingest'
        image    : _dataIngestContainerImage
        resources: {
          cpu    : '0.5'
          memory : '1.0Gi'
        }
        env: [
          {
            name  : 'APPCONFIG_ENDPOINT'
            value : appConfig.outputs.endpoint
          }
        ]
      }
    ]

    tags: union(tags, { 'azd-service-name': 'dataIngest' })
  }
}

// Front‑End Container App
module frontEndContainerApp 'br/public:avm/res/app/container-app:0.16.0' = {
  name: 'frontEndContainerAppModule'
  params: {
    name:                  _frontEndContainerAppName
    location:              _location
    environmentResourceId: containerEnv.outputs.resourceId

    managedIdentities: {
      systemAssigned: true
    }

    containers: [
      {
        name     : 'frontend'
        image    : _frontEndContainerImage
        resources: {
          cpu    : '0.5'
          memory : '1.0Gi'
        }
        env: [
          {
            name  : 'APPCONFIG_ENDPOINT'
            value : appConfig.outputs.endpoint
          }
        ]
      }
    ]

    tags: union(tags, { 'azd-service-name': 'frontend' })
  }
}

//////////////////////////////////////////////////////////////////////////
// ROLE ASSIGNMENTS
//////////////////////////////////////////////////////////////////////////

//Note: Role assignments are created separately to avoid circular dependencies

// Role assignment: APIM ← Cognitive Services OpenAI User (AI Services)
module grantOpenAIUserRoleToAPIM 'core/authorization/ai-services-role.bicep' = if (!_reuseAIServices && !_reuseAPIM && _configureRBAC) {
  name: 'grantOpenAIUserRoleToAPIM'
  params: {
    principalId        : apimService.outputs.systemAssignedMIPrincipalId
    resourceName       : aiServices.outputs.name
    roleDefinitionGuid : '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  }
}

// Role assignment: AI Hub ← Key Vault Secrets User (Key Vault)
module grantKVUserToAIHub 'core/authorization/keyvault-role.bicep' = if (_configureRBAC) {
  name: 'grantKVUserToAIHub'
  params: {
    principalId            : AIHub.outputs.systemAssignedMIPrincipalId
    vaultName              : keyVault.outputs.name
    roleDefinitionIdOrName : 'Key Vault Secrets User'
  }
}

// Role assignment: AI Project ← Key Vault Secrets User (Key Vault)
module grantKVUserToDataIngest 'core/authorization/keyvault-role.bicep' = if (_configureRBAC) {
  name: 'grantKVUserToDataIngest'
  params: {
    principalId            : AIProject.outputs.systemAssignedMIPrincipalId
    vaultName              : keyVault.outputs.name
    roleDefinitionIdOrName : 'Key Vault Secrets User'
  }
}

// Role assignment: AI Hub ← Storage Blob Data Contributor (AI Foundry Storage)
module grantAIFoundryStorageContributorToHub 'core/authorization/storage-account-role.bicep' = if (_configureRBAC) {
  name: 'grantAIFoundryStorageContributorToHub'
  params: {
    principalId            : AIHub.outputs.systemAssignedMIPrincipalId
    storageAccountName     : AIFoundryStorageAccount.outputs.name
    roleDefinitionIdOrName : 'Storage Blob Data Contributor'
  }
}

// Role assignment: AI Project ← Storage Blob Data Contributor (AI Foundry Storage)
module grantAiProjectStorageBlobDataContributor 'core/authorization/storage-account-role.bicep' = if (_configureRBAC) {
  name: 'grantAiProjectStorageBlobDataContributor'
  params: {
    principalId            : AIProject.outputs.systemAssignedMIPrincipalId
    storageAccountName     : AIFoundryStorageAccount.outputs.name
    roleDefinitionIdOrName : 'Storage Blob Data Contributor'
  }
}

// Role assignment: Orchestrator Container App ← App Configuration Data Reader (App Configuration)
module grantOrchestratorConfigDataReader 'core/authorization/app-configuration-role.bicep' = if (_configureRBAC) {
  name: 'grantOrchestratorConfigDataReader'
  params: {
    principalId            : orchestratorContainerApp.outputs.systemAssignedMIPrincipalId
    configStoreName        : AIFoundryStorageAccount.outputs.name
    roleDefinitionIdOrName : 'App Configuration Data Reader'
  }
}

// Role assignment: Frontend Container App ← App Configuration Data Reader (App Configuration)
module grantFrontendConfigDataReader 'core/authorization/app-configuration-role.bicep' = if (_configureRBAC) {
  name: 'grantFrontendConfigDataReader'
  params: {
    principalId            : frontEndContainerApp.outputs.systemAssignedMIPrincipalId
    configStoreName        : AIFoundryStorageAccount.outputs.name
    roleDefinitionIdOrName : 'App Configuration Data Reader'
  }
}

// Role assignment: Data Ingestion Container App ← App Configuration Data Reader (App Configuration)
module grantDataIngestConfigDataReader 'core/authorization/app-configuration-role.bicep' = if (_configureRBAC) {
  name: 'grantDataIngestConfigDataReader'
  params: {
    principalId            : dataIngestContainerApp.outputs.systemAssignedMIPrincipalId
    configStoreName        : AIFoundryStorageAccount.outputs.name
    roleDefinitionIdOrName : 'App Configuration Data Reader'
  }
}

// Role assignment: Principal ← AI Developer (AI Hub)
module grantPrincipalAiHubDeveloper 'core/authorization/ai-foundry-role.bicep' = if (_configureRBAC) {
  name: 'grantPrincipalAiHubDeveloper'
  params: {
    principalId            : _principalId
    workspaceName          : AIHub.outputs.hubName
    roleDefinitionIdOrName : 'AI Developer'
  }
}

// Role assignment: Principal ← AI Developer (AI Project)
module grantPrincipalAiProjectDeveloper 'core/authorization/ai-foundry-role.bicep' = if (_configureRBAC) {
  name: 'grantPrincipalAiProjectDeveloper'
  params: {
    principalId            : _principalId
    workspaceName          : AIProject.outputs.projectName
    roleDefinitionIdOrName : 'AI Developer'
  }
}

//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////

// Deployment context for all scripts
output AZURE_DEPLOYMENT_NAME                 string = deployment().name
output AZURE_LOCATION                        string = _location
output AZURE_RESOURCE_GROUP_NAME             string = resourceGroup().name
output AZURE_SUBSCRIPTION_ID                 string = subscription().subscriptionId
output AZURE_TENANT_ID                       string = tenant().tenantId
output CONFIGURE_RBAC                        string = string(_configureRBAC)

// App Config environment variables
output AZURE_AI_FOUNDRY_HUB_NAME                  string = _reuseAIFoundryHub ? _existingAIFoundryHubName : AIHub.outputs.hubName
output AZURE_AI_FOUNDRY_PROJECT_CONNECTION_STRING string = AIProject.outputs.projectConnectionString
output AZURE_AI_FOUNDRY_PROJECT_NAME              string = AIProject.outputs.projectName
output AZURE_AI_SERVICES_NAME                     string = _reuseAIServices ? _existingAIServicesName : aiServices.outputs.name
output AZURE_APIM_SERVICE_NAME                    string = _reuseAPIM ? existingAPIM.name : apimService.outputs.name
output AZURE_APIM_OPENAI_API_PATH                 string = _openAIAPIPath
output AZURE_APP_CONFIG_ENDPOINT                  string = appConfig.outputs.endpoint
output AZURE_APP_CONFIG_NAME                      string = appConfig.outputs.name
output AZURE_APP_INSIGHTS_NAME                    string = _appInsightsName
output AZURE_CONTAINER_REGISTRY_NAME              string = registry.outputs.name
output AZURE_DATABASE_ACCOUNT_NAME                string = _dbAccountName
output AZURE_DATABASE_CONVERSATION_CONTAINER_NAME string = _conversationContainerName
output AZURE_DATABASE_DATASOURCES_CONTAINER_NAME  string = _datasourcesContainerName
output AZURE_DATABASE_NAME                        string = _dbDatabaseName
output AZURE_DATA_INGEST_CONTAINER_APP_NAME       string = _dataIngestContainerAppName
output AZURE_DOC_INTELLIGENCE_API_VERSION         string = _documentIntelligenceAPIVersion
output AZURE_ENVIRONMENT_NAME                     string = _environmentName
output AZURE_FRONTEND_CONTAINER_APP_NAME          string = _frontEndContainerAppName
output AZURE_KEY_VAULT_NAME                       string = keyVault.outputs.name
output AZURE_OPENAI_API_VERSION                   string = _openAIAPIVersion
output AZURE_OPENAI_CHAT_MODEL_NAME               string = _chatModelName
output AZURE_OPENAI_EMBEDDING_DEPLOYMENT          string = _embeddingsDeploymentName
output AZURE_OPENAI_EMBEDDING_MODEL_NAME          string = _embeddingsModelName
output AZURE_OPENAI_SERVICE_NAME                  string = _reuseAIServices ? existingAi.name : aiServices.outputs.name
output AZURE_ORCHESTRATOR_CONTAINER_APP_NAME      string = _orchestratorContainerAppName
output AZURE_SEARCH_API_VERSION                   string = _searchAPIVersion
output AZURE_SEARCH_SERVICE_NAME                  string = _reuseSearch ? _existingSearchName : searchService.outputs.name
output AZURE_STORAGE_ACCOUNT_CONTAINER_DOCS       string = _storageAccountContainerDocs
output AZURE_STORAGE_ACCOUNT_CONTAINER_IMAGES     string = _storageAccountContainerImages
output AZURE_STORAGE_ACCOUNT_NAME                 string = _solutionStorageAccountName

// Reuse output
output AZURE_REUSE_AI_FOUNDRY_HUB                   string = string(_reuseAIFoundryHub)
output AZURE_EXISTING_AI_FOUNDRY_HUB_RESOURCE_GROUP string = _existingAIFoundryHubResourceGroup
output AZURE_EXISTING_AI_FOUNDRY_HUB_NAME           string = _existingAIFoundryHubName
output AZURE_REUSE_SEARCH                           string = string(_reuseSearch)
output AZURE_EXISTING_SEARCH_RESOURCE_GROUP         string = _existingSearchResourceGroup
output AZURE_EXISTING_SEARCH_NAME                   string = _existingSearchName
output AZURE_REUSE_AI_SERVICES                      string = string(_reuseAIServices)
output AZURE_EXISTING_AI_SERVICES_RESOURCE_GROUP    string = _existingAIServicesResourceGroup
output AZURE_EXISTING_AI_SERVICES_NAME              string = _existingAIServicesName
output AZURE_REUSE_AOAI                             string = string(_reuseAOAI)
output AZURE_EXISTING_AOAI_RESOURCE_GROUP           string = _existingAOAIResourceGroup
output AZURE_EXISTING_AOAI_NAME                     string = _existingAOAIName
output AZURE_REUSE_APIM                             string = string(_reuseAPIM)
output AZURE_EXISTING_APIM_RESOURCE_GROUP           string = _existingAPIMResourceGroup
output AZURE_EXISTING_APIM_NAME                     string = _existingAPIMName

// API Management (APIM)
output AZURE_APIM_OPENAI_API_DISPLAY_NAME         string = _openAIAPIDisplayName
output AZURE_APIM_OPENAI_API_NAME                  string = _openAIAPIName
output AZURE_APIM_OPENAI_API_SPEC_URL              string = _openAIAPISpecURL
output AZURE_APIM_PUBLISHER_EMAIL                  string = _apimPublisherEmail
output AZURE_APIM_PUBLISHER_NAME                   string = _apimPublisherName
output AZURE_APIM_SKU                              string = _apimSku

// Outputs for AI Hub and Foundry Storage
output AZURE_AI_FOUNDRY_STORAGE_ACCOUNT_NAME       string = _aiFoundryStorageAccountName
output AZURE_AI_HUB_NAME                           string = _reuseAIFoundryHub ? _existingAIFoundryHubName : AIHub.outputs.hubName
output AZURE_AI_PROJECT_NAME                       string = AIProject.outputs.projectName


//–– Dynamic AppConfig KV map (single source of truth)
output appConfigKVs object = {
  AZURE_AI_FOUNDRY_PROJECT_CONNECTION_STRING:  AIProject.outputs.projectConnectionString
  AZURE_AI_SERVICES_NAME                    : _reuseAIServices ? _existingAIServicesName : aiServices.outputs.name
  AZURE_APIM_OPENAI_API_PATH                : _openAIAPIPath
  AZURE_APP_CONFIG_ENDPOINT                 : appConfig.outputs.endpoint
  AZURE_APP_CONFIG_NAME                     : _appConfigName
  AZURE_APP_INSIGHTS_NAME                   : _appInsightsName
  AZURE_CONTAINER_REGISTRY_NAME             : _containerRegistryName
  AZURE_DATABASE_ACCOUNT_NAME               : _dbAccountName
  AZURE_DATABASE_CONVERSATION_CONTAINER_NAME: _conversationContainerName
  AZURE_DATABASE_DATASOURCES_CONTAINER_NAME : _datasourcesContainerName
  AZURE_DATABASE_NAME                       : _dbDatabaseName
  AZURE_DATA_INGEST_CONTAINER_APP_NAME      : _dataIngestContainerAppName
  AZURE_DOC_INTELLIGENCE_API_VERSION        : _documentIntelligenceAPIVersion
  AZURE_ENVIRONMENT_NAME                    : _environmentName
  AZURE_FRONTEND_CONTAINER_APP_NAME         : _frontEndContainerAppName
  AZURE_KEY_VAULT_NAME                      : _keyVaultName
  AZURE_LOCATION                            : _location
  AZURE_OPENAI_API_VERSION                  : _openAIAPIVersion
  AZURE_OPENAI_CHAT_DEPLOYMENT              : _chatDeploymentName
  AZURE_OPENAI_CHAT_MODEL_NAME              : _chatModelName
  AZURE_OPENAI_EMBEDDING_DEPLOYMENT         : _embeddingsDeploymentName
  AZURE_OPENAI_EMBEDDING_MODEL_NAME         : _embeddingsModelName
  AZURE_OPENAI_SERVICE_NAME                 : _reuseAIServices ? _existingAIServicesName : aiServices.outputs.name
  AZURE_ORCHESTRATOR_CONTAINER_APP_NAME     : _orchestratorContainerAppName
  AZURE_SEARCH_API_VERSION                  : _searchAPIVersion
  AZURE_SEARCH_SERVICE_NAME                 : _reuseSearch ? _existingSearchName : searchService.outputs.name
  AZURE_STORAGE_ACCOUNT_CONTAINER_DOCS      : _storageAccountContainerDocs
  AZURE_STORAGE_ACCOUNT_CONTAINER_IMAGES    : _storageAccountContainerImages
  AZURE_STORAGE_ACCOUNT_NAME                : _solutionStorageAccountName
  CHAT_NUM_TOKENS                           : _chatNumTokens
  CHUNKING_MIN_CHUNK_SIZE                   : _chunkingMinChunkSize
  CHUNKING_NUM_TOKENS                       : _chunkingNumTokens
  CHUNKING_TOKEN_OVERLAP                    : _chunkingTokenOverlap
  EMBEDDINGS_VECTOR_DIMENSIONS              : _embeddingsVectorDimensions
  SEARCH_INDEX_NAME                         : _searchIndexName
}
