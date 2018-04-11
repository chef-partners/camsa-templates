require 'ms_rest_azure'
require 'azure_mgmt_resources'
require 'inifile'

class Integration < Thor
  attr_reader :credentials, :client

  # Constructor to read in the credentials file and perform
  # the connection to azure
  #
  # @author Russell Seymour
  def initialize(*args)
    super

    # If an AZURE_CREDS_FILE has been specified read that file in
    # otherwise default to on in the home directory
    azure_creds_file = ENV['AZURE_CREDS_FILE']
    if azure_creds_file.nil?
      azure_creds_file = File.join(Dir.home, '.azure', 'credentials')
    end

    # Ensure that the credentials file exists
    if File.file?(azure_creds_file)
      @credentials = IniFile.load(File.expand_path(azure_creds_file))
    else
      @credentials = nil
      warn format('%s was not found or not accessible', azure_creds_file)
    end
  end

  desc 'deploy', 'Deploy the ARM template for testing'
  method_option :group_name, type: :string, default: 'InSpec-AMA'
  method_option :vnet_group_name, type: :string, default: 'InSpec-AMA-Customer'
  method_option :location, type: :string, default: 'westeurope'
  method_option :parameters, type: :string, default: nil
  def deploy
    say '--> Deploy'

    # determine if the resource group for the customer network already exists
    rg_exists = client.resource_groups.check_existence(options[:vnet_group_name])

    if !rg_exists
      say format('  creating resource group: %s', options[:vnet_group_name])

      # create the parameters that hold the location for the resource group
      resource_group_params = client.model_classes.resource_group.new.tap do |rg|
        rg.location = options[:location]
      end

      # now create the resource group
      client.resource_groups.create_or_update(options[:vnet_group_name], resource_group_params)

    else
      say format('  resource group already exists: %s', options[:vnet_group_name])
    end

    # Deploy the virtual network into the :vnet_group_name resource group
    deployment_name = format('InSpec-AMA-Customer-VNet-Deploy-%s', Time.now.to_i.to_s)
    say format('  deploying Customer Virtual Network [%s]', deployment_name)

    # determine if the resource group for the AMA already exists already exists
    rg_exists = client.resource_groups.check_existence(options[:group_name])

    # Determine the path to the arm template
    arm_template = File.read(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test', 'integration', 'build', 'customer-vnet.json')))

    # create the deployment
    # parameters are set in the deployment template so they do not need to be specified here
    deployment = client.model_classes.deployment.new
    deployment.properties = client.model_classes.deployment_properties.new
    deployment.properties.mode = Azure::Resources::Profiles::Latest::Mgmt::Models::DeploymentMode::Incremental
    deployment.properties.template = JSON.parse(arm_template)

    # perform the deployment to the resource group
    client.deployments.create_or_update(options[:vnet_group_name], deployment_name, deployment)

    if !rg_exists
      say format('  creating resource group: %s', options[:group_name])

      # create the parameters that hold the location for the resource group
      resource_group_params = client.model_classes.resource_group.new.tap do |rg|
        rg.location = options[:location]
      end

      # now create the resource group
      client.resource_groups.create_or_update(options[:group_name], resource_group_params)

    else
      say format('  resource group already exists: %s', options[:group_name])
    end

    deployment_name = format('InSpec-AMA-Deploy-%s', Time.now.to_i.to_s)
    say format('  deploying AMA template [%s]', deployment_name)

    # If the parameters file option has not been set then default to the parameters
    # file that is in the build directory
    parameters_file = options[:parameters]
    if parameters_file.nil?
      parameters_file = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test', 'integration', 'build', 'parameters.json'))
    end

    # Ensure that the parameters file exists
    if !File.file?(parameters_file)
      abort format('Parameters file not found or not accessible: %s', parameters)
    end

    # Read the parameters in from the specified parameters file
    parameters = JSON.parse(File.read(parameters_file))

    # Determine the path to the arm template
    arm_template = File.read(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'src', 'mainTemplate.json')))

    # create the deployment
    deployment = client.model_classes.deployment.new
    deployment.properties = client.model_classes.deployment_properties.new
    deployment.properties.mode = Azure::Resources::Profiles::Latest::Mgmt::Models::DeploymentMode::Incremental
    deployment.properties.template = JSON.parse(arm_template)
    # deployment.properties.parameters_link = parameters
    deployment.properties.parameters = parameters['parameters']

    # log information about the deployment
    debug_settings = client.model_classes.debug_setting.new
    debug_settings.detail_level = 'requestContent, responseContent'
    deployment.properties.debug_setting = debug_settings

    # perform the deployment to the resource group
    client.deployments.create_or_update(options[:group_name], deployment_name, deployment)

    # output information about the deployment
    operation_results = client.deployment_operations.list(options[:group_name], deployment_name)
    unless operation_results.nil?
      operation_results.each do |operation_result|
        puts '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
        puts "operation_id = #{operation_result.operation_id}"
        unless operation_result.properties.nil?
          puts "provisioning_state = #{operation_result.properties.provisioning_state}"
          puts "status_code = #{operation_result.properties.status_code}"
          puts "status_message = #{operation_result.properties.status_message}"
          puts "target_resource = #{operation_result.properties.target_resource.id}" unless operation_result.properties.target_resource.nil?
          puts "request = #{operation_result.properties.request.content}" unless operation_result.properties.request.nil?
          puts "response = #{operation_result.properties.response.content}" unless operation_result.properties.response.nil?
        end        
      end
    end
  end

  desc 'destroy', 'Destroy the integration environment'
  method_option :group_name, type: :string, default: 'InSpec-AMA'
  method_option :vnet_group_name, type: :string, default: 'InSpec-AMA-Customer'
  def destroy
    say '--> Destroy'
    say format('  deleting resource group: %s', options[:group_name])

    # Call the SDK method to delete the resource group
    client.resource_groups.delete(options[:group_name])

    say format('  deleting resource group: %s', options[:vnet_group_name])
    client.resource_groups.delete(options[:vnet_group_name])
  end

  private

  # Connect to Azure using the specified credentials
  #
  # @author Russell Seymour
  def client
    # If a connection already exists, return it
    return @client if defined?(@client)

    # get the specific spn details
    creds = spn
    
    # create a new connection
    token_provider = MsRestAzure::ApplicationTokenProvider.new(creds[:tenant_id], creds[:client_id], creds[:client_secret])
    token_creds = MsRest::TokenCredentials.new(token_provider)

    # Create the options hash to create the client
    options = {
      credentials: token_creds,
      subscription_id: creds[:subscription_id],
      tenant_id: creds[:tenant_id],
      client_id: creds[:client_id],
      client_secret: creds[:client_secret],
    }

    @client = Azure::Resources::Profiles::Latest::Mgmt::Client.new(options)
  end

  # Method to retirevd the SPN credentials from the creds file
  #
  # @author Russell Seymour
  def spn
    subscription_id = azure_subscription_id

    # Ensure that the credential exists
    unless credentials.nil?
      raise format('The specified Azure Subscription cannot be found in your credentials: %s', subscription_id) unless @credentials.sections.include?(subscription_id)
    end

    # Get the client_id, tenant_id and the client_secret
    tenant_id = ENV['AZURE_TENANT_ID'] || credentials[subscription_id]['tenant_id']
    client_id = ENV['AZURE_CLIENT_ID'] || credentials[subscription_id]['client_id']
    client_secret = ENV['AZURE_CLIENT_SECRET'] || credentials[subscription_id]['client_secret']

    # return a hash of the spn information
    { subscription_id: subscription_id, client_id: client_id, client_secret: client_secret, tenant_id: tenant_id}
  end

  # Return the subscription ID to use
  #
  # If a subsccription ID has been sepcified in an environment variable attempt to find that one
  # If an index value has been specified get the subscroption ID from the inifile at that location
  # If neither of the above are specifief then return the first subscription id in the file
  #
  # @author Russell Seymour
  def azure_subscription_id
    if !ENV['AZURE_SUBSCRIPTION_ID'].nil?
      id = ENV['AZURE_SUBSCRIPTION_ID']
    elsif !ENV['AZURE_SUBSCRIPTION_NUMBER'].nil?

      # turn the specified subscription number into an integer
      subscription_number = ENV['AZURE_SUBSCRIPTION_NUMBER'].to_i
      subscription_index = subscrioption_number - 1

      # Determmine if the specified index is not greater than the number of subscriptions
      if subscription_number > credentials.sections.length
        raise format('Your credentials file only contains %s subscriptions.  You specified number %s.', @credentials.sections.length, subscription_number)
      end

      # get the subscription id at the specified index
      id = credentials.sections[subscription_index]
    else
      # Get the first subscription ID from the file
      id = credentials.sections[0]
    end

    # return the subscription id to the calling function
    id
  end

end