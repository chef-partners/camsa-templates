resource_group_name = input('resource_group_name', value: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = input('unique_string', value: '9j2f')
location = input('location', value: 'westeurope')
prefix = input('prefix', value: 'inspec')
sa_name = input('sa_name', value: '12345678')

title 'Ensure that the API Connection is configured correctly'

# Set the name of the API connection resource
api_connection_name = format('%s-AzureBlob-APIConnection', prefix)

control 'CAMSA Azure Blob API Connection' do
  impact 1.0
  title 'API Connection'

  describe azure_generic_resource(group_name: resource_group_name, name: api_connection_name) do
    its('type') { should eq 'Microsoft.Web/connections' }
    its('location') { should cmp location }

    its('properties.displayName') { should cmp 'StorageAccountConnection' }

    its('properties.statuses.first.status') { should cmp 'Connected' }

    # Ensure that the correct api is being used
    its('properties.api.name') { should cmp 'azureblob' }
  end
end
