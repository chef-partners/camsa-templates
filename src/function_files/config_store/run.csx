#r "Newtonsoft.Json"
#r "Microsoft.WindowsAzure.Storage"

#load "constants.csx"

using System.Net;
using System.Text;
using Newtonsoft.Json;
using Microsoft.WindowsAzure.Storage.Table;

public static async Task<HttpResponseMessage> Run(HttpRequestMessage req, ICollector<ConfigKV> outSettingTable, CloudTable settingTable, TraceWriter log)
{
    string partition_key = PartitionKey;

    // If the method is a POST then store information in the table store
    // otherwise if it is GET, return the value for the named key
    if (req.Method == HttpMethod.Post || req.Method == HttpMethod.Put) {
        
        TableOperation insertOperation;
        ConfigKV item = new ConfigKV();
        
        // get the payload data which should be JSON so it needs to be decoded
        dynamic body = await req.Content.ReadAsStringAsync();
        Dictionary<string, string> data = JsonConvert.DeserializeObject<Dictionary<string, string>>(body as string);

        // if a category has been set, override the paritionkey
        if (data.ContainsKey("category"))
        {
            partition_key = data["category"];
            data.Remove("category");
        }

        // Iterate around all the data that was sent to the function and add to the table
        Dictionary<string, string>.KeyCollection keys = data.Keys;
        foreach ( string key in keys ) {

            // create the item to add or update
            item = new ConfigKV();
            item.PartitionKey = partition_key;
            item.RowKey = key;
            item.Value = data[key];

            // Based on the method determine the type of operation to perform
            if (req.Method == HttpMethod.Post)
            {
                insertOperation = TableOperation.Insert(item);
                settingTable.Execute(insertOperation);
            }
            else if (req.Method == HttpMethod.Put)
            {
                insertOperation = TableOperation.InsertOrReplace(item);
                settingTable.Execute(insertOperation);
            }
        }
    
        return req.CreateResponse(HttpStatusCode.OK);

    } else if (req.Method == HttpMethod.Get) {
        
        string key = req.GetQueryNameValuePairs()
                        .FirstOrDefault(q => string.Compare(q.Key, "key", true) == 0)
                        .Value;

        string category = req.GetQueryNameValuePairs()
                            .FirstOrDefault(q => string.Compare(q.Key, "category", true) == 0)
                            .Value;

        // If the category is not null, set the partitionkey value
        if (!String.IsNullOrEmpty(category))
        {
            partition_key = category;
        }

        // retrieve the chosen value from the table
        TableOperation operation = TableOperation.Retrieve<ConfigKV>(partition_key, key);
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
