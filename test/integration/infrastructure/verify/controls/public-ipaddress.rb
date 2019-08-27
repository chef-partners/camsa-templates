resource_group_name = input('resource_group_name', value: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = input('unique_string', value: '9j2f')
location = input('location', value: 'westeurope')
provider = input('provider', value: '2680257b-9f22-4261-b1ef-72412d367a68')
prefix = input('prefix', value: 'inspec')

title 'Check Public IP Addresses'

control 'Automate-Server-Public-IP-Address' do
  impact 1.0
  title 'Ensure that the settings are correct for the public IP address for the Automate server'

  describe azure_generic_resource(group_name: resource_group_name, name: "#{prefix}-automate-#{unique_string}-PublicIP") do
    its('type') { should eq 'Microsoft.Network/publicIPAddresses' }
    its('location') { should cmp location }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.publicIPAddressVersion') { should cmp 'IPv4' }
    its('properties.publicIPAllocationMethod') { should cmp 'Dynamic' }
    its('properties.dnsSettings.domainNameLabel') { should cmp "#{prefix}-automate-#{unique_string}" }

    its('tags') { should include 'provider' }
    its('tags') { should include 'description' }
    its('provider_tag') { should cmp provider }
    its('description_tag') { should include 'Public IP address for the Automate server' }
  end
end

control 'Chef-Server-Public-IP-Address' do
  impact 1.0
  title 'Ensure that the settings are correct for the public IP address for the Chef server'

  describe azure_generic_resource(group_name: resource_group_name, name: "#{prefix}-chef-#{unique_string}-PublicIP") do
    its('type') { should eq 'Microsoft.Network/publicIPAddresses' }
    its('location') { should cmp location }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.publicIPAddressVersion') { should cmp 'IPv4' }
    its('properties.publicIPAllocationMethod') { should cmp 'Dynamic' }
    its('properties.dnsSettings.domainNameLabel') { should cmp "#{prefix}-chef-#{unique_string}" }

    its('tags') { should include 'provider' }
    its('tags') { should include 'description' }
    its('provider_tag') { should cmp provider }
    its('description_tag') { should include 'Public IP address for the Chef server' }        
  end
end
