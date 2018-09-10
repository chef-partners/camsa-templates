resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
location = attribute('location', default: 'westeurope')
prefix = attribute('prefix', default: 'inspec')

title 'Ensure that the LogicApp for Backup Housekeeping is properly configured'

# Set the name of the logic app
logic_app_name = format('%s-Backup-HouseKeeping-LogicApp', prefix)

control 'AMA Backup LogicApp' do
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
