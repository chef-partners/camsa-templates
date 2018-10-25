#r "Newtonsoft.Json"
using System;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;

public class LogAnalyticsWriter {

    // Create a dictionary to hold the necessary workspaces
    Dictionary<string, string> workspaces = new Dictionary<string, string>();
    TraceWriter AFLog;

    public LogAnalyticsWriter(TraceWriter log)
    {
        AFLog = log;
    }

    public void AddWorkspace(string customerId, string sharedKey)
    {
        // Add the ID and key to the workspaces dictionary
        workspaces.Add(customerId, sharedKey);
    }

    // Build the API signature
    private string BuildSignature(string message, string secret)
    {
        var encoding = new System.Text.ASCIIEncoding();
        byte[] keyByte = Convert.FromBase64String(secret);
        byte[] messageBytes = encoding.GetBytes(message);
        using (var hmacsha256 = new HMACSHA256(keyByte))
        {
            byte[] hash = hmacsha256.ComputeHash(messageBytes);
            AFLog.Info("in build function 5");
            return Convert.ToBase64String(hash);
        }
    }

    private void PostData(string customer_id, string signature, string json, string logName, string date, string timestamp = "")
    {       
        try
        {
            string url = "https://" + customer_id + ".ods.opinsights.azure.com/api/logs?api-version=2016-04-01";
            AFLog.Info(url);
    
            System.Net.Http.HttpClient client = new System.Net.Http.HttpClient();
            client.DefaultRequestHeaders.Add("Accept", "application/json");
            client.DefaultRequestHeaders.Add("Log-Type", logName);
            client.DefaultRequestHeaders.Add("Authorization", signature);
            client.DefaultRequestHeaders.Add("x-ms-date", date);
            client.DefaultRequestHeaders.Add("time-generated-field", timestamp);
    
            System.Net.Http.HttpContent httpContent = new StringContent(json, Encoding.UTF8);
            httpContent.Headers.ContentType = new MediaTypeHeaderValue("application/json");
            Task<System.Net.Http.HttpResponseMessage> response = client.PostAsync(new Uri(url), httpContent);
    
            System.Net.Http.HttpContent responseContent = response.Result.Content;
            string result = responseContent.ReadAsStringAsync().Result;
            AFLog.Info("Return Result: " + result);
        }
        catch (Exception excep)
        {
            AFLog.Error("API Post Exception: " + excep.Message);
        }
    }

    public void Submit(IMessage automateMessage, string logName){

        string customer_id;
        string shared_key;

        // iterate around the workspaces
        foreach (KeyValuePair<string, string> workspace in workspaces)
        {
            customer_id = workspace.Key;
            shared_key = workspace.Value;

            var json = JsonConvert.SerializeObject(automateMessage);

            var datestring = DateTime.UtcNow.ToString("r");
            string stringToHash = "POST\n" + json.Length + "\napplication/json\n" + "x-ms-date:" + datestring + "\n/api/logs";
            string hashedString = BuildSignature(stringToHash, shared_key);
            string signature = "SharedKey " + customer_id + ":" + hashedString;

            string timestamp = automateMessage.time.ToString("YYYY-MM-DDThh:mm:ssZ");
            AFLog.Info(timestamp);

            AFLog.Info("submiting log");
            PostData(customer_id, signature, json, logName, datestring, timestamp);
        }
    }

}