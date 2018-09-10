#r "Newtonsoft.Json"
#r "Microsoft.WindowsAzure.Storage"

#load "AutomateLog.csx"
#load "AutomateMessage.csx"
#load "AutomateLogParser.csx"
#load "LogAnalyticsWriter.csx"
#load "workspace.csx"

using System.Net;
using Newtonsoft.Json;
using Microsoft.WindowsAzure.Storage.Table;

public static async Task<HttpResponseMessage> Run(HttpRequestMessage req,  CloudTable settingTable, TraceWriter log)
{
    log.Info("C# HTTP trigger function processed a request.");

	// Get request body
	var body = await req.Content.ReadAsStringAsync();
    string[] logs = body.Split('}');

    LogAnalyticsWriter law = new LogAnalyticsWriter(customerId, sharedKey, log);
    AutomateLog data = new AutomateLog();
    foreach(string item in logs){
        string appendedItem = item;
        if(!appendedItem.EndsWith("}")){
            appendedItem = appendedItem + '}';
        }
        log.Info(item);
        if(item != string.Empty){
	        data = JsonConvert.DeserializeObject<AutomateLog>(appendedItem as string);
            AutomateMessage automateMessage = AutomateLogParser.ParseGenericLogMessage(data.MESSAGE_s, customerName, subscriptionId, log);
            log.Info(automateMessage.sourcePackage);
            if(automateMessage.sourcePackage != "Unknown Entry"){
                string logName = automateMessage.sourcePackage.Replace("-", "") + "log";
                law.Submit(automateMessage, logName);

                // Attempt to submit data to central logging
                CentralLogging(automateMessage, logName, settingTable, log);
            }
        }
    }
	log.Info(data._HOSTNAME);


    return data.MESSAGE_s == null
        ? req.CreateResponse(HttpStatusCode.BadRequest, "Please pass a name on the query string or in the request body")
        : req.CreateResponse(HttpStatusCode.OK, "Hello " + data.MESSAGE_s);
}

/**
 * Method to send logging data to central logging
 * The workspace id and key are retrieved from the config store and only if they exist
 * will an attempt be made to send the data to the central logging
 */
public static void CentralLogging(AutomateMessage message, string name, CloudTable table, TraceWriter log)
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