/**
 * Script to deploy the template into Azure
 * This is intended as a testing tool and an easy way to perform deployments
 * It will perform the following steps:
 *    1. Upload template files to blob storage
 *    2. Delete / create resource group
 *    3. Deploy the template from blob storage with specified parameters
 * 
 * @author Russell Seymour
 */

// Libraries --------------------------------------------------------------
import * as program from "commander";
import * as path from "path";
import * as fs from "fs-extra";
import {sprintf} from "sprintf-js"
import * as os from "os";
import * as ini from "ini";
import * as msRestAzure from "ms-rest-azure";
import * as armStorage from "azure-arm-storage";
import * as armResource from "azure-arm-resource";
import * as azureStorage from "azure-storage";
import * as listdir from "recursive-readdir-synchronous";

import {Utils} from "./Utils";

// Functions --------------------------------------------------------------

function parseConfig(app_root, filepath, options, cmd) {
  let config = {};

  // determine if the deploy configuration file exists
  if (fs.existsSync(filepath)) {
    // read in the configuration file
    config = JSON.parse(fs.readFileSync(filepath, 'utf8'));

    // iterate around the dirs and prepend the app_root if it is not an absolute path
    Object.keys(config["dirs"]).forEach(function (key) {
      if (!path.isAbsolute(config["dirs"][key])) {
          config["dirs"][key] = path.join(app_root, config["dirs"][key]);
      };
    });

    // ensure that the resource group section exists
    if (!("resourceGroup" in config)) {
      config["resourceGroup"] = {}
    }

    if (!("name" in config["resourceGroup"])) {
      config["resourceGroup"]["name"] = "";
    }

    if (!("location" in config["resourceGroup"])) {
      config["resourceGroup"]["location"] = "";
    }

    if (!("parametersFile" in config["resourceGroup"])) {
      config["resourceGroup"]["parameters_file"] = "";
    }        

    // determine if a storage_account section exists
    if (!("storageAccount" in config)) {
      config["storageAccount"] = {}
    }

    // esnure that the children of the storage_account exists
    if (!("name" in config["storageAccount"])) {
      config["storageAccount"]["name"] = "";
    }

    if (!("container" in config["storageAccount"])) {
      config["storageAccount"]["container"] = "";
    }

    if (!("resourceGroup" in config["storageAccount"])) {
      config["storageAccount"]["resourceGroup"] = "";
    }

    // determine if the options for these values have been set, if they
    // have then overwrite the values that have come from the configuration file
    if (options.saname) {
      config["storageAccount"]["name"] = options.saname;
    }

    if (options.container) {
      config["storageAccount"]["container"] = options.container;
    }

    if (options.sagroupname) {
      config["storageAccount"]["groupName"] = options.sagroupname;
    }

    if (options.groupname) {
      config["resourceGroup"]["name"] = options.groupname;
    }

    if (options.location) {
      config["resourceGroup"]["location"] = options.location;
    }

    if (options.parameters) {
      config["resourceGroup"]["parameters_file"] = options.parameters;
    }

    // perform some validation checks
    let validation_errors = [];
    if (cmd == "upload") {
      if (config["storageAccount"]["name"] == "") {
        validation_errors.push("Storage account name has not been specified. Use -s or --saname or set in the configuration file");
      }

      if (config["storageAccount"]["container"] == "") {
        validation_errors.push("Container name must be specified. Use -n or --container or set in the configuration file");
      }
    }

    // if there are validation errors write them out
    if (validation_errors.length > 0) {
      console.log(sprintf("Errors have been detected: %s", validation_errors.length));
      for (let message of validation_errors) {
        console.log(sprintf(" - %s", message));
      }
      process.exit(1);
    }

  } else {
    console.log("Deploy configuration file not found: %s", filepath);
  }

  // add the command line options to the config
  config["options"] = options;

  // configure the locale deployment file
  config["control_file"] = path.join(app_root, ".deploy");
  if (!fs.existsSync(config["control_file"])) {

    // set the content of the control_file, as it does not exist, with an interation
    // value of 1
    let content = sprintf('{"%s": {"iteration": 1}}', config["resourceGroup"]["name"]);

    // write out the file
    fs.writeFileSync(config["control_file"], content, "utf8");
  }

  return config;
}

async function upload(config, subscription) {
  
  // create the necessary storage client
  let smClient = get_client(config["options"]["authfile"], subscription, "storage");
  let rmClient = get_client(config["options"]["authfile"], subscription, "resource");

  // Perform some checks to ensure that all necessary resources exist
  // - resource group
  let rg_exists = await rmClient.resourceGroups.checkExistence(config["storageAccount"]["groupName"]);
  // - storage account
  let sa_exists = await checkStorageAccountExists(smClient, config["storageAccount"]["name"]);
  // - container
  let container_exists = await checkContainerExists(smClient, config["storageAccount"]["groupName"], config["storageAccount"]["name"], config["storageAccount"]["container"]);

  // determine if the credentials file can be located
  if (rg_exists && sa_exists && container_exists) {

    // create blob service so that files can be uploaded
    let sakeys = await smClient.storageAccounts.listKeys(config["storageAccount"]["groupName"], config["storageAccount"]["name"], {});
    let blob_service = azureStorage.createBlobService(config["storageAccount"]["name"], sakeys.keys[0].value);

    // get all the files in the specified directory to be uploaded
    let items = listdir(config["dirs"]["working"]);

    // iterate around all the files
    let stats;
    let name;
    for (let item of items) {

      // continue onto the next item if this is is a directory
      stats = fs.lstatSync(item);
      if (stats.isDirectory()) {
        continue;
      }

      // the item is a file
      name = item.replace(/\\/g, '/');

      // create the correct name for the blob
      let string_to_check = config["dirs"]["working"].replace(/\\/g, '/');
      if (string_to_check.endsWith('/') == false) {
        string_to_check += "/"
      }
      name = name.replace(string_to_check, '')

      // upload the item
      blob_service.createBlockBlobFromLocalFile(config["storageAccount"]["container"], name, item, {}, (error, result) => {
        if (error) {
          console.log("FAILED to upload: %s", getError(error)) 
        } else {
          console.log("SUCCESS upload file: %s", item)
        }
      });
    }

  } else {
    console.error("Resource Group '%s' exists: %s", config["storageAccount"]["groupName"], rg_exists);
    console.error("Storage Account '%s' exists: %s", config["storageAccount"]["name"], sa_exists);
    console.error("Container '%s' exists: %s", config["storageAccount"]["container"], container_exists);
    console.error("Errors have occurred, please ensure that all the above resources exist");
    process.exit(4);
  }
}

async function deploy(config, subscription) {

  // read the local control file to determine the name of the resource group
  // to delete and then create
  let deploy_settings = JSON.parse(fs.readFileSync(config["control_file"], 'utf8'));
  if (!(config["resourceGroup"]["name"] in deploy_settings)) {
    deploy_settings[config["resourceGroup"]["name"]] = {"iteration": 0};
  }

  // determine the name of the resource group to delete
  let rg_name_existing = sprintf("%s-%s", config["resourceGroup"]["name"], deploy_settings[config["resourceGroup"]["name"]]["iteration"]);

  // create the necessary resource manager client
  let rmClient = get_client(config["options"]["authfile"], subscription, "resource");

  // determine if the rg exists
  if (rmClient != false) {
    console.log("Resource Group: %s", rg_name_existing);

    let exists = await new Promise<boolean>((resolve, reject) => {
      rmClient.resourceGroups.checkExistence(rg_name_existing, (error, exists) => {
        if (error) {
          return reject(sprintf("Failed to check the resource group status. Error: %s", Utils.getError(error)))
        }
        resolve(exists);
      })
    })
    if (exists) {
      console.log("   exists, deleting");

      let delete_status = new Promise<void> ((resolve, reject) => {
        rmClient.resourceGroups.deleteMethod(rg_name_existing, (error) => {
          if (error) {
            return reject(sprintf("Failed to delete the resource group. Error: %s", Utils.getError(error)))
          }
          resolve()
        })
      })

    } else {
      console.log("   does not exist");
    }

    // determine the next iteration and therefore the name of the new RG
    deploy_settings[config["resourceGroup"]["name"]]["iteration"] += 1;
    let rg_name = sprintf("%s-%s", config["resourceGroup"]["name"], deploy_settings[config["resourceGroup"]["name"]]["iteration"]);

    // write out the new iteration to the deployment file
    fs.writeFileSync(config["control_file"], JSON.stringify(deploy_settings), "utf8");

    // create the rg
    console.log("Creating Resource Group: %s", rg_name);
    console.log("  Location: %s", config["resourceGroup"]["location"]);

    await new Promise<void> ((resolve, reject) => {
      // define the parameters for the new RG
      let parameters = {
        "name": rg_name,
        "location": config["options"]["location"]
      }

      rmClient.resourceGroups.createOrUpdate(rg_name, parameters, (error) => {
        if (error) {
          return reject(sprintf("Failed to create the resource group. Error: %s", Utils.getError(error)))
        }
        resolve();
      })
    });

    // perform the deployment of the template and parameters
    // read in the parameters file
    let template_parameters;
    console.log("Reading parameters file: %s", config["resourceGroup"]["parameters_file"]);
    if (fs.existsSync(config["resourceGroup"]["parameters_file"])) {
      template_parameters = JSON.parse(fs.readFileSync(config["resourceGroup"]["parameters_file"], "utf8"));
    } else {
      console.error("  cannot find file");
      process.exit(3);
    }

    // determine the template-uri
    let template_uri = sprintf("https://%s.blob.core.windows.net/%s/mainTemplate.json", config["storageAccount"]["name"], config["storageAccount"]["container"]);

    console.log("Deploying template: %s", template_uri);

    // create the deployment parameters
    let deployment_parameters = {
      "properties":{
        "parameters": template_parameters["parameters"],
        "templateLink": {
          "uri": template_uri,
        },
        "mode": "Incremental"
      }
    }

    // create a deployment name
    let date_now = new Date().toISOString().replace(/-|T.*/g, '');
    let deployment_name = sprintf("%s-%s", rg_name.toLocaleLowerCase(), date_now);

    await new Promise<void> ((resolve, reject) => {
      rmClient.deployments.createOrUpdate(rg_name, deployment_name, deployment_parameters, (error) => {
        if (error) {
          return reject(sprintf("Failed to deploy the template. Error: %s", Utils.getError(error)))
        }
        resolve();
      })
    });



  }

}

function get_client(authfile, subscription, type) {

  // define the client to return
  let client;

  if (fs.existsSync(authfile)) {
    
    // read in the configuration file
    let credentials = ini.parse(fs.readFileSync(authfile, 'utf-8'));

    // ensure that the specified subscription can be found in the file
    if (subscription in credentials) {
 
      // get the required settings from the credentials file
      let client_id = credentials[subscription].client_id;
      let client_secret = credentials[subscription].client_secret;
      let tenant_id = credentials[subscription].tenant_id;

      // create token credentials with access to Azure
      let azure_token_creds = new msRestAzure.ApplicationTokenCredentials(client_id, tenant_id, client_secret);

      // create the necessary storage client
      if (type == "storage") {
        client = new armStorage.StorageManagementClient(azure_token_creds, subscription);
      } else if (type == "resource") {
        client = new armResource.ResourceManagementClient(azure_token_creds, subscription);
      } else {
        client = false;
      }
    } else {
      console.log("Unable to find subscription '%s' in auth file: %s", subscription, authfile);
      client = false;
    }
  } else {
    console.log("Unable to find credentials file: %s", authfile);
    client = false;
  }

  return client;
}

function getError(error: any): string {
  if (error && error.message) {
      return JSON.stringify(error.message)
  }

  return JSON.stringify(error)
}

async function checkStorageAccountExists(client, storage_account_name) {
  return new Promise<boolean>((resolve, reject) => {

      client.storageAccounts.checkNameAvailability(storage_account_name, 
                                                  (error, exists, request, response) => {
          if (error) {
              if (this.taskParameters.isDev) {
                  console.log(Utils.getError(error))
              }
          }
          resolve(!exists.nameAvailable);                
      })                   
  })

}

async function checkContainerExists(client, resource_group_name, storage_account_name, container_name) {
  return new Promise<boolean>((resolve, reject) => {
      client.blobContainers.get(resource_group_name,
                                 storage_account_name,
                                 container_name,
                                 {},
                                 (error, result, request, response) => {

          let exists: boolean;

          if (!error) {
              exists = true
          } else {
              if (error.message.startsWith("The specified container does not")) {
                  exists = false
              } else {
                  return reject(sprintf("Failed to return list of storage account containers: %s", Utils.getError(error)))
              }
          }

          resolve(exists)
      })
  })
}

// Main -------------------------------------------------------------------

// Set the application root so that configuration files can be located
let app_root = path.resolve(__dirname, "..");
let deploy_config_file = path.join(app_root, "deploy.json");

// Configure the script
program.version('0.0.1')
       .description('Helper script to perform a deployment of the built templates')
       .option('-c, --config [config]', 'Configuration file to use', deploy_config_file);

// Add command to upload the files to blob storage
program.command('upload <subscription>')
       .description('Upload files to blob storage. Storage account and container are taken from configuration or overridden with options')
       .option('-s, --saname [name]', 'Storage account name')
       .option('-n, --container [container]', 'Name of container within specified storage')
       .option('-a, --authfile [authfilename]', 'Path to Azure credentials file', path.join(os.homedir(), '.azure', 'credentials'))
       .option('-G, --groupname [sagroupname]', 'Name of the resource group that contains the storage account')
       .action(function (subscription, options) {
          upload(parseConfig(app_root, program.config, options, "upload"), subscription)
       });

// Add command to manage resource group and deploy the template
program.command('deploy <subscription>')
       .description('Manage the specified resource group and then deploy the uploaded templates to it')
       .option('-l, --location [location]', 'Azure location that the template should be deployed to', 'eastus')
       .option('-s, --saname [name]', 'Storage account name')
       .option('-n, --container [container]', 'Name of container within specified storage')
       .option('-a, --authfile [authfilename]', 'Path to Azure credentials file', path.join(os.homedir(), '.azure', 'credentials'))
       .option('-g, --groupname [groupname]', 'Name of the resource group to deploy into')
       .option('-p, --parameters [parameters]', 'Path to the parameters file', path.join(app_root, "local", "parameters.json"))
       .action(function (subscription, options) {
          deploy(parseConfig(app_root, program.config, options, "deploy"), subscription)
       });

// Execute the program
program.parse(process.argv);