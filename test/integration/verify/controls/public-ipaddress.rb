resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')

title 'Check Public IP Addresses'

control 'Automate-Server-Public-IP-Address' do
  impact 1.0
  title 'Ensure that the settings are correct for the public IP address for the Automate server'

  describe azure_generic_resource(group_name: resource_group_name, name: "inspec-automate-#{unique_string}-PublicIP") do
    its('location') { should cmp 'westeurope' }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.publicIPAddressVersion') { should cmp 'IPv4' }
    its('properties.publicIPAllcationMethod') { should cmp 'Dynamic' }
    its('properties.dnsSettings.domainNameLabel') { should cmp "inspec-automate-#{unique_string}" }
  end
end

control 'Chef-Server-Public-IP-Address' do
  impact 1.0
  title 'Ensure that the settings are correct for the public IP address for the Chef server'

  describe azure_generic_resource(group_name: resource_group_name, name: "inspec-chef-#{unique_string}-PublicIP") do
    its('location') { should cmp 'westeurope' }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.publicIPAddressVersion') { should cmp 'IPv4' }
    its('properties.publicIPAllcationMethod') { should cmp 'Dynamic' }
    its('properties.dnsSettings.domainNameLabel') { should cmp "inspec-chef-#{unique_string}" }
  end
end
