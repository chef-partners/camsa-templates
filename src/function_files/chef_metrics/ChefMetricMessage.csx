using System.Net;
using System.Text.RegularExpressions;

public class ChefMetricMessage {
    public DateTime cm_time { get; set; }
    public string cm_name { get; set; }
    public string cm_type { get; set; }
    public string cm_host { get; set; }
    public double cm_value { get; set; } 
}