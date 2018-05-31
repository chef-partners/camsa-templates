# Template Urls and SAS Keys

The `mainTemplate.json` has been designed to be flexible so that it can be called either using a 'uri' or a 'file'. In addition support for Azure Blob Storage has been added so that a SAS key can be supplied. This section illustrates how things work when calling the main template file as a file or a URI.

## Using a URI

Both the command line tool `az` and the PowerShell cmdlet `New-AzureRmResourceGroupDeployment` support the ability to pass the parent template file using a URL. This URL has to be publicly accessible or accessible with some sort of key.

When a template is deployed in this fashion extra information can be retrived in the template to get the base URL from which it was called, e.g.

If the template was called with `https://example.com/templates/mainTemplate.json` then the base URL will be `https://example.com/templates`. This is exposed in the template using the `deployment().properties.templateLink.uri` property.

The template uses the following rules to establish if it has been called using a URL and if so it will create the necessary base URL.

1. Does the `deployment().properties` have a `templateLink` property.
  - This is done using this expression `contains(deployment().properties, 'templateLink')`
2. If the result of 1 is true then create the base url
  - The expression for this is `uri(deployment().properties.templateLink.uri, '.')`

### Automatically getting Token

In the scenario where the files have been uploaded to a service that requires a key in order to access them, the template will attempt to detect it from the URl that it was called in. For example Azure Blob Storage SAS tokens are specified as a query string, e.g.

```
https://example.com/templates/mainTemplate.json?se=2018-05-15T17%3A00Z&sp=rl&sv=2017-07-29&sr=c&sig=aIR7TM3BBOhBDjgSseBgkyRy%2BGx/d0QkzMqVvoxJo%3D
```

NOTE: This is not a valid SAS token, but the format is accurate.

The following process is applied to finding the SAS token.

1. Split the result of `deployment().properties.templateLink.uri` string into an array using the `?` character as delimiter
2. If the resultant array in step 1 has two elements, return the second one as the SAS array
3. If only one element in the array then return ''

This is all done in in the variables section of the template, the following shows the variable being set with the above rules

```json
{
    "sasTokenFromDeployment": "[if(equals(length(split(deployment().properties.templateLink.uri, '?')), 2), last(split(deployment().properties.templateLink.uri, '?')), '')]",
}
```

## Using a File

If the `az` command or the `New-AzureRmResourceGroupDeployment` is called referencing a local file, the template still needs to be able to access the nested templates to perform the deployment. These should be accessible publicy or using a key.

To handle this situation a parameter is provided which should be set to state what the base url should be. The name of this parameter is `baseUrl`. This would be set in a parameters file.

So if all the files had been uploaded to `https://example.com/templates` then the parameter `baseUrl` would need to be set to this and run with the deployment. This will ensure that all the nested templates are correctly referenced.

### Specifying a token

In the similar situation to above, where files have been uploaded to Azure Blob storage, a parameter is available to allow the SAS token to be set. This parameter is called `azureStorageSASToken`.

This would be need to be set as a paremeter when the template is deployed. 

# Building up the URLs to the nested Templates

The query string is built up and then appended to the end of the URLs for the nested template files that need to be downloaded using the SAS key. There is a parameter in the template that permits the SAS token to be supplied as a parameter, this is the case then that is used instead of the one that has been dervied.

The varible `templateQueryString` is made up using the following rules.

1. Are both the derived SAS token and parameter SAS empty? If so return ''
2. If the parameter is empty but the `sasTokenFromDeployment` is not concatenate the `?` chracter with the value of `sasTokenFromParameter` so it is valid query string
3. If the `sasTokenFromDeployment` is empty but the parameter has been supplied return a concatenation of the `?` character and the parameter.