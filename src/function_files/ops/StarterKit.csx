#r "Newtonsoft.Json"
#r "System.IO.Compression.Filesystem"

#load "Constants.csx"
#load "ResponseMessage.csx"

using System.Net;
using System.Collections.Generic;
using System.Text;
using System.IO.Compression;
using Newtonsoft.Json;
using Microsoft.WindowsAzure.Storage.Table;

public class StarterKit
{
  private ResponseMessage _response = new ResponseMessage();
  private StringBuilder _sb = new StringBuilder();
  private Dictionary<string, string> config_store;

  public async Task<HttpResponseMessage> Process(HttpRequestMessage req, CloudTable table, IEntity config, TraceWriter log, string category, ExecutionContext executionContext)
  {

    HttpResponseMessage msg;

    if (req.Method == HttpMethod.Get)
    {

      // initalise variables
      string client_key_filename = "";
      string validator_key_filename = "";

      // Create the directory structure for the files that need to be zipped up
      string chef_repo_path = Path.Combine(executionContext.FunctionDirectory, "chef-repo");
      string extras_path = Path.Combine(chef_repo_path, "extras");
      string dot_chef_path = Path.Combine(chef_repo_path, ".chef");

      // delete the repo path if it already exists
      if (Directory.Exists(chef_repo_path))
      {
          Directory.Delete(chef_repo_path, true);
      }

      if (!Directory.Exists(extras_path))
      {
          Directory.CreateDirectory(extras_path);
      }

      if (!Directory.Exists(dot_chef_path)) {
        Directory.CreateDirectory(dot_chef_path);
      }

      // create the data service to collect the data from the settings table
      DataService data_service = new DataService(table, log);
      Dictionary<string, string> config_store = data_service.GetAll(config, category);

      // Base64 decode the user key and set the path to the file
      if (config_store.ContainsKey(UserKey) && config_store.ContainsKey(UserKeyKey))
      {
        client_key_filename = String.Format("{0}.pem", config_store[UserKey]);
        string client_key_path = Path.Combine(dot_chef_path, client_key_filename);
        string user_key = Encoding.UTF8.GetString(Convert.FromBase64String(config_store[UserKeyKey]));

        // Write out the client key to the file
        File.WriteAllText(client_key_path, user_key);
      }

      // Base64 decode the validator key and set the path to the file
      if (config_store.ContainsKey(OrgKey) && config_store.ContainsKey(OrgKeyKey))
      {
        validator_key_filename = String.Format("{0}-validator.pem", config_store[OrgKey]);
        string validator_key_path = Path.Combine(dot_chef_path, validator_key_filename);
        string validator_key = Encoding.UTF8.GetString(Convert.FromBase64String(config_store[OrgKeyKey]));

        File.WriteAllText(validator_key_path, validator_key);
      }

      // create a dictionary to hold relevant settings
      // this will be used to create the necessary JSON file as well as patching the other files
      // that are created here
      Dictionary<string, string> data = new Dictionary<string, string>();

      if (config_store.ContainsKey(ChefServerFQDNKey) && config_store.ContainsKey(OrgKey))
        data.Add("CHEF_SERVER_URL", String.Format("https://{0}/organizations/{1}", config_store[ChefServerFQDNKey], config_store[OrgKey]));

      if (config_store.ContainsKey(UserKey))
      {
        data.Add("USER_USERNAME", config_store[UserKey]);
        data.Add("NODE_NAME", config_store[UserKey]);
      }

      if (!String.IsNullOrEmpty(client_key_filename))
        data.Add("CLIENT_KEY_FILENAME", client_key_filename);

      if (!String.IsNullOrEmpty(validator_key_filename))
        data.Add("ORG_KEY_FILENAME", validator_key_filename);

      if (config_store.ContainsKey(OrgKey))
        data.Add("ORG_VALIDATOR_NAME", String.Format("{0}-validator", config_store[OrgKey]));

      if (config_store.ContainsKey(OrgKeyKey))
        data.Add("ORG_VALIDATOR_KEY", config_store[OrgKeyKey]);
      
      if (config_store.ContainsKey(UserPasswordKey))
        data.Add("USER_PASSWORD", config_store[UserPasswordKey]);

      if (config_store.ContainsKey(AutomateServerFQDNKey))
        data.Add("AUTOMATE_SERVER_URL", String.Format("https://{0}", config_store[AutomateServerFQDNKey]));

      if (config_store.ContainsKey(AutomateCredentialsAdminUsernameKey))
        data.Add("AUTOMATE_ADMIN_USERNAME", config_store[AutomateCredentialsAdminUsernameKey]);

      if (config_store.ContainsKey(AutomateCredentialsAdminPasswordKey))
        data.Add("AUTOMATE_ADMIN_PASSWORD", config_store[AutomateCredentialsAdminPasswordKey]);

      if (config_store.ContainsKey(AutomateTokenKey))
        data.Add("AUTOMATE_ADMIN_TOKEN", config_store[AutomateTokenKey]);

      if (config_store.ContainsKey(ChefServerInternalIPAddressKey))
        data.Add("CHEF_SERVER_INTERNAL_IP_ADDRESS", config_store[ChefServerInternalIPAddressKey]);

      if (config_store.ContainsKey(AutomateServerInternalIPAddressKey))
        data.Add("AUTOMATE_SERVER_INTERNAL_IP_ADDRESS", config_store[AutomateServerInternalIPAddressKey]);

      // Create the Chef Automate credentials file
      string credentials_path = Path.Combine(chef_repo_path, "credentials.txt");
      string knife_file_path = Path.Combine(chef_repo_path, ".chef", "knife.rb"); 
      string arm_extension_path = Path.Combine(extras_path, "chef-extension.json");

      // Define a dictionary of the name of the output file and the source file to patch
      Dictionary<string, string> files_to_patch = new Dictionary<string, string>();
      files_to_patch.Add(credentials_path, Path.Combine(executionContext.FunctionDirectory, "credentials.txt"));
      files_to_patch.Add(knife_file_path, Path.Combine(executionContext.FunctionDirectory, "knife.rb"));
      files_to_patch.Add(arm_extension_path, Path.Combine(executionContext.FunctionDirectory, "chef-extension.json"));

      // iterate around the files that need to be patched
      string template;
      foreach (KeyValuePair<string, string> entry in files_to_patch)
      {
        // read in the template file that needs to be patched
        template = File.ReadAllText(entry.Value);

        // iterate around the data and patch the template
        foreach (KeyValuePair<string, string> setting in data)
        {
          template = template.Replace(String.Format("{{{{ {0} }}}}", setting.Key), setting.Value);
        }

        // Save the file out to its target location
        File.WriteAllText(entry.Key, template);
      }

      // Write out the data to a json file in the extras directory
      string credentials_json_path = Path.Combine(extras_path, "credentials.json") ;
      string data_json = JsonConvert.SerializeObject(data, Formatting.Indented);
      File.WriteAllText(credentials_json_path, data_json);

      // Zip up the directory
      string zip_path = Path.Combine(executionContext.FunctionDirectory, "starter_kit.zip");

      // Delete the zip if it already exists
      if (File.Exists(zip_path))
      {
          File.Delete(zip_path);
      }

      ZipFile.CreateFromDirectory(chef_repo_path, zip_path);
  
      // create a response with the response message class
      msg = _response.CreateResponse(zip_path);

      // Removbe the chef_repo directory and the starter_kit zip file
      Directory.Delete(chef_repo_path, true);
      File.Delete(zip_path);

    }
    else
    {
      _response.SetError("HTTP Method not supported", true, HttpStatusCode.BadRequest);
      msg = _response.CreateResponse();
    }

    return msg;
  }
}