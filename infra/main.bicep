// main.bicep - Deployment Template (Resource Group Scope)
// This template provisions the following components:
// • An Application Configuration store (centralizes properties for Function and App Services)
// • A Container Registry (to store container images)
// • An AI Foundry Environment – comprising an AI project and hub – for managing AI services
//   (the hub can be newly created or reused if desired)
// • A Data Ingest Function App (the only function app deployed)
// • A Cosmos DB account and database (with two containers)
// • A Key Vault (for securing secrets)
// • Application Insights (for monitoring)
// • An App Service Plan (for hosting the Front‑end App Service)
// • A Front‑end App Service (hosting your UI)
// • A Storage Account (for deployment packages)
// • AI Services (Cognitive Services), an Azure OpenAI resource, and an AI Search Service
// • An Orchestrator Container App (which pulls its image from the Container Registry)
// Note: Networking (vNETs, private endpoints) and the legacy orchestrator function app are omitted.

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

@description('Principal ID used to assign access roles (set by azd or manually).')
param principalId string = ''

// Parameters for AI Foundry Environment
@description('Existing AI project connection string; leave empty to deploy a new AI environment.')
param aiExistingProjectConnectionString string = ''

@description('Azure AI Foundry Hub resource name. If omitted, a new hub name is generated.')
param aiHubName string = ''

@description('Azure AI Foundry project name. If omitted, a new project name is generated.')
param aiProjectName string = ''

@description('Reuse an existing AI Foundry Hub?')
param foundryHubReuse bool = false

@description('Existing Foundry Hub resource group (if reusing).')
param existingFoundryHubResourceGroupName string = ''

@description('Existing Foundry Hub name (if reusing).')
param existingFoundryHubName string = ''

@description('The AI Services connection name. If omitted, a default value will be used.')
param aiServicesConnectionName string = ''

@description('The AI Services content safety connection name. If omitted, a default value will be used.')
param aiServicesContentSafetyConnectionName string = ''

@description('The Azure Search connection name. If omitted, a default value will be used.')
param searchConnectionName string = ''

@description('The search index name.')
param aiSearchIndexName string = 'ragindex'

@description('The log analytics workspace name for AI monitoring. If omitted, it will be generated.')
param logAnalyticsWorkspaceName string = ''

// Reuse configuration parameter
@description('Azure reuse configuration.')
param azureReuseConfig object = {}

@description('Cosmos DB configuration')
param azureDbConfig object = {}

@description('Python runtime version for Function Apps.')
param funcAppRuntimeVersion string = '3.11'
@description('Python runtime version for App Services.')
param appServiceRuntimeVersion string = '3.12'

// Naming parameters (optional overrides)
@description('Application Configuration store name. Leave empty to derive from resource token.')
param appConfigName string = ''
@description('Container Registry name. Leave empty to derive from resource token.')
param containerRegistryName string = ''
@description('Data Ingest Function App name. Leave empty to derive from resource token.')
param dataIngestFunctionAppName string = ''
@description('Key Vault name. Leave empty to derive from resource token.')
param keyVaultName string = ''
@description('Application Insights name. Leave empty to derive from resource token.')
param appInsightsName string = ''
@description('App Service Plan name. Leave empty to derive from resource token.')
param appServicePlanName string = ''
@description('Front-End App Service name. Leave empty to derive from resource token.')
param frontEndAppServiceName string = ''
@description('Storage Account name. Leave empty to derive from resource token.')
param storageAccountName string = ''
@description('AI Services name. Leave empty to derive from resource token.')
param aiServicesName string = ''
@description('Azure OpenAI Service name. Leave empty to derive from resource token.')
param openAiServiceName string = ''
@description('Search Service name. Leave empty to derive from resource token.')
param searchServiceName string = ''

//////////////////////////////////////////////////////////////////////////
// VARIABLES
//////////////////////////////////////////////////////////////////////////

// Standard variables.
var tags = union({ env: environmentName }, deploymentTags)
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Reuse defaults
var azureReuseDefaults = {
  cosmosDbReuse: false
  appInsightsReuse: false
  appServicePlanReuse: false
  appServiceReuse: false
  dataIngestionFunctionAppReuse: false
  aiServicesReuse: false
  aoaiReuse: false
  storageReuse: false
  keyVaultReuse: false
  aiSearchReuse: false
}
var reuseConfig = union(azureReuseDefaults, azureReuseConfig)

// Cosmos DB defaults.
var azureDbDefaults = {
  dbAccountName: 'dbgpt0-${resourceToken}'
  dbDatabaseName: 'db0-${resourceToken}'
  conversationContainerName: 'conversations'
  datasourcesContainerName: 'datasources'
}
var dbConfig = union(azureDbDefaults, azureDbConfig)

// Compute final names based on resourceToken. If the user did not supply an override, compute the name.
var finalAppConfigName = empty(appConfigName) ? 'appconfig-${resourceToken}' : appConfigName
var finalContainerRegistryName = empty(containerRegistryName) ? 'cr${resourceToken}' : containerRegistryName
var finalDataIngestFunctionAppName = empty(dataIngestFunctionAppName) ? 'funcdataingest-${resourceToken}' : dataIngestFunctionAppName
var finalKeyVaultName = empty(keyVaultName) ? 'kv0-${resourceToken}' : keyVaultName
var finalAppInsightsName = empty(appInsightsName) ? 'appins0-${resourceToken}' : appInsightsName
var finalAppServicePlanName = empty(appServicePlanName) ? 'appplan0-${resourceToken}' : appServicePlanName
var finalFrontEndAppServiceName = empty(frontEndAppServiceName) ? 'webgpt0-${resourceToken}' : frontEndAppServiceName
var finalStorageAccountName = empty(storageAccountName) ? 'strag0${resourceToken}' : storageAccountName
var finalAiServicesName = empty(aiServicesName) ? 'ai0-${resourceToken}' : aiServicesName
var finalOpenAiServiceName = empty(openAiServiceName) ? 'oai0-${resourceToken}' : openAiServiceName
var finalSearchServiceName = empty(searchServiceName) ? 'search0-${resourceToken}' : searchServiceName

// For Cosmos DB, use the computed account name from dbConfig.
var finalCosmosDbAccountNameFromConfig = dbConfig.dbAccountName

// Abbreviation dictionary for naming in the AI environment module.
var abbrs = {
  resourcesResourceGroups: 'rg-'
  insightsComponents: 'appins'
  keyVaultVaults: 'kv'
  storageStorageAccounts: 'st'
  operationalInsightsWorkspaces: 'law'
  searchSearchServices: 'search'
}

// Derive a project name for the AI environment.
var projectNameResolved = empty(aiProjectName) ? 'ai-project-${resourceToken}' : aiProjectName

//////////////////////////////////////////////////////////////////////////
// RESOURCES
//////////////////////////////////////////////////////////////////////////

// 1. Application Configuration Store
resource appConfig 'Microsoft.AppConfiguration/configurationStores@2021-03-01-preview' = {
  name: finalAppConfigName
  location: location
  sku: {
    name: 'Standard'
  }
  tags: tags
}

// 2. Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2019-05-01' = {
  name: finalContainerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
  tags: tags
}

// 3. Log Analytics Workspace for Monitoring (used by the Container App Environment)
param useLogAnalytics bool = true
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (useLogAnalytics) {
  name: empty(logAnalyticsWorkspaceName) ? 'law-${resourceToken}' : logAnalyticsWorkspaceName
  location: location
  sku: {
    name: 'pergb2018'
  }
  properties: {
    retentionInDays: 30
  }
  tags: tags
}
var logAnalyticsCustomerId = useLogAnalytics ? logAnalytics.properties.customerId : ''
var logAnalyticsSharedKey = useLogAnalytics ? first(listKeys(logAnalytics.id, '2023-09-01').value).primarySharedKey : ''

// 4. AI Foundry Environment (Project + Hub)
module aiEnv 'core/host/ai-environment.bicep' = if (!foundryHubReuse && empty(aiExistingProjectConnectionString)) {
  name: 'aiEnv'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    hubName: empty(aiHubName) ? 'ai-hub-${resourceToken}' : aiHubName
    projectName: projectNameResolved
    keyVaultName: finalKeyVaultName
    storageAccountName: finalStorageAccountName
    aiServicesName: empty(aiServicesName) ? 'aoai-${resourceToken}' : aiServicesName
    aiServicesConnectionName: empty(aiServicesConnectionName) ? 'aoai-${resourceToken}' : aiServicesConnectionName
    aiServicesContentSafetyConnectionName: empty(aiServicesContentSafetyConnectionName) ? 'aoai-content-safety-connection' : aiServicesContentSafetyConnectionName
    logAnalyticsName: empty(logAnalyticsWorkspaceName) ? '${abbrs.operationalInsightsWorkspaces}${resourceToken}' : logAnalyticsWorkspaceName
    applicationInsightsName: finalAppInsightsName
    searchServiceName: finalSearchServiceName
    searchConnectionName: empty(searchConnectionName) ? 'search-service-connection' : searchConnectionName
  }
}
resource existingFoundryHub 'Microsoft.AI/foundryHubs@2023-01-01' existing = if (foundryHubReuse) {
  name: existingFoundryHubName
  scope: resourceGroup(existingFoundryHubResourceGroupName)
}
var foundryHubId = foundryHubReuse ? existingFoundryHub.id : (empty(aiExistingProjectConnectionString) ? aiEnv.outputs.hubId : '')

// 5. Construct project connection string from AI environment outputs.
var projectConnectionString = empty(aiEnv.outputs.discoveryUrl)
  ? aiExistingProjectConnectionString
  : '${split(aiEnv.outputs.discoveryUrl, '/')[2]};${subscription().subscriptionId};${resourceGroup().name};${projectNameResolved}'

// 6. Data Ingest Function App
module dataIngestion 'core/host/functions.bicep' = {
  name: 'dataIngestionModule'
  params: {
    name: finalDataIngestFunctionAppName
    functionAppResourceGroupName: resourceGroup().name
    functionAppReuse: reuseConfig.dataIngestionFunctionAppReuse
    location: location
    tags: union(tags, { 'azd-service-name': 'dataIngest' })
    appServicePlanId: ''  // External App Service Plan ID (if applicable)
    runtimeName: 'python'
    runtimeVersion: funcAppRuntimeVersion
    appSettings: [
      {
        name: 'DOCINT_API_VERSION'
        value: '2024-11-30'
      }
      {
        name: 'AZURE_KEY_VAULT_NAME'
        value: finalKeyVaultName
      }
      {
        name: 'FUNCTION_APP_NAME'
        value: finalDataIngestFunctionAppName
      }
      {
        name: 'SEARCH_INDEX_NAME'
        value: 'ragindex'
      }
      {
        name: 'SEARCH_ANALYZER_NAME'
        value: 'standard'
      }
      {
        name: 'SEARCH_API_VERSION'
        value: '2024-07-01'
      }
      {
        name: 'SEARCH_INDEX_INTERVAL'
        value: 'PT1H'
      }
      {
        name: 'STORAGE_ACCOUNT_NAME'
        value: finalStorageAccountName
      }
      {
        name: 'STORAGE_CONTAINER'
        value: 'documents'
      }
      {
        name: 'STORAGE_CONTAINER_IMAGES'
        value: 'documents-images'
      }
      {
        name: 'AZURE_FORMREC_SERVICE'
        value: finalAiServicesName
      }
      {
        name: 'AZURE_OPENAI_API_VERSION'
        value: '2024-10-21'
      }
      {
        name: 'AZURE_SEARCH_APPROACH'
        value: 'hybrid'
      }
      {
        name: 'AZURE_SEARCH_SERVICE'
        value: finalSearchServiceName
      }
      {
        name: 'AZURE_SEARCH_INDEX_NAME'
        value: 'ragindex'
      }
      {
        name: 'AZURE_OPENAI_SERVICE_NAME'
        value: finalOpenAiServiceName
      }
      {
        name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT'
        value: 'text-embedding'
      }
      {
        name: 'AZURE_EMBEDDINGS_VECTOR_SIZE'
        value: '3072'
      }
      {
        name: 'AZURE_OPENAI_EMBEDDING_MODEL'
        value: 'text-embedding-3-large'
      }
      {
        name: 'AZURE_OPENAI_CHATGPT_DEPLOYMENT'
        value: 'chat'
      }
      {
        name: 'NUM_TOKENS'
        value: '2048'
      }
      {
        name: 'MIN_CHUNK_SIZE'
        value: '100'
      }
      {
        name: 'TOKEN_OVERLAP'
        value: '200'
      }
      {
        name: 'ENABLE_ORYX_BUILD'
        value: 'true'
      }
      {
        name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
        value: 'true'
      }
      {
        name: 'LOGLEVEL'
        value: 'INFO'
      }
      {
        name: 'AppConfigConnectionString'
        value: empty(appConfig.listKeys()) || empty(appConfig.listKeys().value) ? 'default-connection-string' : first(appConfig.listKeys().value).connectionString
      }
    ]
  }
}

// 7. Data Ingest Storage Account
module dataIngestionStorage 'core/storage/function-storage-account.bicep' = {
  name: 'dataIngestionStorageModule'
  params: {
    name: '${finalStorageAccountName}ing'
    location: location
    tags: tags
    containers: [
      {
        name: 'deploymentpackage'
      }
    ]
    publicNetworkAccess: 'Enabled'
  }
}

// 8. Cosmos DB Account and Database
var finalCosmosDbAccountName = finalCosmosDbAccountNameFromConfig

// Deploy the Cosmos DB account and SQL database using a module.
module cosmosAccountModule 'core/database/cosmos-account.bicep' = {
  name: 'cosmosAccountModule'
  params: {
    accountName: dbConfig.accountName
    location: location
    sqlDatabaseName: dbConfig.sqlDatabaseName
  }
}

// Deploy the Conversation Container. This module now depends on the Cosmos account module.
module conversationContainer 'core/database/cosmos-container.bicep' = {
  name: 'conversationContainerModule'
  params: {
    databaseName: cosmosAccountModule.outputs.databaseName
    cosmosAccountName: cosmosAccountModule.outputs.cosmosAccountName
    containerName: dbConfig.conversationContainerName
    partitionKeyPath: '/id'
    defaultTtl: -1
  }
}

// Deploy the Datasources Container. This module also depends on the Cosmos account module.
module datasourcesContainer 'core/database/cosmos-container.bicep' = {
  name: 'datasourcesContainerModule'
  params: {
    databaseName: cosmosAccountModule.outputs.databaseName
    cosmosAccountName: cosmosAccountModule.outputs.cosmosAccountName
    containerName: dbConfig.datasourcesContainerName
    partitionKeyPath: '/id'
    defaultTtl: -1
  }
}

// 9. Key Vault
module keyVaultModule 'core/security/keyvault.bicep' = {
  name: 'keyVaultModule'
  params: {
    name: finalKeyVaultName
    location: location
    tags: tags
    principalId: principalId
  }
}

// 10. Application Insights
module appInsights 'core/monitor/applicationinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    name: finalAppInsightsName
    location: location
    logAnalyticsWorkspaceId: logAnalytics.id
  }
}


// 11. App Service Plan (for Front-End App Service)
module appServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'appServicePlanModule'
  params: {
    name: finalAppServicePlanName
    location: location
    tags: tags
    sku: {
      name: 'P0v3'
      capacity: 1
    }
    kind: 'linux'
  }
}

// 12. Front-End App Service (with AppConfig connection string)
module frontEnd 'core/host/appservice.bicep' = {
  name: 'frontEndModule'
  params: {
    name: finalFrontEndAppServiceName
    location: location
    tags: union(tags, { 'azd-service-name': 'frontend' })
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: appServiceRuntimeVersion
    scmDoBuildDuringDeployment: true
    applicationInsightsName: finalAppInsightsName
    appSettings: {
      'AppConfigConnectionString': empty(appConfig.listKeys()) ? 'default-connection-string' : first(appConfig.listKeys().value).connectionString
      // You can add additional settings here as key-value pairs
    }    
    appCommandLine: 'python -m uvicorn main:app --host 0.0.0.0 --port \${PORT:-8000}'
  }
}

// 13. AI Services (Cognitive Services)
module aiServices 'core/ai/aiservices.bicep' = {
  name: 'aiServicesModule'
  params: {
    name: finalAiServicesName
    location: location
    publicNetworkAccess: 'Enabled'
    kind: 'CognitiveServices'
    tags: tags
    sku: {
      name: 'S0'
    }
  }
}

// 14. Azure OpenAI
module openAi 'core/ai/aiservices.bicep' = {
  name: 'openAiModule'
  params: {
    name: finalOpenAiServiceName
    location: location
    publicNetworkAccess: 'Enabled'
    tags: tags
    sku: {
      name: 'S0'
    }
    deployments: [
      {
        name: 'chat'
        model: {
          format: 'OpenAI'
          name: 'gpt-4o'
          version: '2024-11-20'
        }
        sku: {
          name: 'GlobalStandard'
          capacity: 100
        }
      }
      {
        name: 'text-embedding'
        model: {
          format: 'OpenAI'
          name: 'text-embedding-3-large'
          version: '1'
        }
        sku: {
          name: 'Standard'
          capacity: 120
        }
      }
    ]
  }
}

// 15. AI Search Service
module searchService 'core/search/search-services.bicep' = {
  name: 'searchServiceModule'
  params: {
    name: finalSearchServiceName
    location: location
    publicNetworkAccess: 'Enabled'
    tags: tags
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sku: {
      name: 'standard'
    }
  }
}

// 16. Orchestrator Container App Environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: 'containerEnv-${environmentName}'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: first(listKeys(logAnalytics.id, '2023-09-01').value).primarySharedKey
      }
    }
  }
}

// 17. Orchestrator Container App
resource orchestratorContainer 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'orchestratorContainer-${environmentName}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Multiple'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: first(listCredentials(containerRegistry.id, '2019-05-01').value).username
          passwordSecret: first(listCredentials(containerRegistry.id, '2019-05-01').value).password
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'orchestrator', image: '${containerRegistry.properties.loginServer}/orchestrator:latest'
          resources: {
            limits: {
              cpu: '0.5'
              memory: '1Gi'
            }
          }
          env: [
            {
              name: 'AppConfigConnectionString'
              value: first(appConfig.listKeys().value).connectionString
            }
          ]
        }
      ]
    }
  }
  tags: tags
}

//////////////////////////////////////////////////////////////////////////
// OUTPUTS
//////////////////////////////////////////////////////////////////////////

output AZURE_RESOURCE_GROUP_NAME string = resourceGroup().name
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_APP_CONFIG_NAME string = finalAppConfigName
output AZURE_CONTAINER_REGISTRY_NAME string = finalContainerRegistryName
output AZURE_FOUNDRY_HUB_ID string = foundryHubReuse ? existingFoundryHub.id : aiEnv.outputs.hubId
output AZURE_DATA_INGEST_FUNCTION_APP_NAME string = finalDataIngestFunctionAppName
output AZURE_COSMOS_DB_ACCOUNT_NAME string = finalCosmosDbAccountName
output AZURE_KEY_VAULT_NAME string = finalKeyVaultName
output AZURE_APP_INSIGHTS_NAME string = finalAppInsightsName
output AZURE_APP_SERVICE_PLAN_NAME string = finalAppServicePlanName
output AZURE_FRONT_END_APP_SERVICE_NAME string = finalFrontEndAppServiceName
output AZURE_STORAGE_ACCOUNT_NAME string = finalStorageAccountName
output AZURE_AI_SERVICES_NAME string = finalAiServicesName
output AZURE_OPENAI_SERVICE_NAME string = finalOpenAiServiceName
output AZURE_CHAT_GPT_DEPLOYMENT_NAME string = openAi.outputs.name
output AZURE_SEARCH_SERVICE_NAME string = finalSearchServiceName
