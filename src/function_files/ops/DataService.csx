#load "ResponseMessage.csx"

using System;
using System.Net;

using Microsoft.WindowsAzure.Storage.Table;

public class DataService
{
  /*
  private static CloudTable _table;
  private TraceWriter _log;

  public DataService(CloudTable table, TraceWriter log)
  {
    // set the private properties
    _table = table;
    _log = log;

    _response = new ResponseMessage();
  }
  */
 
  private static ResponseMessage _response = new ResponseMessage();

  public static ResponseMessage GetResponseMessage()
  {
    return _response;
  }

  public static dynamic Get(CloudTable table, IEntity entity, string identifier, string category = null)
  {
    dynamic doc = null;

    string partition_key = entity.GetPartitionKey();
    if (!String.IsNullOrEmpty(category))
    {
      partition_key = category;
    }

    // Retrieve the chosen valie from the table
    TableOperation operation = TableOperation.Retrieve<Config>(partition_key, identifier);
    TableResult result = table.Execute(operation);

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

  public static dynamic GetAll(CloudTable table, IEntity entity, string category = null)
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
      TableQuerySegment<Config> resultSegment = table.ExecuteQuerySegmented(query, token);
      token = resultSegment.ContinuationToken;

      foreach (Config item in resultSegment.Results)
      {
        entity.AddItem(item.RowKey, item.Value);
      }
    } while (token != null);

    // return the items that have been requested
    return entity.GetItems();
  }

  public static bool Insert(CloudTable table, IEntity entity, bool update = false)
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
    table.Execute(insertOperation);

    return true;
  }
}