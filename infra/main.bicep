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

param environmentName                     string = ''  // AZD environment
param location                            string       // Primary deployment location.
param deploymentTags                      object = {}  // Tags applied to all resources.
param principalId                         string       // Principal ID for role assignments.
param configureRbac                       string = ''  // Assign RBAC roles to resources.
param networkIsolation                    string = '' 

// ----------------------------------------------------------------------
// Resource Naming params
// ----------------------------------------------------------------------

param aiFoundryStorageAccountName        string = ''
param aiHubName                          string = ''
param aiProjectName                      string = ''
param aiServicesName                     string = ''
param aoaiServiceName                    string = ''
param apimResourceName                   string = ''
param appConfigName                      string = ''
param appInsightsName                    string = ''
param containerEnvName                   string = ''
param containerRegistryName              string = ''
param dataIngestContainerAppName         string = ''
param dbAccountName                      string = ''
param dbDatabaseName                     string = ''
param frontEndContainerAppName           string = ''
param keyVaultName                       string = ''
param logAnalyticsWorkspaceName          string = ''
param orchestratorContainerAppName       string = ''
param searchServiceName                  string = ''
param solutionStorageAccountName         string = ''

// ----------------------------------------------------------------------
// Reuse Config params
// ----------------------------------------------------------------------

param aiFoundryHubReuse                  string = '' 
param existingAifoundryHubResourceGroup  string = '' 
param existingAifoundryHubName           string = '' 
param reuseApim                          string = ''  
param reuseAoai                          string = ''  
param existingAoaiResourceGroup          string = ''  
param existingAoaiName                   string = '' 

// ----------------------------------------------------------------------
// Hooks Configuration params
// ----------------------------------------------------------------------
param runSearchSetup                      string = '' 

// ----------------------------------------------------------------------
// AI Hub and Project params
// ----------------------------------------------------------------------

param aoaiConnectionName                  string = ''
param aiServicesConnectionName            string = ''
param aiSearchConnectionName              string = ''

// ----------------------------------------------------------------------
// Storage Account vars
// ----------------------------------------------------------------------

param storageAccountContainerDocs         string = ''
param storageAccountContainerImages       string = ''

// ----------------------------------------------------------------------
// AI Search Service params
// ----------------------------------------------------------------------

param searchIndexName                    string = ''
param searchApiVersion                   string = ''
param searchAnalyzerName                 string = ''
param searchIndexInterval                string = ''

// ----------------------------------------------------------------------
// API Management params
// ----------------------------------------------------------------------

param apimPublisherEmail                  string = ''
param apimPublisherName                   string = ''
param apimSku                             string = ''
param aoaiApiName                         string = ''
param aoaiApiDisplayName                  string = ''
param aoaiApiPath                         string = ''
param aoaiSubscriptionName                string = ''
param aoaiSubscriptionDescription         string = ''

// ----------------------------------------------------------------------
// AI Services params
// ----------------------------------------------------------------------

param docIntelApiVersion                   string = ''

// ----------------------------------------------------------------------
// Azure Open AI Service params
// ----------------------------------------------------------------------

param chatDeploymentCapacity              string = ''
param chatDeploymentName                  string = ''
param chatModelDeploymentType             string = '' // 'Standard', 'ProvisionedManaged', 'GlobalStandard'
param chatModelName                       string = '' // e.g., 'gpt-35-turbo', 'gpt-4', 'gpt-4o'
param chatModelVersion                    string = '' // e.g., '1106', '0125-preview', '2024-11-20'

param embeddingsDeploymentCapacity        string = ''
param embeddingsDeploymentName            string = ''
param embeddingsDeploymentType            string = ''
param embeddingsModelName                 string = ''
param embeddingsModelVersion              string = '' // e.g., '1', '2'
param embeddingsVectorDimensions          string = ''

param openAiApiVersion                     string = ''

// ----------------------------------------------------------------------
// Chunking params
// ----------------------------------------------------------------------

param chunkingMinChunkSize                string = ''
param chunkingNumTokens                   string = ''
param chunkingTokenOverlap                string = ''
param chatNumTokens                       string = ''

// ----------------------------------------------------------------------
// CosmosDB params
// ----------------------------------------------------------------------

param conversationContainerName          string = ''
param datasourcesContainerName           string = ''

// ----------------------------------------------------------------------
// Container Apps params
// ----------------------------------------------------------------------
param orchestratorContainerImage         string = ''
param dataIngestContainerImage           string = ''
param frontEndContainerImage             string = ''

//////////////////////////////////////////////////////////////////////////
// VARIABLES
//////////////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------------
// General Variables
// ----------------------------------------------------------------------

var _resourceToken           = toLower(uniqueString(subscription().id, environmentName, location))
var _tags                    = union({ env: _environmentName }, deploymentTags)
var _azureCloud              = environment().name
var _environmentName         = empty(environmentName)           ? 'dev'           : environmentName
var _location                = empty(location)                  ? 'eastus2'       : location
var _principalId             = empty(principalId)               ? ''              : principalId
var _configureRbac           = (empty(configureRbac) || toLower(configureRbac) == 'true')
var _dummyImageName          = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
var _networkIsolation        = empty(networkIsolation)          ? false           : (toLower(networkIsolation) == 'true')

// ----------------------------------------------------------------------
// Resource Naming 
// ----------------------------------------------------------------------

var _aiFoundryStorageAccountName        = empty(aiFoundryStorageAccountName)       ? '${_abbrs.storageStorageAccounts}aihub0${_resourceToken}'       : aiFoundryStorageAccountName
var _aiHubName                          = empty(aiHubName)                         ? '${_abbrs.aiHub}-${_resourceToken}'                             : aiHubName
var _aiProjectName                      = empty(aiProjectName)                     ? '${_abbrs.aiProject}-${_resourceToken}'                         : aiProjectName
var _aiServicesName                     = empty(aiServicesName)                    ? '${_abbrs.cognitiveServicesAccounts}-${_resourceToken}'         : aiServicesName
var _aoaiServiceName                    = empty(aoaiServiceName)                   ? '${_abbrs.openaiServices}-${_resourceToken}'                    : aoaiServiceName
var _apimResourceName                   = empty(apimResourceName)                  ? '${_abbrs.apiManagementService}-${_resourceToken}'              : apimResourceName
var _appConfigName                      = empty(appConfigName)                     ? '${_abbrs.appConfigurationStores}-${_resourceToken}'            : appConfigName
var _appInsightsName                    = empty(appInsightsName)                   ? '${_abbrs.insightsComponents}-${_resourceToken}'               : appInsightsName
var _containerEnvName                   = empty(containerEnvName)                  ? '${_abbrs.containerEnvs}${_resourceToken}'                     : containerEnvName
var _containerRegistryName              = empty(containerRegistryName)             ? '${_abbrs.containerRegistries}${_resourceToken}'               : containerRegistryName
var _dataIngestContainerAppName         = empty(dataIngestContainerAppName)        ? 'dataingest-${_resourceToken}'                                 : dataIngestContainerAppName
var _dbAccountName                      = empty(dbAccountName)                     ? '${_abbrs.cosmosDbAccount}-${_resourceToken}'                  : dbAccountName
var _dbDatabaseName                     = empty(dbDatabaseName)                    ? '${_abbrs.cosmosDbDatabase}-${_resourceToken}'                 : dbDatabaseName
var _frontEndContainerAppName           = empty(frontEndContainerAppName)          ? 'frontend-${_resourceToken}'                                   : frontEndContainerAppName
var _keyVaultName                       = empty(keyVaultName)                      ? '${_abbrs.keyVaultVaults}-${_resourceToken}'                   : keyVaultName
var _logAnalyticsWorkspaceName          = empty(logAnalyticsWorkspaceName)         ? '${_abbrs.operationalInsightsWorkspaces}-${_resourceToken}'    : logAnalyticsWorkspaceName
var _orchestratorContainerAppName       = empty(orchestratorContainerAppName)      ? 'orchestrator-${_resourceToken}'                               : orchestratorContainerAppName
var _searchServiceName                  = empty(searchServiceName)                 ? '${_abbrs.searchSearchServices}-${_resourceToken}'             : searchServiceName
var _solutionStorageAccountName         = empty(solutionStorageAccountName)        ? '${_abbrs.storageStorageAccounts}gptrag0${_resourceToken}'     : solutionStorageAccountName

// ----------------------------------------------------------------------
// Reuse Config
// ----------------------------------------------------------------------

var _reuseAifoundryHub                         = empty(aiFoundryHubReuse)                   ? false                                           : (toLower(aiFoundryHubReuse) == 'true')
var _reuseApim                                 = empty(reuseApim)                           ? false                                           : (toLower(reuseApim) == 'true')
var _reuseAoai                                 = empty(reuseAoai)                           ? false                                           : (toLower(reuseAoai) == 'true')
var _existingAifoundryHubResourceGroupName     = empty(existingAifoundryHubResourceGroup)   ? 'set-existing-foundry-hub-resource-group-name'  : location
var _existingAifoundryHubName                  = empty(existingAifoundryHubName)            ? 'set-existing-foundry-hub-name'                 : existingAifoundryHubName
var _existingAoaiResourceGroup                 = empty(existingAoaiResourceGroup)           ? 'set-existing-aoai-resource-group'              : existingAoaiResourceGroup
var _aoaiResourceGroup                         = _reuseAoai                                 ? _existingAoaiResourceGroup                      : resourceGroup().name    
var _existingAoaiName                          = empty(existingAoaiName)                    ? 'set-existing-aoai-name'                        : existingAoaiName

// ----------------------------------------------------------------------
// Hooks Configuration vars
// ----------------------------------------------------------------------

 var _runSearchSetup = empty(runSearchSetup) ? true : (toLower(runSearchSetup) == 'true')

// ----------------------------------------------------------------------
// AI Hub and Project vars
// ----------------------------------------------------------------------

var _aoaiServiceNameFinal       = _reuseAoai             ? _existingAoaiName                                : _aoaiServiceName
var _aiHubId                    = _reuseAifoundryHub     ? aiHubExisting.id                                 : aiHub.outputs.resourceId
var _aiHubDiscoveryUrl          = _reuseAifoundryHub     ? aiHubExisting.properties.discoveryUrl            : 'https://${aiHub.outputs.location}.api.azureml.ms/discovery'
var _aiProjectHost              = replace(replace(_aiHubDiscoveryUrl, 'https://', ''), '/discovery', '')
var _aiProjectConnectionString  = '${_aiProjectHost};${subscription().subscriptionId};${resourceGroup().name};${_aiProjectName}'
var _aoaiEndpoint               = _reuseAoai ? aoaiServiceExisting.properties.endpoint : aoaiService.outputs.endpoint

var _aoaiConnectionName         = empty(aoaiConnectionName)      ? 'openai-conn'      : aoaiConnectionName  
var _aiServicesConnectionName   = empty(aiServicesConnectionName)? 'aiservices-conn'  : aiServicesConnectionName
var _aiSearchConnectionName     = empty(aiSearchConnectionName)  ? 'aisearch-conn'    : aiSearchConnectionName

// ----------------------------------------------------------------------
// Storage Account vars
// ----------------------------------------------------------------------

var _storageAccountContainerDocs    = empty(storageAccountContainerDocs)    ? 'documents'         : storageAccountContainerDocs
var _storageAccountContainerImages  = empty(storageAccountContainerImages)  ? 'documents-images'  : storageAccountContainerImages

// ----------------------------------------------------------------------
// AI Search Service vars
// ----------------------------------------------------------------------

var _searchIndexName      = empty(searchIndexName)       ? 'ragindex-${_resourceToken}'  : searchIndexName
var _searchApiVersion     = empty(searchApiVersion)      ? '2024-07-01'                  : searchApiVersion
var _searchAnalyzerName   = empty(searchAnalyzerName)    ? 'standard'                    : searchAnalyzerName
var _searchIndexInterval  = empty(searchIndexInterval)   ? 'PT1H'                        : searchIndexInterval

// ----------------------------------------------------------------------
// API Management vars
// ----------------------------------------------------------------------

var _apimSku                    = empty(apimSku)                      ? 'Consumption'                                         : apimSku
var _apimPublisherEmail         = empty(apimPublisherEmail)           ? 'noreply@example.com'                                 : apimPublisherEmail
var _apimPublisherName          = empty(apimPublisherName)            ? 'MyCompany'                                           : apimPublisherName
var _aoaiSubscriptionName       = empty(aoaiSubscriptionName)         ? 'openai-subscription'                                 : aoaiSubscriptionName
var _aoaiSubscriptionDescription= empty(aoaiSubscriptionDescription)  ? 'OpenAI Subscription'                                 : aoaiSubscriptionDescription
var _aoaiApiPolicyXmlTemplate = '''
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
var _aoaiApiPolicyXml           = replace(_aoaiApiPolicyXmlTemplate, '__BACKEND_ID__', _aoaiServiceNameFinal)
var _aoaiApiName                = empty(aoaiApiName)                  ? 'openai'              : aoaiApiName
var _aoaiApiPath                = empty(aoaiApiPath)                  ? 'openai'              : aoaiApiPath
var _aoaiApiDisplayName         = empty(aoaiApiDisplayName)           ? 'OpenAI'              : aoaiApiDisplayName
var _aoaiApiSpecUrl             = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json'

// ----------------------------------------------------------------------
// AI Services vars
// ----------------------------------------------------------------------

var _docIntelApiVersion = empty(docIntelApiVersion) ? '2024-11-30' : docIntelApiVersion

// ----------------------------------------------------------------------
// Azure Open AI Service vars
// ----------------------------------------------------------------------

var _aoaiApiVersion             = empty(openAiApiVersion)     ? '2024-10-21'          : openAiApiVersion

var _chatModelName           = empty(chatModelName)           ? 'gpt-4o-mini'                    : chatModelName
var _chatModelDeploymentType = empty(chatModelDeploymentType) ? 'GlobalStandard'                 : chatModelDeploymentType
var _chatModelVersion        = empty(chatModelVersion)        ? '2024-07-18'                     : chatModelVersion
var _chatDeploymentName      = empty(chatDeploymentName)      ? 'chat'                           : chatDeploymentName
var _chatNumTokens           = empty(chatNumTokens)           ? '2048'                           : chatNumTokens
var _chatDeploymentCapacity  = empty(chatDeploymentCapacity)  ? 40                               : int(chatDeploymentCapacity)

var _embeddingsModelName         = empty(embeddingsModelName)         ? 'text-embedding-3-large'      : embeddingsModelName
var _embeddingsModelVersion      = empty(embeddingsModelVersion)      ? '1'                           : embeddingsModelVersion
var _embeddingsDeploymentName    = empty(embeddingsDeploymentName)    ? 'text-embedding'              : embeddingsDeploymentName
var _embeddingsDeploymentType    = empty(embeddingsDeploymentType)    ? 'Standard'                   : embeddingsDeploymentType
var _embeddingsVectorDimensions  = empty(embeddingsVectorDimensions)  ? '3072'                       : embeddingsVectorDimensions
var _embeddingsDeploymentCapacity= empty(embeddingsDeploymentCapacity)? 40                            : int(embeddingsDeploymentCapacity)

// ----------------------------------------------------------------------
// Chunking vars
// ----------------------------------------------------------------------

var _chunkingMinChunkSize = empty(chunkingMinChunkSize) ? '100'        : chunkingMinChunkSize
var _chunkingNumTokens    = empty(chunkingNumTokens)    ? '2048'       : chunkingNumTokens
var _chunkingTokenOverlap = empty(chunkingTokenOverlap) ? '200'        : chunkingTokenOverlap

// ----------------------------------------------------------------------
// CosmosDB vars
// ----------------------------------------------------------------------
var _conversationContainerName = empty(conversationContainerName)   ? 'conversations'                                      : conversationContainerName
var _datasourcesContainerName  = empty(datasourcesContainerName)    ? 'datasources'                                        : datasourcesContainerName

// ----------------------------------------------------------------------
// Container Apps vars
// ----------------------------------------------------------------------
var _orchestratorContainerImage = empty(orchestratorContainerImage)   ? _dummyImageName                  : orchestratorContainerImage
var _dataIngestContainerImage   = empty(dataIngestContainerImage)     ? _dummyImageName                  : dataIngestContainerImage
var _frontEndContainerImage     = empty(frontEndContainerImage)       ? _dummyImageName                  : frontEndContainerImage

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
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: 'logAnalyticsModule'
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
module appInsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: 'appInsightsModule'
  params: {
    name:                _appInsightsName
    location:            _location
    workspaceResourceId: logAnalytics.outputs.resourceId
    applicationType:     'web'
    kind:                'web'
    disableIpMasking:    false
    tags:                _tags
  }
}

// Key Vault
//////////////////////////////////////////////////////////////////////////
module keyVault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: 'keyVaultModule'
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
    roleAssignments: _configureRbac ? [
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'Key Vault Contributor'
      }
      {
        principalId           : containerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }      
      {
        principalId           : containerAppOrchestrator.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
      {
        principalId           : containerAppFrontend.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
    ] : [] 
  }
}

// App Configuration Store
//////////////////////////////////////////////////////////////////////////
module appConfig 'br/public:avm/res/app-configuration/configuration-store:0.6.3' = {
  name: 'appConfigModule'
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
    roleAssignments: _configureRbac ? [
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'App Configuration Data Owner'
      }     
    ] : []    
  }
}

// Cosmos DB Account and Database
//////////////////////////////////////////////////////////////////////////
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
    //                  Principal ← Cosmos DB Built-in Data Contributor (Cosmos DB) 
      sqlRoleAssignmentsPrincipalIds: [
      {
        principalId:        containerAppOrchestrator.outputs.systemAssignedMIPrincipalId
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
module storageAccountSolution 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: 'storageAccountSolutionModule'
  params: {
    name:                     _solutionStorageAccountName
    location:                 _location
    skuName:                  'Standard_LRS'
    kind:                     'StorageV2'
    allowBlobPublicAccess:    false
    supportsHttpsTrafficOnly: true
    tags:                     _tags
    blobServices: {
      automaticSnapshotPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 10
      containerDeleteRetentionPolicyEnabled: true
      containers: [
        {
          name: 'nl2sql'
          publicAccess: 'None'
        }
        {
          name: _storageAccountContainerDocs
          publicAccess: 'None'
        }
        {
          name: _storageAccountContainerImages
          publicAccess: 'None'
        }     
      ]
      deleteRetentionPolicyDays: 7
      deleteRetentionPolicyEnabled: true
      lastAccessTimeTrackingPolicyEnabled: true
    }
    // Role assignment: Data Ingest Container App ← Storage Blob Data Contributor (Solution Storage Account)
    //                  Principal ← Storage Blob Data Contributor (Solution Storage Account)
    //                  Front End Container App ← Storage Blob Data Reader (Solution Storage Account)
    //                  Orchestrator Container App ← Storage Blob Data Reader (Solution Storage Account)
    //                  Search Service ← Storage Blob Data Reader (Solution Storage Account)
    roleAssignments: _configureRbac ? [
      {
        principalId           : containerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }      
      {
        principalId           : containerAppFrontend.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Reader'
      }  
      {
        principalId           : containerAppOrchestrator.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Reader'
      }  
      {
        principalId           : searchService.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Storage Blob Data Reader'
      }                  
    ] : []     
  }
}

// AI Foundry Storage Account
module storageAccountAIFoundry 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: 'storageAccountAIFoundryModule'
  params: {
    name:                     _aiFoundryStorageAccountName
    location:                 _location
    skuName:                  'Standard_LRS'
    kind:                     'StorageV2'
    allowBlobPublicAccess:    false
    supportsHttpsTrafficOnly: true
    tags:                     _tags
    // Role assignment: Principal ← Storage Blob Data Contributor (AI Foundry Storage Account)
    roleAssignments: _configureRbac ? [
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
module searchService 'br/public:avm/res/search/search-service:0.10.0' =  {
  name: 'searchServiceModule'
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
    roleAssignments: _configureRbac ? [
      {
        principalId           : containerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Search Index Data Contributor'
      }      
      {
        principalId           : containerAppOrchestrator.outputs.systemAssignedMIPrincipalId
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
module aoaiService 'br/public:avm/res/cognitive-services/account:0.10.2' = if (!_reuseAoai) {
  name: 'aoaiServiceModule'
  params: {
    kind:     'OpenAI'
    name:     _aoaiServiceName
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
    roleAssignments: _configureRbac ? [
      {
        principalId           : searchService.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
      }
      {
        principalId           : containerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
      }      
      {
        principalId           : containerAppOrchestrator.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
      }        
    ] : []    
  }
}
resource aoaiServiceExisting 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = if (_reuseAoai) {
  name: _existingAoaiName
  scope: resourceGroup(_existingAoaiResourceGroup)
}


// AI Services 
module aiServices 'br/public:avm/res/cognitive-services/account:0.10.2' = {
  name: 'aiServicesModule'
  params: {
    kind:     'AIServices'
    name:     _aiServicesName
    location: _location
    sku:      'S0'
    tags:     _tags
    // Role assignment: Data Ingest Container App ← Cognitive Services User (AI Services)
    roleAssignments: _configureRbac ? [   
      {
        principalId           : containerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'Cognitive Services User'
      }     
    ] : []    
  }
}

//APIM
//////////////////////////////////////////////////////////////////////////
module apimService 'br/public:avm/res/api-management/service:0.9.1' = {
  name: 'apimServiceModule'
  params: {
    // Core APIM properties
    name:           _apimResourceName
    location:       _location
    publisherEmail: _apimPublisherEmail
    publisherName:  _apimPublisherName
    sku:            _apimSku

    // Enable system-assigned managed identity
    managedIdentities: {
      systemAssigned: true
    }

    // 1) Your AOAI API
    apis: [
      {
        name:                        _aoaiApiName
        displayName:                 _aoaiApiDisplayName
        description:                 _aoaiApiName
        path:                        _aoaiApiPath
        protocols:                   [ 'https' ]
        apiType:                     'http'
        format:                      'openapi-link'
        serviceUrl:                  _aoaiApiSpecUrl
        subscriptionRequired:        true
        subscriptionKeyParameterNames: {
          header: 'api-key'
          query:  'api-key'
        }
        policies: [
          {
            format: 'rawxml'
            value:  _aoaiApiPolicyXml
          }
        ]        
      }
    ]

    // 2) Your backend pointing at OpenAI
    backends: [
      {
        name:        _aoaiServiceNameFinal
        url:         '${_aoaiEndpoint}openai'
        protocol:    'http'
        description: 'backend description'
        circuitBreaker: {
          rules: [
            {
              name: 'openAIBreakerRule'
              failureCondition: {
                count:             3
                errorReasons:     [ 'Server errors' ]
                statusCodeRanges: [ { min: 429, max: 429 } ]
                interval:         'PT5M'
              }
              tripDuration: 'PT1M'
            }
          ]
        }
      }
    ]

    // 3) Subscription scoped to all your APIs
    subscriptions: [
      {
        name:         _aoaiSubscriptionName
        displayName:  _aoaiSubscriptionDescription
        scope:        '/apis'
        state:        'active'
        allowTracing: true
      }
    ]

  }
}

// AI Foundry
//////////////////////////////////////////////////////////////////////////
module aiHub 'br/public:avm/res/machine-learning-services/workspace:0.12.0' = if (!_reuseAifoundryHub) {
  name: 'aiHubModule'  
  params: {
    name : _aiHubName
    sku  : 'Basic'
    kind : 'Hub'
    location : _location
    publicNetworkAccess : 'Enabled'
    
    // link existing supporting resources
    associatedKeyVaultResourceId          : keyVault.outputs.resourceId
    associatedStorageAccountResourceId    : storageAccountAIFoundry.outputs.resourceId
    associatedApplicationInsightsResourceId: appInsights.outputs.resourceId

    tags : _tags

    // Role assignment: Principal ← Azure AI Developer (AI Hub)
    roleAssignments: _configureRbac ? [
      {
        principalId           : _principalId
        roleDefinitionIdOrName: '64702f94-c441-49e6-a78b-ef80e0188fee'
      }                
    ] : [] 

  }
}
resource aiHubExisting 'Microsoft.MachineLearningServices/workspaces@2025-01-01-preview' existing = if (_reuseAifoundryHub) {
  name: _existingAifoundryHubName
  scope: resourceGroup(_existingAifoundryHubResourceGroupName)
}

// AI Foundry Project and Connections
module aiProject 'br/public:avm/res/machine-learning-services/workspace:0.9.1' = {
  name: 'aiProjectModule'
  params: {
    // core settings
    name           : _aiProjectName
    kind           : 'Project'         // AVM knows to create a “Project” workspace
    location       : _location
    sku            : 'Basic'           // must specify SKU
    publicNetworkAccess : 'Enabled'

    // link to your existing Hub
    hubResourceId  : _aiHubId
    discoveryUrl   : _aiHubDiscoveryUrl

    // optional extras
    tags           : _tags

    // Role assignment: Principal ← Azure AI Developer (AI Project)
    roleAssignments: _configureRbac ? [
      {
        principalId           : _principalId
        roleDefinitionIdOrName: '64702f94-c441-49e6-a78b-ef80e0188fee'
      }                
    ] : [] 

  }
}

// Container Resources
//////////////////////////////////////////////////////////////////////////

// Container Apps Environment
module containerEnv 'br/public:avm/res/app/managed-environment:0.9.1' = {
  name: 'containerEnvModule'
  params: {
    name:     _containerEnvName
    location: _location
    tags:     _tags
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
    appInsightsConnectionString: appInsights.outputs.connectionString
    zoneRedundant: false
  }
}

// Container Registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: 'containerRegistryModule'
  params: {
    name:     _containerRegistryName
    location: _location
    acrSku:   'Basic'
    tags:     _tags
    // Grant push to your principal, pull to each Container App
    roleAssignments: _configureRbac ? [
      {
        principalId           : _principalId
        roleDefinitionIdOrName: 'AcrPush'      // push+pull
      }
      {
        principalId           : containerAppDataIngest.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'AcrPull'      // push+pull
      }
      {
        principalId           : containerAppFrontend.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'AcrPull'      // push+pull
      }
      {
        principalId           : containerAppOrchestrator.outputs.systemAssignedMIPrincipalId
        roleDefinitionIdOrName: 'AcrPull'      // push+pull
      }            
    ] : []

  }
}

// Orchestrator Container App
module containerAppOrchestrator 'br/public:avm/res/app/container-app:0.16.0' = {
  name: 'containerAppOrchestratorModule'
  params: {
    name:                  _orchestratorContainerAppName
    location:              _location
    environmentResourceId: containerEnv.outputs.resourceId

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
        image    : _orchestratorContainerImage
        resources: {
          cpu    : '0.5'
          memory : '1.0Gi'
        }
        env: [
          {
            name  : 'APP_CONFIG_ENDPOINT'
            value : appConfig.outputs.endpoint
          }
        ]
      }
    ]

    tags: union(_tags, { 'azd-service-name': 'orchestrator' })
  }
}

// DataIngest Container App
module containerAppDataIngest 'br/public:avm/res/app/container-app:0.16.0' = {
  name: 'containerAppDataIngestModule'
  params: {
    name:                  _dataIngestContainerAppName
    location:              _location
    environmentResourceId: containerEnv.outputs.resourceId

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
        image    : _dataIngestContainerImage
        resources: {
          cpu    : '0.5'
          memory : '1.0Gi'
        }
        env: [
          {
            name  : 'APP_CONFIG_ENDPOINT'
            value : appConfig.outputs.endpoint
          }
        ]
      }
    ]

    tags: union(_tags, { 'azd-service-name': 'dataingest' })
  }
}

// Front-End Container App
module containerAppFrontend 'br/public:avm/res/app/container-app:0.16.0' = {
  name: 'containerAppFrontendModule'
  params: {
    name:                  _frontEndContainerAppName
    location:              _location
    environmentResourceId: containerEnv.outputs.resourceId

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
        image    : _frontEndContainerImage
        resources: {
          cpu    : '0.5'
          memory : '1.0Gi'
        }
        env: [
          {
            name  : 'APP_CONFIG_ENDPOINT'
            value : appConfig.outputs.endpoint
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

// Role assignment: APIM ← Cognitive Services OpenAI User (AOAI Service)
module grantOpenAIUserRoleToAPIM 'core/security/role-assignment.bicep' = if (!_reuseApim && _configureRbac) {
  name: 'grantOpenAIUserRoleToAPIM'
  scope: resourceGroup()
  params: {
    principalId        : apimService.outputs.systemAssignedMIPrincipalId
    resourceType       : 'aiservices'
    resourceName       : _reuseAoai ? aoaiServiceExisting.name : aoaiService.outputs.name
    resourceGroupName  : _reuseAoai ? _existingAoaiResourceGroup: resourceGroup().name
    roleDefinitionGuid : '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  }
}

// Role assignment: AI Hub ← Key Vault Secrets User (Key Vault)
module grantKVUserToAIHub 'core/security/role-assignment.bicep' = if (_configureRbac) {
  name: 'grantKVUserToAIHub'
  scope: resourceGroup()  
  params: {
    principalId            : aiHub.outputs.systemAssignedMIPrincipalId
    resourceType           : 'keyvault'    
    resourceName           : keyVault.outputs.name
    resourceGroupName       : _reuseAifoundryHub ? _existingAifoundryHubResourceGroupName : resourceGroup().name    
    roleDefinitionGuid     : '4633458b-17de-408a-b874-0445c86b69e6'
  }
}

// Role assignment: AI Project ← Key Vault Secrets User (Key Vault)
module grantKVUserToDataIngest 'core/security/role-assignment.bicep' = if (_configureRbac) {
  name: 'grantKVUserToDataIngest'
  scope: resourceGroup()  
  params: {
    principalId            : aiProject.outputs.systemAssignedMIPrincipalId
    resourceType           : 'keyvault'    
    resourceName           : keyVault.outputs.name
    roleDefinitionGuid     : '4633458b-17de-408a-b874-0445c86b69e6'
  }
}

// Role assignment: AI Hub ← Storage Blob Data Contributor (AI Foundry Storage)
module grantAIFoundryStorageContributorToHub 'core/security/role-assignment.bicep' = if (_configureRbac) {
  name: 'grantAIFoundryStorageContributorToHub'
  scope: resourceGroup()  
  params: {
    principalId            : aiHub.outputs.systemAssignedMIPrincipalId
    resourceType           : 'storage'    
    resourceName           : storageAccountAIFoundry.outputs.name
    roleDefinitionGuid     : 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
}

// Role assignment: AI Project ← Storage Blob Data Contributor (AI Foundry Storage)
module grantAiProjectStorageBlobDataContributor 'core/security/role-assignment.bicep' = if (_configureRbac) {
  name: 'grantAiProjectStorageBlobDataContributor'
  scope: resourceGroup()  
  params: {
    principalId            : aiProject.outputs.systemAssignedMIPrincipalId
    resourceType           : 'storage'    
    resourceName           : storageAccountAIFoundry.outputs.name
    roleDefinitionGuid     : 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
}

// Role assignment: Orchestrator Container App ← App Configuration Data Reader (App Configuration)
module grantOrchestratorConfigDataReader 'core/security/role-assignment.bicep' = if (_configureRbac) {
  name: 'grantOrchestratorConfigDataReader'
  scope: resourceGroup()  
  params: {
    principalId         : containerAppOrchestrator.outputs.systemAssignedMIPrincipalId
    resourceType        : 'appconfig'
    resourceName        : appConfig.outputs.name
    roleDefinitionGuid  : '516239f1-63e1-4d78-a4de-a74fb236a071'
  }
}

// Role assignment: Frontend Container App ← App Configuration Data Reader (App Configuration)
module grantFrontendConfigDataReader 'core/security/role-assignment.bicep' = if (_configureRbac) {
  name: 'grantFrontendConfigDataReader'
  scope: resourceGroup()  
  params: {
    principalId         : containerAppFrontend.outputs.systemAssignedMIPrincipalId
    resourceType        : 'appconfig'
    resourceName        : appConfig.outputs.name
    roleDefinitionGuid  : '516239f1-63e1-4d78-a4de-a74fb236a071'
  }
}

// Role assignment: Data Ingestion Container App ← App Configuration Data Reader (App Configuration)
module grantDataIngestConfigDataReader 'core/security/role-assignment.bicep' = if (_configureRbac) {
  name: 'grantDataIngestConfigDataReader'
  scope: resourceGroup()  
  params: {
    principalId         : containerAppDataIngest.outputs.systemAssignedMIPrincipalId
    resourceType        : 'appconfig'
    resourceName        : appConfig.outputs.name
    roleDefinitionGuid  : '516239f1-63e1-4d78-a4de-a74fb236a071'
  }
}

//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////

// Outputs for azd post-provision hooks
//////////////////////////////////////////////////////////////////////////
output AZURE_SUBSCRIPTION_ID     string = subscription().subscriptionId
output AZURE_DEPLOYMENT_NAME     string = deployment().name
output AZURE_RESOURCE_GROUP      string = resourceGroup().name
output AZURE_APP_CONFIG_ENDPOINT string = appConfig.outputs.endpoint 
output RUN_AOAI_RAI_POLICIES     string = string(!_reuseAoai)
output RUN_SEARCH_SETUP          string = string(_runSearchSetup)
output AZURE_NETWORK_ISOLATION   string = string(_networkIsolation)

// Infra Configuration
//////////////////////////////////////////////////////////////////////////
output PROVISION_CONFIG object = {
  AZURE_AOAI_RESOURCE_GROUP                  : _aoaiResourceGroup        
  AZURE_APP_CONFIG_ENDPOINT                  : appConfig.outputs.endpoint
  AZURE_APP_CONFIG_NAME                      : _appConfigName
  AZURE_APP_INSIGHTS_NAME                    : _appInsightsName
  AZURE_APIM_OPENAI_API_DISPLAY_NAME         : _aoaiApiDisplayName
  AZURE_APIM_OPENAI_API_NAME                 : _aoaiApiName
  AZURE_APIM_OPENAI_API_PATH                 : _aoaiApiPath
  AZURE_APIM_OPENAI_SUBSCRIPTION_DESC        : _aoaiSubscriptionDescription
  AZURE_APIM_OPENAI_SUBSCRIPTION_NAME        : _aoaiSubscriptionName
  AZURE_APIM_PUBLISHER_EMAIL                 : _apimPublisherEmail
  AZURE_APIM_PUBLISHER_NAME                  : _apimPublisherName
  AZURE_APIM_SERVICE_NAME                    : _apimResourceName
  AZURE_CHAT_DEPLOYMENT_CAPACITY             : string(_chatDeploymentCapacity)
  AZURE_CHAT_DEPLOYMENT_NAME                 : _chatDeploymentName
  AZURE_CHAT_MODEL_DEPLOYMENT_TYPE           : _chatModelDeploymentType
  AZURE_CHAT_MODEL_VERSION                   : _chatModelVersion
  AZURE_CHAT_NUM_TOKENS                      : _chatNumTokens
  AZURE_CONFIGURE_RBAC                       : string(_configureRbac)
  AZURE_CONTAINER_ENV_NAME                   : _containerEnvName
  AZURE_CONTAINER_REGISTRY_NAME              : _containerRegistryName
  AZURE_CONTAINER_REGISTRY_ENDPOINT          : containerRegistry.outputs.loginServer  
  AZURE_CLOUD                                : _azureCloud
  AZURE_DATA_INGEST_CONTAINER_APP_NAME       : _dataIngestContainerAppName
  AZURE_DATA_INGEST_CONTAINER_IMAGE          : _dataIngestContainerImage
  AZURE_DATABASE_ACCOUNT_NAME                : _dbAccountName
  AZURE_DATABASE_CONVERSATION_CONTAINER_NAME : _conversationContainerName
  AZURE_DATABASE_DATASOURCES_CONTAINER_NAME  : _datasourcesContainerName
  AZURE_DATABASE_NAME                        : _dbDatabaseName
  AZURE_EMBEDDINGS_DEPLOYMENT_CAPACITY       : string(_embeddingsDeploymentCapacity)
  AZURE_EMBEDDINGS_DEPLOYMENT_TYPE           : _embeddingsDeploymentType
  AZURE_EMBEDDINGS_MODEL_VERSION             : _embeddingsModelVersion
  AZURE_EMBEDDINGS_VECTOR_DIMENSIONS         : _embeddingsVectorDimensions
  AZURE_ENV_NAME                             : _environmentName
  AZURE_EXISTING_AI_FOUNDRY_HUB_NAME         : _existingAifoundryHubName
  AZURE_EXISTING_AI_FOUNDRY_HUB_RG           : _existingAifoundryHubResourceGroupName
  AZURE_EXISTING_AOAI_NAME                   : _existingAoaiName
  AZURE_EXISTING_AOAI_RESOURCE_GROUP         : _existingAoaiResourceGroup
  AZURE_FRONTEND_CONTAINER_APP_NAME          : _frontEndContainerAppName
  AZURE_FRONT_END_CONTAINER_IMAGE            : _frontEndContainerImage
  AZURE_LOCATION                             : _location
  AZURE_NETWORK_ISOLATION                    : string(_networkIsolation)
  AZURE_OPENAI_API_VERSION                   : _aoaiApiVersion
  AZURE_OPENAI_CHAT_MODEL_NAME               : _chatModelName
  AZURE_OPENAI_EMBEDDING_DEPLOYMENT          : _embeddingsDeploymentName
  AZURE_OPENAI_EMBEDDING_MODEL_NAME          : _embeddingsModelName
  AZURE_OPENAI_SERVICE_NAME                  : _aoaiServiceName
  AZURE_ORCHESTRATOR_CONTAINER_APP_NAME      : _orchestratorContainerAppName
  AZURE_ORCHESTRATOR_CONTAINER_IMAGE         : _orchestratorContainerImage
  AZURE_REUSE_AI_FOUNDRY_HUB                 : _reuseAifoundryHub
  AZURE_REUSE_AOAI                           : _reuseAoai
  AZURE_REUSE_APIM                           : _reuseApim
  AZURE_RESOURCE_GROUP                       : resourceGroup().name
  AZURE_SEARCH_ANALYZER_NAME                 : _searchAnalyzerName
  AZURE_SEARCH_API_VERSION                   : _searchApiVersion
  AZURE_SEARCH_ENDPOINT                      : searchService.outputs.endpoint
  AZURE_SEARCH_INDEX_INTERVAL                : _searchIndexInterval
  AZURE_SEARCH_INDEX_NAME                    : _searchIndexName
  AZURE_SEARCH_SERVICE_NAME                  : _searchServiceName
  AZURE_STORAGE_ACCOUNT_CONTAINER_DOCS       : _storageAccountContainerDocs
  AZURE_STORAGE_ACCOUNT_CONTAINER_IMAGES     : _storageAccountContainerImages
  AZURE_SUBSCRIPTION_ID                      : subscription().subscriptionId
  AZURE_TENANT_ID                            : tenant().tenantId

  // AI Hub & Project
  AZURE_AI_FOUNDRY_HUB_NAME                  : _aiHubName
  AZURE_AI_FOUNDRY_PROJECT_AISEARCH_CONN_NAME: _aiSearchConnectionName
  AZURE_AI_FOUNDRY_PROJECT_AISERVICES_CONN_NAME: _aiServicesConnectionName
  AZURE_AI_FOUNDRY_PROJECT_AOAI_CONN_NAME    : _aoaiConnectionName
  AZURE_AI_FOUNDRY_PROJECT_CONNECTION_STRING : _aiProjectConnectionString
  AZURE_AI_FOUNDRY_PROJECT_NAME              : _aiProjectName
  AZURE_AI_FOUNDRY_STORAGE_ACCOUNT_NAME      : _aiFoundryStorageAccountName
  AZURE_AI_SERVICES_NAME                     : _aiServicesName
  AZURE_AI_SERVICES_ENDPOINT                 : aiServices.outputs.endpoint
  AZURE_SOLUTION_STORAGE_ACCOUNT_NAME        : _solutionStorageAccountName
}

// App Configuration (runtime settings)
//////////////////////////////////////////////////////////////////////////
output APP_SETTINGS object = {
  AI_FOUNDRY_PROJECT_AISEARCH_CONN_NAME     : _aiSearchConnectionName
  AI_FOUNDRY_PROJECT_AISERVICES_CONN_NAME   : _aiServicesConnectionName
  AI_FOUNDRY_PROJECT_AOAI_CONN_NAME         : _aoaiConnectionName
  AI_FOUNDRY_PROJECT_CONNECTION_STRING      : _aiProjectConnectionString
  AI_SERVICES_NAME                          : aiServices.outputs.name
  APP_CONFIG_ENDPOINT                       : appConfig.outputs.endpoint
  APP_CONFIG_NAME                           : _appConfigName
  APP_INSIGHTS_NAME                         : _appInsightsName
  APIM_OPENAI_API_PATH                      : _aoaiApiPath
  CHAT_NUM_TOKENS                           : _chatNumTokens
  CHUNKING_MIN_CHUNK_SIZE                   : _chunkingMinChunkSize
  CHUNKING_NUM_TOKENS                       : _chunkingNumTokens
  CHUNKING_TOKEN_OVERLAP                    : _chunkingTokenOverlap
  CONTAINER_REGISTRY_NAME                   : _containerRegistryName
  CONTAINER_REGISTRY_URL                    : containerRegistry.outputs.loginServer
  DATABASE_ACCOUNT_NAME                     : _dbAccountName
  DATABASE_CONVERSATION_CONTAINER_NAME      : _conversationContainerName
  DATABASE_DATASOURCES_CONTAINER_NAME       : _datasourcesContainerName
  DATABASE_NAME                             : _dbDatabaseName
  DATA_INGEST_CONTAINER_APP_NAME            : _dataIngestContainerAppName
  DATA_INGEST_CONTAINER_APP_ENDPOINT        : containerAppDataIngest.outputs.fqdn
  DOC_INTELLIGENCE_API_VERSION              : _docIntelApiVersion
  EMBEDDINGS_VECTOR_DIMENSIONS              : _embeddingsVectorDimensions
  ENVIRONMENT_NAME                          : _environmentName
  FRONTEND_CONTAINER_APP_NAME               : _frontEndContainerAppName
  KEY_VAULT_URI                             : keyVault.outputs.uri
  LOCATION                                  : _location
  OPENAI_API_VERSION                        : _aoaiApiVersion
  OPENAI_CHAT_DEPLOYMENT                    : _chatDeploymentName
  OPENAI_CHAT_MODEL_NAME                    : _chatModelName
  OPENAI_EMBEDDING_DEPLOYMENT               : _embeddingsDeploymentName
  OPENAI_EMBEDDING_MODEL_NAME               : _embeddingsModelName
  OPENAI_SERVICE_NAME                       : _reuseAoai ? aoaiServiceExisting.name : aoaiService.outputs.name
  ORCHESTRATOR_CONTAINER_APP_NAME           : _orchestratorContainerAppName
  ORCHESTRATOR_CONTAINER_APP_ENDPOINT       : containerAppOrchestrator.outputs.fqdn
  RESOURCE_GROUP                            : resourceGroup().name
  SEARCH_API_VERSION                        : _searchApiVersion
  SEARCH_ENDPOINT                           : searchService.outputs.endpoint
  SEARCH_INDEX_NAME                         : _searchIndexName
  SEARCH_SERVICE_NAME                       : searchService.outputs.name
  STORAGE_ACCOUNT_CONTAINER_DOCS            : _storageAccountContainerDocs
  STORAGE_ACCOUNT_CONTAINER_IMAGES          : _storageAccountContainerImages
  STORAGE_ACCOUNT_NAME                      : _solutionStorageAccountName
  SUBSCRIPTION_ID                           : subscription().subscriptionId
}

