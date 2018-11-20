unique_string = attribute('unique_string', default: '9j2f')
ops_function_apikey = attribute('ops_function_apikey', default: '')
prefix = attribute('prefix', default: 'inspec')

# set the fqdn of the webservice
website_fqdn = format('%s-%s-appservice.azurewebsites.net', prefix, unique_string)
website_url_get = format('https://%s/api/config/%%s?code=%s', website_fqdn, ops_function_apikey)
website_url_post = format('https://%s/api/config?code=%s', website_fqdn, ops_function_apikey)

control 'POST information to the Azure Function' do
  impact 1.0
  title 'Add test data to the AMA Config Store'

  post_data = http(website_url_post,
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

  get_url = format(website_url_get, 'inspec_test')

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
  "pip_automate_fqdn",
  "automate_internal_ip",
  "chef_automate_token",
  "user_automate_token",
  "logging_automate_token",
  "chef_internal_ip",
  "chefserver_fqdn",
  "pip_chefserver_fqdn",
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
    # url = format('%s&key=%s', website_url, item)
    url = format(website_url_get, item)
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
