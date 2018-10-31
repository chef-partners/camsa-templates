<#

.SYNOPSIS
  Ensure that the specified build agent has the correct PowerState

#>

[CmdletBinding()]
param (
  [Parameter(Mandatory=$true, HelpMessage="Resource Group containing the build agent")]
  [string]
  # Name of the resource group that has the build agent to manage
  $ResourceGroupName,

  [Parameter(Mandatory=$true, HelpMessage="Name of the build agent to manage")]
  [Alias('BuildAgentName')]
  [string]
  # Name of the build agent to start or stop
  $VMName,

  [Parameter(Mandatory=$true, HelpMessage="Action to perform on the agent")]
  [ValidateSet('start','stop', ignorecase=$False)]
  [string]
  # Action to perform on the build agent
  $action
)

# Attempt to get the VM that is to be managed
$splat = @{
  ResourceGroupName = $ResourceGroupName
  Name = $VMName
  Status = $true
  ErrorAction = "SilentlyContinue"
}
$azure_vm = Get-AzureRmVm @splat

# Check to see if the vm has been found
if ([String]::IsNullOrEmpty($azure_vm)) {

  Write-Output $("Unable to find VM '{0}' in Resource Group '{1}'" -f $VMName, $ResourceGroupName)

} else {

  # Get the PowerState of the machine
  $power_state = $azure_vm.Statuses[1].Code

  # Depending on the Action and the PowerState perform the necessary operations
  # If the Action is to start and the PowerState is not running attempt to start the machine
  if ($action -eq "start") {
    if ($power_state -ne "PowerState/running") {
      Write-Output $("Starting VM: {0}" -f $VMName)
      Start-AzureRMVm -ResourceGroupName $ResourceGroupName -Name $VMName
    } else {
      Write-Output $("VM is already running: {0}" -f $VMName)
    }
  }

  # If the action is to stop and the powerstate is running, turn off the machine
  if ($action -eq "stop") {
    if ($power_state -eq "PowerState/running") {
      Write-Output $("Stopping VM: {0}" -f $VMName)
      Stop-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $VMName -Confirm:$false -Force
    } else {
      Write-Output $("VM is already powered off: {0}" -f $VMName)
    }
  }
}