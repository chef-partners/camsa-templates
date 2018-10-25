#r "Newtonsoft.Json"
#r "Microsoft.WindowsAzure.Storage"

#load "Constants.csx"
#load "ResponseMessage.csx"
#load "DataService.csx"
#load "Config.csx"

#load "StarterKit.csx"

#load "AutomateLogListener.csx"

#load "../counts/AutomateCounts.csx"

using System.Net;
using System.Text;
using Newtonsoft.Json;
using Microsoft.WindowsAzure.Storage.Table;

public static async Task<HttpResponseMessage> Run(HttpRequestMessage req, string optype, string id, string category, CloudTable settingTable, TraceWriter log, ExecutionContext executionContext)
{

  // Initialise variables
  HttpResponseMessage response = null;
  ResponseMessage msg = null;
  IEntity entity = null;

  // Perform the most appropriate action based on the optype
  switch (optype)
  {
    case "config":
      entity = new Config(ConfigStorePartitionKey);
      response = await entity.Process(req, settingTable, log, id, category);
      break;

    case "starterKit":
      entity = new Config(ConfigStorePartitionKey);
      StarterKit starter_kit = new StarterKit();
      response = await starter_kit.Process(req, settingTable, entity, log, category, executionContext);
      break;

    case "AutomateLog":
      entity = new Config();
      AutomateLogListener automate_log_listener = new AutomateLogListener();
      response = await automate_log_listener.Process(req, settingTable, entity, log);
      break;

    case "counts":
      await AutomateCounts.Process(settingTable, log);
      msg = new ResponseMessage();
      response = msg.CreateResponse();
      break;

    default:
      msg = new ResponseMessage(String.Format("Specified operation is not recognised: {0}", optype), true, HttpStatusCode.NotFound);
      response = msg.CreateResponse();
      break;
  }


  return response;
}