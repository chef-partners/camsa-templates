unique_string = attribute('unique_string', default: '9j2f')
configstore_apikey = attribute('configstore_apikey', default: '')
prefix = attribute('prefix', default: 'inspec')

# set the fqdn of the webservice
website_fqdn = format('%s-%s-appservice.azurewebsites.net', prefix, unique_string)
website_url = format('https://%s/api/chefAMAConfigStore?code=%s', website_fqdn, configstore_apikey)

control 'POST information to the Azure Function' do
  impact 1.0
  title 'Add test data to the AMA Config Store'

  post_data = http(website_url,
                method: 'POST',
                data: '{"inspec_test": "it rocks"}')

  describe post_data do
    it 'should return HTTP 200' do
      expect(subject.status).to eq(200)
    end
  end
end

control 'GET information from the Azure Function' do
  impact 1.0
  title 'Get test data from the AMA config store'

  get_url = format('%s&key=inspec_test', website_url)

  get_data = http(get_url, method: 'GET')

  describe get_data do
    it 'should return HTTP 200' do
      expect(subject.status).to eq(200)
    end

    # ensure that body includes the value that was set
    # Ideally this should create an object from the JSON and test the actual value
    it 'inspec_test should return "it rocks"' do
      expect(JSON.parse(subject.body)['inspec_test']).to eq('it rocks')
    end
  end
end

# Create list of keys that should be in the config store
# This is so that a control can be created for each one to check that it exists
items = [
  "monitor_key",
  "automate_credentials_password",
  "automate_credentials_username",
  "automate_fqdn",
  "automate_internal_ip",
  "automate_token",
  "chef_internal_ip",
  "chefserver_fqdn",
  "automate_credentials_url",
  "monitor_user",
  "monitor_user_password",
  "org",
  "org_validator_key",
  "user",
  "user_key",
  "user_password"
]

items.each do |item|
  control format('Configuration Data: %s', item) do
    impact 1.0
    title format('%s', item)

    # Build up the url that is required to get the data
    url = format('%s&key=%s', website_url, item)
    item_exists = http(url, method: 'GET')

    # ensure that the content is not null and that get a 200
    describe item_exists do
      it 'should respond with HTTP 200' do
        expect(subject.status).to eq(200)
      end

      it 'value should not be null' do
        expect(JSON.parse(subject.body)[item]).to_not be_nil
      end
    end
  end
end

=begin
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
=end
