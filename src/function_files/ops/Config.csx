#load "IEntity.csx"
#load "DataService.csx"

using Microsoft.WindowsAzure.Storage.Table;
using Microsoft.WindowsAzure.Storage;
using System.Net;
using Newtonsoft.Json;

public class Config : TableEntity, IEntity
{
  public string Value { get; set; }

  private Config item { get; set; }
  private Dictionary<string, string> _items = new Dictionary<string, string>();
  private ResponseMessage _response = new ResponseMessage();
  public Config() {}
  public Config(string partition_key)
  {
    this.PartitionKey = partition_key;
  }

  public void SetRowKey(string key) {
    this.RowKey = key;
  }

  public void SetValue(string value) {
    Value = value;
  }

  public string GetPartitionKey() {
    return this.PartitionKey;
  }

  public Config GetItem()
  {
    return item;
  }

  public Dictionary<string, string> GetItems()
  {
    return _items;
  }

  public void AddItem(string key, string value)
  {
    _items.Add(key, value);
  }

  public async Task<HttpResponseMessage> Process(HttpRequestMessage req, CloudTable table, TraceWriter log, string identifier, string category)
  {
    
    HttpResponseMessage response = null;
    ResponseMessage msg = null;

    DataService data_service = new DataService(table, log);
    if (req.Method == HttpMethod.Get)
    {
      dynamic result = data_service.Get(this, identifier, category);

      msg = data_service.GetResponseMessage();
      response = msg.CreateResponse(result);
    }
    else 
    {
      msg = new ResponseMessage();
      string json = await req.Content.ReadAsStringAsync();

      // parse the json that has been sent
      Parse(json);

      // Determine if there were any errors
      msg = GetResponseMessage();
      if (msg.IsError())
      {
        response = msg.CreateResponse();
      }
      else
      {

        // state if the operation is an update, based on the method
        bool update = false;
        if (req.Method == HttpMethod.Put)
        {
          update = true;
        }

        // attempt to insert the data into the table
        bool status = data_service.Insert(this, update);
      }

    }

    return response;
  }

  public void Parse(string json)
  {
    // attempt to deserialise the json into an array of objects
    Dictionary<string, string> data = JsonConvert.DeserializeObject<Dictionary<string, string>>(json);
    string partition_key = GetPartitionKey();

    if (data.ContainsKey("category")) {
      partition_key = data["category"];
      data.Remove("category");
    }

    item = new Config(partition_key);

    // iterate around all the data in the dictionary
    Dictionary<string, string>.KeyCollection keys = data.Keys;
    foreach (string key in keys)
    {
      item.SetRowKey(key);
      item.SetValue(data[key]);
    }
  }

  public ResponseMessage GetResponseMessage()
  {
    return _response;
  }  
}