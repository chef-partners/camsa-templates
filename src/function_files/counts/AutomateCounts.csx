#r "Newtonsoft.Json"
#r "Microsoft.WindowsAzure.Storage"

#load "NodeCount.csx"
#load "UserCount.csx"

#load "../ops/Constants.csx"

#load "../ops/IEntity.csx"
#load "../ops/Config.csx"
#load "../ops/DataService.csx"

#load "../ops/LogAnalyticsWriter.csx"

// Load in the workspace which contains the customerName and subscriptionId
#load "../ops/workspace.csx"

using System;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

using Microsoft.WindowsAzure.Storage.Table;

public class AutomateCounts
{
  public static async Task Process(CloudTable settingTable, TraceWriter log)
  {
    // Create necessary objects to get information from the datastore
    IEntity config = new Config(ConfigStorePartitionKey);

    // Get all the settings for the CentralLogging partition
    Dictionary<string, string> central_logging = DataService.GetAll(settingTable, config, "centralLogging");

    // Create an instance of the LogAnalyticsWriter
    LogAnalyticsWriter log_analytics_writer = new LogAnalyticsWriter(log);

    // Add in the customer workspace information
    log_analytics_writer.AddWorkspace(customerId, sharedKey);

    // if the central logging dictionary contains entries for an ID and key add it to the workspace
    if (central_logging.ContainsKey("workspace_id") && central_logging.ContainsKey("workspace_key"))
    {
        log_analytics_writer.AddWorkspace(central_logging["workspace_id"], central_logging["workspace_key"]);
    }

    // Get the Automate token and fqdn from the config store
    Dictionary<string, string> token_setting = DataService.Get(settingTable, config, AutomateLoggingTokenKey);
    Dictionary<string, string> fqdn_setting = DataService.Get(settingTable, config, AutomateServerFQDNKey);

    // Set the time that that count was performed
    DateTime time = DateTime.UtcNow;

    // Request the NodeCount data from the Automate Server
    NodeCount node_count = await GetData("node", fqdn_setting[AutomateServerFQDNKey], token_setting[AutomateLoggingTokenKey], log);
    node_count.time = time;
    node_count.subscriptionId = subscriptionId;
    node_count.customerName = customerName;

    // Submit the node count
    log_analytics_writer.Submit(node_count, "ChefAutomateAMAInfraNodeCount");

    // Request the UserCount data from the Automate Server
    UserCount user_count = await GetData("user", fqdn_setting[AutomateServerFQDNKey], token_setting[AutomateLoggingTokenKey], log);

    user_count.time = time;
    user_count.subscriptionId = subscriptionId;
    user_count.customerName = customerName;

    log_analytics_writer.Submit(user_count, "ChefAutomateAMAUserCount");

  }

  public static async Task<dynamic> GetData(string type, string fqdn, string token, TraceWriter log)
  {
    // Initialise variables
    dynamic count = null;
    string url = String.Empty;

    // based on the type, set the url that needs to be accessed
    if (type == "node")
    {
      url = String.Format("https://{0}/api/v0/cfgmgmt/stats/node_counts", fqdn);
    }
    else if(type == "user")
    {
      url = String.Format("https://{0}/api/v0/auth/users", fqdn);
    }

    // Attempt to get the data from the Specified automate server using the token
    try
    {
      ServicePointManager.ServerCertificateValidationCallback += (sender, cert, chain, sslPolicyErrors) => true;

      // Create a client and submit the request to the URL
      HttpClient client = new HttpClient();

      // Set a header that contains the token we need to use for authentication
      client.DefaultRequestHeaders.Add("x-data-collector-token", token);

      HttpResponseMessage response = await client.GetAsync(new Uri(url));

      // if the response is OK read the data
      if (response.IsSuccessStatusCode)
      {
        if (type == "node")
        {
          count = response.Content.ReadAsAsync<NodeCount>().Result;
        }
        else if (type == "user")
        {
          // Get the data from the response
          dynamic user = response.Content.ReadAsAsync<dynamic>().Result;

          // Turn the users into an array so they can be easily counted
          JArray users = (JArray) user.users;

          // Create a User object with so that the count can be set
          count = new UserCount();
          count.Total = users.Count;
        }

        // set the server address on the object
        count.ServerAddress = fqdn;
      }

    }
    catch (Exception excep)
    {
      log.Info(String.Format("API Post Exception: {0}", excep.Message));
    }

    // return the count
    return count;
  }
}