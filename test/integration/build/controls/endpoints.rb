
unique_string = attribute('unique_string', default: '9j2f')
location = attribute('location', default: 'westeurope')
apikey = attribute('apikey', default: '')
username = attribute('username', default: 'inspec')
org = attribute('org', default: 'ama')
endpoint_test = attribute('endpoint_test', default: false)

# set the fqdn of the webservice
website_fqdn = format('inspec-%s-appservice.azurewebsites.net', unique_string)
website_url = format('https://%s/api/chefAMAConfigStore?code=%s', website_fqdn, apikey)

control 'Test Chef Server Endpoint' do
  impact 1.0
  title 'Make sure that it is up and running and shows the default text'

  fqdn = format('inspec-chef-%s.%s.cloudapp.azure.com', unique_string, location)
  url = format('https://%s', fqdn)

  describe http(url,
                ssl_verify: false) do
    its('status') { should eq 200 }
    its('body') { should include 'Are You Looking For the Chef Server' }
  end
end

# Automate server test can be run as well, however the URL that is required
# needs to have a session ID which you get from a redirect. The root page performs
# a redirect using JavaScript which InSpec does not run. If a url to the main
# login page is available this could be used instead
#
# The following is an example of the test that could be run

control 'Test Automate Server Endpoint' do
  impact 1.0
  title 'Make sure that it is up and running and presents a login form'

  fqdn = format('inspec-automate-%s.%s.cloudapp.azure.com', unique_string, location)
  url = format('https://%s', fqdn)

  describe http(url,
                ssl_verify: false) do
    its('status') { should eq 200 }

    # It should include a login form
    # its('body') { should include 'input id="login"' }
    # its('body') { should include 'input id="password"' }
  end
end

control 'POST information to the Azure Function' do
  impact 1.0
  title 'Add test data to the AMA Config Store'

  describe http(website_url,
                method: 'POST',
                data: '{"inspec_test": "it rocks"}') do

    its('status') { should eq 200 }
  end
end

control 'GET information from the Azure Function' do
  impact 1.0
  title 'Get test data from the AMA config store'

  get_url = format('%s&key=inspec_test', website_url)

  describe http(get_url,
    method: 'GET') do

    it 'should respond with HTTP 200' do
      expect(described_class.status).to eq(200)
    end

    # ensure that body includes the value that was set
    # Ideally this should create an object from the JSON and test the actual value
    it 'inspec_test should return "it rocks"' do
      expect(JSON.parse(described_class.body)['inspec_test']).to eq('it rocks')
    end
  end
end

# Create a control that checks that the three entries from the scripts exist
control 'Configuration Data - Automate Token' do
  impact 1.0
  title 'Automate token exists in the config store'

  # automate token exists and has a value
  get_url = format('%s&key=automate_token', website_url)
  token_exists = http(get_url, method: 'GET')

  describe token_exists do
    it 'should have an automate_token' do
      expect(JSON.parse(described_class.body)['automate_token']).to_not be_nil
    end
  end
end

control 'Configuration Data - Chef user key' do
  impact 1.0
  title 'Chef user key exists in the config store'

  # user key exists and has a value
  config_key = format('%s_key', username)
  get_url = format('%s&key=%s', website_url, config_key)
  user_key_exists = http(get_url, method: 'GET')

  describe user_key_exists do
    it format('should have a user key for Chef (%s)', config_key) do
      expect(JSON.parse(described_class.body)[config_key]).to_not be_empty
    end
  end
end

control 'Configuration Data - Chef org key' do
  impact 1.0
  title 'Chef org key exists in the config store'

  # org key exists and has a value
  config_key = format('%s_validator_key', org)
  get_url = format('%s&key=%s', website_url, config_key)
  org_key_exists = http(get_url, method: 'GET')

  describe org_key_exists do
    it format('should have a organisation key for Chef (%s)', config_key) do
      expect(JSON.parse(described_class.body)[config_key]).to_not be_empty
    end
  end
end
