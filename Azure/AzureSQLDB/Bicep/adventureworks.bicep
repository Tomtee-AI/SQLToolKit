param location string = resourceGroup().location
param sqlServerName string = 'adventureworksserver'
param sqlDbName string = 'adventureworksdb'
param adminLogin string = 'sqladmin'
param adminPassword string = 'P@ssw0rd123!'  // Replace with secure value (use param secureString for production)

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    version: '12.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: location
  sku: {
    name: 'S0'  // Standard S0; adjust tier/capacity as needed (e.g., 'GP_Gen5_2' for vCore)
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    sampleName: 'AdventureWorksLT'  // Deploys lightweight AdventureWorks sample; for full, import bacpac post-deploy
  }
}

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output connectionString string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabase.name};Persist Security Info=False;User ID=${adminLogin};Password=${adminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
