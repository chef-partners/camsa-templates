#load "BaseCount.csx"
#load "ICount.csx"
#load "../ops/IMessage.csx"

public class UserCount : BaseCount, ICount, IMessage
{
  public int Total { get; set; }
}