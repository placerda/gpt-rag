// core/database/cosmos-account.bicep
@description('The name of the Cosmos DB account.')
param accountName string

@description('The location for the Cosmos DB account.')
param location string

@description('The name for the SQL database.')
param sqlDatabaseName string

// Resource for Cosmos DB account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    // Additional properties…
  }
}

// Resource for SQL database (child of account)
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-04-15' = {
  name: sqlDatabaseName
  parent: cosmosAccount
  properties: {
    resource: {
      id: sqlDatabaseName
    }
  }
}

output cosmosAccountName string = cosmosAccount.name
output databaseName string = cosmosDatabase.name
