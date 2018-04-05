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

(az group create --name "$RG" --location "$LOC")

echo Creating VM $NAME in resource group "$RG"...
(az vm create --name "$NAME" --resource-group "$RG" \
    $SSH_KEY_PARAM \
    --admin-username core --image CoreOS:CoreOS:Stable:latest \
    --size Standard_B1s --storage-sku Standard_LRS \
    --custom-data "$(ct -platform azure -in-file cloud-config.yaml)" )
