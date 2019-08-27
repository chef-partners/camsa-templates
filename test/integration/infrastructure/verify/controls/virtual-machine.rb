resource_group_name = input('resource_group_name', value: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = input('unique_string', value: '9j2f')
location = input('location', value: 'westeurope')
provider = input('provider', value: '2680257b-9f22-4261-b1ef-72412d367a68')
prefix = input('prefix', value: 'inspec')

title 'Check AMA Chef and Automate virtual machines'

%w(chef automate).each do |component|
  control format('CAMSA %s Server', component) do
    impact 1.0
    title format('Check the attributes of the %s server', component)

    component_title = component.split(' ').map(&:capitalize).join(' ')
    server_name = format('%s-%s-%s-VM', prefix, component, unique_string)
    customer_nic_name = format('%s-%s-%s-Customer-VNet-NIC', prefix, component, unique_string)
    disk_name = format('%s-%s-%s-OSDisk', prefix, component, unique_string)

    describe azure_virtual_machine(group_name: resource_group_name, name: server_name) do
      its('type') { should eq 'Microsoft.Compute/virtualMachines' }
      its('location') { should cmp location }

      # Ensure that the machine is from an Ubuntu image
      its('publisher') { should cmp 'canonical' }
      its('offer') { should cmp 'ubuntuserver' }
      its('sku') { should cmp '16.04-LTS' }

      # There should be no data disk attached to the machine
      its('data_disk_count') { should eq 1 }

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
