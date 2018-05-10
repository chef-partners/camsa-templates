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
        // Update customerId to your Operations Management Suite workspace ID
        string CustomerId;
        // For sharedKey, use either the primary or the secondary Connected Sources client authentication key   
        string SharedKey;
        TraceWriter AFLog;

    public LogAnalyticsWriter(string customerId, string sharedKey, TraceWriter log){
        CustomerId = customerId;
        SharedKey = sharedKey;
        AFLog = log;
        AFLog.Info(CustomerId);
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

    private void PostData(string signature, string json, string logName, string date, string timestamp = "")
    {       
        try
        {
            string url = "https://" + CustomerId + ".ods.opinsights.azure.com/api/logs?api-version=2016-04-01";
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

    public void Submit(AutomateMessage automateMessage, string logName){
        var json = JsonConvert.SerializeObject(automateMessage);

        var datestring = DateTime.UtcNow.ToString("r");
        string stringToHash = "POST\n" + json.Length + "\napplication/json\n" + "x-ms-date:" + datestring + "\n/api/logs";
        string hashedString = BuildSignature(stringToHash, SharedKey);
        string signature = "SharedKey " + CustomerId + ":" + hashedString;

        string timestamp = automateMessage.time.ToString("YYYY-MM-DDThh:mm:ssZ");
        AFLog.Info(timestamp);

        AFLog.Info("submiting log");
        PostData(signature, json, logName, datestring, timestamp);
    }

}