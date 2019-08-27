resource_group_name = input('resource_group_name', value: 'InSpec-AMA', description: 'Name of the resource group to interogate')
location = input('location', value: 'westeurope')
prefix = input('prefix', value: 'inspec')

title 'Ensure that the LogicApp for Backup Housekeeping is properly configured'

# Set the name of the logic app
logic_app_name = format('%s-Backup-HouseKeeping-LogicApp', prefix)

control 'CAMSA Backup LogicApp' do
  impact 1.0
  title 'LogicApp for Housekeeping'

  describe azure_generic_resource(group_name: resource_group_name, name: logic_app_name) do
    its('type') { should eq 'Microsoft.Logic/workflows' }
    its('location') { should cmp location }

    its('properties.provisioningState') { should cmp 'Succeeded' }

    its('properties.state') { should cmp 'Enabled' }

    its('tags') { should include 'description' }
  end
end
