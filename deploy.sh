#!/usr/bin/env bash
set -eu

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

RG=${CNF_resourceGroup:="test-CA"}
LOC=${CNF_location:="southcentralus"}
NAME=${CNF_name:="my-CA"}
if [ -n $CNF_ssh_keyfile ]; then
    SSH_KEY_PARAM="--ssh-key-value $CNF_ssh_keyfile"
else
    SSH_KEY_PARAM=--generate-ssh-keys
fi

az account show 1> /dev/null
if [ $? != 0 ]; then
	az login
fi

RG_EXISTS=$(az group exists --name "$RG")
if [ "$RG_EXISTS" == "true" ]; then
    echo "Resource group '$RG' already exists, chose a different and not yet existing group name" && exit 1
fi
(az group create --name "$RG" --location "$LOC")

GEN_DIR=build
[ -d $GEN_DIR ] || mkdir $GEN_DIR 2>/dev/null
PARAMS_FILE=${GEN_DIR}/ARM.params.gen.json

echo Generating parameters file $PARAMS_FILE...
# capture SSH public key file:
SSH_KEY_DATA=$(cat ${CNF_ssh_keyfile/\~/$HOME})

# inject YAML config files into the cloud-config file:
sed -e "s|##sshPort##|${CNF_ssh_port}|g" \
    cloud-config.yaml > ${GEN_DIR}/cloud-config.yaml

# generate the ARM parameters json file
IGNITION=$(ct -platform azure -in-file ${GEN_DIR}/cloud-config.yaml | jq '. | tojson')
jq -n -c --arg name "$NAME" --arg sshPort "$CNF_ssh_port" --arg sshKeyData "$SSH_KEY_DATA" --arg ignition "$IGNITION" \
    '{ "vmName": { "value": $name}, "cloudConfigIgnition": { "value": $ignition }, "sshPort": { "value": $sshPort }, "sshKeyData": { "value": $sshKeyData } }' > $PARAMS_FILE

echo Creating VM $NAME in resource group "$RG"...
(az group deployment create --resource-group "$RG" --template-file "CA-node.ARM.json" --parameters @$PARAMS_FILE )
exit $?
