#r "Microsoft.WindowsAzure.Storage"
#r "System.IO.Compression.Filesystem"
#r "Newtonsoft.Json"

#load "constants.csx"

using System.Net;
using System.Collections.Generic;
using System.Text;
using System.IO.Compression;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Table;
using Newtonsoft.Json;

public static async Task<HttpResponseMessage> Run(HttpRequestMessage req, CloudTable settingTable, TraceWriter log, ExecutionContext executionContext)
{

    // Get all the settings from the table into a hashtable
    Dictionary<string, string> AMA = GetAMA(settingTable);

    // Create directory structure for the files that need to be zipped up
    string chef_repo_path = Path.Combine(executionContext.FunctionDirectory, "chef-repo");

    // delete the repo path if it already exists
    if (Directory.Exists(chef_repo_path))
    {
        Directory.Delete(chef_repo_path, true);
    }

    // Base64 decode the user key and set the path to the file
    string client_key_filename = String.Format("{0}.pem", AMA[UserKey]);
    string client_key_path = Path.Combine(chef_repo_path, ".chef", client_key_filename);
    string user_key = Encoding.UTF8.GetString(Convert.FromBase64String(AMA[UserKeyKey]));

    // Base64 decode the validator key and set the path to the file
    string validator_key_filename = String.Format("{0}-validator.pem", AMA[OrgKey]);
    string validator_key_path = Path.Combine(chef_repo_path, ".chef", validator_key_filename);
    string validator_key = Encoding.UTF8.GetString(Convert.FromBase64String(AMA[OrgKeyKey]));

    string extras_path = Path.Combine(chef_repo_path, "extras");

    // Ensure that the parent for the client_key_path exists
    if (!Directory.Exists(Directory.GetParent(client_key_path).ToString()))
    {
        Directory.CreateDirectory(Directory.GetParent(client_key_path).ToString());
    }

    if (!Directory.Exists(extras_path))
    {
        Directory.CreateDirectory(extras_path);
    }

    // Write the client and validation keys out to a file
    File.WriteAllText(client_key_path, user_key);
    File.WriteAllText(validator_key_path, validator_key);

    // Create the Chef Automate credentials file
    string credentials_path = Path.Combine(chef_repo_path, "credentials.txt");
    StringBuilder sb = new StringBuilder();
    sb.AppendLine(String.Format("Chef Server URL: https://{0}/organizations/{1}", AMA[ChefServerFQDNKey], AMA[OrgKey]));
    sb.AppendLine(String.Format("User username: {0}", AMA[UserKey]));
    sb.AppendLine(String.Format("User password: {0}", AMA[UserPasswordKey]));
    sb.AppendLine();
    sb.AppendLine(String.Format("Automate URL: https://{0}", AMA[AutomateServerFQDNKey]));
    sb.AppendLine(String.Format("Automate admin username: {0}", AMA[AutomateCredentialsAdminUsernameKey]));
    sb.AppendLine(String.Format("Automate admin password: {0}", AMA[AutomateCredentialsAdminPasswordKey]));
    sb.AppendLine(String.Format("Automate Token: {0}", AMA[AutomateTokenKey]));
    sb.AppendLine();
    sb.AppendLine(String.Format("Chef Server Internal IP Address: {0}", AMA[ChefServerInternalIPAddressKey]));
    sb.AppendLine(String.Format("Automate Server Internal IP Address: {0}", AMA[AutomateServerInternalIPAddressKey]));
    File.WriteAllText(credentials_path, sb.ToString());
    
    // create a dictionary to hold the credentials data so that it can be written out as JSON
    Dictionary<string, string> data = new Dictionary<string, string>();
    data.Add("CHEF_SERVER_URL", String.Format("https://{0}/organizations/{1}", AMA[ChefServerFQDNKey], AMA[OrgKey]));
    data.Add("USER_USERNAME", AMA[UserKey]);
    data.Add("USER_PASSWORD", AMA[UserPasswordKey]);
    data.Add("AUTOMATE_SERVER_URL", String.Format("https://{0}", AMA[AutomateServerFQDNKey]));
    data.Add("AUTOMATE_ADMIN_USERNAME", AMA[AutomateCredentialsAdminUsernameKey]);
    data.Add("AUTOMATE_ADMIN_PASSWORD", AMA[AutomateCredentialsAdminPasswordKey]);
    data.Add("AUTOMATE_ADMIN_TOKEN", AMA[AutomateTokenKey]);
    data.Add("CHEF_SERVER_INTERNAL_IP_ADDRESS", AMA[ChefServerInternalIPAddressKey]);
    data.Add("AUTOMATE_SERVER_INTERNAL_IP_ADDRESS", AMA[AutomateServerInternalIPAddressKey]);

    // Write out the data to a file in the extras directory
    string credentials_json_path = Path.Combine(extras_path, "credentials.json") ;
    string data_json = JsonConvert.SerializeObject(data, Formatting.Indented);
    File.WriteAllText(credentials_json_path, data_json);

    // Read in the knife file and patch it so that it has the correct values
    string knife_config = File.ReadAllText(Path.Combine(executionContext.FunctionDirectory, "knife.rb"));

    knife_config = knife_config.Replace("{{ NODE_NAME }}", AMA[UserKey]);
    knife_config = knife_config.Replace("{{ CLIENT_KEY_FILENAME }}", client_key_filename);
    knife_config = knife_config.Replace("{{ ORG_VALIDATOR_NAME }}", String.Format("{0}-validator", AMA[OrgKey]));
    knife_config = knife_config.Replace("{{ ORG_KEY_FILENAME }}", validator_key_filename);
    knife_config = knife_config.Replace("{{ CHEF_SERVER_URL }}", String.Format("https://{0}/organizations/{1}", AMA[ChefServerFQDNKey], AMA[OrgKey]));

    // Write out the knife file to the repo directoyr
    string knife_file_path = Path.Combine(chef_repo_path, ".chef", "knife.rb");
    File.WriteAllText(knife_file_path, knife_config);

    // Read in the ARM extension template and patch the values
    string arm_extension = File.ReadAllText(Path.Combine(executionContext.FunctionDirectory, "chef_extension.json"));

    arm_extension = arm_extension.Replace("{{ CHEF_SERVER_URL }}", String.Format("https://{0}/organizations/{1}", AMA[ChefServerFQDNKey], AMA[OrgKey]));
    arm_extension = arm_extension.Replace("{{ ORG_VALIDATOR_NAME }}", String.Format("{0}-validator", AMA[OrgKey]));
    arm_extension = arm_extension.Replace("{{ ORG_VALIDATOR_KEY }}", AMA[OrgKeyKey]);

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

    // Turn the Zip file into a byte array
    var dataBytes = File.ReadAllBytes(zip_path);
    var dataStream = new MemoryStream(dataBytes);

    // Build up the response so that the zip file can be returned
    HttpResponseMessage response = new HttpResponseMessage(HttpStatusCode.OK);
    response.Content = new StreamContent(dataStream);
    response.Content.Headers.ContentDisposition = new System.Net.Http.Headers.ContentDispositionHeaderValue("attachment");
    response.Content.Headers.ContentDisposition.FileName = "starter_kit.zip";
    response.Content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("application/octet-stream");

    // Remove the chef_repo directory and the starter kit
    Directory.Delete(chef_repo_path, true);
    File.Delete(zip_path);

    return response;
}

public static Dictionary<string, string> GetAMA (CloudTable settingTable) {

    // Initialise the dictionary that is to be returned
    Dictionary<string, string> AMA = new Dictionary<string, string>();

    // create a table query to get all the information from the table
    TableQuery<ConfigKV> query = new TableQuery<ConfigKV>().Where(TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, PartitionKey));

    // iterate around the table and get all the required values
    TableContinuationToken token = null;
    do
    {
        TableQuerySegment<ConfigKV> resultSegment = settingTable.ExecuteQuerySegmented(query, token);
        token = resultSegment.ContinuationToken;

        foreach (ConfigKV item in resultSegment.Results)
        {
            AMA.Add(item.RowKey, item.Value);
        }
    } while (token != null);

    return AMA;

}

public class ConfigKV : TableEntity {
    public string Value { get; set; }
}
