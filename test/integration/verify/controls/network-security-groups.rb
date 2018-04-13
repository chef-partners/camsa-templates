resource_group_name = attribute('resource_group_name', default: 'InSpec-AMA', description: 'Name of the resource group to interogate')
unique_string = attribute('unique_string', default: '9j2f')
location = attribute('location', default: 'westeurope')
ssh_source_addresses = attribute('ssh_source_addresses', default: ['10.1.1.0/24'])

# Define array that states where the traffic is coming from
# Both denote access from the Internet
sources = ['*', 'Internet']

title 'Ensure that all Network Security Groups are setup correctly'

control 'Automate-Server-NSG' do
  impact 1.0
  title 'Check the settings of the network security group for the Automate server'

  describe azure_generic_resource(group_name: resource_group_name, name: "inspec-automate-#{unique_string}-Customer-NSG") do
    its('location') { should cmp location }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.securityRules.count') { should cmp 3 }

    # it should be connected to the correct NIC
    its('properties.networkInterfaces.first.id') { should include "inspec-automate-#{unique_string}-Customer-VNet-NIC" }
  end
end

control 'Automate-Server-NSG-Port-80' do
  impact 1.0
  title 'Ensure that port 80 (HTTP) is accessible from the Internet'

  # Perform specifc test to check that port 80 is open
  port_80_rule = azure_generic_resource(group_name: resource_group_name, name: "inspec-automate-#{unique_string}-Customer-NSG")
                 .properties.securityRules.find { |r| r.properties.destinationPortRange == '80' && sources.include?(r.properties.sourceAddressPrefix) }

  describe port_80_rule do
    it 'rule should exist' do
      expect(subject).not_to be_nil
    end
  end
end

control 'Automate-Server-NSG-Port-443' do
  impact 1.0
  title 'Ensure that port 443 (HTTPS) is accessible from the Internet'

  # Perform specifc test to check that port 443 is open
  port_443_rule = azure_generic_resource(group_name: resource_group_name, name: "inspec-automate-#{unique_string}-Customer-NSG")
                  .properties.securityRules.find { |r| r.properties.destinationPortRange == '443' && sources.include?(r.properties.sourceAddressPrefix) }

  describe port_443_rule do
    it 'rule should exist' do
      expect(subject).not_to be_nil
    end
  end
end

control 'Automate-Server-NSG-Port-22' do
  impact 1.0
  title 'Ensure that port 22 (SSH) is not accessible from the Internet'

  # Perform specifc test to check that port 22 is open
  port_22_rule = azure_generic_resource(group_name: resource_group_name, name: "inspec-automate-#{unique_string}-Customer-NSG")
                 .properties.securityRules.find { |r| r.properties.destinationPortRange == '22' && sources.include?(r.properties.sourceAddressPrefixes) }

  describe port_22_rule do
    it 'rule should not exist' do
      expect(subject).to be_nil
    end
  end
end

control 'Automate-Server-NSG-Port-22-from-CHefHQ' do
  impact 1.0
  title 'Ensure that port 22 (SSH) is permitted from Chef HQ addresses'

  # Ensure that port 22 is accessible from the ssh source addresses
  ssh_source_addresses.each do |ssh_src_addr|
    rule = azure_generic_resource(group_name: resource_group_name, name: "inspec-automate-#{unique_string}-Customer-NSG")
          .properties.securityRules.find { |r| r.properties.destinationPortRange == '22' && r.properties.sourceAddressPrefixes.include?(ssh_src_addr) }

    describe rule do
      it format('should allow SSH access from %s', ssh_src_addr) do
        expect(subject).to_not be_nil
      end
    end
  end
end


control 'Chef-Server-NSG' do
  impact 1.0
  title 'Check the settings of the network security group for the Chef server'

  describe azure_generic_resource(group_name: resource_group_name, name: "inspec-chef-#{unique_string}-Customer-NSG") do
    its('location') { should cmp location }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.securityRules.count') { should cmp 3 }

    # it should be connected to the correct NIC
    its('properties.networkInterfaces.first.id') { should include "inspec-chef-#{unique_string}-Customer-VNet-NIC" }
  end
end

control 'Chef-Server-NSG-Port-80' do
  impact 1.0
  title 'Ensure that port 80 (HTTP) is accessible from the Internet'

  # Perform specifc test to check that port 80 is open
  port_80_rule = azure_generic_resource(group_name: resource_group_name, name: "inspec-chef-#{unique_string}-Customer-NSG")
                 .properties.securityRules.find { |r| r.properties.destinationPortRange == '80' && sources.include?(r.properties.sourceAddressPrefix) }

  describe port_80_rule do
    it 'rule should exist' do
      expect(subject).not_to be_nil
    end
  end
end

control 'Chef-Server-NSG-Port-443' do
  impact 1.0
  title 'Ensure that port 443 (HTTPS) is accessible from the Internet'

  # Perform specifc test to check that port 443 is open
  port_443_rule = azure_generic_resource(group_name: resource_group_name, name: "inspec-chef-#{unique_string}-Customer-NSG")
                  .properties.securityRules.find { |r| r.properties.destinationPortRange == '443' && sources.include?(r.properties.sourceAddressPrefix) }

  describe port_443_rule do
    it 'rule should exist' do
      expect(subject).not_to be_nil
    end
  end
end

control 'Chef-Server-NSG-Port-22' do
  impact 1.0
  title 'Ensure that port 22 (SSH) is not accessible from the Internet'

  # Perform specifc test to check that port 22 is not accessible from the Internet
  port_22_rule = azure_generic_resource(group_name: resource_group_name, name: "inspec-chef-#{unique_string}-Customer-NSG")
                 .properties.securityRules.find { |r| r.properties.destinationPortRange == '22' && sources.include?(r.properties.sourceAddressPrefixes) }

  describe port_22_rule do
    it 'rule should not exist' do
      expect(subject).to be_nil
    end
  end
end

control 'Chef-Server-NSG-Port-22-from-CHefHQ' do
  impact 1.0
  title 'Ensure that port 22 (SSH) is permitted from Chef HQ addresses'

  # Ensure that port 22 is accessible from the ssh source addresses
  ssh_source_addresses.each do |ssh_src_addr|
    rule = azure_generic_resource(group_name: resource_group_name, name: "inspec-chef-#{unique_string}-Customer-NSG")
          .properties.securityRules.find { |r| r.properties.destinationPortRange == '22' && r.properties.sourceAddressPrefixes.include?(ssh_src_addr) }

    describe rule do
      it format('should allow SSH access from %s', ssh_src_addr) do
        expect(subject).to_not be_nil
      end
    end
  end
end
