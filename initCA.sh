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

CA_DOMAIN=${CNF_ca_domain:="example.info"}
CA_COUNTRY=${CNF_ca_country:="US"}
CA_STATE=${CNF_ca_state:="SD"}

# create root-CA directory in user's home directory
MINICA_HOME=~/.miniCA
ROOT_CA_PATH=$MINICA_HOME/rootCA
CERTS_PATH=$MINICA_HOME/certs
CONFIG_PATH=$MINICA_HOME/config
if [ ! -d $MINICA_HOME ]; then
    echo "Creating $MINICA_HOME and making it readable for this user only..."
    mkdir -p $MINICA_HOME
    mkdir -p $CERTS_PATH
    mkdir -p $CONFIG_PATH
    for CONFIG_FILE in ca-config.json root-ca.json; do
        cat config/$CONFIG_FILE | sed \
            -e "s|##caDomain##|$CA_DOMAIN|g" \
            -e "s|##caCountry##|$CA_COUNTRY|g" \
            -e "s|##caState##|$CA_STATE|g" \
            > $CONFIG_PATH/$CONFIG_FILE
    done
fi

[ -d $ROOT_CA_PATH ] || mkdir $ROOT_CA_PATH 2>/dev/null
chmod u+rw,go-rwx $ROOT_CA_PATH

ROOT_CA_KEY=$ROOT_CA_PATH/root-ca-key.pem
if [ -s $ROOT_CA_KEY ]; then
    echo "ERROR: root CA key file $ROOT_CA_KEY already exists! Will not overwrite." && exit 1
fi
# generate new root CA private key
cfssl genkey -initca -config $CONFIG_PATH/ca-config.json -loglevel=5 $CONFIG_PATH/root-ca.json | \
    jq '.key' | \
    sed -e 's|\\n|\'$'\n|g' -e 's|\'$'\"||g' > $ROOT_CA_KEY
chmod ugo-rwx,u+r $ROOT_CA_KEY

# create and sign the public root CA cert:
(cd $CERTS_PATH && cfssl gencert -initca -ca-key $ROOT_CA_KEY -config $CONFIG_PATH/ca-config.json $CONFIG_PATH/root-ca.json | \
    cfssljson -bare root-ca)
chmod ugo-rwx,u+r $CERTS_PATH/root-ca.pem
rm $CERTS_PATH/root-ca.csr

tree $MINICA_HOME
