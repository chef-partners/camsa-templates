resource_group_name = input('resource_group_name', value: 'InSpec-AMA', description: 'Name of the resource group to interogate')
execute_rules_tests = input('execute_rules_tests', value: false)

title = 'Ensure that the scheduled query rules have been deployed correctly'

# Create hashtable of querie rules to ensure that they have been created
query_rules = [
  {
    name: "linux-vm-critical-cpu",
  },
]

# Iterate around each of the query rules
query_rules.each do |query_rule|
  control format('Monitor Alert - %s', query_rule[:name]) do
    impact 1.0
    title query_rule[:name]

    only_if { execute_rules_tests }

    describe azure_generic_resource(group_name: resource_group_name, name: query_rule[:name]) do
      its('type') { should eq 'Microsoft.Insights/scheduledQueryRules' }
      its('properties.enabled') { should be true }
    end
  end
end
