/**
 * Simple script to output the names and values of ALL environment variables
 */

 for (var key in process.env) {
     console.log('%s: %s', key, process.env[key])
 }