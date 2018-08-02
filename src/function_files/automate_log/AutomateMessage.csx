using System.Net;
using System.Text.RegularExpressions;

public class AutomateMessage{
    public string sourcePackage { get; set; }
    public string logLevel { get; set; }
    public DateTime time { get; set; }
    public string message { get; set; }
    public string job { get; set; }
    public string function { get; set; }
    public string status { get; set; }
    public decimal request_time { get; set; }

    public string GetLogFriendlyPackageName(){
        string str = sourcePackage;
        
        Regex rgx = new Regex("[^a-zA-Z0-9]");
        str = rgx.Replace(str, "") + "log";

        return str;
    }
}
