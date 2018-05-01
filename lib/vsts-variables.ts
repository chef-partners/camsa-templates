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
 * Will result in two variables being emitted into VSTS, `name` and `team`.
 * The script can handle an object with a `value` element.
 * 
 * Optionally a prefix can be applied to the variable name using the `-p` option to the script.
 * 
 * The use case for this is to take the outputs from an ARM template deployment and make them
 * available in the rest of the build. To this end the `securestring` type is honoured when the
 * variables are submitted to VSTS.
 * 
 * It is assumed that the JSON object is contained within an environment variable the name
 * of which is passed to the script when run.
 * 
 */

// Import necessary libraries
import * as program from "commander";

let variable_name = "";
let is_secret = "false";

// Build up the command line that the script uses
program.version('0.0.1')
       .arguments('<variable>')
       .description('Read JSON string and output as VSTS variables')
       .option('-p, --prefix [prefix]', 'Add a prefix to the VSTS variables', '')
       .action(function (variable) {
           variable_name = variable;
       })
       .parse(process.argv);

// The script should have been passed the name of the variable from which
// to get the JSON object to convert. Parse this as JSON into a local variable
console.log('Value: %s', process.env[variable_name]);
process.exit();

let json_object = JSON.parse(process.env[variable_name]);

// Iterate around the JSON object and output the VSTS variables as required
let value = null;
for (var key in json_object) {

    // rset the value on each iteration
    value = null;
    is_secret = 'false';

    // determine the value of the key
    // this is handle the situation where the value maybe an object with a value inside
    if (typeof json_object[key] == 'object') {
        if ('value' in json_object[key]) {
            value = json_object[key].value;
        }

        // if the type is a securestring then set the secret flag to true
        if ('type' in json_object[key] && json_object[key]['type'] == 'securestring') {
            is_secret = 'true';
        }
    } else {
        value = json_object[key];
    }

    // output the variable to VSTS if there is a value
    if (value == null) {
        console.log('##vso[task.logissue type=warning]Variable "%s" does not have a value', key);
    } else {
        console.log('##vso[task.setvariable variable=%s%s;issecret=%s]%s', program.prefix, key, is_secret, value);
    }
}
