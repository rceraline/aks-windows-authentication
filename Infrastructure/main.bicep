param location string = resourceGroup().location
param tenantId string = subscription().tenantId

@description('Admin user account for the DC.')
param username string = 'useradmin'

@description('Admin user account for the DC.')
@secure()
param password string

param acrName string = 'cr${uniqueString(resourceGroup().id)}'

param kvName string = 'kv-${uniqueString(resourceGroup().id)}'

var dnsServers = [ '168.63.129.16', '10.0.0.4' ]

var clusterName = 'aks-01'

var agentCount = 2

var agentVMSize = 'standard_d2s_v3'

resource vnet01 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'vnet-01'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    dhcpOptions: {
      dnsServers: dnsServers
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'snet-01'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'snet-02'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

resource dcNetworkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: 'nic-dc-01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig-1'
        properties: {
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: vnet01.properties.subnets[1].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
          privateIPAddress: '10.0.0.4'
        }
      }
    ]
  }
}

resource vm01NetworkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: 'nic-vm-01'
  location: location
  properties: {
    dnsSettings: {
      dnsServers: [
        '10.0.0.4'
      ]
    }
    ipConfigurations: [
      {
        name: 'ipconfig-1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.0.5'
          subnet: {
            id: vnet01.properties.subnets[1].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
  }
}

resource dc 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'vm-dc-01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D3_v2'
    }
    osProfile: {
      computerName: 'vm-dc-01'
      adminUsername: username
      adminPassword: password
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: 'disk-dc-01'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: dcNetworkInterface.id
        }
      ]
    }
  }
}

resource vm01 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'vm-01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D3_v2'
    }
    osProfile: {
      computerName: 'vm-01'
      adminUsername: username
      adminPassword: password
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: 'disk-vm-01'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm01NetworkInterface.id
        }
      ]
    }
  }
}

resource dcScript 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: 'dc-script'
  location: location
  parent: dc
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    settings: {
      commandToExecute: 'powershell Install-WindowsFeature AD-Domain-Services -IncludeManagementTools; Install-ADDSForest -DomainName "mycompany.local" -DomainNetbiosName mycompany -InstallDNS -SafeModeAdministratorPassword $(ConvertTo-SecureString "${password}" -AsPlainText -Force) -Force'
    }
  }
}

resource basIp 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'ip-bas-01'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: 'bas-01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ip-bas-01'
        properties: {
          subnet: {
            id: vnet01.properties.subnets[0].id
          }
          publicIPAddress: {
            id: basIp.id
          }
        }
      }
    ]
  }
}

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: kvName
  location: location
  properties: {
    tenantId: tenantId
    accessPolicies: []
    sku: {
      name: 'standard'
      family: 'A'
    }
    enableSoftDelete: false
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
}

var networkContributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: 'id-control-plane-01'
  location: location
}

resource vnetNetworkContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(managedIdentity.id, vnet01.id, networkContributorRoleDefinitionId)
  scope: vnet01
  properties: {
    roleDefinitionId: networkContributorRoleDefinitionId
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2023-06-02-preview' = {
  name: clusterName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    dnsPrefix: clusterName
    agentPoolProfiles: [
      {
        name: 'linux01'
        osDiskSizeGB: 0
        count: 1
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: vnet01.properties.subnets[2].id
      }
      {
        name: 'win01'
        osDiskSizeGB: 0
        count: agentCount
        vmSize: agentVMSize
        osType: 'Windows'
        vnetSubnetID: vnet01.properties.subnets[2].id
      }
    ]
    networkProfile: {
      dnsServiceIP: '10.1.1.4'
      networkPlugin: 'azure'
      serviceCidr: '10.1.1.0/24'
    }
    windowsProfile: {
      adminUsername: username
      adminPassword: password
      gmsaProfile: {
        enabled: true
      }
    }
  }
}

output acrUrl string = '${acr.name}.azurecr.io'
