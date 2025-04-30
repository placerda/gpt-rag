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
param configureRAIpolicies                 string = ''   // Configure content filtering policies for AOAI gpt model.

// ----------------------------------------------------------------------
// Reuse Parameters
// ----------------------------------------------------------------------

// Foundry Hub
param AIFoundryHubReuse                    string = ''
param existingAIFoundryHubResourceGroupName string = ''
param existingAIFoundryHubName             string = ''

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
param AOAIServiceName                      string = ''
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
param AOAIAPIName                          string = ''
param AOAIAPIDisplayName                   string = ''
param AOAIAPISpecURL                       string = ''
param AOAIAPIPath                          string = ''
param AOAISubscriptionName                 string = ''
param AOAISubscriptionDescription          string = ''
param AOAISubscriptionSecretName           string = ''

// ----------------------------------------------------------------------
// API Versions
// ----------------------------------------------------------------------

param docIntelAPIVersion                   string = ''
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

// ----------------------------------------------------------------------
// General Variables
// ----------------------------------------------------------------------
var _resourceToken        = toLower(uniqueString(subscription().id, environmentName, location))
var _tags                 = union({ env: _environmentName }, deploymentTags)
var _environmentName      = empty(environmentName)           ? 'dev'           : environmentName
var _location             = empty(location)                  ? 'eastus2'       : location
var _principalId          = empty(principalId)               ? ''              : principalId
var _configureRBAC        = (empty(configureRBAC) || toLower(configureRBAC) == 'true')
var _dummyImageName       = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
var _configureRAIpolicies = (!empty(configureRAIpolicies) && toLower(configureRAIpolicies) == 'true')

// ----------------------------------------------------------------------
// Existing Resources Reuse Flags
// ----------------------------------------------------------------------
var _reuseAIFoundryHub = (!empty(AIFoundryHubReuse) && toLower(AIFoundryHubReuse)   == 'true')
var _reuseAPIM         = (!empty(reuseAPIM)          && toLower(reuseAPIM)          == 'true')
var _reuseAOAI         = (!empty(reuseAOAI)          && toLower(reuseAOAI)          == 'true')

// ----------------------------------------------------------------------
// Existing Resource Names
// ----------------------------------------------------------------------
var _existingAIFoundryHubResourceGroup = empty(existingAIFoundryHubResourceGroupName) ? 'set-existing-foundry-hub-resource-group-name' : existingAIFoundryHubResourceGroupName
var _existingAIFoundryHubName          = empty(existingAIFoundryHubName)              ? 'set-existing-foundry-hub-name'                : existingAIFoundryHubName
var _existingAPIMResourceGroup         = empty(existingAPIMResourceGroup)             ? 'set-existing-apim-resource-group'             : existingAPIMResourceGroup
var _existingAPIMName                  = empty(existingAPIMName)                      ? 'set-existing-apim-name'                       : existingAPIMName
var _existingAOAIResourceGroup         = empty(existingAOAIResourceGroup)             ? 'set-existing-aoai-resource-group'             : existingAOAIResourceGroup
var _existingAOAIName                  = empty(existingAOAIName)                      ? 'set-existing-aoai-name'                       : existingAOAIName

// ----------------------------------------------------------------------
// AI Hub and Services
// ----------------------------------------------------------------------
var _AIHubName                  = empty(AIHubName)       ? '${_abbrs.aiHub}-${_resourceToken}'                     : AIHubName
var _AIProjectName              = empty(AIProjectName)   ? '${_abbrs.aiProject}-${_resourceToken}'                 : AIProjectName
var _AIServicesName             = empty(AIServicesName)  ? '${_abbrs.cognitiveServicesAccounts}-${_resourceToken}' : AIServicesName
var _AOAIServiceName            = empty(AOAIServiceName) ? '${_abbrs.openaiServices}-${_resourceToken}'            : AOAIServiceName
var _AOAIServiceNameFinal       = _reuseAOAI             ? _existingAOAIName                                       : _AOAIServiceName

var _AIHubId                    = _reuseAIFoundryHub     ? AIHubExisting.id                                        : AIHub.outputs.resourceId
var _AIHubDiscoveryUrl          = _reuseAIFoundryHub     ? AIHubExisting.properties.discoveryUrl                   : 'https://${AIHub.outputs.location}.api.azureml.ms/discovery'
var _AIProjectHost              = replace(replace(_AIHubDiscoveryUrl, 'https://', ''), '/discovery', '')
var _AIProjectConnectionString  = '${_AIProjectHost};${subscription().subscriptionId};${resourceGroup().name};${_AIProjectName}'
var _AOAIEndpoint               = _reuseAOAI ? OAIServiceExisting.properties.endpoint : OAIService.outputs.endpoint

// ----------------------------------------------------------------------
// App Configuration and Infrastructure
// ----------------------------------------------------------------------
var _appConfigName             = empty(appConfigName)        ? '${_abbrs.appConfigurationStores}-${_resourceToken}' : appConfigName
var _containerRegistryName     = empty(containerRegistryName)? '${_abbrs.containerRegistries}${_resourceToken}'   : containerRegistryName
var _containerEnvName          = empty(containerEnvName)     ? '${_abbrs.containerEnvs}${_resourceToken}'          : containerEnvName
var _keyVaultName              = empty(keyVaultName)         ? '${_abbrs.keyVaultVaults}-${_resourceToken}'        : keyVaultName
var _logAnalyticsWorkspaceName = empty(logAnalyticsWorkspaceName) ? '${_abbrs.operationalInsightsWorkspaces}-${_resourceToken}' : logAnalyticsWorkspaceName
var _appInsightsName           = empty(appInsightsName)      ? '${_abbrs.insightsComponents}-${_resourceToken}'    : appInsightsName

// ----------------------------------------------------------------------
// Search Service
// ----------------------------------------------------------------------
var _searchServiceName = empty(searchServiceName) ? '${_abbrs.searchSearchServices}-${_resourceToken}' : searchServiceName
var _searchIndexName   = empty(searchIndexName)   ? 'ragindex'                                         : searchIndexName

// ----------------------------------------------------------------------
// Storage
// ----------------------------------------------------------------------
var _AIFoundryStorageAccountName    = empty(AIFoundryStorageAccountName)    ? '${_abbrs.storageStorageAccounts}aihub0${_resourceToken}'  : AIFoundryStorageAccountName
var _solutionStorageAccountName     = empty(solutionStorageAccountName)     ? '${_abbrs.storageStorageAccounts}gptrag0${_resourceToken}' : solutionStorageAccountName
var _storageAccountContainerDocs    = empty(storageAccountContainerDocs)    ? 'documents'         : storageAccountContainerDocs
var _storageAccountContainerImages  = empty(storageAccountContainerImages)  ? 'documents-images'  : storageAccountContainerImages

// ----------------------------------------------------------------------
// OpenAI API Configuration
// ----------------------------------------------------------------------
var _AOAIAPIName                = empty(AOAIAPIName)                  ? 'openai'              : AOAIAPIName
var _AOAIAPIPath                = empty(AOAIAPIPath)                  ? 'openai'              : AOAIAPIPath
var _AOAIAPIDisplayName         = empty(AOAIAPIDisplayName)           ? 'OpenAI'              : AOAIAPIDisplayName
var _AOAIAPISpecURL             = empty(AOAIAPISpecURL)               ? 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json' : AOAIAPISpecURL
var _AOAIAPIVersion             = empty(openAIAPIVersion)             ? '2024-10-21'          : openAIAPIVersion
var _AOAISubscriptionSecretName = empty(AOAISubscriptionSecretName)   ? 'AOAISubscriptionKey' : AOAISubscriptionSecretName

// ----------------------------------------------------------------------
// APIM Configuration
// ----------------------------------------------------------------------
var _apimResourceName            = empty(apimResourceName)             ? '${_abbrs.apiManagementService}-${_resourceToken}'    : apimResourceName
var _apimSku                     = empty(apimSku)                      ? 'Consumption'                                         : apimSku
var _apimPublisherEmail          = empty(apimPublisherEmail)           ? 'noreply@example.com'                                 : apimPublisherEmail
var _apimPublisherName           = empty(apimPublisherName)            ? 'MyCompany'                                           : apimPublisherName
var _AOAISubscriptionName        = empty(AOAISubscriptionName)         ? 'openai-subscription'                                 : AOAISubscriptionName
var _AOAISubscriptionDescription = empty(AOAISubscriptionDescription)  ? 'OpenAI Subscription'                                 : AOAISubscriptionDescription
var _AOAIAPIpolicyXmlTemplate = '''
<policies>
    <inbound>
      <base />
      <authentication-managed-identity
        resource="https://cognitiveservices.azure.com"
        output-token-variable-name="token" />
      <set-header name="Authorization" exists-action="override">
        <value>@("Bearer " + context.Variables["token"])</value>
      </set-header>
      <set-backend-service backend-id="__BACKEND_ID__" />
    </inbound>
    <backend>
      <base />
    </backend>
    <outbound>
      <base />
    </outbound>
    <on-error>
      <base />
    </on-error>
</policies>
'''
var _AOAIAPIpolicyXml = replace(_AOAIAPIpolicyXmlTemplate, '__BACKEND_ID__', _AOAIServiceNameFinal)
var _apimGatewayUrl   = _reuseAPIM ? '' : APIMService.properties.gatewayUrl

// ----------------------------------------------------------------------
// Cosmos DB Configuration
// ----------------------------------------------------------------------
var _dbAccountName            = empty(dbAccountName)               ? '${_abbrs.cosmosDbAccount}-${_resourceToken}'       : dbAccountName
var _dbDatabaseName           = empty(dbDatabaseName)              ? '${_abbrs.cosmosDbDatabase}-${_resourceToken}'      : dbDatabaseName
var _conversationContainerName= empty(conversationContainerName)   ? 'conversations'                                      : conversationContainerName
var _datasourcesContainerName = empty(datasourcesContainerName)    ? 'datasources'                                        : datasourcesContainerName

// ----------------------------------------------------------------------
// Container Apps and Images
// ----------------------------------------------------------------------
var _orchestratorContainerAppName = empty(orchestratorContainerAppName) ? 'orchestrator-${_resourceToken}' : orchestratorContainerAppName
var _orchestratorImage            = empty(orchestratorImage)              ? _dummyImageName                  : orchestratorImage
var _dataIngestContainerAppName   = empty(dataIngestContainerAppName)     ? 'dataingest-${_resourceToken}'   : dataIngestContainerAppName
var _dataIngestImage               = empty(dataIngestContainerImage)       ? _dummyImageName                  : dataIngestContainerImage
var _frontEndContainerAppName     = empty(frontEndContainerAppName)       ? 'frontend-${_resourceToken}'     : frontEndContainerAppName
var _frontEndImage                = empty(frontEndContainerImage)         ? _dummyImageName                  : frontEndContainerImage

// ----------------------------------------------------------------------
// Chat Model Configuration
// ----------------------------------------------------------------------
var _chatModelName           = empty(chatModelName)           ? 'gpt-4o-mini'                    : chatModelName
var _chatModelDeploymentType = empty(chatModelDeploymentType) ? 'GlobalStandard'                 : chatModelDeploymentType
var _chatModelVersion        = empty(chatModelVersion)        ? '2024-07-18'                     : chatModelVersion
var _chatDeploymentName      = empty(chatDeploymentName)      ? 'chat'                           : chatDeploymentName
var _chatNumTokens           = empty(chatNumTokens)           ? '2048'                           : chatNumTokens
var _chatDeploymentCapacity  = empty(chatDeploymentCapacity)  ? 40                               : int(chatDeploymentCapacity)

// ----------------------------------------------------------------------
// Embeddings Model Configuration
// ----------------------------------------------------------------------
var _embeddingsModelName        = empty(embeddingsModelName)    ? 'text-embedding-3-large'      : embeddingsModelName
var _embeddingsModelVersion     = empty(embeddingsModelVersion) ? '1'                           : embeddingsModelVersion
var _embeddingsDeploymentName   = empty(embeddingsDeploymentName)? 'text-embedding'             : embeddingsDeploymentName
var _embeddingsDeploymentType   = empty(embeddingsDeploymentType)? 'Standard'                   : embeddingsDeploymentType
var _embeddingsVectorDimensions = empty(embeddingsVectorDimensions)? '3072'                     : embeddingsVectorDimensions
var _embeddingsDeploymentCapacity = empty(embeddingsDeploymentCapacity)? 40                     : int(embeddingsDeploymentCapacity)

// ----------------------------------------------------------------------
// Chunking and Search API
// ----------------------------------------------------------------------
var _chunkingMinChunkSize = empty(chunkingMinChunkSize) ? '100'        : chunkingMinChunkSize
var _chunkingNumTokens    = empty(chunkingNumTokens)    ? '2048'       : chunkingNumTokens
var _chunkingTokenOverlap = empty(chunkingTokenOverlap) ? '200'        : chunkingTokenOverlap
var _searchAPIVersion     = empty(searchAPIVersion)     ? '2024-07-01' : searchAPIVersion

// ----------------------------------------------------------------------
// Document Intelligence
// ----------------------------------------------------------------------
var _docIntelAPIVersion = empty(docIntelAPIVersion) ? '2024-11-30' : docIntelAPIVersion

// Abbreviation dictionary
var _abbrs = {
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
// RESOURCES 
//////////////////////////////////////////////////////////////////////////

// Log Analytics Workspace
//////////////////////////////////////////////////////////////////////////
module LogAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: 'LogAnalyticsModule'
  params: {
    name:          _logAnalyticsWorkspaceName
    location:      _location
    skuName:       'PerGB2018'  // updated
    dataRetention: 30           // updated
    tags:          _tags
  }
}

// Application Insights
//////////////////////////////////////////////////////////////////////////
module AppInsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: 'AppInsightsModule'
  params: {
    name:                _appInsightsName
    location:            _location
    workspaceResourceId: LogAnalytics.outputs.resourceId
    applicationType:     'web'
    kind:                'web'
    disableIpMasking:    false
    tags:                _tags
  }
}

// Key Vault
//////////////////////////////////////////////////////////////////////////
module KeyVault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: 'KeyVaultModule'
  params: {
    name:                  _keyVaultName
    location:              _location
    sku:                   'standard'
    enableRbacAuthorization: true
    tags:                  _tags
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
        principalId           : ContainerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }      
      {
        principalId           : ContainerAppOrchestrator.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
      {
        principalId           : ContainerAppFrontend.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
    ] : []    
    secrets: [
      {
        name: _AOAISubscriptionDescription
        value: APIMServiceOAISubscription.listSecrets().primaryKey
      }
    ]
  }
}

// App Configuration Store
//////////////////////////////////////////////////////////////////////////
module AppConfig 'br/public:avm/res/app-configuration/configuration-store:0.6.3' = {
  name: 'AppConfigModule'
  params: {
    name:     _appConfigName
    location: _location
    sku:      'Standard'
    tags:     _tags
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

// Cosmos DB Account and Database
//////////////////////////////////////////////////////////////////////////
module DatabaseAccount 'br/public:avm/res/document-db/database-account:0.12.0' = {
  name: 'DatabaseAccountModule'
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
    //                  Principal ← Cosmos DB Built-in Data Contributor (Cosmos DB) 
      sqlRoleAssignmentsPrincipalIds: [
      {
        principalId:        ContainerAppOrchestrator.outputs.systemAssignedMIPrincipalId
        roleDefinitionName: 'Cosmos DB Built-in Data Contributor'
        scopeType:          'account'                 // account | database | container
        scopeName:          ''                        // empty == whole account
      }
      {
        principalId:        _principalId
        roleDefinitionName: 'Cosmos DB Built-in Data Contributor' 
        scopeType:          'account'                 // account | database | container
        scopeName:          ''                        // empty == whole account
      }      
    ]

    defaultConsistencyLevel:'Session'
    capabilitiesToAdd: [
      'EnableServerless'
    ]
    tags:                   _tags
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

// Storage Accounts
//////////////////////////////////////////////////////////////////////////

// Solution Storage Account
module StorageAccountSolution 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: 'StorageAccountSolutionModule'
  params: {
    name:                     _solutionStorageAccountName
    location:                 _location
    skuName:                  'Standard_LRS'
    kind:                     'StorageV2'
    allowBlobPublicAccess:    false
    supportsHttpsTrafficOnly: true
    tags:                     _tags
    // Role assignment: Data Ingest Container App ← Storage Blob Data Contributor (Solution Storage Account)
    //                  Principal ← Storage Blob Data Contributor (Solution Storage Account)
    //                  Front End Container App ← Storage Blob Data Reader (Solution Storage Account)
    //                  Orchestrator Container App ← Storage Blob Data Reader (Solution Storage Account)
    //                  Search Service ← Storage Blob Data Reader (Solution Storage Account)

    roleAssignments: _configureRBAC ? [
      {
        principalId           : ContainerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }      
      {
        principalId           : ContainerAppFrontend.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Reader'
      }  
      {
        principalId           : ContainerAppOrchestrator.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Reader'
      }  
      {
        principalId           : SearchService.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Reader'
      }                  
    ] : []     
  }
}

// AI Foundry Storage Account
module StorageAccountAIFoundry 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: 'StorageAccountAIFoundryModule'
  params: {
    name:                     _AIFoundryStorageAccountName
    location:                 _location
    skuName:                  'Standard_LRS'
    kind:                     'StorageV2'
    allowBlobPublicAccess:    false
    supportsHttpsTrafficOnly: true
    tags:                     _tags
    // Role assignment: Principal ← Storage Blob Data Contributor (AI Foundry Storage Account)
    roleAssignments: _configureRBAC ? [
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }                
    ] : []      
  }
}

// AI Search and AI Services
//////////////////////////////////////////////////////////////////////////

// Azure AI Search Service
module SearchService 'br/public:avm/res/search/search-service:0.9.2' =  {
  name: 'SearchServiceModule'
  params: {
    name: _searchServiceName
    location: _location
    // Tags
    tags: _tags
    // SKU & capacity
    sku: 'standard'
    replicaCount: 1
    semanticSearch: 'disabled'
    managedIdentities : {
      systemAssigned: true
    }    
    // Role assignment: Data Ingest Container App ← Search Index Data Contributor (Search Service)
    //                  Orchestrator Container App ← Search Index Data Reader (Search Service)
    //                  Principal ← Search Index Data Reader (Search Service)
    //                  Principal ← Search Service Contributor (Search Service)    
    roleAssignments: _configureRBAC ? [
      {
        principalId           : ContainerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Search Index Data Contributor'
      }      
      {
        principalId           : ContainerAppOrchestrator.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Search Index Data Reader'
      }
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'Search Service Contributor'
      }
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'Search Index Data Reader'
      }                
    ] : []
  }
}

// OpenAI Service
module OAIService 'br/public:avm/res/cognitive-services/account:0.10.2' = if (!_reuseAOAI) {
  name: 'OpenAIServiceModule'
  params: {
    kind:     'OpenAI'
    name:     _AOAIServiceName
    location: _location
    sku:      'S0'
    tags:     _tags
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
    roleAssignments: _configureRBAC ? [
      {
        principalId           : SearchService.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
      }
      {
        principalId           : ContainerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
      }      
      {
        principalId           : ContainerAppOrchestrator.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
      }        
    ] : []    
  }
}
resource OAIServiceExisting 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = if (_reuseAOAI) {
  name: _existingAOAIName
  scope: resourceGroup(_existingAOAIResourceGroup)
}


// AI Services 
module AIServices 'br/public:avm/res/cognitive-services/account:0.10.2' = {
  name: 'aiServicesModule'
  params: {
    kind:     'AIServices'
    name:     _AIServicesName
    location: _location
    sku:      'S0'
    tags:     _tags
    // Role assignment: Data Ingest Container App ← Cognitive Services User (AI Services)
    roleAssignments: _configureRBAC ? [   
      {
        principalId           : ContainerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services User'
      }     
    ] : []    
  }
}

//APIM
//////////////////////////////////////////////////////////////////////////


// API Management Service
// Note: The AVM's APIM module was not utilized here because it does not support retrieving APIMSubscription.listSecrets().primaryKey, 
// which is required for creating the AI Foundry connection. Creating directly using the resource avoids passing the key as a custom module output.
resource APIMService 'Microsoft.ApiManagement/service@2023-05-01-preview' = if (!_reuseAPIM) {
  name: _apimResourceName
  location: _location
  sku: {
    name: _apimSku
    capacity: (_apimSku == 'Consumption') ? 0 : (_apimSku == 'Developer' ? 1 : 1)
  }
  properties: {
    publisherEmail: _apimPublisherEmail
    publisherName: _apimPublisherName
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// API Management API
resource APIMServiceOAIAPI 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = if (!_reuseAPIM) {
    name: _AOAIAPIName
    parent: APIMService
    properties: {
      apiType: 'http'
      description: _AOAIAPIName
      displayName: _AOAIAPIDisplayName
      format: 'openapi-link'
      path: _AOAIAPIPath
      protocols: [
        'https'
      ]
      subscriptionKeyParameterNames: {
        header: 'api-key'
        query: 'api-key'
      }
      subscriptionRequired: true
      type: 'http'
      value: _AOAIAPISpecURL
    }
  }

// API Management Backend
// Backend for OpenAI in API Management. Add more backends as needed for a backend pool.
resource APIMServiceBackendOAI 'Microsoft.ApiManagement/service/backends@2023-05-01-preview'  =  if (!_reuseAPIM)  {
  name: _AOAIServiceNameFinal
  parent: APIMService
  properties: {
    description: 'backend description'
    url:  '${_AOAIEndpoint}openai'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          failureCondition: {
            count: 3
            errorReasons: [
              'Server errors'
            ]
            interval: 'PT5M'
            statusCodeRanges: [
              {
                min: 429
                max: 429
              }
            ]
          }
          name: 'openAIBreakerRule'
          tripDuration: 'PT1M'
        }
      ]
    }
  }
}

// API Management API Policy
resource APIMServiceOAIAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = if (!_reuseAPIM) {
  name: 'policy'
  parent: APIMServiceOAIAPI
  dependsOn: [
    APIMServiceBackendOAI
  ]  
  properties: {
    format: 'rawxml'
    value: _AOAIAPIpolicyXml
  }
}

// API Management Subscription
resource APIMServiceOAISubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = if (!_reuseAPIM)  {
  name: _AOAISubscriptionName
  parent: APIMService
  properties: {
    allowTracing: true
    displayName: _AOAISubscriptionDescription
    scope: '/apis'
    state: 'active'
  }
}

// AI Foundry
//////////////////////////////////////////////////////////////////////////
module AIHub 'br/public:avm/res/machine-learning-services/workspace:0.12.0' = if (!_reuseAIFoundryHub) {
  name: 'AIHubModule'
  params: {
    name : _AIHubName
    sku  : 'Basic'
    kind : 'Hub'
    location : _location

    // link existing supporting resources
    associatedKeyVaultResourceId          : KeyVault.outputs.resourceId
    associatedStorageAccountResourceId    : StorageAccountAIFoundry.outputs.resourceId
    associatedApplicationInsightsResourceId: AppInsights.outputs.resourceId

    tags : _tags
  }
}
resource AIHubExisting 'Microsoft.MachineLearningServices/workspaces@2025-01-01-preview' existing = if (_reuseAIFoundryHub) {
  name: _existingAIFoundryHubName
  scope: resourceGroup(_existingAIFoundryHubResourceGroup)
}

// AI Foundry Project and Connections
module AIProject 'br/public:avm/res/machine-learning-services/workspace:0.9.1' = if (!_reuseAIFoundryHub) {
  name: 'AIProjectModule'
  params: {
    // core settings
    name           : _AIProjectName
    kind           : 'Project'         // AVM knows to create a “Project” workspace
    location       : _location
    sku            : 'Basic'           // must specify SKU

    // link to your existing Hub
    hubResourceId  : _AIHubId
    discoveryUrl   : _AIHubDiscoveryUrl

    // optional extras
    tags           : _tags

    connections: [
      // OpenAI via APIM (ApiKey)
      {
        name       : 'open_ai_connection'
        category   : 'AzureOpenAI'
        target     : _apimGatewayUrl
        connectionProperties: {
          authType                       : 'ApiKey'
          credentials: {
            key                         : APIMServiceOAISubscription.listSecrets().primaryKey
          }
          useWorkspaceIdentity           : true
          enforceAccessToDefaultSecretStores: true
          isSharedToAll                  : false
        }
        metadata: {
          ApiVersion                    : _AOAIAPIVersion
          ApiType                       : 'AzureOpenAI'
          Kind                          : 'AzureOpenAI'
        }
      }

      // Cognitive Services (AAD)
      {
        name       : 'aiservices-conn'
        category   : 'CognitiveService'
        target     : 'https://${AIServices.outputs.name}.cognitiveservices.azure.com'
        connectionProperties: {
          authType                       : 'AAD'
          credentials                    : {}       // empty for AAD
          useWorkspaceIdentity           : true
          enforceAccessToDefaultSecretStores: true
          isSharedToAll                  : false
        }
        metadata: {
          Kind                          : 'CognitiveService'
        }
      }

      // Azure Cognitive Search (AAD)
      {
        name       : 'cognitive-search-conn'
        category   : 'CognitiveSearch'
        target     : 'https://${SearchService.outputs.name}.search.windows.net'
        connectionProperties: {
          authType                       : 'AAD'
          credentials                    : {}
          useWorkspaceIdentity           : true
          enforceAccessToDefaultSecretStores: true
          isSharedToAll                  : false
        }
        metadata: {}                  // no extra metadata needed
      }
    ]
  }
}


// Container Resources
//////////////////////////////////////////////////////////////////////////

// Container Apps Environment
module ContainerEnv 'br/public:avm/res/app/managed-environment:0.9.1' = {
  name: 'ContainerEnvModule'
  params: {
    name:     _containerEnvName
    location: _location
    tags:     _tags
    logAnalyticsWorkspaceResourceId: LogAnalytics.outputs.resourceId
    appInsightsConnectionString: AppInsights.outputs.connectionString
    zoneRedundant: false
  }
}

// Container Registry
module ContainerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: 'ContainerRegistryModule'
  params: {
    name:     _containerRegistryName
    location: _location
    acrSku:   'Basic'
    tags:     _tags
    // Grant push to your principal, pull to each Container App
    roleAssignments: _configureRBAC ? [
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'AcrPush'      // push+pull
      }
      {
        principalId           : ContainerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'AcrPull'      // push+pull
      }
      {
        principalId           : ContainerAppFrontend.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'AcrPull'      // push+pull
      }
      {
        principalId           : ContainerAppOrchestrator.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'AcrPull'      // push+pull
      }            
    ] : []

  }
}

// Orchestrator Container App
module ContainerAppOrchestrator 'br/public:avm/res/app/container-app:0.16.0' = {
  name: 'ContainerAppOrchestratorModule'
  params: {
    name:                  _orchestratorContainerAppName
    location:              _location
    environmentResourceId: ContainerEnv.outputs.resourceId

    ingressExternal: true
    ingressTargetPort: 80
    ingressTransport: 'auto'
    ingressAllowInsecure: false

    dapr: {
      enabled     : true
      appId       : 'orchestrator'
      appPort     : 80
      appProtocol : 'http'
    }

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
            value : AppConfig.outputs.endpoint
          }
        ]
      }
    ]

    tags: union(_tags, { 'azd-service-name': 'orchestrator' })
  }
}

// DataIngest Container App
module ContainerAppDataIngest 'br/public:avm/res/app/container-app:0.16.0' = {
  name: 'ContainerAppDataIngestModule'
  params: {
    name:                  _dataIngestContainerAppName
    location:              _location
    environmentResourceId: ContainerEnv.outputs.resourceId

    ingressExternal: true
    ingressTargetPort: 80
    ingressTransport: 'auto'
    ingressAllowInsecure: false

    dapr: {
      enabled     : true
      appId       : 'dataingest'
      appPort     : 80
      appProtocol : 'http'
    }

    managedIdentities: {
      systemAssigned: true
    }

    containers: [
      {
        name     : 'dataingest'
        image    : _dataIngestImage
        resources: {
          cpu    : '0.5'
          memory : '1.0Gi'
        }
        env: [
          {
            name  : 'APPCONFIG_ENDPOINT'
            value : AppConfig.outputs.endpoint
          }
        ]
      }
    ]

    tags: union(_tags, { 'azd-service-name': 'dataIngest' })
  }
}

// Front-End Container App
module ContainerAppFrontend 'br/public:avm/res/app/container-app:0.16.0' = {
  name: 'ContainerAppFrontendModule'
  params: {
    name:                  _frontEndContainerAppName
    location:              _location
    environmentResourceId: ContainerEnv.outputs.resourceId

    ingressExternal: true
    ingressTargetPort: 80
    ingressTransport: 'auto'
    ingressAllowInsecure: false

    dapr: {
      enabled     : true
      appId       : 'frontend'
      appPort     : 80
      appProtocol : 'http'
    }

    managedIdentities: {
      systemAssigned: true
    }

    containers: [
      {
        name     : 'frontend'
        image    : _frontEndImage
        resources: {
          cpu    : '0.5'
          memory : '1.0Gi'
        }
        env: [
          {
            name  : 'APPCONFIG_ENDPOINT'
            value : AppConfig.outputs.endpoint
          }
        ]
      }
    ]

    tags: union(_tags, { 'azd-service-name': 'frontend' })
  }
}

//////////////////////////////////////////////////////////////////////////
// ROLE ASSIGNMENTS
//////////////////////////////////////////////////////////////////////////

//Note: Some role assignments are created separately to avoid circular dependencies
//      Using custom modules for role assignments since they are not yet available in AVM
//      They're proposed at the time of writing this template, but not yet published

// Role assignment: APIM ← Cognitive Services OpenAI User (AI Services)
module grantOpenAIUserRoleToAPIM 'core/security/role-assignment.bicep' = if (!_reuseAPIM && _configureRBAC) {
  name: 'grantOpenAIUserRoleToAPIM'
  params: {
    principalId        : APIMService.identity.principalId
    resourceType       : 'aiservices'
    resourceName       : AIServices.outputs.name
    roleDefinitionGuid : '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  }
}


// Role assignment: AI Hub ← Key Vault Secrets User (Key Vault)
module grantKVUserToAIHub 'core/security/role-assignment.bicep' = if (_configureRBAC) {
  name: 'grantKVUserToAIHub'
  params: {
    principalId            : AIHub.outputs.systemAssignedMIPrincipalId
    resourceType           : 'keyvault'    
    resourceName           : KeyVault.outputs.name
    roleDefinitionGuid     : '4633458b-17de-408a-b874-0445c86b69e6'
  }
}

// Role assignment: AI Project ← Key Vault Secrets User (Key Vault)
module grantKVUserToDataIngest 'core/security/role-assignment.bicep' = if (_configureRBAC) {
  name: 'grantKVUserToDataIngest'
  params: {
    principalId            : AIProject.outputs.systemAssignedMIPrincipalId
    resourceType           : 'keyvault'    
    resourceName           : KeyVault.outputs.name
    roleDefinitionGuid     : '4633458b-17de-408a-b874-0445c86b69e6'
  }
}

// Role assignment: AI Hub ← Storage Blob Data Contributor (AI Foundry Storage)
module grantAIFoundryStorageContributorToHub 'core/security/role-assignment.bicep' = if (_configureRBAC) {
  name: 'grantAIFoundryStorageContributorToHub'
  params: {
    principalId            : AIHub.outputs.systemAssignedMIPrincipalId
    resourceType           : 'storage'    
    resourceName           : StorageAccountAIFoundry.outputs.name
    roleDefinitionGuid     : 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
}

// Role assignment: AI Project ← Storage Blob Data Contributor (AI Foundry Storage)
module grantAiProjectStorageBlobDataContributor 'core/security/role-assignment.bicep' = if (_configureRBAC) {
  name: 'grantAiProjectStorageBlobDataContributor'
  params: {
    principalId            : AIProject.outputs.systemAssignedMIPrincipalId
    resourceType           : 'storage'    
    resourceName           : StorageAccountAIFoundry.outputs.name
    roleDefinitionGuid     : 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
}

// Role assignment: Orchestrator Container App ← App Configuration Data Reader (App Configuration)
module grantOrchestratorConfigDataReader 'core/security/role-assignment.bicep' = if (_configureRBAC) {
  name: 'grantOrchestratorConfigDataReader'
  params: {
    principalId         : ContainerAppOrchestrator.outputs.systemAssignedMIPrincipalId
    resourceType        : 'appconfig'
    resourceName        : AppConfig.outputs.name
    roleDefinitionGuid  : '516239f1-63e1-4d78-a4de-a74fb236a071'
  }
}

// Role assignment: Frontend Container App ← App Configuration Data Reader (App Configuration)
module grantFrontendConfigDataReader 'core/security/role-assignment.bicep' = if (_configureRBAC) {
  name: 'grantFrontendConfigDataReader'
  params: {
    principalId         : ContainerAppFrontend.outputs.systemAssignedMIPrincipalId
    resourceType        : 'appconfig'
    resourceName        : AppConfig.outputs.name
    roleDefinitionGuid  : '516239f1-63e1-4d78-a4de-a74fb236a071'
  }
}

// Role assignment: Data Ingestion Container App ← App Configuration Data Reader (App Configuration)
module grantDataIngestConfigDataReader 'core/security/role-assignment.bicep' = if (_configureRBAC) {
  name: 'grantDataIngestConfigDataReader'
  params: {
    principalId         : ContainerAppDataIngest.outputs.systemAssignedMIPrincipalId
    resourceType        : 'appconfig'
    resourceName        : AppConfig.outputs.name
    roleDefinitionGuid  : '516239f1-63e1-4d78-a4de-a74fb236a071'
  }
}

// Role assignment: Principal ← Azure AI Developer (AI Hub)
module grantPrincipalAiHubDeveloper 'core/security/role-assignment.bicep' = if (_configureRBAC) {
  name: 'grantPrincipalAiHubDeveloper'
  params: {
    principalId         : _principalId
    resourceType        : 'aifoundry'
    resourceName        : AIHub.outputs.name 
    roleDefinitionGuid  : '64702f94-c441-49e6-a78b-ef80e0188fee'


  }
}

// Role assignment: Principal ← Azure AI Developer (AI Project)
// module grantPrincipalAiProjectDeveloper 'core/security/role-assignment.bicep' = if (_configureRBAC) {
//   name: 'grantPrincipalAiProjectDeveloper'
//   params: {
//     principalId         : _principalId
//     resourceType        : 'aifoundry'
//     resourceName        : AIProject.outputs.name 
//     roleDefinitionGuid  : '64702f94-c441-49e6-a78b-ef80e0188fee'
//   }
// }

//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////

// ============================================================================
// Deployment Context
// ============================================================================
output AZURE_DEPLOYMENT_NAME                 string = deployment().name
output AZURE_LOCATION                        string = _location
output AZURE_RESOURCE_GROUP                  string = resourceGroup().name
output AZURE_SUBSCRIPTION_ID                 string = subscription().subscriptionId
output AZURE_TENANT_ID                       string = tenant().tenantId
output AZURE_ENV_NAME                        string = _environmentName
output AZURE_PRINCIPAL_ID                    string = _principalId
output AZURE_CONFIGURE_RBAC                  string = string(_configureRBAC)
output AZURE_CONFIGURE_RAI_POLICIES          string = string(_configureRAIpolicies)

// ============================================================================
// Container Apps
// ============================================================================
output AZURE_FRONTEND_CONTAINER_APP_NAME     string = _frontEndContainerAppName
output AZURE_ORCHESTRATOR_CONTAINER_APP_NAME string = _orchestratorContainerAppName
output AZURE_DATA_INGEST_CONTAINER_APP_NAME  string = _dataIngestContainerAppName
output AZURE_CONTAINER_ENV_NAME              string = _containerEnvName
output AZURE_CONTAINER_REGISTRY_URL          string = ContainerRegistry.outputs.loginServer

// ============================================================================
// Azure AI Services & OpenAI
// ============================================================================
output AZURE_AI_SERVICES_NAME                string = AIServices.outputs.name
output AZURE_OPENAI_SERVICE_NAME             string = _reuseAOAI? OAIServiceExisting.name : OAIService.outputs.name
output AZURE_OPENAI_API_VERSION              string = _AOAIAPIVersion
output AZURE_OPENAI_CHAT_MODEL_NAME          string = _chatModelName
output AZURE_OPENAI_EMBEDDING_MODEL_NAME     string = _embeddingsModelName
output AZURE_OPENAI_EMBEDDING_DEPLOYMENT     string = _embeddingsDeploymentName

// Chat Model Deployment
output AZURE_CHAT_DEPLOYMENT_CAPACITY        string = string(_chatDeploymentCapacity)
output AZURE_CHAT_DEPLOYMENT_NAME            string = _chatDeploymentName
output AZURE_CHAT_MODEL_DEPLOYMENT_TYPE      string = _chatModelDeploymentType
output AZURE_CHAT_MODEL_VERSION              string = _chatModelVersion
output AZURE_CHAT_NUM_TOKENS                 string = _chatNumTokens

// Embeddings Deployment
output AZURE_EMBEDDINGS_DEPLOYMENT_CAPACITY  string = string(_embeddingsDeploymentCapacity)
output AZURE_EMBEDDINGS_DEPLOYMENT_TYPE      string = _embeddingsDeploymentType
output AZURE_EMBEDDINGS_MODEL_VERSION        string = _embeddingsModelVersion
output AZURE_EMBEDDINGS_VECTOR_DIMENSIONS    string = _embeddingsVectorDimensions

// ============================================================================
// AI Hub & Project
// ============================================================================
output AZURE_AI_FOUNDRY_HUB_NAME             string = _reuseAIFoundryHub ? _existingAIFoundryHubName : AIHub.outputs.name
output AZURE_AI_FOUNDRY_PROJECT_NAME         string = AIProject.outputs.name
output AZURE_AI_FOUNDRY_STORAGE_ACCOUNT_NAME string = StorageAccountAIFoundry.outputs.name

// ============================================================================
// App Configuration & Monitoring
// ============================================================================
output AZURE_APP_CONFIG_NAME                 string = AppConfig.outputs.name

// ============================================================================
// API Management (APIM)
// ============================================================================
output AZURE_APIM_SERVICE_NAME                string = _reuseAPIM ? _existingAPIMName : APIMService.name
output AZURE_APIM_OPENAI_API_DISPLAY_NAME     string = _AOAIAPIDisplayName
output AZURE_APIM_OPENAI_API_NAME             string = _AOAIAPIName
output AZURE_APIM_OPENAI_API_PATH             string = _AOAIAPIPath

output AZURE_APIM_PUBLISHER_EMAIL             string = _apimPublisherEmail
output AZURE_APIM_PUBLISHER_NAME              string = _apimPublisherName

output AZURE_APIM_OPENAI_API_SPEC_URL         string = _AOAIAPISpecURL

output AZURE_APIM_GATEWAY_URL                 string = _apimGatewayUrl
output AZURE_APIM_OPENAI_SUBSCRIPTION_NAME    string = _AOAISubscriptionName
output AZURE_APIM_OPENAI_SUBSCRIPTION_DESC    string = _AOAISubscriptionDescription
output AZURE_APIM_SUBSCRIPTION_SECRET_NAME    string = _AOAISubscriptionSecretName

// ============================================================================
// Azure Search
// ============================================================================
output AZURE_SEARCH_SERVICE_NAME             string = SearchService.outputs.name
output AZURE_SEARCH_INDEX_NAME               string = _searchIndexName
output AZURE_SEARCH_API_VERSION              string = _searchAPIVersion

// ============================================================================
// Storage
// ============================================================================
output AZURE_STORAGE_ACCOUNT_NAME            string = _solutionStorageAccountName
output AZURE_STORAGE_ACCOUNT_CONTAINER_DOCS  string = _storageAccountContainerDocs
output AZURE_STORAGE_ACCOUNT_CONTAINER_IMAGES string = _storageAccountContainerImages
output AZURE_CONTAINER_REGISTRY_NAME         string = ContainerRegistry.outputs.name

// ============================================================================
// Key Vault
// ============================================================================
output AZURE_KEY_VAULT_NAME                 string = KeyVault.outputs.name
output AZURE_AOAI_SUBSCRIPTION_SECRET_NAME  string = _AOAISubscriptionSecretName

// ============================================================================
// Reuse Flags and Existing Resource Info
// ============================================================================
output AZURE_REUSE_AI_FOUNDRY_HUB                   string = string(_reuseAIFoundryHub)
output AZURE_EXISTING_AI_FOUNDRY_HUB_RESOURCE_GROUP string = _existingAIFoundryHubResourceGroup
output AZURE_EXISTING_AI_FOUNDRY_HUB_NAME           string = _existingAIFoundryHubName

output AZURE_REUSE_AOAI                             string = string(_reuseAOAI)
output AZURE_EXISTING_AOAI_RESOURCE_GROUP           string = _existingAOAIResourceGroup
output AZURE_EXISTING_AOAI_NAME                     string = _existingAOAIName

output AZURE_REUSE_APIM                             string = string(_reuseAPIM)
output AZURE_EXISTING_APIM_RESOURCE_GROUP           string = _existingAPIMResourceGroup
output AZURE_EXISTING_APIM_NAME                     string = _existingAPIMName

//–– Dynamic AppConfig KV map (single source of truth)
output appConfigKVs object = {
  AI_FOUNDRY_PROJECT_CONNECTION_STRING: _AIProjectConnectionString
  AI_SERVICES_NAME                    : AIServices.outputs.name
  APIM_OPENAI_API_PATH                : _AOAIAPIPath
  APP_CONFIG_ENDPOINT                 : AppConfig.outputs.endpoint
  APP_CONFIG_NAME                     : _appConfigName
  APP_INSIGHTS_NAME                   : _appInsightsName
  CONTAINER_REGISTRY_NAME             : _containerRegistryName
  CONTAINER_REGISTRY_URL              : ContainerRegistry.outputs.loginServer
  DATABASE_ACCOUNT_NAME               : _dbAccountName
  DATABASE_CONVERSATION_CONTAINER_NAME: _conversationContainerName
  DATABASE_DATASOURCES_CONTAINER_NAME : _datasourcesContainerName
  DATABASE_NAME                       : _dbDatabaseName
  DATA_INGEST_CONTAINER_APP_NAME      : _dataIngestContainerAppName
  DOC_INTELLIGENCE_API_VERSION        : _docIntelAPIVersion
  ENV_NAME                            : _environmentName
  FRONTEND_CONTAINER_APP_NAME         : _frontEndContainerAppName
  KEY_VAULT_NAME                      : _keyVaultName
  LOCATION                            : _location
  OPENAI_API_VERSION                  : _AOAIAPIVersion
  OPENAI_CHAT_DEPLOYMENT              : _chatDeploymentName
  OPENAI_CHAT_MODEL_NAME              : _chatModelName
  OPENAI_EMBEDDING_DEPLOYMENT         : _embeddingsDeploymentName
  OPENAI_EMBEDDING_MODEL_NAME         : _embeddingsModelName
  OPENAI_SERVICE_NAME                 : _reuseAOAI ? OAIServiceExisting.name : OAIService.outputs.name
  ORCHESTRATOR_CONTAINER_APP_NAME     : _orchestratorContainerAppName
  SEARCH_API_VERSION                  : _searchAPIVersion
  SEARCH_SERVICE_NAME                 : SearchService.outputs.name
  STORAGE_ACCOUNT_CONTAINER_DOCS      : _storageAccountContainerDocs
  STORAGE_ACCOUNT_CONTAINER_IMAGES    : _storageAccountContainerImages
  STORAGE_ACCOUNT_NAME                : _solutionStorageAccountName
  SUBSCRIPTION_ID                     : subscription().subscriptionId
  CHAT_NUM_TOKENS                     : _chatNumTokens
  CHUNKING_MIN_CHUNK_SIZE             : _chunkingMinChunkSize
  CHUNKING_NUM_TOKENS                 : _chunkingNumTokens
  CHUNKING_TOKEN_OVERLAP              : _chunkingTokenOverlap
  EMBEDDINGS_VECTOR_DIMENSIONS        : _embeddingsVectorDimensions
  SEARCH_INDEX_NAME                   : _searchIndexName
}
