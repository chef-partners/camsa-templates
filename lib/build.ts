/**
 * Script to handle the build process for creating the Managed App zip file
 * 
 * @author Russell Seymour
 */

// Libraries --------------------------------------------------------------
import * as program from "commander";
import * as path from "path";
import * as fs from "fs-extra";
import * as rimraf from "rimraf";
import {sprintf} from "sprintf-js"
import * as zip from "zip-folder";

// Functions --------------------------------------------------------------

function parseBuildConfig(app_root, build_config_file) {
    let build_config = {};

    // Check if the build configuration file exists
    if (fs.existsSync(build_config_file)) {
        // read in the configuration file so that it can be passed to operations
        build_config = JSON.parse(fs.readFileSync(build_config_file, "utf8"));

            // iterate around the dirs and prepend the app_root if it is not an absolute path
            Object.keys(build_config["dirs"]).forEach(function (key) {
            if (!path.isAbsolute(build_config["dirs"][key])) {
                build_config["dirs"][key] = path.join(app_root, build_config["dirs"][key]);
            };

            // add in the extra directories below the build dir
            build_config["dirs"]["app_root"] = app_root;
            build_config["dirs"]["working"] = path.join(build_config["dirs"]["build"], "working");
            build_config["dirs"]["output"] = path.join(build_config["dirs"]["build"], "output");
        });
    } else {
        console.log("##vso[task.logissue type=error]Build configuration file not found: %s", build_config_file)
    }

    return build_config;
}

function init(options, build_config) {

    console.log("Initialising build directory");

    // clean the build directory if the option to clean it has been specified and
    // the directory exists
    if (options.parent.clean && fs.existsSync(build_config["dirs"]["build"])) {
        console.log("Removing build directory");
        rimraf.sync(build_config["dirs"]["build"]);
    }

    // create the necessary directories if they do not exist
    for (var dir of ['working', 'output']) {
        if (!fs.existsSync(build_config['dirs'][dir])) {
            console.log("Creating %s directory: %s", dir, build_config['dirs'][dir]);
            fs.ensureDirSync(build_config['dirs'][dir]);
        }
    }
}

/**
 * Use the build_config files array to copy from the target into the working
 * directory. 
 * 
 * @param build_config 
 */
function copy(build_config) {
    // initialize variables
    let source;
    let target;

    // iterate around the files
    for (var file of build_config["files"]) {
        
        // get the source and target
        source = file["source"];
        target = file["target"];

        // ensure each of them are based of the relevant path if they
        // are relative paths
        // the source is based off the app_root
        // the target is based off the workingdir
        if (!path.isAbsolute(source)) {
            source = path.join(build_config["dirs"]["app_root"], source);
        }
        if (!path.isAbsolute(target)) {
            target = path.join(build_config["dirs"]["working"], target);
        }

        // is the source is a directory, ensure that the target dir exists
        if (fs.statSync(source).isDirectory()) {
            fs.ensureDirSync(target);
        }

        // if the source is a file, ensure that the target is as well
        // if it is a directory then append the source filename to the target
        if (fs.statSync(source).isFile() && fs.statSync(target).isDirectory()) {
            target = path.join(target, path.basename(source));
        }

        console.log("Copying: %s -> %s", source, target);

        // Perform the copy of the files
        fs.copySync(source, target);
    }
}

function patch(options, build_config) {

    console.log("Patching template files with function code");

    let template;

    // iterate around the functions array
    for (var f of build_config["functions"]) {

        console.log("Patching File: %s", f["template_file"]);

        // determine the full path to the file that needs to be updated
        if (!path.isAbsolute(f["template_file"])) {
            f["template_file"] = path.join(build_config["dirs"]["working"], f["template_file"])
        }

        // determine the full path to the configuration file
        if (!path.isAbsolute(f["config"])) {
            f["config"] = path.join(build_config["dirs"]["app_root"], f["config"]);
        }

        // if the config file exists, read in the object
        if (fs.existsSync(f["config"])) {
            f["config"] = JSON.parse(fs.readFileSync(f["config"], 'utf8'));
        } else {
            console.log("##vso[task.issue type=error]Function configutation file cannot be found: %s", f["config"]);
        }

        // work out the full path to the specified code_file if needed
        // and set the base64 encoded value of the file in the code array
        for (var name in f["code_files"]) {
            if(!path.isAbsolute(f["code_files"][name])) {
                f["code_files"][name] = path.join(build_config["dirs"]["app_root"], f["code_files"][name]);
            }

            // set the base64 encoding of the file, if it exists
            if (fs.existsSync(f["code_files"][name])) {
                f["code_files"][name] = new Buffer(fs.readFileSync(f["code_files"][name], 'utf8')).toString('base64');
            } else {
                console.log("##vso[task.issue type=error]Function file cannot be found: %s", f["code_files"][name]);
            }
        }

        // Read in the template file and patch the values as defined
        if (fs.existsSync(f["template_file"])) {
            template = JSON.parse(fs.readFileSync(f["template_file"], 'utf8'));

            // patch the parts of the tempate
            template["variables"]["code"] = f["code_files"];
            template["resources"][0]["properties"]["config"] = f["config"];

            // save the file
            fs.writeFileSync(f["template_file"], JSON.stringify(template, null, 4), 'utf8');
        } else {
            console.log("##vso[task.issue type=error]Template file cannot be found: %s", f["template_file"]);
        }
    }

    // Patch the mainTemplate so that it has the correct BaseURl if it has been specified in options
    let main_template_file = path.join(build_config["dirs"]["working"], "mainTemplate.json");
    if (fs.existsSync(main_template_file)) {
        if (options.baseurl != "") {
            console.log("Patching main template: %s", main_template_file);

            let main_template = JSON.parse(fs.readFileSync(main_template_file, 'utf8'));

            // patch the default value for the parameter
            main_template["parameters"]["baseUrl"]["defaultValue"] = options.baseurl;
            fs.writeFileSync(main_template_file, JSON.stringify(main_template, null, 4), 'utf8');
        }
    } else {
        console.log("##vso[task.issue type=error]Unable to find main template: %s", main_template_file);
    }
}

function packageFiles(options, build_config) {
    console.log("Packaging files");

    // determine the filename for the zip
    let zip_filename = sprintf("%s-%s.zip", build_config["package"]["name"], options.version);
    let zip_filepath = path.join(build_config["dirs"]["output"], zip_filename);

    // zip up the files
    zip(build_config["dirs"]["working"], zip_filepath, function(err) {
        if (err) {
            console.log("##vso[task.logissue type=error]Packaging Failed: %s", err);
        } else {
            console.log("Packaging Successful: %s", zip_filename);

            // set a variable as the path to the zip_file, this can then be used in subsequent
            // tasks to add the zip to the artefacts
            console.log("##vso[task.setvariable variable=%s]%s", options.outputvar, zip_filepath);
        }
    })
}

// Main -------------------------------------------------------------------

// Set the application root so that files can be found
let app_root = path.resolve(__dirname, "..");
let build_config_file = path.join(app_root, "build.json");
let build_config;

// Setup the way the script operates
program.version('0.0.1')
       .description('Packaging process for Azure Managed App for Chef Automate')
       .option('-c, --config [config]', 'Configuration file to use', build_config_file);

// Add command to initialise the build
program.command("init")
       .description("Initialise the build")
       .option('--clean', 'Optionally remove the build directory if it already exists', true)
       .action(function (options) {
           init(options, parseBuildConfig(app_root, program.config))
       });

// Copy files into the correct location
program.command("copy")
       .description("Copy files into the working directory that are required")
       .action(function () {
           copy(parseBuildConfig(app_root, program.config));
       })

// Patch files with function definitions
program.command("patch")
       .description("Patch the output files with functions")
       .option("-b, --baseurl [base_url]", "Base URL from which the nested templates can be found", "")
       .action(function (options) {
           patch(options, parseBuildConfig(app_root, program.config));
       })

// Package up the files into a zip file
program.command("package")
       .option("-v, --version <version>", "Version to be applied to the zip file", "0.0.1")
       .option("--outputvar [variable_name]", "Name of the variable to output the filename to in VSTS", "AMA_ZIP_PATH")
       .action(function (options) {
           packageFiles(options, parseBuildConfig(app_root, program.config))
       })
       .description("Package up the files into a zip file for deployment")

program.parse(process.argv)







