#load "IMessage.csx"
#load "BaseMessage.csx"

public class ChefMetricMessage : BaseMessage, IMessage 
{
    public string metricName { get; set; }
    public string metricType { get; set; }
    public string metricHost { get; set; }
    public double metricValue { get; set; }
}