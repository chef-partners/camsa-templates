resource_group_name = input('resource_group_name', value: 'InSpec-AMA', description: 'Name of the resource group to interogate')
test_number_of_resources = input('test_number_of_resources', value: false)


title 'Check all resources are present'

control 'Azure-Managed-Automate-Resources' do
  impact 1.0
  title 'Determine that all resources for the Managed Application have been created'

  only_if { test_number_of_resources }

  describe azure_generic_resource(group_name: resource_group_name) do
    # It should have two public IP addresses
    its('Microsoft.Network/publicIPAddresses') { should eq 2 }

    # It should have two network interfaces, one for each vm
    its('Microsoft.Network/networkInterfaces') { should eq 2 }

    # It should have two network security groups, one for each server
    its('Microsoft.Network/networkSecurityGroups') { should eq 2 }

    # There should be one storage account to store the boot diagnostics
    # of the servers
    its('Microsoft.Storage/storageAccounts') { should eq 1 }

    its('Microsoft.Compute/virtualMachines') { should eq 2 }

    # The VMs should each have a disk associated
    its('Microsoft.Compute/disks') { should eq 2 }

    # There should be two extensions, one for each of the VMs to execute the script
    its('Microsoft.Compute/virtualMachines/extensions') { should eq 4 }

    # Set the counts for the ServerFarm, WebSite and Functions
    its('Microsoft.Web/serverFarms') { should eq 1 }
    its('Microsoft.Web/sites') { should eq 1 }

    # Log Anlytics Checks
    # its('Microsoft.Insights/scheduledQueryRules') { should eq 6 }

    # There should be resources for the logic app
    its('Microsoft.Web/connections') { should eq 1 }
    its('Microsoft.Logic/workflows') { should eq 1 }
 
  end
end
