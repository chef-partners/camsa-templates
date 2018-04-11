resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')

title 'Check all resources are present'

control 'Azure-Managed-Automate-Resources' do
  impact 1.0
  title 'Determine that all resources for the Managed Application have been created'

  describe azure_generic_resource(group_name: resource_group_name) do
    # It should have two public IP addresses
    its('Microsoft.Network/publicIPAddresses') { should eq 2 }

    # It should have two network interfaces, one for each vm
    its('Microsoft.Network/networkInterfaces') { should eq 4 }

    # It should have two network security groups, one for each server
    its('Microsoft.Network/networkSecurityGroups') { should eq 2 }

    # There should be one storage account to store the boot diagnostics
    # of the servers
    its('Microsoft.Storage/storageAccounts') { should eq 1 }

    its('Microsoft.Compute/virtualMachines') { should eq 2 }

    # The VMs should each have a disk associated
    its('Microsoft.Compute/disks') { should eq 2 }
  end
end
