resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')
prefix = attribute('prefix', default: 'inspec')

# Set the name of the ActionGroup to be used for testing
action_group_name = format('%s-%s-ActionGroup', prefix, unique_string)

title 'Ensure that the Action Group for alerts has been deployed properly'

control 'AMA Action Group' do
  impact 1.0
  title 'Email notifications are configured'

  describe azure_generic_resource(group_name: resource_group_name, name: action_group_name) do
    its('type') { should eq 'Microsoft.Insights/ActionGroups' }
    
    its('properties.groupShortName') { should eq 'camsa-ag' }
    its('properties.enabled') { should be true }

    its('properties.emailReceivers.count') { should cmp 1 }
  end
end
