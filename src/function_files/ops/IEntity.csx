#load "ResponseMessage.csx"

using Microsoft.WindowsAzure.Storage.Table;

internal interface IEntity
{
  string GetPartitionKey();
  void Parse(string json);
  ResponseMessage GetResponseMessage();
  Config GetItem();
  void AddItem(string key, string value);
  Dictionary<string, string> GetItems();
  Task<HttpResponseMessage> Process(HttpRequestMessage req, CloudTable table, TraceWriter log, string identifier, string category);
}