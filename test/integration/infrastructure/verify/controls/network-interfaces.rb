resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')
location = attribute('location', default: 'westeurope')
customer_subnet_name = attribute('customer_subnet_name', default: 'InSpec-Customer-Subnet')
provider = attribute('provider', default: '2680257b-9f22-4261-b1ef-72412d367a68')
prefix = attribute('prefix', default: 'inspec')

title 'Check that all Network Interface Cards are setup correctly'

control 'AMA-Automate-Server-Customer-NIC' do
  impact 1.0
  title 'Ensure that the NIC connected to the Customer VNet is configured correctly'

  describe azure_generic_resource(group_name: resource_group_name, name: "#{prefix}-automate-#{unique_string}-Customer-VNet-NIC") do
    its('type') { should eq 'Microsoft.Network/networkInterfaces' }
    its('location') { should cmp location }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.ipConfigurations.first.properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.ipConfigurations.first.properties.privateIPAllocationMethod') { should cmp 'Dynamic' }
    its('properties.ipConfigurations.first.properties.publicIPAddress.id') { should include "#{prefix}-automate-#{unique_string}-PublicIP" }
    its('properties.ipConfigurations.first.properties.subnet.id') { should include customer_subnet_name }
    its('properties.ipConfigurations.first.properties.primary') { should be true }
    its('properties.ipConfigurations.first.properties.privateIPAddressVersion') { should cmp 'IPv4' }

    its('properties.dnsSettings.dnsServers.count') { should be 0 }
    its('properties.dnsSettings.appliedDnsServers.count') { should be 0 }

    its('properties.enableAcceleratedNetworking') { should be false }
    its('properties.enableIPForwarding') { should be false }

    # Ensure it is connected to the correct network security group
    its('properties.networkSecurityGroup.id') { should include "#{prefix}-automate-#{unique_string}-Customer-NSG" }

    its('tags') { should include 'provider' }
    its('tags') { should include 'description' }
    its('provider_tag') { should cmp provider }
    its('description_tag') { should include 'Network card for the Automate server connected to the customer subnet' }
  end
end

control 'AMA-Chef-Server-Customer-NIC' do
  impact 1.0
  title 'Ensure that the NIC connected to the Customer VNet is configured correctly'

  describe azure_generic_resource(group_name: resource_group_name, name: "#{prefix}-chef-#{unique_string}-Customer-VNet-NIC") do
    its('type') { should eq 'Microsoft.Network/networkInterfaces' }
    its('location') { should cmp location }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.ipConfigurations.first.properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.ipConfigurations.first.properties.privateIPAllocationMethod') { should cmp 'Dynamic' }
    its('properties.ipConfigurations.first.properties.publicIPAddress.id') { should include "#{prefix}-chef-#{unique_string}-PublicIP" }
    its('properties.ipConfigurations.first.properties.subnet.id') { should include customer_subnet_name }
    its('properties.ipConfigurations.first.properties.primary') { should be true }
    its('properties.ipConfigurations.first.properties.privateIPAddressVersion') { should cmp 'IPv4' }

    its('properties.dnsSettings.dnsServers.count') { should be 0 }
    its('properties.dnsSettings.appliedDnsServers.count') { should be 0 }

    its('properties.enableAcceleratedNetworking') { should be false }
    its('properties.enableIPForwarding') { should be false }

    # Ensure it is connected to the correct network security group
    its('properties.networkSecurityGroup.id') { should include "#{prefix}-chef-#{unique_string}-Customer-NSG" }

    its('tags') { should include 'provider' }
    its('tags') { should include 'description' }
    its('provider_tag') { should cmp provider }
    its('description_tag') { should include 'Network card for the Chef server connected to the customer subnet' }    
  end
end
