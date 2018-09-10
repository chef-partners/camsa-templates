unique_string = attribute('unique_string', default: '9j2f')
location = attribute('location', default: 'westeurope')
prefix = attribute('prefix', default: 'inspec')

control 'Test Chef Server Endpoint' do
  impact 1.0
  title 'Make sure that it is up and running and shows the default text'

  fqdn = format('%s-chef-%s.%s.cloudapp.azure.com', prefix, unique_string, location)
  url = format('https://%s', fqdn)

  describe http(url,
                ssl_verify: false) do
    its('status') { should eq 200 }
    its('body') { should include 'Are You Looking For the Chef Server' }
  end
end