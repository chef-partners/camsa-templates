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
import {existsSync, lstatSync, readdirSync, readFileSync, writeFileSync} from "fs-extra";
import {parse as iniParse} from "ini";
import {ApplicationTokenCredentials} from "ms-rest-azure";
import {homedir} from "os";
import {isAbsolute, join as pathJoin, resolve} from "path";
import {sprintf} from "sprintf-js";

import {ResourceManagementClient} from "azure-arm-resource";
import {StorageManagementClient} from "azure-arm-storage";
import {createBlobService} from "azure-storage";

import {Utils} from "./Utils";

// Define constants for the keys in the configuration arrays
const dirsKey = "dirs";
const workingKey = "working";
const resourceGroupKey = "resourceGroup";
const resourceGroupNameKey = "name";
const storageAccountKey = "storageAccount";
const storageAccountNameKey = "name";
const parametersFileKey = "parametersFile";
const containerNameKey = "container";
const controlFileKey = "controlFile";
const groupNameKey = "groupName";
const optionsKey = "options";
const authFileKey = "authfile";
const iterationKey = "iteration";
const locationKey = "location";
const parametersKey = "parameters";

// Functions --------------------------------------------------------------

function parseConfig(appRoot, filepath, options, cmd) {
    let config = {};

    // determine if the deploy configuration file exists
    if (existsSync(filepath)) {
        // read in the configuration file
        config = JSON.parse(readFileSync(filepath, "utf8"));

        // iterate around the dirs and prepend the appRoot if it is not an absolute path
        Object.keys(config[dirsKey]).forEach((key) => {
            if (!isAbsolute(config[dirsKey][key])) {
                config[dirsKey][key] = pathJoin(appRoot, config[dirsKey][key]);
            }
        });

        // ensure that the resource group section exists
        if (!(resourceGroupKey in config)) {
            config[resourceGroupKey] = {};
        }

        if (!(resourceGroupNameKey in config[resourceGroupKey])) {
            config[resourceGroupKey][resourceGroupNameKey] = "";
        }

        if (!(locationKey in config[resourceGroupKey])) {
            config[resourceGroupKey][locationKey] = "";
        }

        if (!(parametersFileKey in config[resourceGroupKey])) {
            config[resourceGroupKey][parametersFileKey] = "";
        }

        // determine if a storage_account section exists
        if (!(storageAccountKey in config)) {
            config[storageAccountKey] = {};
        }

        // esnure that the children of the storage_account exists
        if (!(storageAccountNameKey in config[storageAccountKey])) {
            config[storageAccountKey][storageAccountNameKey] = "";
        }

        if (!(containerNameKey in config[storageAccountKey])) {
            config[storageAccountKey][containerNameKey] = "";
        }

        if (!(resourceGroupKey in config[storageAccountKey])) {
            config[storageAccountKey][resourceGroupKey] = "";
        }

        // determine if the options for these values have been set, if they
        // have then overwrite the values that have come from the configuration file
        if (options.saname) {
            config[storageAccountKey][storageAccountNameKey] = options.saname;
        }

        if (options.container) {
            config[storageAccountKey][containerNameKey] = options.container;
        }

        if (options.sagroupname) {
            config[storageAccountKey][groupNameKey] = options.sagroupname;
        }

        if (options.groupname) {
            config[resourceGroupKey][resourceGroupNameKey] = options.groupname;
        }

        if (options.location) {
            config[resourceGroupKey][locationKey] = options.location;
        }

        if (options.parameters) {
            config[resourceGroupKey][parametersFileKey] = options.parameters;
        }

        // perform some validation checks
        let validationErrors = [];
        if (cmd === "upload") {
            if (config[storageAccountKey][storageAccountNameKey] === "") {
                validationErrors.push("Storage account name has not been specified. Use -s or --saname or set in the configuration file");
            }

            if (config[storageAccountKey][containerNameKey] === "") {
                validationErrors.push("Container name must be specified. Use -n or --container or set in the configuration file");
            }
        }

        // if there are validation errors write them out
        if (validationErrors.length > 0) {
            console.log(sprintf("Errors have been detected: %s", validationErrors.length));
            for (let message of validationErrors) {
                console.log(sprintf(" - %s", message));
            }
            process.exit(1);
        }

    } else {
        console.log("Deploy configuration file not found: %s", filepath);
        process.exit(2);
    }

    // add the command line options to the config
    config[optionsKey] = options;

    // configure the locale deployment file
    config[controlFileKey] = pathJoin(appRoot, ".deploy");
    if (!existsSync(config[controlFileKey])) {

        // set the content of the controlFile, as it does not exist, with an iteration
        // value of 1
        // The iteration is used to track what the resource group that was created on this deployment
        // It is used to delete that resource group on the next deployment and then increment the iteration to create
        // the new resource group
        // This is to speed up the deployments as much as possible by not having to wait for the resource group
        // to deploy before a new deployment can be done.
        let content = sprintf("{\"%s\": {\"%s\": 1}}", config[resourceGroupKey][resourceGroupNameKey], iterationKey);

        // write out the file
        writeFileSync(config[controlFileKey], content, "utf8");
    }

    return config;
}

async function upload(config, subscription) {

    // create the necessary storage client
    let smClient = get_client(config[optionsKey][authFileKey], subscription, "storage");
    let rmClient = get_client(config[optionsKey][authFileKey], subscription, "resource");

    // Perform some checks to ensure that all necessary resources exist
    // - resource group
    let rgExists = await rmClient.resourceGroups.checkExistence(config[storageAccountKey][groupNameKey]);
    // - storage account
    let saExists = await checkStorageAccountExists(smClient, config[storageAccountKey][storageAccountNameKey]);
    // - container
    let containerExists = await checkContainerExists(smClient, config[storageAccountKey][groupNameKey], config[storageAccountKey][storageAccountNameKey], config[storageAccountKey][containerNameKey]);

    // determine if the credentials file can be located
    if (rgExists && saExists && containerExists) {

        // create blob service so that files can be uploaded
        let sakeys = await smClient.storageAccounts.listKeys(config[storageAccountKey][groupNameKey], config[storageAccountKey][storageAccountNameKey], {});
        let blobService = createBlobService(config[storageAccountKey][storageAccountNameKey], sakeys.keys[0].value);

        // get all the files in the specified directory to be uploaded
        let items = listdir(config[dirsKey][workingKey]);

        // iterate around all the files
        let stats;
        let name;
        for (let item of items) {

            // continue onto the next item if this is is a directory
            stats = lstatSync(item);
            if (stats.isDirectory()) {
                continue;
            }

            // the item is a file
            name = item.replace(/\\/g, "/");

            // create the correct name for the blob
            let stringToCheck = config[dirsKey][workingKey].replace(/\\/g, "/");
            if (stringToCheck.endsWith("/") === false) {
                stringToCheck += "/";
            }
            name = name.replace(stringToCheck, "");

            // upload the item
            blobService.createBlockBlobFromLocalFile(config[storageAccountKey][containerNameKey], name, item, {}, (error, result) => {
                if (error) {
                    console.log("FAILED to upload: %s", getError(error));
                } else {
                    console.log("SUCCESS upload file: %s", item);
                }
            });
        }

    } else {
        console.error("Resource Group \"%s\" exists: %s", config[storageAccountKey][groupNameKey], rgExists);
        console.error("Storage Account \"%s\" exists: %s", config[storageAccountKey][storageAccountNameKey], saExists);
        console.error("Container \"%s\" exists: %s", config[storageAccountKey][containerNameKey], containerExists);
        console.error("Errors have occurred, please ensure that all the above resources exist");
        process.exit(4);
    }
}

async function deploy(config, subscription) {

    // read the local control file to determine the name of the resource group
    // to delete and then create
    let deploySettings = JSON.parse(readFileSync(config[controlFileKey], "utf8"));
    if (!(config[resourceGroupKey][resourceGroupNameKey] in deploySettings)) {
        deploySettings[config[resourceGroupKey][name]] = {iterationKey: 0};
    }

    // determine the name of the resource group to delete
    let rgNameExisting = sprintf("%s-%s", config[resourceGroupKey][resourceGroupNameKey], deploySettings[config[resourceGroupKey][resourceGroupNameKey]][iterationKey]);

    // create the necessary resource manager client
    let rmClient = get_client(config[optionsKey][authFileKey], subscription, "resource");

    // determine if the rg exists
    if (rmClient !== false) {
        console.log("Resource Group: %s", rgNameExisting);

        let exists = await new Promise<boolean>((resolve, reject) => {
            rmClient.resourceGroups.checkExistence(rgNameExisting, (error, exists) => {
                if (error) {
                    return reject(sprintf("Failed to check the resource group status. Error: %s", Utils.getError(error)));
                }
                resolve(exists);
            });
        });

        if (exists) {
            console.log("\texists, deleting");

            let deleteStatus = new Promise<void> ((resolve, reject) => {
                rmClient.resourceGroups.deleteMethod(rgNameExisting, (error) => {
                    if (error) {
                        return reject(sprintf("Failed to delete the resource group. Error: %s", Utils.getError(error)));
                    }
                    resolve();
                });
            });

        } else {
            console.log("\tdoes not exist");
        }

        // determine the next iteration and therefore the name of the new RG
        deploySettings[config[resourceGroupKey][resourceGroupNameKey]][iterationKey] += 1;
        let rgName = sprintf("%s-%s", config[resourceGroupKey][resourceGroupNameKey], deploySettings[config[resourceGroupKey][resourceGroupNameKey]][iterationKey]);

        // write out the new iteration to the deployment file
        writeFileSync(config[controlFileKey], JSON.stringify(deploySettings), "utf8");

        // create the rg
        console.log("Creating Resource Group: %s", rgName);
        console.log("\tLocation: %s", config[resourceGroupKey][locationKey]);

        await new Promise<void> ((resolve, reject) => {
            // define the parameters for the new RG
            let parameters = {
                location: config[optionsKey][locationKey],
                name: rgName,
            };

            rmClient.resourceGroups.createOrUpdate(rgName, parameters, (error) => {
                if (error) {
                    return reject(sprintf("Failed to create the resource group. Error: %s", Utils.getError(error)));
                }
                resolve();
            });
        });

        // perform the deployment of the template and parameters
        // read in the parameters file
        let templateParameters;
        console.log("Reading parameters file: %s", config[resourceGroupKey][parametersFileKey]);
        if (existsSync(config[resourceGroupKey][parametersFileKey])) {
            templateParameters = JSON.parse(readFileSync(config[resourceGroupKey][parametersFileKey], "utf8"));
        } else {
            console.error("\tcannot find file");
            process.exit(3);
        }

        // determine the template-uri
        let templateUri = sprintf("https://%s.blob.core.windows.net/%s/mainTemplate.json", config[storageAccountKey][storageAccountNameKey], config[storageAccountKey][containerNameKey]);

        console.log("Deploying template: %s", templateUri);

        // create the deployment parameters
        let deploymentParemeters = {
            properties: {
                mode: "Incremental",
                parameters: templateParameters[parametersKey],
                templateLink: {
                    uri: templateUri,
                },
            },
        };

        // create a deployment name
        let dateNow = new Date().toISOString().replace(/-|T.*/g, "");
        let deploymentName = sprintf("%s-%s", rgName.toLocaleLowerCase(), dateNow);

        await new Promise<void> ((resolve, reject) => {
            rmClient.deployments.createOrUpdate(rgName, deploymentName, deploymentParemeters, (error) => {
                if (error) {
                    return reject(sprintf("Failed to deploy the template. Error: %s", Utils.getError(error)));
                }
                resolve();
            })
        });
    }
}

function get_client(authfile, subscription, type) {

    // define the client to return
    let client;

    if (existsSync(authfile)) {

        // read in the configuration file
        let credentials = iniParse(readFileSync(authfile, "utf-8"));

        // ensure that the specified subscription can be found in the file
        if (subscription in credentials) {

            // get the required settings from the credentials file
            let clientId = credentials[subscription].client_id;
            let clientSecret = credentials[subscription].client_secret;
            let tenantId = credentials[subscription].tenant_id;

            // create token credentials with access to Azure
            let azureTokenCreds = new ApplicationTokenCredentials(clientId, tenantId, clientSecret);

            // create the necessary storage client
            if (type === "storage") {
                client = new StorageManagementClient(azureTokenCreds, subscription);
            } else if (type === "resource") {
                client = new ResourceManagementClient(azureTokenCreds, subscription);
            } else {
                client = false;
            }
        } else {
            console.log("Unable to find subscription \"%s\" in auth file: %s", subscription, authfile);
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
        return JSON.stringify(error.message);
    }

    return JSON.stringify(error);
}

async function checkStorageAccountExists(client, storageAccountName) {
    return new Promise<boolean>((resolve, reject) => {

        client.storageAccounts.checkNameAvailability(storageAccountName,
                                                    (error, exists, request, response) => {
            if (error) {
                if (this.taskParameters.isDev) {
                    console.log(Utils.getError(error));
                }
            }
            resolve(!exists.nameAvailable);
        });
    });
}

async function checkContainerExists(client, resourceGroupName, storageAccountName, containerName) {
    return new Promise<boolean>((resolve, reject) => {
        client.blobContainers.get(resourceGroupName,
                                 storageAccountName,
                                 containerName,
                                 {},
                                 (error, result, request, response) => {

            let exists: boolean;

            if (!error) {
                exists = true;
            } else {
                if (error.message.startsWith("The specified container does not")) {
                    exists = false;
                } else {
                    return reject(sprintf("Failed to return list of storage account containers: %s", Utils.getError(error)));
                }
            }

            resolve(exists);
        });
    });
}

function listdir(path) {
    let list = [];
    let files = readdirSync(path);
    let stats;

    files.forEach((file) => {
        stats = lstatSync(pathJoin(path, file));
        if (stats.isDirectory()) {
            list = list.concat(listdir(pathJoin(path, file)));
        } else {
            list.push(pathJoin(path, file));
        }
    });

    return list;
}

// Main -------------------------------------------------------------------

// Set the application root so that configuration files can be located
let programAppRoot = resolve(__dirname, "..");
let programDeployConfigFile = pathJoin(programAppRoot, "deploy.json");

// Configure the script
program.version("0.0.1")
       .description("Helper script to perform a deployment of the built templates")
       .option("-c, --config [config]", "Configuration file to use", programDeployConfigFile);

// Add command to upload the files to blob storage
program.command("upload <subscription>")
       .description("Upload files to blob storage. Storage account and container are taken from configuration or overridden with options")
       .option("-s, --saname [name]", "Storage account name")
       .option("-n, --container [container]", "Name of container within specified storage")
       .option("-a, --authfile [authfilename]", "Path to Azure credentials file", pathJoin(homedir(), ".azure", "credentials"))
       .option("-G, --groupname [sagroupname]", "Name of the resource group that contains the storage account")
       .action((subscription, options) => {
           upload(parseConfig(programAppRoot, program.config, options, "upload"), subscription);
       });

// Add command to manage resource group and deploy the template
program.command("deploy <subscription>")
       .description("Manage the specified resource group and then deploy the uploaded templates to it")
       .option("-l, --location [location]", "Azure location that the template should be deployed to", "eastus")
       .option("-s, --saname [name]", "Storage account name")
       .option("-n, --container [container]", "Name of container within specified storage")
       .option("-a, --authfile [authfilename]", "Path to Azure credentials file", pathJoin(homedir(), ".azure", "credentials"))
       .option("-g, --groupname [groupname]", "Name of the resource group to deploy into")
       .option("-p, --parameters [parameters]", "Path to the parameters file", pathJoin(programAppRoot, "local", "parameters.json"))
       .action((subscription, options) => {
           deploy(parseConfig(programAppRoot, program.config, options, "deploy"), subscription);
       });

// Execute the program
program.parse(process.argv);
