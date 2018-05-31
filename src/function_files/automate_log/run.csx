#r "Newtonsoft.Json"
#load "AutomateLog.csx"
#load "AutomateMessage.csx"
#load "AutomateLogParser.csx"
#load "LogAnalyticsWriter.csx"
#load "workspace.csx"
using System.Net;
using Newtonsoft.Json;
public static async Task<HttpResponseMessage> Run(HttpRequestMessage req, TraceWriter log)
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
            AutomateMessage automateMessage = AutomateLogParser.ParseGenericLogMessage(data.MESSAGE_s, log);
            log.Info(automateMessage.sourcePackage);
            if(automateMessage.sourcePackage != "Unknown Entry"){
                string logName = automateMessage.sourcePackage.Replace("-", "") + "log";
                law.Submit(automateMessage, logName);
            }
        }
    }
	log.Info(data._HOSTNAME);


    return data.MESSAGE_s == null
        ? req.CreateResponse(HttpStatusCode.BadRequest, "Please pass a name on the query string or in the request body")
        : req.CreateResponse(HttpStatusCode.OK, "Hello " + data.MESSAGE_s);
}

