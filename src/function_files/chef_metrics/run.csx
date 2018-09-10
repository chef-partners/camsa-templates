
#r "Newtonsoft.Json"
#r "Microsoft.WindowsAzure.Storage"

#load "LogAnalyticsWriter.csx"
#load "ChefMetricMessage.csx"
#load "workspace.csx"

using System;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Microsoft.WindowsAzure.Storage.Table; 

public static void Run(string rawmetric, CloudTable settingTable, TraceWriter log)
{
    log.Info($"C# Queue trigger function processed: {rawmetric}");

    // Initalise variables
    System.DateTime dateTime = new System.DateTime(1970, 1, 1, 0, 0, 0, 0);
    LogAnalyticsWriter law = new LogAnalyticsWriter(customerId, sharedKey, log);

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
        message.cm_name = (string) metric["metric"];
        message.cm_type = (string) metric["type"];
        message.cm_host = (string) metric["host"];
        message.cm_time = time;
        message.cm_value = (double) metric["points"][0][1];
        message.cm_customer_name = customerName;
        message.cm_subscription_id = subscriptionId;

        // Submit the metric to Log Analytics
        law.Submit(message, "statsd_log");

        // Attempt to send data to Central Logging
        CentralLogging(message, "statsd_log", settingTable, log);
    }

}

/**
 * Method to send logging data to central logging
 * The workspace id and key are retrieved from the config store and only if they exist
 * will an attempt be made to send the data to the central logging
 */
public static void CentralLogging(ChefMetricMessage message, string name, CloudTable table, TraceWriter log)
{
    // initialise variables
    string workspace_id = String.Empty;
    string workspace_key = String.Empty;

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
            workspace_id = entity.Value;
        }

        if (entity.RowKey == "workspace_key")
        {
            workspace_key = entity.Value;
        }
    }

    // if the worksoace key and id have been set create a new LogAnalyticsWriter and send the
    // data
    if (!String.IsNullOrEmpty(workspace_id) && !String.IsNullOrEmpty(workspace_key))
    {
        log.Info("Sending to Central Log Analytics workspace");
        LogAnalyticsWriter centralWorkspace = new LogAnalyticsWriter(workspace_id, workspace_key, log);
        centralWorkspace.Submit(message, name);
    }
}

public class ConfigKV : TableEntity {
    public string Value { get; set; }
}