
require 'net/http'
require 'uri'
require 'gist'
require 'json'

class UI < Thor
  desc 'url FILE', 'Return the URL required to test the specified UI file'
  method_option :update, type: :string, default: nil
  def url(file)
    # Ensure that the specified file is readable
    abort format('Specified file cannot be found: %s', file) unless File.file?(file)

    # Upload the contents of the file to Pastebin
    gist = upload(file, options)

    raw_url = gist['files'][File.basename(file)]['raw_url']

    encoded_raw_url = URI.encode_www_form_component(raw_url).gsub('+', '%20')

    # Write out the Azure URL for testing the UI file
    azure_url = format('https://portal.azure.com/?clientOptimizations=false#blade/Microsoft_Azure_Compute/CreateMultiVmWizardBlade/internal_bladeCallId/anything/internal_bladeCallerParams/{"initialData":{},"providerConfig":{"createUiDefinition":"%s"}}', encoded_raw_url)
    puts azure_url
  end

  private

  def upload(file, task_options)
    # Upload the file as a gist
    data = IO.read(file)
    options = {
      filename: File.basename(file),
      output: :all,
    }

    # if an update id has been specified add it to the options
    options[:update] = task_options[:update] unless task_options[:update].nil?

    Gist.gist(data, options)
  end
end
