resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')
location = attribute('location', default: 'westeurope')
provider = attribute('provider', default: '33194f91-eb5f-4110-827a-e95f640a9e46')

title 'Check AMA Chef and Automate virtual machines'

%w(chef automate).each do |component|
  control format('AMA %s Server', component) do
    impact 1.0
    title format('Check the attributes of the %s server', component)

    component_title = component.split(' ').map(&:capitalize).join(' ')
    server_name = format('inspec-%s-%s-VM', component, unique_string)
    customer_nic_name = format('inspec-%s-%s-Customer-VNet-NIC', component, unique_string)
    disk_name = format('inspec-%s-%s-OSDisk', component, unique_string)

    describe azure_virtual_machine(group_name: resource_group_name, name: server_name) do
      its('type') { should eq 'Microsoft.Compute/virtualMachines' }
      its('location') { should cmp location }

      # Ensure that the machine is from an Ubuntu image
      its('publisher') { should cmp 'canonical' }
      its('offer') { should cmp 'ubuntuserver' }
      its('sku') { should cmp '16.04-LTS' }

      # There should be no data disk attached to the machine
      its('data_disk_count') { should eq 0 }

      # The template sets authentication using an SSK key so password authentication should 
      # be disabled
      it { should_not have_password_authentication }
      it { should have_ssh_keys }
      its('ssh_key_count') { should > 0 }

      # There should be 2 nics attached to the machine
      # these should be one for the AMA network and one for the customer
      it { should have_nics }
      its('nic_count') { should eq 1 }
      its('connected_nics') { should include /#{customer_nic_name}/ }

      # Ensure that boot diagnostics have been enabled
      it { should have_boot_diagnostics }

      # ensure the OSDisk is setup correctly
      its('os_type') { should eq 'Linux' }
      its('os_disk_name') { should eq disk_name }
      it { should have_managed_osdisk }
      its('create_option') { should eq 'FromImage' }

      its('tags') { should include 'provider' }
      its('tags') { should include 'description' }
      its('provider_tag') { should cmp provider }
      its('description_tag') { should include format('%s Server Virtual Machine', component_title) } 
    end
  end
end
