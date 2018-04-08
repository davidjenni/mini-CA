# mini-ca

A private Certificate Authority (CA) "en miniature", deployed as a small VM on Azure.

## Usage

TBD

## Deployment

To deploy, the dev tools (below) need to be installed. Deployment is using an [Azure ARM template file](https://docs.microsoft.com/en-us/azure/templates/).

The deployment is configured using a simple [YAML file](https://github.com/davidjenni/mini-CA/blob/master/ca.yaml); in absence of this file, useful defaults are selected. To deploy, run the following command:

```bash
./deploy.sh ca.yaml
```

An optional second parameter `--dryrun` will do a validation of the config with Azure ARM, but without actually creating any resources. Note that an empty resource group will be created.

ARM template deployments are idempotent, so calling `deploy.sh` more than once without changing the YAML config, cloudconfig.yaml or CA-node.ARM.json will quickly run without changing any of the resources.

To delete the resource group and its resources, use the Azure CLI:

```bash
az group delete --name <group-name>
```

The ARM template also sets up boot diagnostics. This can help debugging if the VM will not boot up to the SSH prompt (e.g. when making changes to the cloudconfig.yaml file...). Use the [Serial Console](http://aka.ms/serialconsolehelp) to inspect the boot messages and to connect to an emergency console prompt. Don't ask how I know.

## Dev Environment

My environment is a MBP. The following tools are assumed to be installed:

``` bash
brew install azure-cli coreos-ct cfssl docker
```
