resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')
location = attribute('location', default: 'westeurope')
provider = attribute('provider', default: '33194f91-eb5f-4110-827a-e95f640a9e46')

title 'Ensure that the Log Analytics workspace is configured correctly'

control 'AMA Log Analytics Workspace' do
  impact 1.0
  title 'Log Analytics workspace'

  describe azure_generic_resource(group_name: resource_group_name, name: format('inspec-%s-LogAnalytics', unique_string)) do
    its('type') { should eq 'Microsoft.OperationalInsights/workspaces' }
    its('location') { should cmp location }

    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.sku.name') { should cmp 'free' }
    its('properties.retentionInDays') { should eq 7 }

    its('tags') { should include 'provider' }
    its('tags') { should include 'description' }
    its('provider_tag') { should cmp provider }
    its('description_tag') { should include 'Log Analytics workspace to capture information about the health of the Chef Automate Managed App' }
  end
end
