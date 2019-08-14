/**
 * Script that reads in a JSON object and outputs the values within as VST variables
 *
 * For example the following JSON string
 *
 * {
 *    "name": "Russell",
 *    "team": {
 *       "value": "Partner Engineering"
 *    }
 * }
 *
 * Will result in two variables being emitted into Azure DevOps, `name` and `team`.
 * The script can handle an object with a `value` element.
 *
 * Optionally a prefix can be applied to the variable name using the `-p` option to the script.
 *
 * The use case for this is to take the outputs from an ARM template deployment and make them
 * available in the rest of the build. To this end the `securestring` type is honoured when the
 * variables are submitted to Azure DevOps.
 *
 * It is assumed that the JSON object is contained within an environment variable the name
 * of which is passed to the script when run.
 *
 */

// Import necessary libraries
import * as program from "commander";

const typeKey = "type";

let variableName = "";
let isSecret = "false";

// Build up the command line that the script uses
program.version("0.0.1")
       .arguments("<variable>")
       .description("Read JSON string and output as Azure DevOps variables")
       .option("-p, --prefix [prefix]", "Add a prefix to the Azure DevOps variables", "")
       .action((variable) => {
           variableName = variable;
       })
       .parse(process.argv);

// The script should have been passed the name of the variable from which
// to get the JSON object to convert. Parse this as JSON into a local variable
let jsonObject = JSON.parse(process.env[variableName]);

// Iterate around the JSON object and output the Azure DevOps variables as required
let value = null;
for (let key in jsonObject) {

    if (key != null) {

        // reset the value on each iteration
        value = null;
        isSecret = "false";

        // determine the value of the key
        // this is handle the situation where the value maybe an object with a value inside
        if (typeof jsonObject[key] === "object") {
            if ("value" in jsonObject[key]) {
                value = jsonObject[key].value;
            }

            // if the type is a securestring then set the secret flag to true
            if ("type" in jsonObject[key] && jsonObject[key][typeKey] === "securestring") {
                isSecret = "true";
            }
        } else {
            value = jsonObject[key];
        }

        // output the variable to Azure DevOps if there is a value
        if (value == null) {
            console.log("##vso[task.logissue type=warning]Variable \"%s\" does not have a value", key);
        } else {
            console.log("##vso[task.setvariable variable=%s%s;issecret=%s]%s", program.prefix, key, isSecret, value);
        }
    }
}
