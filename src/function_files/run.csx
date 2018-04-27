#r "Newtonsoft.Json"
#r "Microsoft.WindowsAzure.Storage"

#load "constants.csx"

using System.Net;
using System.Text;
using Newtonsoft.Json;
using Microsoft.WindowsAzure.Storage.Table;

public static async Task<HttpResponseMessage> Run(HttpRequestMessage req, ICollector<ConfigKV> outSettingTable, CloudTable settingTable, TraceWriter log)
{

    // If the method is a POST then store information in the table store
    // otherwise if it is GET, return the value for the named key
    if (req.Method == HttpMethod.Post) {
        
        // get the payload data which should be JSON so it needs to be decoded
        dynamic body = await req.Content.ReadAsStringAsync();
        var data = JsonConvert.DeserializeObject<Dictionary<string, string>>(body as string);

        // Iterate around all the data that was sent to the function and add to the table
        Dictionary<string, string>.KeyCollection keys = data.Keys;
        foreach ( string key in keys ) {
            outSettingTable.Add(
                new ConfigKV() {
                    PartitionKey = PartitionKey,
                    RowKey = key,
                    Value = data[key]
                }
            );
        }
    
        return req.CreateResponse(HttpStatusCode.OK);

    } else if (req.Method == HttpMethod.Get) {
        
        string key = req.GetQueryNameValuePairs()
                        .FirstOrDefault(q => string.Compare(q.Key, "key", true) == 0)
                        .Value;

        // retrieve the chosen value from the table
        TableOperation operation = TableOperation.Retrieve<ConfigKV>(PartitionKey, key);
        TableResult result = settingTable.Execute(operation);

        // if a result has been found get the data
        if (result.Result != null) {
            ConfigKV setting = (ConfigKV)result.Result;

            // create a dictionary to hold the return data
            Dictionary<string, string> responseData = new Dictionary<string, string>();
            responseData.Add(key, setting.Value);

            return new HttpResponseMessage(HttpStatusCode.OK) {
                Content = new StringContent(JsonConvert.SerializeObject(responseData), Encoding.UTF8, "application/json")
            };
        } else {
            return req.CreateResponse(HttpStatusCode.BadRequest, string.Format("The specified key cannot be found: {0}", key));
        }

    } else {
        return req.CreateResponse(HttpStatusCode.OK, "Not Supported");
    }

}

public class ConfigKV : TableEntity {
    public string Value { get; set; }
}
