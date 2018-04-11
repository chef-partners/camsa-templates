# Azure Managed Chef Automate

This repository holds the Azure Resource Manager (ARM) and Azure Portal UI templates required to deploy the Azure Managed App version of Chef Automate.

## Process

The ARM template contains links back to this repository so that they can be referenced externally. This helps with the development and maintenance of the solution template. However the downside is that it if anything changes in the repo then there is the potential to break the published solution template. To get around this the template will only reference files in the `release` branch of the repo.

Th aim is to have tests around the infrastructure so and a pipeline so that any changes can be tested locally and against Azure _before_ they are promoted into the `release` branch which will then become live.

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

If you have multiple subscription IDs in your credentials file you will need to add the subscription_id you want to use to the end of the above command.

NOTE: If you have InSpec 2.x installed locally then you do not have to use the Docker image.

