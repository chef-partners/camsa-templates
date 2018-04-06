# Azure Managed Chef Automate

This repository holds the Azure Resource Manager (ARM) and Azure Portal UI templates required to deploy the Azure Managed App version of Chef Automate.

## Process

The ARM template contains links back to this repository so that they can be referenced externally. This helps with the development and maintenance of the solution template. However the downside is that it if anything changes in the repo then there is the potential to break the published solution template. To get around this the template will only reference files in the `release` branch of the repo.

Th aim is to have tests around the infrastructure so and a pipeline so that any changes can be tested locally and against Azure _before_ they are promoted into the `release` branch which will then become live.