# Configure attributes for the tests
customer_resource_group_name = attribute('customer_resource_group_name', default: 'InSpec-AMA-Customer', description: 'Name of the resource group that holds the existing customer virtual network')
customer_virtual_network_name = attribute('customer_virtual_network_name', default: 'InSpec-Customer-Network', description: 'Name of the eixsiting customer virtual network')
customer_subnet_name = attribute('customer_subnet_name', default: 'InSpec-Customer-Subnet', description: 'Name of the customer subnet within the customer vnet')
vnet_address_prefix = attribute('vnet_address_prefix', default: '10.3.0.0/24', description: 'The address space that has been assigned to the virtual network')
customer_subnet_prefix = attribute('customer_subnet_prefix', default: '10.3.0.0/25', description: 'The address space assigned to the customer subnet')
location = attribute('location', default: 'westeurope', description: 'Location of the resources within Azure')
unique_string = attribute('unique_string', default: '9j2f', description: 'The 4 character string that is used to uniquely identify resources')

title 'Ensure Subnets are configured in customer network'

control 'Customer Virtual Network' do
  impact 1.0
  title 'Virtual network has correct address space and has the required number of subnets'

  describe azure_generic_resource(group_name: customer_resource_group_name, name: customer_virtual_network_name) do
    its('type') { should eq 'Microsoft.Network/virtualNetworks' }
    its('location') { should cmp location }
    its('properties.provisioningState') { should cmp 'Succeeded' }

    # Check the address space for the virtual network
    its('properties.addressSpace.addressPrefixes') { should include vnet_address_prefix }

    # it should have 2 subnets
    its('properties.subnets.count') { should eq 1 }
  end
end

control 'Customer Subnet' do
  impact 1.0
  title 'Customer Subnet has correct address space assigned and has 2 network cards connected to it'

  subnet = azure_generic_resource(group_name: customer_resource_group_name, name: customer_virtual_network_name)
           .properties.subnets.find { |s| s.name == customer_subnet_name }

  describe subnet do
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.addressPrefix') { should cmp customer_subnet_prefix }
    its('properties.ipConfigurations.count') { should eq 2 }
  end

  # Ensure the customer facing NIC for Chef is connected
  chef_nic = format('inspec-chef-%s-Customer-VNet-NIC', unique_string)

  chef_nic_connected = subnet.properties.ipConfigurations.find { |i| i.id.include? chef_nic }

  describe chef_nic_connected do
    it "NIC #{chef_nic} should be connected to #{customer_subnet_name}" do
      expect(subject).not_to be_nil
    end
  end

  # Ensure the customer facing NIC for Automate is connected
  automate_nic = format('inspec-automate-%s-Customer-VNet-NIC', unique_string)

  automate_nic_connected = subnet.properties.ipConfigurations.find { |i| i.id.include? automate_nic }

  describe automate_nic_connected do
    it "NIC #{automate_nic} should be connected to #{customer_subnet_name}" do
      expect(subject).not_to be_nil
    end
  end
end
