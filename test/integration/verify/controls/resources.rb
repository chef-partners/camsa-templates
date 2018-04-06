title 'Check all resources are present'

control 'Azure-Managed-Automate-Resources' do
  impact 1.0
  title 'Determine that all resources for the Managed Application have been created'

  describe azure_generic_resource(group_name: 'ama-20180406-6') do
    # It should have two public IP addresses
    its('Microsoft.Network/publicIPAddresses') { should eq 2 }

    # It should have two network interfaces, one for each vm
    its('Microsoft.Network/networkInterfaces') { should eq 2 }
  end
end
