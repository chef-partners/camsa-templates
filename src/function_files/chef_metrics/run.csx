
#r "Newtonsoft.Json"
#r "Microsoft.WindowsAzure.Storage"

#load "../ops/IEntity.csx"
#load "../ops/Config.csx"
#load "../ops/DataService.csx"

#load "../ops/Constants.csx"
#load "../ops/IMessage.csx"
#load "../ops/LogAnalyticsWriter.csx"
#load "../ops/ChefMetricMessage.csx"
#load "../ops/workspace.csx"

using System;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Microsoft.WindowsAzure.Storage.Table; 

public static void Run(string rawmetric, CloudTable settingTable, TraceWriter log)
{
    // Instantiate objects to get relevant data from the configuration store
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

    // Create a datetime variable that is the Linux Epoch time
    System.DateTime dateTime = new System.DateTime(1970, 1, 1, 0, 0, 0, 0);

    // Parse the raw metric json into an object
    Newtonsoft.Json.Linq.JObject statsd = Newtonsoft.Json.Linq.JObject.Parse(rawmetric);

    // Iterate around the series data and create a message for each one
    var metrics = (JArray) statsd["series"];
    foreach (JObject metric in metrics) {

        // create message to send to Log Analytics
        ChefMetricMessage message = new ChefMetricMessage();

        // determine the time of the event
        DateTime time = dateTime.AddSeconds((double) metric["points"][0][0]);

        // set the properties of the object
        message.metricName = (string) metric["metric"];
        message.metricType = (string) metric["type"];
        message.metricHost = (string) metric["host"];
        message.time = time;
        message.metricValue = (double) metric["points"][0][1];
        message.customerName = customerName;
        message.subscriptionId = subscriptionId;

        // Submit the metric to Log Analytics
        log_analytics_writer.Submit(message, "statsd_log");
    }
}