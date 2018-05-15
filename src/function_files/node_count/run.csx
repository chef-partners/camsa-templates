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
    public string ServerType { get;set; }
    public int Total { get; set; }
    public int Success { get; set; }
    public int Failure { get; set; }
    public int Missing { get; set; }
}
 
public static void Run(TimerInfo myTimer, CloudTable settingTable, TraceWriter log)
{
    log.Info("Start function to add information to Log Analytics");
 
    // LogName is name of the event type that is being submitted to Log Analytics
    string LogName = "ChefAutomateAMAInfraNodeCount";

    Random garbage = new Random();
    string ServerType = "Automate";
    string Address = "https://opschefautomate.west.centralus.cloudapp.azure.com/";
    if(garbage.Next(1,3) == 1){
    ServerType = "Chef Server";
    Address = "https://opschefserver.west.centralus.cloudapp.azure.com/";
    }

    log.Info("Server Type is " + ServerType + " and address is " + Address);

    // Get the automate token from the config store table
    // and the automate FQDN
    TableOperation operation = TableOperation.Retrieve<ConfigKV>(PartitionKey, AutomateTokenKeyName);
    TableResult token_result = settingTable.Execute(operation);

    TableOperation operation = TableOperation.Retrieve<ConfigKV>(PartitionKey, AutomateFQDNKeyName);
    TableResult fqdn_result = settingTable.Execute(operation);

    // if there is a result get the key value, otherwise log error
    if (token_result.Result != null && fqdn_result.Result != ) {

        // get the token value
        ConfigKV token_setting = (ConfigKV)token_result.Result;
        ConfigKV fqdn_setting = (ConfigKV)fqdn_result.Result;
        string automate_token = token_setting.Value;
        string automate_fqdn = fqdn_setting.Value;

        // Creates the JSON object, with key/value pairs
        log.Info(GetStringData(log, automate_fqdn, automate_token));
        NodeCount jsonObj = new NodeCount();
        jsonObj = GetData(automate_fqdn, automate_token);
        jsonObj.ServerType = ServerType;
        jsonObj.ServerAddress = Address;
        // Convert object to json
        var json = JsonConvert.SerializeObject(jsonObj);
    
        log.Info("json file sent to Log Analytics: " + json);
        
        // Create a hash for the API signature
        var datestring = DateTime.UtcNow.ToString("r");
        string stringToHash = "POST\n" + json.Length + "\napplication/json\n" + "x-ms-date:" + datestring + "\n/api/logs";
        string hashedString = BuildSignature(stringToHash, sharedKey);
        string signature = "SharedKey " + customerId + ":" + hashedString;
    
        PostData(signature, datestring, json, customerId, LogName);
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
public static void PostData(string signature, string date, string json, string customerId, string LogName)
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
        Console.WriteLine("Return Result: " + result);
    }
    catch (Exception excep)
    {
        Console.WriteLine("API Post Exception: " + excep.Message);
    }
}

// Send a request to the POST API endpoint
public static NodeCount GetData(string automate_fqdn, string token)
{
    
    NodeCount nodeCount = null;
    try
    {
        ServicePointManager.ServerCertificateValidationCallback += (sender, cert, chain, sslPolicyErrors) => true;
        string url = String.format("https://{0}/api/v0/cfgmgmt/stats/node_counts", automate_fqdn);
        Console.WriteLine("PREPARING REQUEST======");
        System.Net.Http.HttpClient client = new System.Net.Http.HttpClient();
        client.DefaultRequestHeaders.Add("x-data-collector-token", token);

         Task<HttpResponseMessage> response = client.GetAsync(new Uri(url));

        if (response.Result.IsSuccessStatusCode)
            {
                nodeCount = response.Result.Content.ReadAsAsync<NodeCount>().Result;
            }

        Console.WriteLine("Return Result: " + response.Result.Content);
    }
    catch (Exception excep)
    {
        Console.WriteLine("API Post Exception: " + excep.Message);
    } 
    return nodeCount;
}

public static string GetStringData(TraceWriter log, string automate_fqdn, string token)
{
    
    string nodeCount = "unchanged";
    try
    {
        ServicePointManager.ServerCertificateValidationCallback += (sender, cert, chain, sslPolicyErrors) => true;
        string url = String.format("https://{0}/api/v0/cfgmgmt/stats/node_counts", automate_fqdn);
        log.Info("PREPARING REQUEST======");
        System.Net.Http.HttpClient client = new System.Net.Http.HttpClient();
        client.DefaultRequestHeaders.Add("x-data-collector-token", token);

        Task<HttpResponseMessage> response = client.GetAsync(new Uri(url));

        if (response.Result.IsSuccessStatusCode)
            {
                nodeCount = response.Result.Content.ReadAsStringAsync().Result;
            }

        log.Info("Return Result: " + response.Result.Content);
    }
    catch (Exception excep)
    {
        log.Info("API Get Exception: " + excep.Message);
        nodeCount = "failed";
    } 
    return nodeCount;
}

public class ConfigKV : TableEntity {
    public string Value { get; set; }
}