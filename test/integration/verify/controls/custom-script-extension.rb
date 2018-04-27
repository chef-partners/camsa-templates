resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')
provider = attribute('provider', default: '33194f91-eb5f-4110-827a-e95f640a9e46')

title 'Ensure that the script extension has been deployed for each machine'

%w(chef automate).each do |component|
  control format('AMA Script Extension - %s Server', component) do
    impact 1.0
    title 'Ensure the script has been deployed'

    component_title = component.split(' ').map(&:capitalize).join(' ')
    resource_name = format('inspec-%s-%s-VM/InstallAndConfigure%s', component, unique_string, component_title)

    describe azure_generic_resource(group_name: resource_group_name, name: resource_name) do
      its('type') { should eq 'Microsoft.Compute/virtualMachines/extensions' }
      its('properties.publisher') { should cmp 'Microsoft.Azure.Extensions' }
      its('properties.type') { should cmp 'CustomScript' }
      its('properties.settings.fileUris.first') { should include format('%s-server.sh', component) }
      its('properties.provisioningState') { should cmp 'Succeeded' }

      its('tags') { should include 'provider' }
      its('tags') { should include 'description' }
      its('provider_tag') { should cmp provider }
      its('description_tag') { should include format('Script to install and configure the %s server', component_title) }
    end
  end
end
