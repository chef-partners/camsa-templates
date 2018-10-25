#r "Newtonsoft.Json"

#load "DataService.csx"
#load "ResponseMessage.csx"

#load "LogAnalyticsWriter.csx"
#load "AutomateLog.csx"
#load "AutomateLogParser.csx"
#load "AutomateMessage.csx"

// Load in the workspace file that contains the ID and key for the customer
// Log Analytics workspace
#load "workspace.csx"

using System.Net;
using Newtonsoft.Json;
using Microsoft.WindowsAzure.Storage.Table;

public class AutomateLogListener
{
  private ResponseMessage _response = new ResponseMessage();
  public async Task<HttpResponseMessage> Process(HttpRequestMessage req, CloudTable table, IEntity config, TraceWriter log)
  {
    HttpResponseMessage msg;

    // Only respond to an HTTP Post
    if (req.Method == HttpMethod.Post)
    {

      // Get all the settings for the CentralLogging partition
      Dictionary<string, string> central_logging = DataService.GetAll(table, config, "centralLogging");

      // Get the body of the request
      string body = await req.Content.ReadAsStringAsync();
      string[] logs = body.Split('}');

      // Create an instance of the LogAnalyticsWriter
      LogAnalyticsWriter log_analytics_writer = new LogAnalyticsWriter(log);

      // Add in the customer workspace information
      log_analytics_writer.AddWorkspace(customerId, sharedKey);

      // if the central logging dictionary contains entries for an ID and key add it to the workspace
      if (central_logging.ContainsKey("workspace_id") && central_logging.ContainsKey("workspace_key"))
      {
        log_analytics_writer.AddWorkspace(central_logging["workspace_id"], central_logging["workspace_key"]);
      }

      // Create an instance of AutomateLog which will hold the data that has been submitted
      AutomateLog data = new AutomateLog();

      // iterate around each item in the logs
      string appended_item;
      string log_name;
      foreach (string item in logs)
      {
        appended_item = item;
        if (!appended_item.EndsWith("}"))
        {
          appended_item += "}";
        }

        // output the item to the console
        log.Info(item);

        // if the item is not empty, process it
        if (!String.IsNullOrEmpty(item))
        {
          // Deserialise the item into the AutomateLog object
          data = JsonConvert.DeserializeObject<AutomateLog>(appended_item as string);

          // From this data create an AutomateMessage object
          AutomateMessage automate_message = AutomateLogParser.ParseGenericLogMessage(data.MESSAGE_s, customerName, subscriptionId, log);

          // if the message is known then submit to LogAnalytics
          if(automate_message.sourcePackage.ToLower() != "uknown entry")
          {
            // Determine the log name of the message
            log_name = automate_message.sourcePackage.Replace("-", "") + "log";

            // Submit the data
            log_analytics_writer.Submit(automate_message, log_name);
          }
        }
      }

      _response.SetMessage("Log data accepted");
      msg = _response.CreateResponse();

    }
    else
    {
      _response.SetError("HTTP Method not supported", true, HttpStatusCode.BadRequest);
      msg = _response.CreateResponse();
    }

    return msg;
  }
}