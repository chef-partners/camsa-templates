unique_string = attribute('unique_string', default: '9j2f')
ops_function_apikey = attribute('ops_function_apikey', default: '')
prefix = attribute('prefix', default: 'inspec')

# set the fqdn of the webservice
website_fqdn = format('%s-%s-appservice.azurewebsites.net', prefix, unique_string)
website_url = format('https://%s/api/starterKit?code=%s', website_fqdn, ops_function_apikey)

# Ensure that the starter kit can be downloaded
control 'Starter Kit' do
  impact 1.0
  title 'Download'

  starter_kit = http(website_url, method: 'GET')

  describe starter_kit do
    it 'should respond with HTTP 200' do
      expect(subject.status).to eq(200)
    end

    its('headers.Content-Type') { should cmp 'application/octet-stream' }
  end
end 