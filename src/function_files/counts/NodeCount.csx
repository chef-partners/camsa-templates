#load "BaseCount.csx"
#load "ICount.csx"
#load "../ops/IMessage.csx"

public class NodeCount : BaseCount, ICount, IMessage
{
  public int Total { get; set; }
  
  public int Success { get; set; }
  public int Failure { get; set; }
  public int Missing { get; set; }
}