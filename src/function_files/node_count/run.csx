#r "Newtonsoft.Json"
#r "Microsoft.WindowsAzure.Storage"
#load "workspace.csx"
#load "constants.csx"

using System;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Microsoft.WindowsAzure.Storage.Table;
 
// Class for what should be sent to Log Analytics
public class NodeCount
{
    public string ServerAddress { get; set; }
    public int Total { get; set; }
    public int Success { get; set; }
    public int Failure { get; set; }
    public int Missing { get; set; }
}
 
public static void Run(TimerInfo myTimer, CloudTable settingTable, TraceWriter log)
{
    // LogName is name of the event type that is being submitted to Log Analytics
    string LogName = "ChefAutomateAMAInfraNodeCount";

    string datestring = String.Empty;
    string stringToHash = String.Empty;
    string hashedString = String.Empty;
    string signature = String.Empty;

    // Get the automate token from the config store table
    // and the automate FQDN
    TableOperation token_operation = TableOperation.Retrieve<ConfigKV>(PartitionKey, AutomateTokenKeyName);
    TableResult token_result = settingTable.Execute(token_operation);

    TableOperation fqdn_operation = TableOperation.Retrieve<ConfigKV>(PartitionKey, AutomateFQDNKeyName);
    TableResult fqdn_result = settingTable.Execute(fqdn_operation);

    // if there is a result get the key value, otherwise log error
    if (token_result.Result != null && fqdn_result.Result != null) {

        // get the token value
        ConfigKV token_setting = (ConfigKV)token_result.Result;
        ConfigKV fqdn_setting = (ConfigKV)fqdn_result.Result;
        string automate_token = token_setting.Value;
        string automate_fqdn = fqdn_setting.Value;

        // Creates the JSON object, with key/value pairs
        NodeCount jsonObj = new NodeCount();
        jsonObj = GetData(automate_fqdn, automate_token, log);
        jsonObj.ServerAddress = automate_fqdn;
        // Convert object to json
        var json = JsonConvert.SerializeObject(jsonObj);
    
        log.Info("json file sent to Log Analytics: " + json);
        
        // Create a hash for the API signature
        datestring = DateTime.UtcNow.ToString("r");
        stringToHash = "POST\n" + json.Length + "\napplication/json\n" + "x-ms-date:" + datestring + "\n/api/logs";
        hashedString = BuildSignature(stringToHash, sharedKey);
        signature = "SharedKey " + customerId + ":" + hashedString;
    
        PostData(signature, datestring, json, customerId, LogName, log);

        // Get the central logging workspace and attempt to send data there as well
        Dictionary<string, dynamic> cl_workspace = GetCentralLoggingWorkspace(settingTable, log);
        if (cl_workspace["id"] != false && cl_workspace["key"] != false)
        {
            // Create a hash for the API signature
            hashedString = BuildSignature(stringToHash, cl_workspace["key"]);
            signature = "SharedKey " + cl_workspace["id"] + ":" + hashedString;

            PostData(signature, datestring, json, cl_workspace["id"], LogName, log);
        }
    } else {
        log.Info(String.Format("Unable to find selected token in table: {0}", AutomateTokenKeyName));
    }
}
 
// Build the API signature
public static string BuildSignature(string message, string secret)
{
    var encoding = new System.Text.ASCIIEncoding();
    byte[] keyByte = Convert.FromBase64String(secret);
    byte[] messageBytes = encoding.GetBytes(message);
    using (var hmacsha256 = new HMACSHA256(keyByte))
    {
        byte[] hash = hmacsha256.ComputeHash(messageBytes);
        return Convert.ToBase64String(hash);
    }
}
 
// Send a request to the POST API endpoint
public static void PostData(string signature, string date, string json, string customerId, string LogName, TraceWriter log)
{
    // You can use an optional field to specify the timestamp from the data. If the time field is not specified, Log Analytics assumes the time is the message ingestion time
    string TimeStampField = "";
    try
    {
        string url = "https://" + customerId + ".ods.opinsights.azure.com/api/logs?api-version=2016-04-01";
 
        System.Net.Http.HttpClient client = new System.Net.Http.HttpClient();
        client.DefaultRequestHeaders.Add("Accept", "application/json");
        client.DefaultRequestHeaders.Add("Log-Type", LogName);
        client.DefaultRequestHeaders.Add("Authorization", signature);
        client.DefaultRequestHeaders.Add("x-ms-date", date);
        client.DefaultRequestHeaders.Add("time-generated-field", TimeStampField);
 
        System.Net.Http.HttpContent httpContent = new StringContent(json, Encoding.UTF8);
        httpContent.Headers.ContentType = new MediaTypeHeaderValue("application/json");
        Task<System.Net.Http.HttpResponseMessage> response = client.PostAsync(new Uri(url), httpContent);
 
        System.Net.Http.HttpContent responseContent = response.Result.Content;
        string result = responseContent.ReadAsStringAsync().Result;
        log.Info("Return Result: " + result);
    }
    catch (Exception excep)
    {
        log.Info("API Post Exception: " + excep.Message);
    }
}

// Send a request to the POST API endpoint
public static NodeCount GetData(string automate_fqdn, string token, TraceWriter log)
{
    
    NodeCount nodeCount = null;
    try
    {
        ServicePointManager.ServerCertificateValidationCallback += (sender, cert, chain, sslPolicyErrors) => true;
        string url = String.Format("https://{0}/api/v0/cfgmgmt/stats/node_counts", automate_fqdn);
        System.Net.Http.HttpClient client = new System.Net.Http.HttpClient();
        client.DefaultRequestHeaders.Add("x-data-collector-token", token);

         Task<HttpResponseMessage> response = client.GetAsync(new Uri(url));

        if (response.Result.IsSuccessStatusCode)
            {
                nodeCount = response.Result.Content.ReadAsAsync<NodeCount>().Result;
            }

        log.Info("Return Result: " + response.Result.Content);
    }
    catch (Exception excep)
    {
        log.Info("API Post Exception: " + excep.Message);
    } 
    return nodeCount;
}

public static Dictionary<string, dynamic> GetCentralLoggingWorkspace(CloudTable table, TraceWriter log)
{
    // initialise variables
    Dictionary<string, dynamic> workspace = new Dictionary<string, dynamic>();

    // Set default values
    workspace.Add("id", false);
    workspace.Add("key", false);

    // Get the workspace id and key from the config stiore using the centralLogging partitionkey
    string partition_filter = TableQuery.GenerateFilterCondition(
        "PartitionKey",
        QueryComparisons.Equal,
        "centralLogging"
    );

    // create a partition query
    TableQuery<ConfigKV> query = new TableQuery<ConfigKV>().Where(partition_filter);

    // iterate around the results and set the workspace id and key of they exist
    foreach (ConfigKV entity in table.ExecuteQuery(query))
    {
        if (entity.RowKey == "workspace_id")
        {
            workspace["id"] = entity.Value;
        }

        if (entity.RowKey == "workspace_key")
        {
            workspace["key"] = entity.Value;
        }
    }

    return workspace;
}

public class ConfigKV : TableEntity {
    public string Value { get; set; }
}