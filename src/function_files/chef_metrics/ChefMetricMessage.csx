using System.Net;
using System.Text.RegularExpressions;

public class ChefMetricMessage {
    public DateTime time { get; set; }
    public string name { get; set; }
    public string type { get; set; }
    public string host { get; set; }
    public double value { get; set; } 
}