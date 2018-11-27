# Domain Names

In order to support different scenarios that customers have, it is possible to specify a custom domain and and hostnames for the machines that are built as a result of these templates.

There are three patterns that are supported:

1. No custom domain name and is not a Managed App

In this case the servers will have a fully qualified domain name (FQDN) based on the prefix, server type, unique string and the domain for the region in Azure that was set. For example

```
Prefix: rjs
Server Type: chef
Unique String: fg6t
Azure Region: eastus

FQDN: rjs-chef-fg6t.eastus.cloudapp.azure.com
```

2. Managed App and no custom domain

Here the Managed App domain is `managedautomate.io` and the machines will be named accordingly.

```
Prefix: rjs
Server Type: chef
Unique String: fg6t

FQDN: rjs-chef-fg6t.managedautomate.io
```

3. Custom Domain Name

The final scenario allows complete customisation of the server hostnames and the domain that that they are configured with. Three parameters are required to be set `customDomainName`, `customChefServerHostname` and `customAutomateServerHostname`.

```
customChefServerHostname: mycorpchef
customDomainName: corp.com

FQDN: mycorpchef.corp.com

```