#load "ResponseMessage.csx"

using System;
using System.Net;

using Microsoft.WindowsAzure.Storage.Table;

public class DataService
{
  private CloudTable _table;
  private TraceWriter _log;
  private ResponseMessage _response;

  public DataService(CloudTable table, TraceWriter log)
  {
    // set the private properties
    _table = table;
    _log = log;

    _response = new ResponseMessage();
  }

  public ResponseMessage GetResponseMessage()
  {
    return _response;
  }

  public dynamic Get(IEntity entity, string identifier, string category = null)
  {
    dynamic doc = null;

    string partition_key = entity.GetPartitionKey();
    if (!String.IsNullOrEmpty(category))
    {
      partition_key = category;
    }

    // Retrieve the chosen valie from the table
    TableOperation operation = TableOperation.Retrieve<Config>(partition_key, identifier);
    TableResult result = _table.Execute(operation);

    // if a result has been found, get the data
    if (result.Result != null)
    {
      doc = (Config) result.Result;

      // Create a dictionary to hold the return data
      // this is so that it is in the correct format to be consumed by the setup scripts
      Dictionary <string, string> data = new Dictionary<string, string>();
      data.Add(identifier, doc.Value);
      
      doc = data;
    }
    else
    {
      _response.SetError(String.Format("Unable to find item: {0}", identifier), true, HttpStatusCode.NotFound);
    }

    return doc;
  }

  public dynamic GetAll(IEntity entity, string category = null)
  {

    string partition_key = entity.GetPartitionKey();
    if (!String.IsNullOrEmpty(category))
    {
      partition_key = category;
    }

    // Retrieve all the items from the table
    TableQuery<Config> query = new TableQuery<Config>().Where(TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, partition_key));

    // iterate around the table and get all the required values
    TableContinuationToken token = null;
    do
    {
      TableQuerySegment<Config> resultSegment = _table.ExecuteQuerySegmented(query, token);
      token = resultSegment.ContinuationToken;

      foreach (Config item in resultSegment.Results)
      {
        entity.AddItem(item.RowKey, item.Value);
      }
    } while (token != null);

    // return the items that have been requested
    return entity.GetItems();
  }

  public bool Insert(IEntity entity, bool update = false)
  {
    bool status;

    TableOperation insertOperation;

    if (update)
    {
      insertOperation = TableOperation.InsertOrReplace(entity.GetItem());
    }
    else
    {
      insertOperation = TableOperation.Insert(entity.GetItem());
    }
    _table.Execute(insertOperation);

    return true;
  }
}