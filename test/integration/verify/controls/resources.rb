resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')

title 'Check all resources are present'

control 'Azure-Managed-Automate-Resources' do
  impact 1.0
  title 'Determine that all resources for the Managed Application have been created'

  describe azure_generic_resource(group_name: resource_group_name) do
    # There should be at least 1 virtual network which should be the one that we created
    # for support purposes. Although it is recommended that the managed app is deployed into
    # an isolated resource group there is nothing to enforce this so there maybe more than one
    # virtual network in the resource group
    its('Microsoft.Network/virtualNetworks') { should >= 1 }

    # It should have two public IP addresses
    its('Microsoft.Network/publicIPAddresses') { should eq 2 }

    # It should have two network interfaces, one for each vm
    its('Microsoft.Network/networkInterfaces') { should eq 4 }
  end
end
