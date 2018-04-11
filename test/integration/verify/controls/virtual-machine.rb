resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')
location = attribute('location', default: 'westeurope')

title 'Check AMA Chef and Automate virtual machines'

%w(chef automate).each do |component|
  control format('AMA %s Server', component) do
    impact 1.0
    title format('Check the attributes of the %s server', component)

    server_name = format('inspec-%s-%s-VM', component, unique_string)
    ama_nic_name = format('inspec-%s-%s-AMA-NIC', component, unique_string)
    customer_nic_name = format('inspec-%s-%s-Customer-VNet-NIC', component, unique_string)

    describe azure_virtual_machine(group_name: resource_group_name, name: server_name) do
      its('location') { should cmp location }

      # Ensure that the machine is from an Ubuntu image
      its('publisher') { should cmp 'canonical' }
      its('offer') { should cmp 'ubuntuserver' }
      its('sku') { should cmp '16.04-LTS' }

      # The OS disk should be a managed disk
      it { should have_managed_osdisk }

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
      its('nic_count') { should eq 2 }
      its('connected_nics') { should include /#{ama_nic_name}/ }
      its('connected_nics') { should include /#{customer_nic_name}/ }

      # Ensure that boot diagnostics have been enabled
      it { should have_boot_diagnostics }
    end
  end
end