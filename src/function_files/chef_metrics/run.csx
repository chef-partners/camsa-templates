
#r "Newtonsoft.Json"

#load "LogAnalyticsWriter.csx"
#load "ChefMetricMessage.csx"
#load "workspace.csx"

using System;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

public static void Run(string rawmetric, TraceWriter log)
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
        message.name = (string) metric["metric"];
        message.type = (string) metric["type"];
        message.host = (string) metric["host"];
        message.time = time;
        message.value = (double) metric["points"][0][1];

        // Submit the metric to Log Analytics
        law.Submit(message, "statsd_log");
    }

}
