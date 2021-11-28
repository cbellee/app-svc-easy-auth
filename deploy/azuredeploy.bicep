param location string = 'australiaeast'
param prefix string = 'cbellee-app-oauth-demo'
param acrName string
param version string = '0.0.1'
param backendAppId string

var frontendWebAppName = '${prefix}-fe'
var backendWebAppName = '${prefix}-be'
var serverFarmName = '${prefix}-plan'
var backendUri = 'https://${backendWebApp.properties.defaultHostName}/helloBackend'

resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
    anonymousPullEnabled: false
  }
}

resource serverFarm 'Microsoft.Web/serverfarms@2021-02-01' = {
  dependsOn: [
    acr
  ]
  name: serverFarmName
  location: location
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
    size: 'P1v3'
    family: 'Pv3'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: true
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource acrBackendWebHook 'Microsoft.ContainerRegistry/registries/webhooks@2021-06-01-preview' = {
  parent: acr
  name: 'backendACRWebHook'
  location: location
  properties: {
    status: 'enabled'
    scope: 'backend:*'
    actions: [
      'push'
    ]
    serviceUri: '${list(resourceId('Microsoft.Web/sites/config', backendWebAppName, 'publishingcredentials'), '2015-08-01').properties.scmUri}/docker/hook'
  }
}

resource acrFrontendWebhook 'Microsoft.ContainerRegistry/registries/webhooks@2021-06-01-preview' = {
  parent: acr
  name: 'frontendACRWebHook'
  location: location
  properties: {
    status: 'enabled'
    scope: 'frontend:*'
    actions: [
      'push'
    ]
    serviceUri: '${list(resourceId('Microsoft.Web/sites/config', frontendWebAppName, 'publishingcredentials'), '2015-08-01').properties.scmUri}/docker/hook' //'list(${frontendWebAppConfig.id}, publishingcredentials), 2015-08-01).properties.scmUri, /docker/hook'
  }
}

resource backendWebApp 'Microsoft.Web/sites@2021-02-01' = {
  dependsOn: [
    acr
  ]
  name: backendWebAppName
  location: 'Australia East'
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    serverFarmId: serverFarm.id
    reserved: true
    isXenon: false
    hyperV: false
    siteConfig: {
      numberOfWorkers: 1
      acrUseManagedIdentityCreds: false
      alwaysOn: true
      http20Enabled: false
      functionAppScaleLimit: 0
      minimumElasticInstanceCount: 1
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    clientCertMode: 'Required'
    hostNamesDisabled: false
    containerSize: 0
    dailyMemoryTimeQuota: 0
    httpsOnly: false
    redundancyMode: 'None'
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

resource frontendWebApp 'Microsoft.Web/sites@2021-02-01' = {
  dependsOn: [
    acr
  ]
  name: frontendWebAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    serverFarmId: serverFarm.id
    reserved: true
    isXenon: false
    hyperV: false
    siteConfig: {
      numberOfWorkers: 1
      acrUseManagedIdentityCreds: false
      alwaysOn: true
      http20Enabled: false
      functionAppScaleLimit: 0
      minimumElasticInstanceCount: 1
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    clientCertMode: 'Required'
    hostNamesDisabled: false
    containerSize: 0
    dailyMemoryTimeQuota: 0
    httpsOnly: false
    redundancyMode: 'None'
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

resource backendWebAppConfig 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: backendWebApp
  name: 'web'
  properties: {
    appSettings: [
      {
        name: 'DOCKER_ENABLE_CI'
        value: 'true'
      }
      {
        name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
        value: (listCredentials(acr.id, acr.apiVersion)).passwords[0].value
      }
      {
        name: 'DOCKER_REGISTRY_SERVER_USERNAME'
        value: acr.name
      }
      {
        name: 'DOCKER_REGISTRY_SERVER_URL'
        value: 'https://${acr.properties.loginServer}'
      }
    ]
    numberOfWorkers: 1
    defaultDocuments: [
      'Default.htm'
      'Default.html'
      'Default.asp'
      'index.htm'
      'index.html'
      'iisstart.htm'
      'default.aspx'
      'index.php'
      'hostingstart.html'
    ]
    netFrameworkVersion: 'v4.0'
    linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/backend:${version}'
    requestTracingEnabled: false
    remoteDebuggingEnabled: false
    remoteDebuggingVersion: 'VS2019'
    httpLoggingEnabled: false
    acrUseManagedIdentityCreds: false
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: false
    scmType: 'None'
    use32BitWorkerProcess: true
    webSocketsEnabled: false
    alwaysOn: true
    managedPipelineMode: 'Integrated'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true
      }
    ]
    loadBalancing: 'LeastRequests'
    experiments: {
      rampUpRules: []
    }
    autoHealEnabled: false
    vnetRouteAllEnabled: false
    vnetPrivatePortsCount: 0
    localMySqlEnabled: false
    ipSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: false
    minTlsVersion: '1.2'
    scmMinTlsVersion: '1.0'
    ftpsState: 'AllAllowed'
    preWarmedInstanceCount: 0
    functionAppScaleLimit: 0
    functionsRuntimeScaleMonitoringEnabled: false
    minimumElasticInstanceCount: 1
    azureStorageAccounts: {}
  }
}

resource frontendWebAppConfig 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: frontendWebApp
  name: 'web'
  properties: {
    numberOfWorkers: 1
    defaultDocuments: [
      'Default.htm'
      'Default.html'
      'Default.asp'
      'index.htm'
      'index.html'
      'iisstart.htm'
      'default.aspx'
      'index.php'
      'hostingstart.html'
    ]
    appSettings: [
      {
        name: 'BACKEND_URI'
        value: backendUri
      }
      {
        name: 'BACKEND_CLIENT_ID'
        value: backendAppId
      }
      {
        name: 'DOCKER_ENABLE_CI'
        value: 'true'
      }
      {
        name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
        value: (listCredentials(acr.id, acr.apiVersion)).passwords[0].value
      }
      {
        name: 'DOCKER_REGISTRY_SERVER_USERNAME'
        value: acr.name
      }
      {
        name: 'DOCKER_REGISTRY_SERVER_URL'
        value: 'https://${acr.properties.loginServer}'
      }
    ]
    netFrameworkVersion: 'v4.0'
    linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/frontend:${version}'
    requestTracingEnabled: false
    remoteDebuggingEnabled: false
    remoteDebuggingVersion: 'VS2019'
    httpLoggingEnabled: false
    acrUseManagedIdentityCreds: false
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: false
    scmType: 'None'
    use32BitWorkerProcess: true
    webSocketsEnabled: false
    alwaysOn: true
    managedPipelineMode: 'Integrated'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true
      }
    ]
    loadBalancing: 'LeastRequests'
    experiments: {
      rampUpRules: []
    }
    autoHealEnabled: false
    vnetRouteAllEnabled: false
    vnetPrivatePortsCount: 0
    localMySqlEnabled: false
    ipSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: false
    minTlsVersion: '1.2'
    scmMinTlsVersion: '1.0'
    ftpsState: 'AllAllowed'
    preWarmedInstanceCount: 0
    functionAppScaleLimit: 0
    functionsRuntimeScaleMonitoringEnabled: false
    minimumElasticInstanceCount: 1
    azureStorageAccounts: {}
  }
}

resource backend_auth_settings 'Microsoft.Web/sites/config@2021-02-01' = {
  name: 'authsettingsV2'
  parent: backendWebApp
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: backendAppId
        }
      }
    }
  }
}

output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output acrPassword string = (listCredentials(acr.id, acr.apiVersion)).passwords[0].value
output acrId string = acr.id
output frontendMIObjectId string = frontendWebApp.identity.principalId
