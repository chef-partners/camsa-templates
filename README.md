
# Azure Managed Chef Automate

This repository holds all of the ARM templates, functions and scripts that make up the Azure Managed App for Chef Automate 2. 

It has been developed so that it can be used either from the Azure Portal when someone wants the Managed App, or as a deployment into a subscription. This latter scenario is for people and companies that want to have the same deployment as Chef provides, but want to run the infrastructure themselves.

This README contains QuickStart information about how you can use the templates. For more in depth information please refer to the [Wiki](https://github.com/chef-partners/azure-managed-automate/wiki).

## Quick Start

All of the files in this repo are part of a Build and Release pipeline in VSTS. This pipeline deploys the template to Azure, runs a number of InSpec tests and then, if they all pass, a release is made to publiclly accessible blob storage. By deploying to Azure blob storage the issues regarding creating branches in git automatically are avoided.

The main template is therefore hosted here https://chefmanagedapp.blob.core.windows.net/files/mainTemplate.json. All of the other files are also hosted here and the main template references them during deployment.

As always there are a number of parameters that can be specified to adjust the deployment to your needs. The table below highlights the ones that are most common. For a complete list of available parameters and a description please refer to the Wiki.

| Parameter | Description | Required | Default Value |
|---|---|---|---|
| `prefix` | All resources are prefixed with this value to help avoid conflicts in Azure | [X] | |
| `existingVnet` | State if an existing virtual network should be used | [] | true |
| `virtualNetworkName` | Virtual network to use or create, based on `existingVnet` | [x] | |
| `customerResourceGroup` | If using an existing vnet, this is the name of the resource group it is in | [X] | "" |
| `subnetName` | Name of the subnet to use or created, based on `existingVnet` | [X] | "" |
| `sshSourceAddresses` | Array of IP addresses or range that are permitted to SSH to the servers | [] | 34.206.89.3/32 |
| `chefUsername` | Name of the account to create on the Chef and Automate servers | [X] | |
| `chefUserFullname` | Fullname of the user being created. Must be in the form '`firstname lastname`' | [X] | |
| `chefUserPassword` | Password to be associated with the user | [X] | |
| `chefUserEmailaddress` | EMail address associated with the user | [X] | | 
| `chefOrg` | Short name of the organisation to create. Must not contain spaces | [X] | |
| `chefOrgDescription` | Description of the organisation | [X] | |
| `automateLicence` | Automate licence as provided by Chef. If not specified a 30 day trial is enabled. | [] | "" |
| `enableLogAnalytics` | If enabled then a Log Analytics workspace will be created for monitoring purposes | [] | true |
| `enableBackup` | If enabled a backup will be taken, as specified, and placed in blob storage | [] | true |
| `backupHour` | The hour at which the backup should occur. Time is taken as UTC | [] | 1 |
| `backupMinute` | Minute in the hour that the backup should be taken | [] | 0 |
| `sshPublicKeys` | Array of SSH keys that should be associated with the `azureama` user | [] | |

These settings should be put into a parameters file that can be read by the command line. An skeleton sample file is provided in [here](samples/parameters.json); set the values as required for your deployment.

### Deployment

The following commands show how to perform the deployment using either the Azure CLI or Windows PowerShell. The parameters file will be used and the main template will be called from Blob storage.

In both cases a new resource group is created, the template and parameters are validated and then a deployment is performed. In the examples a resource group called "chef-automate-2" is created, but change this accordingly.

NOTE The following examples assume that Azure CLI will be run on Linux and PowerShell will be run on Windows. Of course it is possible to run them the other way around, but that is not shown here.

#### Azure CLI

```bash
# Set variables
RESOURCE_GROUP_NAME="chef-automate-2"
LOCATION="westeurope"
PARAMETERS_FILE="samples/parameters.json"

# Create the resource group
az group create -l $LOCATION -n $RESOURCE_GROUP_NAME

# Validate the deployment. If successful a JSON string of the template will be returned
az group deployment validate -g $RESOURCE_GROUP_NAME \
  --template-uri https://chefmanagedapp.blob.core.windows.net/files/mainTemplate.json \
  --parameters $PARAMETERS_FILE

# Perform the deployment
az group deployment create -g $RESOURCE_GROUP_NAME \
  --template-uri https://chefmanagedapp.blob.core.windows.net/files/mainTemplate.json \
  --parameters $PARAMETERS_FILE \
  --no-wait
```

#### PowerShell

```powershell
# Set variables
$RESOURCE_GROUP_NAME="chef-automate-2"
$LOCATION="westeurope"
$PARAMETERS_FILE="samples/parameters.json"

# Create the resource group
New-AzureRMResourceGroup -Location $LOCATION -Name $RESOURCE_GROUP_NAME

# Validate the deployment
Test-AzureRMResourceGroupDeployment -ResourceGroupName $RESOURCE_GROUP_NAME `
  -TemplateParameterFile $PARAMETERS_FILE `
  -TemplateUri https://chefmanagedapp.blob.core.windows.net/files/mainTemplate.json

# Perform the deployment
New-AzureRMResourceGroupDeployment -ResourceGroupName $RESOURCE_GROUP_NAME `
  -TemplateParameterFile $PARAMETERS_FILE `
  -TemplateUri https://chefmanagedapp.blob.core.windows.net/files/mainTemplate.json
```

