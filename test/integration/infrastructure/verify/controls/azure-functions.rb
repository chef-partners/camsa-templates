resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')
location = attribute('location', default: 'westeurope')
prefix = attribute('prefix', default: 'inspec')

# This name needs to be specified because for AppServices Azure passes the displayname and not the name of the location
# So westeurope = West Europe
location_name = attribute('location_name', default: 'West Europe')

provider = attribute('provider', default: '2680257b-9f22-4261-b1ef-72412d367a68')

title 'Ensure that the server farm, website and functions are setup correctly'

# Set the name of the app service to be used for testing
app_service_plan_name = format('%s-%s-AppServicePlan', prefix, unique_string)
app_service_name = format('%s-%s-AppService', prefix, unique_string)

control 'AMA Functions Service Plan (Server Farm)' do
  impact 1.0
  title 'Service Plan is using the Consumption Hosting option'

  describe azure_generic_resource(group_name: resource_group_name, name: app_service_plan_name) do
    its('type') { should eq 'Microsoft.Web/serverfarms' }
    its('location') { should cmp location_name }

    its('properties.status') { should cmp 'Ready' }

    its('tags') { should include 'provider' }
    its('tags') { should include 'description' }
    its('provider_tag') { should cmp provider }
    its('description_tag') { should include 'Service plan to host functions for setup and logging' }
  end
end

control 'AMA Functions Server (Web site)' do
  impact 1.0
  title 'Website to host the functions for the managed application'

  describe azure_generic_resource(group_name: resource_group_name, name: app_service_name) do
    its('type') { should eq 'Microsoft.Web/sites' }
    its('location') { should cmp location_name }
    its('kind') { should cmp 'functionapp' }

    its('properties.hostNames') { should include format('%s.azurewebsites.net', app_service_name.downcase) }
    its('properties.webSpace') { should cmp format('%s-%swebspace', resource_group_name, location_name.gsub(/\s/, '')) }
    its('properties.repositorySiteName') { should cmp app_service_name }

    its('properties.enabled') { should be true }

    # Check that it is linked to the correct service plan
    its('properties.serverFarmId') { should include app_service_plan_name }

    its('properties.sku') { should cmp 'Dynamic' }

    its('tags') { should include 'provider' }
    its('tags') { should include 'description' }
    its('provider_tag') { should cmp provider }
    its('description_tag') { should include 'Website app service to store the various functions required for the Chef Managed App' }
  end
end
