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
  private Dictionary<string, string> _config_store;

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

      // Create the Chef Automate credentials file
      string credentials_path = Path.Combine(chef_repo_path, "credentials.txt");

      AddString("Chef Server URL: https://{0}/organizations/{1}", new string[] { ChefServerFQDNKey, OrgKey });
      AddString("User username: {0}", new string[] { UserKey });
      AddString("User password: {0}", new string[] { UserPasswordKey });
      _sb.AppendLine();
      AddString("Automate URL: https://{0}", new string[] { AutomateServerFQDNKey });
      AddString("Automate admin username: {0}", new string[] { AutomateCredentialsAdminUsernameKey });
      AddString("Automate admin password: {0}", new string[] { AutomateCredentialsAdminPasswordKey });
      AddString("Automate Token: {0}", new string[] { AutomateTokenKey });
      _sb.AppendLine();
      AddString("Chef Server Internal IP Address: {0}", new string[] { ChefServerInternalIPAddressKey });
      AddString("Automate Server Internal IP Address: {0}", new string[] { AutomateServerInternalIPAddressKey });
      File.WriteAllText(credentials_path, _sb.ToString());
     
      // create a dictionary to hold the credentials data so that it can be written out as JSON
      Dictionary<string, string> data = new Dictionary<string, string>();

      if (_config_store.ContainsKey(ChefServerFQDNKey) && _config_store.ContainsKey(OrgKey))
        data.Add("CHEF_SERVER_URL", String.Format("https://{0}/organizations/{1}", _config_store[ChefServerFQDNKey], _config_store[OrgKey]));

      if (_config_store.ContainsKey(UserKey))
        data.Add("USER_USERNAME", _config_store[UserKey]);
      
      if (_config_store.ContainsKey(UserPasswordKey))
        data.Add("USER_PASSWORD", _config_store[UserPasswordKey]);

      if (_config_store.ContainsKey(AutomateServerFQDNKey))
        data.Add("AUTOMATE_SERVER_URL", String.Format("https://{0}", config_store[AutomateServerFQDNKey]));

      if (_config_store.ContainsKey(AutomateCredentialsAdminUsernameKey))
        data.Add("AUTOMATE_ADMIN_USERNAME", config_store[AutomateCredentialsAdminUsernameKey]);

      if (_config_store.ContainsKey(AutomateCredentialsAdminPasswordKey))
        data.Add("AUTOMATE_ADMIN_PASSWORD", config_store[AutomateCredentialsAdminPasswordKey]);

      if (_config_store.ContainsKey(AutomateTokenKey))
        data.Add("AUTOMATE_ADMIN_TOKEN", config_store[AutomateTokenKey]);

      if (_config_store.ContainsKey(ChefServerInternalIPAddressKey))
        data.Add("CHEF_SERVER_INTERNAL_IP_ADDRESS", config_store[ChefServerInternalIPAddressKey]);

      if (_config_store.ContainsKey(AutomateServerInternalIPAddressKey))
        data.Add("AUTOMATE_SERVER_INTERNAL_IP_ADDRESS", config_store[AutomateServerInternalIPAddressKey]);

      // Write out the data to a file in the extras directory
      string credentials_json_path = Path.Combine(extras_path, "credentials.json") ;
      string data_json = JsonConvert.SerializeObject(data, Formatting.Indented);
      File.WriteAllText(credentials_json_path, data_json);

      // Read in the knife file and patch it so that it has the correct values
      string knife_config = File.ReadAllText(Path.Combine(executionContext.FunctionDirectory, "knife.rb"));

      knife_config = knife_config.Replace("{{ NODE_NAME }}", config_store[UserKey]);
      knife_config = knife_config.Replace("{{ CLIENT_KEY_FILENAME }}", client_key_filename);
      knife_config = knife_config.Replace("{{ ORG_VALIDATOR_NAME }}", String.Format("{0}-validator", config_store[OrgKey]));
      knife_config = knife_config.Replace("{{ ORG_KEY_FILENAME }}", validator_key_filename);
      knife_config = knife_config.Replace("{{ CHEF_SERVER_URL }}", String.Format("https://{0}/organizations/{1}", config_store[ChefServerFQDNKey], config_store[OrgKey]));

      // Write out the knife file to the repo directoyr
      string knife_file_path = Path.Combine(chef_repo_path, ".chef", "knife.rb");
      File.WriteAllText(knife_file_path, knife_config);

      // Read in the ARM extension template and patch the values
      string arm_extension = File.ReadAllText(Path.Combine(executionContext.FunctionDirectory, "chef_extension.json"));

      arm_extension = arm_extension.Replace("{{ CHEF_SERVER_URL }}", String.Format("https://{0}/organizations/{1}", config_store[ChefServerFQDNKey], config_store[OrgKey]));
      arm_extension = arm_extension.Replace("{{ ORG_VALIDATOR_NAME }}", String.Format("{0}-validator", config_store[OrgKey]));
      arm_extension = arm_extension.Replace("{{ ORG_VALIDATOR_KEY }}", config_store[OrgKeyKey]);

      string arm_extension_path = Path.Combine(extras_path, "chef_extension.json");
      File.WriteAllText(arm_extension_path, arm_extension);

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

  private void AddString(string phrase, string[] keys)
  {
    string[] replacements = new string[keys.Count()];
    string replacement;

    foreach (string key in keys)
    {
      if (_config_store.ContainsKey(key))
      {
        replacement = _config_store[key];
      }
      else
      {
        replacement = "NOT IN CONFIG STORE";
      }

      replacements.Append(replacement);
    }

    // add to the StringBuilder if the key exists in the configstore
    _sb.AppendLine(String.Format(phrase, replacements));
  }

}