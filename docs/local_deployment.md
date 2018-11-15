# Local Deployment

When using nested templates against Azure, they need to be publicly accessible. This is not easy to accomplish if you are developing on a laptop within a corporate network for example. To assist with this a local script has been setup that will perform the deployment for you.

## Process

When the script is executed it runs through the following process all of which are automatic.

 - Does the resource group already exist?
   - If this is the first time the script has been run this will be false
   - If this is not the first time, then a local file `.deploy` will be read and the iteration found. The resource group name is thus `<RESCOURCE_GROUP>-<ITERATION>`. Delete the resource group.
 - Increment the iteration and write out to the `.deploy` file
 - Determine the name of the resource group to create, again `<RESCOURCE_GROUP>-<ITERATION>`
 - Upload files to the specified storage account and container
 - Perform deployment into the newly created resource group

## Limitations

The are currently some few limitations on the tooling. These will be addressed

 - The storage account and container must already exist
 - The container must have public access set on it
 - The deployment blocks until it is complete

## Pre-requisites

In order to perform a local deployment the following pre-requisites must be met:

  - Publicly accessible storage account and container
  - Azure Service principal in your credentials file (default location is `~/.azure/credentials`)

For the moment a storage account and container with public access needs to be configured.

An Azure Service Principal Name stored in a credentials file. By default it will be looked for in `~/.azure/credentials`.

## Configuration

In order for deployments to work, a deployment configuration file is required. By default it will be found in the project root directory and is called `deploy.json`.
This file should not be checked into source control and as such is part of the `.gitignore`.

This file should contain the following information:

| Attribute | Description | Example |
|---|---|---|
| resourceGroup.name | The name of the resource group to create to perform the deployment into | |
| resourceGroup.location | Azure location for the resource group | |
| resourceGroup.parameters_file | Path to the parameters file for the deployment | `.local/parameters.json` |
| storageAccount.name | Name of the storage account that the files are to be uploaded to | |
| storageAccount.container | Container within the storage account for the files | |
| storageAccount.group_name | Resource group that contains the storage account for uploads | |
| dirs.working | The directory containing the built template files | `build/working` |

### Upload

The upload sub-command has the following syntax and options.

_Syntax_

`deploy.js upload <SUBSCRIPTION> [-s <STORAGE_ACCOUNT_NAME>] [-n <CONTAINER_NAME>] [-a <AZURE_CREDS_FILE>] [-G <STORAGE_ACCOUNT_RESOURCE_GROUP>]`

_Settings_

| Name | Description | Default Value | Optional |
|---|---|---|--|
| SUBSCRIPTION | The subscription that the storage account is in | | No |
| STORAGE_ACCOUNT_NAME | The name of the storage account | | Yes |
| CONTAINER_NAME | Name of the container within the storage account that will contain the files | | Yes |
| AZURE_CREDS_FILE | The location of the Azure credentials file containing SPN. | `~/.azure/credentials` | Yes |
| STORAGE_ACCOUNT_RESOURCE_GROUP | The name of the resource group containing the named storage account | | Yes |

All optional parameters can be specified in the `deploy.json` file of the project.
If an option is specified it will overwrite any values from the configuration file for the duration of that command.

### Deploy

The deploy sub-command has the following syntax and options.

_Syntax_

`deploy.js deploy <SUBSCRIPTION> [-l <LOCATION>] [-s <STORAGE_ACCOUNT_NAME>] [-n <CONTAINER_NAME>] [-a <AZURE_CREDS_FILE>] [-g <DEPLOYMENT_RESOURCE_GROUP>] [-p <PARAMETERS_FILE>]`

_Settings_

| Name | Description | Default Value | Optional |
|---|---|---|--|
| SUBSCRIPTION | The subscription that deployment resource group should be deployed into | | No |
| LOCATION | Location in Azure that the resource group should be created in | | Yes |
| STORAGE_ACCOUNT_NAME | The name of the storage account | | Yes |
| CONTAINER_NAME | Name of the container within the storage account that contains the template files | | Yes |
| AZURE_CREDS_FILE | The location of the Azure credentials file containing SPN. | `~/.azure/credentials` | Yes |
| DEPLOYMENT_RESOURCE_GROUP | The name of the resource group to deploy into | | Yes |
| PARAMETERS_FILE | Path to the parameters file for the deploument | `.local/parameters.json` | Yes |

All optional parameters can be specified in the `deploy.json` file of the project.
If an option is specified it will overwrite any values from the configuration file for the duration of that command.

## Examples

### Compile the scripts

The following command will compile the necessary scripts and place them in the `bin` directory

```
npm run compile:scripts
```

### Perform a build

In order to upload and deploy the templates, they need to be built.

```
npm run build:run
```
### Upload files

Upload the files into the storage account

```
node bin\deploy.js upload <SUBSCRIPTION>
```

### Deploy the templates

Perform a deployment. A parameters file is expected in `.local/parameters.json` but can be overridden using the `-p` option.

```
node bin\deploy.js deploy <SUBSCRIPTION>
```