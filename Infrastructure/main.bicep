param location string = resourceGroup().location
param tenantId string = subscription().tenantId

@description('Admin user account for the DC.')
param dcAdminUsername string = 'useradmin'

@secure()
param dcAdminPassword string

@description('Admin user account for the vm01.')
param vm01AdminUsername string = 'useradmin'

@secure()
param vm01AdminPassword string

@secure()
param dcSafeModeAdministratorPassword string

param acrName string

param kvName string

resource vnetHub 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'vnet-hub'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-01'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
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
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetHub.properties.subnets[0].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
  }
}

resource vm01NetworkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: 'nic-vm-01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig-1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetHub.properties.subnets[0].id
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
      adminUsername: dcAdminUsername
      adminPassword: dcAdminPassword
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
      adminUsername: vm01AdminUsername
      adminPassword: vm01AdminPassword
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
      commandToExecute: 'powershell Install-WindowsFeature AD-Domain-Services -IncludeManagementTools; Install-ADDSForest -DomainName "mycompany.local" -SafeModeAdministratorPassword $(ConvertTo-SecureString "${dcSafeModeAdministratorPassword}" -AsPlainText -Force) -Force'
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
            id: vnetHub.properties.subnets[1].id
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
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
}
