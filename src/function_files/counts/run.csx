
#r "Microsoft.WindowsAzure.Storage"

#load "AutomateCounts.csx"

using System;
using System.Threading.Tasks;

using Microsoft.WindowsAzure.Storage.Table;

public static async Task Run(TimerInfo myTimer, CloudTable settingTable, TraceWriter log)
{

  // Create a new instance of AutomateCounts and call the process function
  // AutomateCounts automate_counts = new AutomateCounts();
  await AutomateCounts.Process(settingTable, log);

}
