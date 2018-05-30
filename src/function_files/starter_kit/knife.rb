current_dir = ::File.dirname(__FILE__)
log_level                :info
log_location             $stdout
node_name                "{{ NODE_NAME }}"
client_key               ::File.join(current_dir, "{{ CLIENT_KEY_FILENAME }}")
validation_client_name   "{{ ORG_VALIDATOR_NAME }}"
validation_key           ::File.join(current_dir, "{{ ORG_KEY_FILENAME }}")
chef_server_url          "{{ CHEF_SERVER_URL }}"
cookbook_path            [::File.join(current_dir, "../cookbooks")]
