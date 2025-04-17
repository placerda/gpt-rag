// main.bicep - Deployment Template (Resource Group Scope) using Azure Verified Modules (AVM)
// Reference: https://azure.github.io/Azure-Verified-Modules/indexes/bicep/bicep-resource-modules/


targetScope = 'resourceGroup'

//////////////////////////////////////////////////////////////////////////
// PARAMETERS
//////////////////////////////////////////////////////////////////////////

@description('Environment name used for tagging resources.')
param environmentName string = 'dev'
@description('Primary deployment location.')
param location string 
@description('Key-value pairs of tags to assign to all resources.')
param deploymentTags object = {}
@description('Principal ID used to assign access roles.')
param principalId string = ''

@description('Existing AI project connection string; leave empty to deploy new AI.')
param aiExistingProjectConnectionString string = ''
@description('Reuse an existing AI Foundry Hub?')
param foundryHubReuse bool = false
@description('Existing Foundry Hub resource group name (if reusing).')
param existingFoundryHubResourceGroupName string = ''
@description('Existing Foundry Hub name (if reusing).')
param existingFoundryHubName string = ''

// Override names (leave empty to generate)
param aiHubName string = ''
param aiProjectName string = ''
param aiServicesName string = ''
param appConfigName string = ''
param containerRegistryName string = ''
param dataIngestFunctionAppName string = ''
param keyVaultName string = ''
param logAnalyticsWorkspaceName string = ''
param appInsightsName string = ''
param appServicePlanName string = ''
param frontEndAppServiceName string = ''
param aiFoundryStorageAccountName string = ''
param functionAppStorageAccountName string = ''
param solutionStorageAccountName string = ''
param searchServiceName string = ''
param provisionAPIM bool = true
param apimResourceName string = ''
param apimSku string = ''
param apimSkuCount int = 1
param apimPublisherEmail string = ''
param apimPublisherName string = ''
param openAIAPIName string = ''
param openAIAPIPath string = ''
param openAIAPIDisplayName string = ''
param openAIAPISpecURL string = ''
param openAISubscriptionName string = ''
param openAISubscriptionDescription string = ''
param dbAccountName string = ''
param dbDatabaseName string = ''
param conversationContainerName string = ''
param datasourcesContainerName string = ''
param funcAppRuntimeVersion string = ''
param frontEndAppRuntimeVersion string = ''
param semanticSearch string = ''
param orchestratorContainerAppName string = ''
param orchestratorImage string = ''


@description('GPT tokens per minute (in thousands).')
@minValue(1)
@maxValue(300)
param chatGptDeploymentCapacity      int    = 120

@description('Embeddings tokens per minute (in thousands).')
param embeddingsDeploymentCapacity   int    = 120

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// ─────────────────────────────────────────────────────────────────────────────
// Fallback “effective” values for every string parameter, underscore‑prefixed
// ─────────────────────────────────────────────────────────────────────────────
var _environmentName            = empty(environmentName           ) ? 'dev'                              : environmentName
var _location                   = empty(location                  ) ? 'eastus2'                          : location
var _principalId                = empty(principalId               ) ? ''                                 : principalId
var _aiExistingProjectConnectionString = empty(aiExistingProjectConnectionString) ? ''                   : aiExistingProjectConnectionString
var _existingFoundryHubResourceGroupName = empty(existingFoundryHubResourceGroupName) ? ''             : existingFoundryHubResourceGroupName
var _existingFoundryHubName     = empty(existingFoundryHubName    ) ? ''                                 : existingFoundryHubName
var _aiHubName = empty(aiHubName) ? '' : aiHubName

var _aiProjectName              = empty(aiProjectName             ) ? 'ai-project-${resourceToken}'      : aiProjectName
var _aiServicesName             = empty(aiServicesName            ) ? '${abbrs.openaiServices}0-${resourceToken}'        : aiServicesName
var _appConfigName              = empty(appConfigName             ) ? '${abbrs.appConfigurationStores}-${resourceToken}'  : appConfigName
var _solutionStorageAccountName = empty(solutionStorageAccountName) ? '${abbrs.storageStorageAccounts}rag0${resourceToken}'   : solutionStorageAccountName
var _containerRegistryName      = empty(containerRegistryName     ) ? '${abbrs.containerRegistries}${resourceToken}'     : containerRegistryName
var _dataIngestFunctionAppName  = empty(dataIngestFunctionAppName ) ? '${abbrs.functionApps}-${resourceToken}'           : dataIngestFunctionAppName
var _keyVaultName               = empty(keyVaultName              ) ? '${abbrs.keyVaultVaults}0-${resourceToken}'        : keyVaultName
var _logAnalyticsWorkspaceName  = empty(logAnalyticsWorkspaceName ) ? '${abbrs.operationalInsightsWorkspaces}0-${resourceToken}' : logAnalyticsWorkspaceName
var _appInsightsName            = empty(appInsightsName           ) ? '${abbrs.insightsComponents}0-${resourceToken}'    : appInsightsName
var _appServicePlanName         = empty(appServicePlanName        ) ? '${abbrs.serverfarms}0-${resourceToken}'           : appServicePlanName
var _frontEndAppServiceName     = empty(frontEndAppServiceName    ) ? '${abbrs.webSites}0-${resourceToken}'            : frontEndAppServiceName
var _aiFoundryStorageAccountName = empty(aiFoundryStorageAccountName) ? '${abbrs.storageStorageAccounts}ai0${resourceToken}' : aiFoundryStorageAccountName
var _functionAppStorageAccountName = empty(functionAppStorageAccountName) ? '${abbrs.storageStorageAccounts}ing0${resourceToken}'  : functionAppStorageAccountName
var _searchServiceName          = empty(searchServiceName         ) ? '${abbrs.searchSearchServices}0-${resourceToken}' : searchServiceName

var _openAIAPIName              = empty(openAIAPIName             ) ? 'openai'                            : openAIAPIName
var _openAIAPIPath              = empty(openAIAPIPath             ) ? 'openai'                            : openAIAPIPath
var _openAIAPIDisplayName       = empty(openAIAPIDisplayName      ) ? 'OpenAI'                            : openAIAPIDisplayName
var _openAIAPISpecURL           = empty(openAIAPISpecURL          ) ? 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json' : openAIAPISpecURL
var _openAISubscriptionName     = empty(openAISubscriptionName    ) ? 'openai-subscription'               : openAISubscriptionName
var _openAISubscriptionDescription = empty(openAISubscriptionDescription) ? 'OpenAI Subscription'            : openAISubscriptionDescription

var _apimSku                    = empty(apimSku)                   ? 'Consumption'          : apimSku
var _apimPublisherEmail         = empty(apimPublisherEmail)        ? 'noreply@example.com'  : apimPublisherEmail
var _apimPublisherName          = empty(apimPublisherName)         ? 'MyCompany'            : apimPublisherName

var _dbAccountName              = empty(dbAccountName)            ? '${abbrs.cosmosDbAccount}0-${resourceToken}' : dbAccountName    
var _dbDatabaseName             = empty(dbDatabaseName)           ? '${abbrs.cosmosDbDatabase}0-${resourceToken}' : dbDatabaseName
var _conversationContainerName  = empty(conversationContainerName) ? 'conversations'       : conversationContainerName
var _datasourcesContainerName   = empty(datasourcesContainerName)  ? 'datasources'         : datasourcesContainerName

var _orchestratorContainerAppName = empty(orchestratorContainerAppName) ? 'orchestrator-${resourceToken}' : orchestratorContainerAppName
var _orchestratorImage = empty(orchestratorImage) ? '${registry.outputs.loginServer}/orchestrator:latest' : orchestratorImage

var _funcAppRuntimeVersion      = empty(funcAppRuntimeVersion     ) ? '3.11'                             : funcAppRuntimeVersion
var _frontEndAppRuntimeVersion  = empty(frontEndAppRuntimeVersion ) ? '3.12'                             : frontEndAppRuntimeVersion
var _semanticSearch             = empty(semanticSearch            ) ? 'disabled'                         : semanticSearch

@allowed([
  ''  // allow fallback
  'gpt-35-turbo'
  'gpt-35-turbo-16k'
  'gpt-4'
  'gpt-4-32k'
  'gpt-4o'
  'gpt-4o-mini'
])
param chatGptModelName string = ''
var _chatGptModelName           = empty(chatGptModelName          ) ? 'gpt-4o'                           : chatGptModelName

@allowed([
  '' // allow fallback
  'Standard'
  'ProvisionedManaged'
  'GlobalStandard'
])
param chatGptModelDeploymentType string = ''
var _chatGptModelDeploymentType  = empty(chatGptModelDeploymentType ) ? 'GlobalStandard'                  : chatGptModelDeploymentType

@allowed([
  '' // allow fallback
  '0613'
  '1106'
  '1106-Preview'
  '0125-preview'
  'turbo-2024-04-09'
  '2024-05-13'
  '2024-11-20'
])
param chatGptModelVersion string = ''
var _chatGptModelVersion         = empty(chatGptModelVersion       ) ? '2024-11-20'                      : chatGptModelVersion

param chatGptDeploymentName string = ''
var _chatGptDeploymentName      = empty(chatGptDeploymentName      ) ? 'chat'                             : chatGptDeploymentName

param embeddingsModelName string = ''
var _embeddingsModelName       = empty(embeddingsModelName        ) ? 'text-embedding-3-large'           : embeddingsModelName

@allowed(['', 'Standard'])
param embeddingsDeploymentType string = ''
var _embeddingsDeploymentType  = empty(embeddingsDeploymentType   ) ? 'Standard'                         : embeddingsDeploymentType

@allowed(['', '1', '2'])
param embeddingsModelVersion string = ''
var _embeddingsModelVersion   = empty(embeddingsModelVersion      ) ? '1'                                : embeddingsModelVersion

param embeddingsDeploymentName string = ''
var _embeddingsDeploymentName  = empty(embeddingsDeploymentName   ) ? 'text-embedding'                   : embeddingsDeploymentName

//////////////////////////////////////////////////////////////////////////
// VARIABLES
//////////////////////////////////////////////////////////////////////////

var tags = union({ env: _environmentName }, deploymentTags)

// Abbreviation dictionary
var abbrs = {
  resourcesResourceGroups: 'rg'
  insightsComponents: 'appins'
  keyVaultVaults: 'kv'
  storageStorageAccounts: 'st'
  operationalInsightsWorkspaces: 'law'
  searchSearchServices: 'search'
  appConfigurationStores: 'appconfig'
  containerRegistries: 'cr'
  webSites: 'webgpt'
  serverfarms: 'appplan'
  cognitiveServicesAccounts: 'ai'
  openaiServices: 'oai'
  functionApps: 'funcdataingest'
  cosmosDbAccount: 'dbgpt'
  cosmosDbDatabase: 'db'
}

//////////////////////////////////////////////////////////////////////////
// MODULES 
//////////////////////////////////////////////////////////////////////////

// 1. App Configuration Store
module appConfig 'br/public:avm/res/app-configuration/configuration-store:0.1.1' = {
  name: 'appConfigModule'
  params: {
    name:     _appConfigName
    location: _location
    sku:      'Standard'
    tags:     tags
    keyValues: [
      {
        name:  'AI_SERVICES_NAME'
        value: empty(aiServicesName)
          ? '${abbrs.cognitiveServicesAccounts}0-${resourceToken}'
          : aiServicesName
      }
      {
        name:  'APP_CONFIG_NAME'
        value: _appConfigName
      }
      {
        name:  'APP_INSIGHTS_NAME'
        value: _appInsightsName
      }
      {
        name:  'APP_SERVICE_PLAN_NAME'
        value: _appServicePlanName
      }
      { name: 'AZURE_OPENAI_API_VERSION',          value: '2024-10-21' }
      { name: 'AZURE_OPENAI_CHATGPT_DEPLOYMENT',    value: 'chat' }
      { name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT',  value: 'text-embedding' }
      { name: 'AZURE_OPENAI_EMBEDDING_MODEL',       value: 'text-embedding-3-large' }
      {
        name:  'AZURE_OPENAI_SERVICE_NAME'
        value: _aiServicesName
      }
      { name: 'AZURE_RESOURCE_GROUP_NAME',         value: resourceGroup().name }
      {
        name:  'CONTAINER_REGISTRY_NAME'
        value: _containerRegistryName
      }
      {
        name:  'DATA_INGEST_FUNCTION_APP_NAME'
        value: _dataIngestFunctionAppName
      }
      {
        name:  'FRONT_END_APP_SERVICE_NAME'
        value: _frontEndAppServiceName
      }
      {
        name:  'FUNCTION_APP_NAME'
        value: _dataIngestFunctionAppName
      }
      {
        name:  'KEY_VAULT_NAME'
        value: _keyVaultName
      }
      { name: 'LOCATION',                          value: _location }
      {
        name:  'OPENAI_SERVICE_NAME'
        value: _aiServicesName
      }
      {
        name:  'SEARCH_SERVICE_NAME'
        value: _searchServiceName
      }
      {
        name:  'STORAGE_ACCOUNT_NAME'
        value: _solutionStorageAccountName
      }
      { name: 'STORAGE_CONTAINER',                 value: 'documents' }
      { name: 'STORAGE_CONTAINER_IMAGES',          value: 'documents-images' }
      { name: 'NUM_TOKENS',                        value: '2048' }
      { name: 'MIN_CHUNK_SIZE',                    value: '100' }
      { name: 'TOKEN_OVERLAP',                     value: '200' }
      { name: 'ENVIRONMENT_NAME',                  value: _environmentName }
      { name: 'RESOURCE_TOKEN',                    value: resourceToken }
    ]
  }
}

var appConfigConnectionString = listKeys(
  resourceId(
    'Microsoft.AppConfiguration/configurationStores',
    _appConfigName
  ),
  '2021-03-01-preview'
).value[0].connectionString

// 3. Container Registry
module registry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: 'containerRegistryModule'
  params: {
    name:     _containerRegistryName
    location: _location
    acrSku:   'Basic'
    tags:     tags
  }
}

// 18. Container Apps Environment (required backing resource)
module containerEnv 'br/public:avm/res/app/managed-environment:0.9.1' = {
  name: 'containerEnvModule'
  params: {
    name:     'ace-${resourceToken}'
    location: _location
    tags:     tags
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
  }
}


// 19. Orchestrator Container App (AVM v0.16.0)
module orchestrator 'br/public:avm/res/app/container-app:0.16.0' = {
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
            name      : 'AppConfigConnectionString'
            secretRef : 'appConfigConn'
          }
        ]
      }
    ]

    secrets: [
      {
        name  : 'appConfigConn'
        value : appConfigConnectionString
      }
    ]

    tags: tags
  }
}

// 4. Log Analytics Workspace
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

// 6. Application Insights
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

// 5. Key Vault
module keyVault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: 'keyVaultModule'
  params: {
    name:                  _keyVaultName
    location:              _location
    sku:                   'standard'
    enableRbacAuthorization: true
    tags:                  tags
  }
}

// 7. AI Foundry Storage Account
module aiFoundryStorageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: 'aiFoundryStorageModule'
  params: {
    name:                     _aiFoundryStorageAccountName
    location:                 _location
    skuName:                  'Standard_LRS'
    kind:                     'StorageV2'
    allowBlobPublicAccess:    false
    supportsHttpsTrafficOnly: true
    tags:                     tags
  }
}

// 7. Shared App Service Plan
module appServicePlan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  name: 'appServicePlanModule'
  params: {
    name:         _appServicePlanName
    location:     _location
    skuName:      'P0v3'
    skuCapacity:  1
    kind:         'linux'
    reserved:     true
    tags:         tags
  }
}

// 8. Function App Storage Account
module functionAppStorageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: 'functionAppStorageModule'
  params: {
    name:                     _functionAppStorageAccountName
    location:                 _location
    skuName:                  'Standard_LRS'
    kind:                     'StorageV2'
    allowBlobPublicAccess:    false
    supportsHttpsTrafficOnly: true
    tags:                     tags
  }
}

// 8. Data Ingestion Function App
module functionApp 'br/public:avm/res/web/site:0.15.1' = {
  name: 'functionAppModule'
  params: {
    name:                     _dataIngestFunctionAppName
    kind:                     'functionapp,linux'
    location:                 _location
    serverFarmResourceId:     appServicePlan.outputs.resourceId
    managedIdentities:        { systemAssigned: true }
    // link to Log Analytics via diagnosticSettings:
    diagnosticSettings: [
      {
        name:               'functionApp-diag'
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]
    // if you also want App Insights:
    appInsightResourceId:     appInsights.outputs.resourceId

    // storage mount for function triggers/logs:
    storageAccountResourceId:            functionAppStorageAccount.outputs.resourceId
    storageAccountUseIdentityAuthentication: true

    siteConfig: {
      linuxFxVersion: 'python|${funcAppRuntimeVersion}'
    }
    appSettingsKeyValuePairs: {
      AppConfigConnectionString: appConfigConnectionString
      ENABLE_ORYX_BUILD:          'true'
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'
      LOGLEVEL:                   'INFO'
    }
    tags: tags
  }
}


// 16. Front‑End App Service
module frontEnd 'br/public:avm/res/web/site:0.15.1' = {
  name: 'frontEndModule'
  params: {
    name:                     _frontEndAppServiceName
    kind:                     'app,linux'
    location:                 _location
    serverFarmResourceId:     appServicePlan.outputs.resourceId
    managedIdentities:        { systemAssigned: true }
    diagnosticSettings: [
      {
        name:               'frontEnd-diag'
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]
    appInsightResourceId:     appInsights.outputs.resourceId

    // if your front end also needs a storage account:
    storageAccountResourceId:            functionAppStorageAccount.outputs.resourceId
    storageAccountUseIdentityAuthentication: true

    siteConfig: {
      linuxFxVersion: 'python|${frontEndAppRuntimeVersion}'
      appCommandLine: 'python -m uvicorn main:app --host 0.0.0.0 --port \${PORT:-8000}'
    }
    appSettingsKeyValuePairs: {
      AppConfigConnectionString: appConfigConnectionString
    }
    tags: union(tags, { 'azd-service-name': 'frontend' })
  }
}

module databaseAccount 'br/public:avm/res/document-db/database-account:0.12.0' = {
  name: 'databaseAccountModule'
  params: {
    name:                   _dbAccountName  
    location:               _location
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

// 10. Azure Cognitive Search Service
module searchService 'br/public:avm/res/search/search-service:0.9.2' = {
  name: 'searchServiceModule'
  params: {
    // Required parameters
    name:                              _searchServiceName
    location:                          _location
    // Tags
    tags: tags
    // SKU & capacity
    sku: 'standard'
    semanticSearch: empty(semanticSearch) ? 'disabled' : semanticSearch
  }
}


// AI Services (including OpenAI deployments)
module aiServices 'br/public:avm/res/cognitive-services/account:0.10.2' = {
  name: 'aiServicesModule'
  params: {
    kind:     'AIServices'
    name:     _aiServicesName
    location: _location
    sku:      'S0'
    tags:     tags

    deployments: [
      {
        name: _chatGptDeploymentName       
        model: {
          format:  'OpenAI'
          name:    _chatGptModelName
          version: _chatGptModelVersion
        }
        sku: {
          name:     _chatGptModelDeploymentType
          capacity: chatGptDeploymentCapacity
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
          capacity: embeddingsDeploymentCapacity
        }
      }
    ]
  }
}

// 17. API Management Service + AI Services API + Policy + Subscription
module apimService 'br/public:avm/res/api-management/service:0.9.1' = if (provisionAPIM) {
  name: 'apimModule'
  params: {
    name           : empty(apimResourceName) ? 'apim-${resourceToken}' : apimResourceName
    location       : _location
    publisherEmail : _apimPublisherEmail
    publisherName  : _apimPublisherName
    sku            : _apimSku
    tags           : tags
    backends: [
      {
        name : 'ai-services-backend'
        url  : aiServices.outputs.endpoint
        tls : {
          validateCertificateChain : true
          validateCertificateName  : true
        }
      }
    ]

    apis: [
      {
        displayName : _openAIAPIDisplayName
        name        : _openAIAPIName
        path        : _openAIAPIPath
        protocols   : [ 'https' ]
        serviceUrl  : aiServices.outputs.endpoint
        format      : 'openapi-link'
        value       : _openAIAPISpecURL
      }
    ]

    policies: [
      {
        format: 'xml'
        value: '''
        <policies>
          <inbound>
            <authentication-managed-identity 
              resource="https://cognitiveservices.azure.com" 
              output-token-variable-name="managed-id-access-token" 
              ignore-error="false" />
            <set-header name="Authorization" exists-action="override">
              <value>@("Bearer " + (string)context.Variables["managed-id-access-token"])</value>
            </set-header>
            <set-backend-service backend-id="ai-services-backend" />
          </inbound>
          <!-- empty sections are fine if you want to preserve them -->
          <backend />
          <outbound />
          <on-error />
        </policies>
        '''
      }
    ]

    subscriptions: [
      {
        name        : _openAISubscriptionName
        displayName : _openAISubscriptionDescription
        scope       : '/apis'
      }
    ]
  }
}



// 13. AI Foundry Hub (custom)
module aiHub 'core/ai/ai-hub.bicep' = if (!foundryHubReuse && empty(_aiExistingProjectConnectionString)) {
  name: 'aiHubModule'
  scope: resourceGroup()
  params: {
    location:              _location
    tags:                  tags
    hubName:               empty(_aiHubName) 
                          ? 'aihub-${uniqueString(resourceGroup().id)}' 
                          : _aiHubName
    keyVaultName:          keyVault.outputs.name
    storageAccountName:    aiFoundryStorageAccount.outputs.name
    applicationInsightsName: appInsights.outputs.name
  }
}

resource existingAiHub 'Microsoft.MachineLearningServices/workspaces@2024-01-01-preview' existing = if (foundryHubReuse) {
  name: _existingFoundryHubName
  scope: resourceGroup(_existingFoundryHubResourceGroupName)
}
var aiHubId = foundryHubReuse ? existingAiHub.id : (empty(_aiExistingProjectConnectionString) ? aiHub.outputs.hubId : '')

// 14. AI Foundry Project (custom)
module aiProject 'core/ai/ai-project.bicep' = {
  name: 'aiProjectModule'
  scope: resourceGroup()
  params: {
    location: _location
    tags: tags
    projectName: empty(_aiProjectName) ? 'ai-project-${resourceToken}' : _aiProjectName
    hubResourceId: aiHubId
    discoveryUrl: empty(aiHub.outputs.hubDiscoveryUrl) ? '' : aiHub.outputs.hubDiscoveryUrl
  }
}


//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////
// Core parameters
output AZURE_ENVIRONMENT_NAME                       string = _environmentName
output AZURE_LOCATION                               string = _location
output AZURE_DEPLOYMENT_TAGS                        object = deploymentTags
output AZURE_PRINCIPAL_ID                           string = _principalId

// AI Foundry inputs
output AZURE_AI_EXISTING_PROJECT_CONNECTION_STRING  string = _aiExistingProjectConnectionString
output AZURE_FOUNDRY_HUB_REUSE                      bool   = foundryHubReuse
output AZURE_EXISTING_FOUNDRY_HUB_RESOURCE_GROUP_NAME string = _existingFoundryHubResourceGroupName
output AZURE_EXISTING_FOUNDRY_HUB_NAME              string = _existingFoundryHubName
output AZURE_AI_HUB_NAME                            string = aiHub.outputs.hubName
output AZURE_AI_PROJECT_NAME                        string = aiProject.outputs.projectName

// Platform service names
output AZURE_APP_CONFIG_NAME                        string = appConfig.outputs.name
output AZURE_CONTAINER_REGISTRY_NAME                string = registry.outputs.name
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME           string = logAnalytics.outputs.name
output AZURE_APP_INSIGHTS_NAME                      string = appInsights.outputs.name
output AZURE_KEY_VAULT_NAME                         string = keyVault.outputs.name
output AZURE_AIFOUNDRY_STORAGE_ACCOUNT_NAME         string = aiFoundryStorageAccount.outputs.name
output AZURE_FUNCTION_APP_STORAGE_ACCOUNT_NAME      string = functionAppStorageAccount.outputs.name
output AZURE_APP_SERVICE_PLAN_NAME                  string = appServicePlan.outputs.name
output AZURE_FUNCTION_APP_NAME                      string = functionApp.outputs.name
output AZURE_FRONT_END_APP_SERVICE_NAME             string = frontEnd.outputs.name
output AZURE_SEARCH_SERVICE_NAME                    string = searchService.outputs.name
output AZURE_ORCHESTRATOR_APP_NAME                  string = orchestrator.outputs.name
output AZURE_ORCHESTRATOR_APP_FQDN                  string = orchestrator.outputs.fqdn
output AZURE_ORCHESTRATOR_APP_ID                    string = orchestrator.outputs.resourceId

// AI Services (OpenAI) deployments
output AZURE_OPENAI_SERVICE_NAME                    string = aiServices.outputs.name
output AZURE_CHATGPT_DEPLOYMENT_NAME                string = _chatGptDeploymentName
output AZURE_EMBEDDINGS_DEPLOYMENT_NAME             string = _embeddingsDeploymentName

// API Management
output AZURE_PROVISION_APIM                         bool   = provisionAPIM
output AZURE_APIM_SKU_CAPACITY                      int    = apimSkuCount
output AZURE_APIM_SERVICE_NAME                      string = apimService.outputs.name
output AZURE_APIM_SKU                               string = _apimSku
output AZURE_APIM_PUBLISHER_EMAIL                   string = _apimPublisherEmail
output AZURE_APIM_PUBLISHER_NAME                    string = _apimPublisherName
output AZURE_APIM_AI_SUBSCRIPTION_NAME              string = _openAISubscriptionName
output AZURE_APIM_AI_SUBSCRIPTION_DESCRIPTION       string = _openAISubscriptionDescription

// Runtime & feature flags
output AZURE_FUNCAPP_RUNTIME_VERSION                string = _funcAppRuntimeVersion
output AZURE_FRONTEND_RUNTIME_VERSION               string = _frontEndAppRuntimeVersion
output AZURE_SEMANTIC_SEARCH                        string = _semanticSearch

output AZURE_DB_ACCOUNT_NAME                        string = _dbAccountName
output AZURE_DB_DATABASE_NAME                       string = _dbDatabaseName

output AZURE_CONVERSATION_CONTAINER_NAME            string = _conversationContainerName
output AZURE_DATASOURCES_CONTAINER_NAME             string = _datasourcesContainerName
