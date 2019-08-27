unique_string = input('unique_string', value: '9j2f')
location = input('location', value: 'westeurope')
prefix = input('prefix', value: 'inspec')

# Automate server test can be run as well, however the URL that is required
# needs to have a session ID which you get from a redirect. The root page performs
# a redirect using JavaScript which InSpec does not run. If a url to the main
# login page is available this could be used instead
#
# The following is an example of the test that could be run

control 'Test Automate Server Endpoint' do
  impact 1.0
  title 'Make sure that it is up and running and presents a login form'

  fqdn = format('%s-automate-%s.%s.cloudapp.azure.com', prefix, unique_string, location)
  url = format('https://%s', fqdn)

  describe http(url,
                ssl_verify: false) do
    its('status') { should eq 200 }

    # It should include a login form
    # its('body') { should include 'input id="login"' }
    # its('body') { should include 'input id="password"' }
  end
end