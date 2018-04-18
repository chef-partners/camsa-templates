resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')
location = attribute('location', default: 'westeurope')

title 'Ensure that the script extension has been deployed for each machine'

%w(chef automate).each do |component|
  control format('AMA Script Extension - %s Server', component) do
    impact 1.0
    title 'Ensure the script has been deployed'

    resource_name = format('inspec-%s-%s-VM/InstallAndConfigure%s', component, unique_string, component.split(" ").map {|word| word.capitalize}.join(" "))

    describe azure_generic_resource(group_name: resource_group_name, name: resource_name) do
      its('properties.publisher') { should cmp 'Microsoft.Azure.Extensions' }
      its('properties.type') { should cmp 'CustomScript' }
      its('properties.settings.fileUris.first') { should include format('%s-server.sh', component) }
      its('properties.provisioningState') { should cmp 'Succeeded' }
    end
  end
end
