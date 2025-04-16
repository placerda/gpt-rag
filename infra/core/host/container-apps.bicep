@description('Creates an Azure Container App.')
param name string
param location string = resourceGroup().location
param tags object = {}

@description('Allowed origins for CORS.')
param allowedOrigins array = []
@description('Name of the Container Apps environment.')
param containerAppsEnvironmentName string
@description('CPU cores per container (e.g., 0.5).')
param containerCpuCoreCount string = '0.5'
@description('Max number of container replicas.')
@minValue(1)
param containerMaxReplicas int = 10
@description('Memory per container (e.g., 1.0Gi).')
param containerMemory string = '1.0Gi'
@description('Min number of container replicas.')
param containerMinReplicas int = 1
@description('Name of the container.')
param containerName string = 'main'
@allowed([ 'http', 'grpc' ])
@description('Protocol for container app communication.')
param daprAppProtocol string = 'http'
@description('Dapr app ID.')
param daprAppId string = containerName
@description('Enable Dapr.')
param daprEnabled bool = false
@description('Environment variables for the container.')
param env array = []
@description('Whether the app ingress is external.')
param external bool = true
@description('Type of identity for the container app.')
@allowed([ 'None', 'SystemAssigned', 'UserAssigned' ])
param identityType string = 'None'
@description('Name of the container image.')
param imageName string = ''
@description('Whether ingress is enabled.')
param ingressEnabled bool = true
param revisionMode string = 'Single'
@secure()
@description('Secrets for the container app.')
param secrets object = {}
@description('Service binds for the container app.')
param serviceBinds array = []
@description('Target port for the container.')
param targetPort int = 80

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: containerAppsEnvironmentName
}

resource containerApp 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: identityType
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: revisionMode
      ingress: ingressEnabled ? {
        external: external
        targetPort: targetPort
        transport: 'auto'
        corsPolicy: {
          allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
        }
      } : null
      dapr: daprEnabled ? {
        enabled: true
        appId: daprAppId
        appProtocol: daprAppProtocol
        appPort: ingressEnabled ? targetPort : 0
      } : { enabled: false }
      secrets: [for secret in items(secrets): {
        name: secret.key
        value: secret.value
      }]
      service: !empty(serviceBinds) ? { type: serviceBinds[0].serviceType } : null
      registries: []
    }
    template: {
      containers: [
        {
          name: containerName
          image: imageName
          env: env
          resources: {
            cpu: json(containerCpuCoreCount)
            memory: containerMemory
          }
        }
      ]
      scale: {
        minReplicas: containerMinReplicas
        maxReplicas: containerMaxReplicas
      }
    }
  }
}

output defaultDomain string = containerApp.properties.configuration.ingress.fqdn
output name string = containerApp.name
output uri string = ingressEnabled ? 'https://${containerApp.properties.configuration.ingress.fqdn}' : ''
