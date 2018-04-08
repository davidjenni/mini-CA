#!/usr/bin/env bash
set -e

# from: https://stackoverflow.com/a/21189044
# $1:   yaml file
# $2:   prefix for env variables (optional)
# usage: eval $(parse_yaml sample.yml "CNF_")
function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

if [ -n $1 -a -s $1 ]; then
    eval $(parse_yaml $1 "CNF_")
fi

# lame param handling...
if [ -n $2 -a $2 = --dryrun ]; then
    AZ_VERB=validate
    VALIDATE=1
else
    AZ_VERB=create
    VALIDATE=0
fi

RG=${CNF_resourceGroup:="mini-CA"}
LOC=${CNF_location:="southcentralus"}
NAME=${CNF_name:="mini-CA"}
SUBSCRIPTION=$CNF_subscription
SSH_PORT=${CNF_ssh_port:="4410"}

if [ -s $CNF_ssh_keyfile ]; then
    echo "Must specify an entry 'ssh_keyfile' in the YAML file!" && exit 1
fi
SSH_KEY_FILE=${CNF_ssh_keyfile/\~/$HOME}
if [ ! -s $SSH_KEY_FILE ]; then
    echo "The required SSH public key file $SSH_KEY_FILE does not exist!" && exit 1
fi

if [ -z "$SUBSCRIPTION" ]; then
    echo "Must specify an Azure subscription (specified by its name or guid)!" && exit 1
fi
set -eu

az account show 1> /dev/null
if [ $? != 0 ]; then
	az login
fi
az account set --subscription "$SUBSCRIPTION"

RG_EXISTS=$(az group exists --name "$RG")
if [ "$RG_EXISTS" = "false" ]; then
    (az group create --name "$RG" --location "$LOC")
fi

GEN_DIR=build
[ -d $GEN_DIR ] || mkdir $GEN_DIR 2>/dev/null
PARAMS_FILE=${GEN_DIR}/ARM.params.gen.json

echo Generating parameters file $PARAMS_FILE...
# capture SSH public key file:
SSH_KEY_DATA=$(cat $SSH_KEY_FILE)

# generate the ARM parameters json file
# inject YAML config CNF_* values into the cloud-config file:
IGNITION=$( \
    sed -e "s|##sshPort##|${CNF_ssh_port}|g" cloud-config.yaml \
    | ct -platform azure | jq -c '.')
echo $IGNITION > $GEN_DIR/ignition.txt

jq -n -c --arg name "$NAME" --arg sshPort "$CNF_ssh_port" --arg sshKeyData "$SSH_KEY_DATA" --arg ignition "$IGNITION" \
    '{ "vmName": { "value": $name}, "cloudConfigIgnition": { "value": $ignition }, "sshPort": { "value": $sshPort }, "sshKeyData": { "value": $sshKeyData } }' > $PARAMS_FILE

if [ $VALIDATE = 1 ]; then
    echo DRYRUN, validating only.
else
    echo Creating VM $NAME in resource group "$RG"...
fi

az group deployment $AZ_VERB --resource-group "$RG" --template-file "CA-node.ARM.json" --parameters @$PARAMS_FILE
echo "Connect to VM with SSH:"
echo "  ssh core@$NAME.$LOC.cloudapp.azure.com -p $SSH_PORT -i $(dirname $SSH_KEY_FILE)/$(basename -s .pub $SSH_KEY_FILE)"
