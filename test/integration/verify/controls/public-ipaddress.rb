resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')
location = attribute('location', default: 'westeurope')
provider = attribute('provider', default: '33194f91-eb5f-4110-827a-e95f640a9e46')

title 'Check Public IP Addresses'

control 'Automate-Server-Public-IP-Address' do
  impact 1.0
  title 'Ensure that the settings are correct for the public IP address for the Automate server'

  describe azure_generic_resource(group_name: resource_group_name, name: "inspec-automate-#{unique_string}-PublicIP") do
    its('type') { should eq 'Microsoft.Network/publicIPAddresses' }
    its('location') { should cmp location }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.publicIPAddressVersion') { should cmp 'IPv4' }
    its('properties.publicIPAllocationMethod') { should cmp 'Dynamic' }
    its('properties.dnsSettings.domainNameLabel') { should cmp "inspec-automate-#{unique_string}" }

    its('tags') { should include 'provider' }
    its('tags') { should include 'description' }
    its('provider_tag') { should cmp provider }
    its('description_tag') { should include 'Public IP address for the Automate server' }
  end
end

control 'Chef-Server-Public-IP-Address' do
  impact 1.0
  title 'Ensure that the settings are correct for the public IP address for the Chef server'

  describe azure_generic_resource(group_name: resource_group_name, name: "inspec-chef-#{unique_string}-PublicIP") do
    its('type') { should eq 'Microsoft.Network/publicIPAddresses' }
    its('location') { should cmp location }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.publicIPAddressVersion') { should cmp 'IPv4' }
    its('properties.publicIPAllocationMethod') { should cmp 'Dynamic' }
    its('properties.dnsSettings.domainNameLabel') { should cmp "inspec-chef-#{unique_string}" }

    its('tags') { should include 'provider' }
    its('tags') { should include 'description' }
    its('provider_tag') { should cmp provider }
    its('description_tag') { should include 'Public IP address for the Chef server' }        
  end
end
