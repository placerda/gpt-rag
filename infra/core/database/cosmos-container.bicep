@description('The name of the Cosmos DB SQL database.')
param databaseName string

@description('The name of the Cosmos DB account.')
param cosmosAccountName string

@description('The name of the container to be created.')
param containerName string

@description('The partition key path for the container (default is /partitionKey).')
param partitionKeyPath string = '/partitionKey'

@description('The default TTL (in seconds) for container items. Set to -1 for infinite TTL.')
param defaultTtl int = -1

// Declare the Cosmos DB account as an existing resource.
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' existing = {
  name: cosmosAccountName
}

// Declare the Cosmos SQL database as an existing resource.
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-04-15' existing = {
  name: databaseName
  parent: cosmosAccount
}

// Create the container as a child resource of the SQL database.
resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-04-15' = {
  name: containerName
  parent: cosmosDatabase
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          partitionKeyPath
        ]
        kind: 'Hash'
      }
      defaultTtl: defaultTtl
    }
  }
}

output containerId string = container.properties.resource.id
