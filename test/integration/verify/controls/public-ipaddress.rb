title 'Check Public IP Addresses'

control 'Automate-Server-Public-IP-Address' do
  impact 1.0
  title 'Ensure that the settings are correct for the public IP address for the Automate server'

  describe azure_generic_resource(group_name: 'ama-20180406-6', name: 'inspec-automate-9j2f-PublicIP') do
    its('location') { should cmp 'westeurope' }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.publicIPAddressVersion') { should cmp 'IPv4' }
    its('properties.publicIPAllcationMethod') { should cmp 'Dynamic' }
    its('properties.dnsSettings.domainNameLabel') { should cmp 'inspec-automate-9j2f' }
  end
end

control 'Chef-Server-Public-IP-Address' do
  impact 1.0
  title 'Ensure that the settings are correct for the public IP address for the Chef server'

  describe azure_generic_resource(group_name: 'ama-20180406-6', name: 'inspec-chef-9j2f-PublicIP') do
    its('location') { should cmp 'westeurope' }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.publicIPAddressVersion') { should cmp 'IPv4' }
    its('properties.publicIPAllcationMethod') { should cmp 'Dynamic' }
    its('properties.dnsSettings.domainNameLabel') { should cmp 'inspec-chef-9j2f' }
  end
end
