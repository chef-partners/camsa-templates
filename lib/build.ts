/**
 * Script to handle the build process for creating the Managed App zip file
 *
 * @author Russell Seymour
 */

// Libraries --------------------------------------------------------------
import * as program from "commander";
import {copySync, ensureDirSync, existsSync, readFileSync, statSync, unlinkSync, writeFileSync} from "fs-extra";
import {basename, isAbsolute, join as pathJoin, resolve} from "path";
import {sync as rimrafSync} from "rimraf";
import {sprintf} from "sprintf-js";
import * as zip from "zip-folder";

// Define constants for the keys in the buildConfig object
const dirsKey = "dirs";
const appRootKey = "appRoot";
const outputKey = "output";
const workingKey = "working";
const buildKey = "build";
const productionKey = "production";
const stagingKey = "staging";
const filesKey = "files";
const functionsKey = "functions";
const templateFileKey = "template_file";
const configKey = "config";
const codeKey = "code";
const codeFilesKey = "code_files";
const templateKey = "template";
const variablesKey = "variables";
const propertiesKey = "properties";
const resourcesKey = "resources";
const parametersKey = "parameters";
const baseUrlKey = "baseUrl";
const defaultValueKey = "defaultValue";
const outputsKey = "outputs";
const verifyURLApiKeyKey = "verifyURLApiKey";
const packageKey = "package";
const nameKey = "name";

// Functions --------------------------------------------------------------

function parseBuildConfig(appRoot, buildConfigFile, workDir = null) {
    let buildConfig = {};

    // Check if the build configuration file exists
    if (existsSync(buildConfigFile)) {
        // read in the configuration file so that it can be passed to operations
        buildConfig = JSON.parse(readFileSync(buildConfigFile, "utf8"));

        // iterate around the dirs and prepend the appRoot if it is not an absolute path
        Object.keys(buildConfig[dirsKey]).forEach((key) => {
            if (!isAbsolute(buildConfig[dirsKey][key])) {
                buildConfig[dirsKey][key] = pathJoin(appRoot, buildConfig[dirsKey][key]);
            }

            // add in the extra directories below the build dir
            buildConfig[dirsKey][appRootKey] = appRoot;
            buildConfig[dirsKey][outputKey] = pathJoin(buildConfig[dirsKey][buildKey], "output");
            buildConfig[dirsKey][workingKey] = {};

            // set the work directory based on whether it has been set in options
            if (workDir == null) {
                buildConfig[dirsKey][workingKey][productionKey] =
                    pathJoin(buildConfig[dirsKey][buildKey], "working", "production");
                buildConfig[dirsKey][workingKey][stagingKey] =
                    pathJoin(buildConfig[dirsKey][buildKey], "working", "staging");
            } else {
                if (!isAbsolute(workDir)) {
                    workDir = pathJoin(appRoot, workDir);
                }
                buildConfig[dirsKey][workingKey][productionKey] = pathJoin(workDir, "production");
                buildConfig[dirsKey][workingKey][stagingKey] = pathJoin(workDir, "staging");
            }
        });
    } else {
        console.log("##vso[task.logissue type=error]Build configuration file not found: %s", buildConfigFile);
    }

    return buildConfig;
}

function init(options, buildConfig) {

    console.log("Initialising build directory");

    // clean the build directory if the option to clean it has been specified and
    // the directory exists
    if (options.clean && existsSync(buildConfig[dirsKey][buildKey])) {
        console.log("Removing build directory");
        rimrafSync(buildConfig[dirsKey][buildKey]);
    }

    // create the necessary directories if they do not exist
    if (!existsSync(buildConfig[dirsKey][outputKey])) {
        console.log("Creating output directory: %s", buildConfig[dirsKey][outputKey]);
        ensureDirSync(buildConfig[dirsKey][outputKey]);
    }
    for (let dir of ["production", "staging"]) {
        if (!existsSync(buildConfig[dirsKey][workingKey][dir])) {
            console.log("Creating %s directory: %s", dir, buildConfig[dirsKey][workingKey][dir]);
            ensureDirSync(buildConfig[dirsKey][workingKey][dir]);
        }
    }
}

/**
 * Use the buildConfig files array to copy from the target into the working
 * directory.
 *
 * @param buildConfig
 */
function copy(buildConfig) {
    // initialize variables
    let source;
    let target;

    let sourceFileKey = "source";
    let targetFileKey = "target";

    // iterate around the files
    for (let file of buildConfig[filesKey]) {

        // get the source and target
        source = file[sourceFileKey];
        target = file[targetFileKey];

        // ensure each of them are based of the relevant path if they
        // are relative paths
        // the source is based off the appRoot
        // the target is based off the workingdir
        if (!isAbsolute(source)) {
            source = pathJoin(buildConfig[dirsKey][appRootKey], source);
        }
        if (!isAbsolute(target)) {
            target = pathJoin(buildConfig[dirsKey][workingKey][productionKey], target);
        }

        // is the source is a directory, ensure that the target dir exists
        if (statSync(source).isDirectory()) {
            ensureDirSync(target);
        }

        // if the source is a file, ensure that the target is as well
        // if it is a directory then append the source filename to the target
        if (statSync(source).isFile() && statSync(target).isDirectory()) {
            target = pathJoin(target, basename(source));
        }

        console.log("Copying: %s -> %s", source, target);

        // Perform the copy of the files
        copySync(source, target);
    }
}

function patch(options, buildConfig) {

    console.log("Patching template files with function code");

    let template;

    // iterate around the functions array
    for (let f of buildConfig[functionsKey]) {

        console.log("Patching File: %s", f[templateFileKey]);

        // determine the full path to the file that needs to be updated
        if (!isAbsolute(f[templateFileKey])) {
            f[templateFileKey] = pathJoin(buildConfig[dirsKey][workingKey][productionKey], f[templateFileKey]);
        }

        // determine the full path to the configuration file
        if (!isAbsolute(f[configKey])) {
            f[configKey] = pathJoin(buildConfig[dirsKey][appRootKey], f[configKey]);
        }

        // if the config file exists, read in the object
        if (existsSync(f[configKey])) {
            f[configKey] = JSON.parse(readFileSync(f[configKey], "utf8"));
        } else {
            console.log("##vso[task.issue type=error]Function configutation file cannot be found: %s", f[configKey]);
        }

        // work out the full path to the specified code_file if needed
        // and set the base64 encoded value of the file in the code array
        for (let name in f[codeFilesKey]) {
            if (f[codeFilesKey].hasOwnProperty(name)) {
                if (!isAbsolute(f[codeFilesKey][name])) {
                    f[codeFilesKey][name] = pathJoin(buildConfig[dirsKey][appRootKey], f[codeFilesKey][name]);
                }

                // set the base64 encoding of the file, if it exists
                if (existsSync(f[codeFilesKey][name])) {
                    f[codeFilesKey][name] = Buffer.from(readFileSync(f[codeFilesKey][name], "utf8")).toString("base64");
                } else {
                    console.log("##vso[task.issue type=error]Function file cannot be found: %s", f[codeFilesKey][name]);
                }
            }
        }

        // Read in the template file and patch the values as defined
        if (existsSync(f[templateFileKey])) {
            template = JSON.parse(readFileSync(f[templateFileKey], "utf8"));

            // patch the parts of the template
            template[variablesKey][codeKey] = f[codeFilesKey];
            template[resourcesKey][0][propertiesKey][configKey] = f[configKey];

            // save the file
            writeFileSync(f[templateFileKey], JSON.stringify(template, null, 4), "utf8");
        } else {
            console.log("##vso[task.issue type=error]Template file cannot be found: %s", f[templateFileKey]);
        }
    }

    // Patch the mainTemplate so that it has the correct BaseURl if it has been specified in options
    let mainTemplateFile = pathJoin(buildConfig[dirsKey][workingKey][productionKey], "mainTemplate.json");
    if (existsSync(mainTemplateFile)) {
        if (options.baseurl !== "") {
            console.log("Patching main template: %s", mainTemplateFile);

            let mainTemplate = JSON.parse(readFileSync(mainTemplateFile, "utf8"));

            // patch the default value for the parameter
            mainTemplate[parametersKey][baseUrlKey][defaultValueKey] = options.baseurl;
            writeFileSync(mainTemplateFile, JSON.stringify(mainTemplate, null, 4), "utf8");
        }
    } else {
        console.log("##vso[task.issue type=error]Unable to find main template: %s", mainTemplateFile);
    }

    // Patch the createUIDefinition.json file with the API key for the verifyurl
    let uiDefinitionFile = pathJoin(buildConfig[dirsKey][workingKey][productionKey], "createUiDefinition.json");
    if (existsSync(uiDefinitionFile) && process.env.VERIFY_URL_API_KEY) {
        console.log("Patching createUIDefinition.json with API key");
        let uiDefinition = JSON.parse(readFileSync(uiDefinitionFile, "utf8"));

        // patch the parameter value
        uiDefinition[parametersKey][outputsKey][verifyURLApiKeyKey] = process.env.VERIFY_URL_API_KEY;
        writeFileSync(uiDefinitionFile, JSON.stringify(uiDefinition, null, 4), "utf8");
    }
}

function createStaging(options, buildConfig) {
    console.log("Creating staging files");

    // copy the contents of the production directory to staging
    copySync(buildConfig[dirsKey][workingKey][productionKey], buildConfig[dirsKey][workingKey][stagingKey]);

    // patch the mainTemplate with the staging URL
    let mainTemplateFile = pathJoin(buildConfig[dirsKey][workingKey][stagingKey], "mainTemplate.json");
    if (existsSync(mainTemplateFile)) {
        if (options.url !== "") {
            console.log("Patching main template: %s", mainTemplateFile);

            let mainTemplate = JSON.parse(readFileSync(mainTemplateFile, "utf8"));

            // patch the default value for the parameter
            mainTemplate[parametersKey][baseUrlKey][defaultValueKey] = options.url;
            writeFileSync(mainTemplateFile, JSON.stringify(mainTemplate, null, 4), "utf8");
        }
    } else {
        console.log("##vso[task.issue type=error]Unable to find main template: %s", mainTemplateFile);
    }
}

function packageFiles(options, buildConfig) {
    console.log("Packaging files");

    // determine if a nightly flag needs to be added to the zip file
    let flag = "";
    if (process.env.BUILD_REASON) {
        if (process.env.BUILD_REASON.toLocaleLowerCase() === "schedule") {
            flag = "-nightly";
        }
    }

    // add the branch that this has been built from to the filename
    let branch = "local";
    if (process.env.BUILD_SOURCEBRANCHNAME) {
        branch = process.env.BUILD_SOURCEBRANCHNAME.toLocaleLowerCase();
    }

    // iterate around the production and staging directories
    Object.keys(buildConfig[dirsKey][workingKey]).forEach((key) => {

        // determine the filename for the zip
        let zipFilename = sprintf("%s-%s%s-%s-%s.zip",
            buildConfig[packageKey][nameKey], options.version, flag, branch, key);
        let zipFilepath = pathJoin(buildConfig[dirsKey][outputKey], zipFilename);

        // zip up the files
        zip(buildConfig[dirsKey][workingKey][key], zipFilepath, (err) => {
            if (err) {
                console.log("##vso[task.logissue type=error]Packaging Failed: %s", err);
            } else {
                console.log("Packaging Successful: %s", zipFilename);

                // set a variable as the path to the zip_file, this can then be used in subsequent
                // tasks to add the zip to the artefacts
                console.log("##vso[task.setvariable variable=%s]%s", options.outputvar, zipFilepath);

                // remove the createUIdefinition file from the working dir as this will be uploaded to
                // blob storage and the API key should not be visible
                let uiDefinitionFile = pathJoin(buildConfig[dirsKey][workingKey][key], "createUiDefinition.json");
                if (existsSync(uiDefinitionFile)) {
                    console.log("Removing UI definition file: ", uiDefinitionFile);
                    unlinkSync(uiDefinitionFile);
                }
            }
        });
    });
}

// Main -------------------------------------------------------------------

// Set the application root so that files can be found
let programAppRoot = resolve(__dirname, "..");
let programBuildConfigFile = pathJoin(programAppRoot, "build.json");

// Setup the way the script operates
program.version("0.0.1")
       .description("Packaging process for Azure Managed App for Chef Automate")
       .option("-c, --config [config]", "Configuration file to use", programBuildConfigFile);

// Add command to initialise the build
program.command("init")
       .description("Initialise the build")
       .option("--clean", "Optionally remove the build directory if it already exists", true)
       .action((options) => {
           init(options, parseBuildConfig(programAppRoot, program.config));
       });

// Copy files into the correct location
program.command("copy")
       .description("Copy files into the working directory that are required")
       .action(() => {
           copy(parseBuildConfig(programAppRoot, program.config));
       });

// Patch files with function definitions
program.command("patch")
       .description("Patch the output files with functions")
       .option("-b, --baseurl [base_url]", "Base URL from which the nested templates can be found", "")
       .option("-d, --directory [directory]", "Directory which contains the files to patch", null)
       .action((options) => {
           patch(options, parseBuildConfig(programAppRoot, program.config, options.directory));
       });

// Create the staging directory
program.command("staging")
       .description("Create staging version of the templates")
       .option("-u, --url [staging_url]", "Base URL from which the staging files can be located")
       .action((options) => {
           createStaging(options, parseBuildConfig(programAppRoot, program.config, options.directory));
       });

// Package up the files into a zip file
program.command("package")
       .option("-v, --version <version>", "Version to be applied to the zip file", "0.0.1")
       .option("--outputvar [variable_name]", "Name of the variable to output the filename to in VSTS", "AMA_ZIP_PATH")
       .action((options) => {
           packageFiles(options, parseBuildConfig(programAppRoot, program.config));
       })
       .description("Package up the files into a zip file for deployment");

// Command to run all the stages in one go
program.command("run")
       .option("-b, --baseurl <base_url>", "Base URL from which the nested templates can be found", "")
       .option("-u, --url <staging_url>", "Base URL for the staging files")
       .option("-v, --version <version>", "Version to be applied to the zip file", "0.0.1")
       .option("--outputvar <variable_name>", "Name of the variable to output the filename to in VSTS", "AMA_ZIP_PATH")
       .option("--clean", "Optionally remove the build directory if it already exists", true)
       .action((options) => {
           let buildConfig = parseBuildConfig(programAppRoot, program.config);
           init(options, buildConfig);
           copy(buildConfig);
           patch(options, buildConfig);
           createStaging(options, buildConfig);
           packageFiles(options, buildConfig);
       });

program.parse(process.argv);
