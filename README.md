# Azure Managed Chef Automate

This repository holds the Azure Resource Manager (ARM) and Azure Portal UI templates required to deploy the Azure Managed App version of Chef Automate.

## Process

The ARM template contains links back to this repository so that they can be referenced externally. This helps with the development and maintenance of the solution template. However the downside is that it if anything changes in the repo then there is the potential to break the published solution template. To get around this the template will only reference files in the `release` branch of the repo.

Th aim is to have tests around the infrastructure so and a pipeline so that any changes can be tested locally and against Azure _before_ they are promoted into the `release` branch which will then become live.

## Build Process

The build process has been written as a set of NodeJS tasks. The scripts themselves have been written in TypeScript which are then transpiled to JavaScript as part of the build process (very meta).
The end result of the build is that a single zip file containing all the templates required by the managed app will be produced. This zip file is versioned.

## Installing Dependencies

As mentioned the build process is based on NodeJS, which means NodeJS has to be installed. Once that is done then the following command will install the necessary dependencies for the scripts:

```
npm install
```

## Configuration

The configuration for the build is set in the `build.json` file which is in the root of the repository.

The root of the repo is referred to as `app_root` within the build process.

This file describes to the build process where working and output directories and the functions that need to be added to the templates.

| Parameter | Purpose |
|----|----|
| `dirs.build` | Where the build directory is located. If it is not an absolute path it will be assumed to be in the root of the repo |
| `files` | An array of objects describing the files that need to be copied to the working directory for packaging |
| `package.name` | The name of the zip file to create. The version number is appended to the this name |
| `functions` | This is an array of objects that describe the functions that need to be patched into the template files |

The `dirs.build` directory will have `working` and `output` created beneath it when the step `init` is called.

### files

The `files` section is an array of objects that contain the source and target destinations.

| Parameter | Purpose |
|---|---|
| `source` | The source file or directory that needs to be copied |
| `target` | The target destination for the files |

If the `source` is not an absolute path then it is prepended with the `app_root`.
If the `target` is not an absolute path it is prepended with the `dirs.build.workdir` value.

### functions

The `functions` section is an array of objects that contain details about the functions that need to be added to the templates.

| Parameter | Purpose |
|---|---|
| `template_file` | The file that needs to be patched with the functions. If this is not an absolute path the `dirs.build.workdir` value is prepended to it |
| `config` | The configuration file for the function which contains the bindings for the Azure Function. If this is not an absolute path then `app_root` is prepended to it |
| `code_files` | This is a simple name key object that states the name of the code file (as is set in the target template) and the value which is the path to the function file. If this function file is not an absolute path then it will have `app_root` prepended to it |

The `config` and `code` will be replace any value that is already in the template file.

NOTE: All patching is done on the copy of the templates that are in the working directory.

## Build Steps

There are a number of build steps in the process and some of them have options that can be passed. The following shows these steps and the options that can be provided.

NOTE: When an option is specified a value is required.

### Initialising the build

Command: `node bin/build.js init`
NPM: `npm run build:init`

This will delete the existing build directory and create it again ready for the new files.

### Copying the files

Command: `node bin/build.js copy`
NPM: `npm run build:copy`

This will copy all the template files into the `working` directory as specified in the `build.json` file.

### Patch files

Command: `node bin/build.js patch`
NPM: `npm run build:patch`

| Options | Description |
|---|---|
| `-b` or `--baseurl` | The BaseURL from which nested templates can be found |

There are a number of Azure Functions that are deployed with this template and these are held in source control. However to get them to deploy into Azure they need to be added to the templates as Base64 strings.

The `build.json` contains a list of the functions, the template that it applies to and the files that make up thet function. It will then patch the template with the Base64 representation of the contents of the file.

NOTE: All patching is done on the copy of the templates that are in the working directory.

### Package Files

Command: `node bin/build.js package`
NPM: `npm run build:package`

| Options | Description |
|---|---|
| `-v` or `--version` | The version number to be applied to the ZIP file |
| `--outputvar` | The name of the variable to create in VSTS that points to the resultant zip fie. This is so that VSTS can find the file for upload to Artefacts |

This step creates a zip file of all the files in the working directory and places the file in the output directory.

### All in One

Command: `node bin/build.js run`
NPM: `npm run build:run`

| Options | Description |
|---|---|
| `-v` or `--version` | The version number to be applied to the ZIP file |
| `--outputvar` | The name of the variable to create in VSTS that points to the resultant zip fie. This is so that VSTS can find the file for upload to Artefacts |
| `-b` or `--baseurl` | The BaseURL from which nested templates can be found |

This is an all in one step that performs all of the steps that have been described above.


## Integration Tests

_This is very simple information at the moment - more detailed info will be added_

As the template in this repo is designed to spin up a Chef and Automate server that will be supported by Chef and used by the customer, a number of tests have been written.

These tests are InSpec tests and are developed for the Azure plugin which is available in InSpec 2.0

A number of Thor tasks have been created that assist with the building and, eventually, the execution of the tests.

```
thor integration:deploy   # Deploy the ARM template for testing
thor integration:destroy  # Destroy the integration environment
```

In order to execute the tests a valid Service Principal Name (SPN) is required for Azure. The details of which should be added to the file `~/.azure/credentials`.

At the moment the easiest way to run the tests is to use Christoph's docker image, e.g.

```bash
docker run -it --rm -v .:/workdir -v ~/.azure:/root/.azure chrisrock/inspec-playground
```

Assuming you are in the project directory it will map the repo into the container at `/workdir` and also map you credentials directory into the root user so that the tasks can access the credentials for Azure.

Now the tests can be executed running the following:

```
inspec exec test/integration/very -t azure://
```

If you have multiple ssubscription IDs in your credentials file you will need to add the subscription_id you want to use to the end of the above command.

NOTE: If you have InSpec 2.x installed locally then you do not have to use the Docker image.

## Validation

The Azure command line tool has the ability to perform a validation test on the templates. This will check that parameter names are set and that links to other templates are correct. However even if this passes there is no guarantee that it will work in a deployment - this is because there are some things that are only referenced at runtime which may throw an error that the validation is unable to replicate.

If there are no errors then the response to the command is a JSON object which is the semi-rendered template.

```
az group deployment validate -g InSpec-AMA --parameters test/integration/build/parameters.json --template-file src/mainTemplate.json
```