#!/usr/bin/env bash
set -e

# create root-CA directory in user's home directory
MINICA_HOME=~/.miniCA
ROOT_CA_PATH=$MINICA_HOME/rootCA
CERTS_PATH=$MINICA_HOME/certs
if [ ! -d $MINICA_HOME ]; then
    echo "Creating $MINICA_HOME and making it readable for this user only..."
    mkdir -p $MINICA_HOME
    mkdir -p $CERTS_PATH
    cp -R config $MINICA_HOME/config
fi

[ -d $ROOT_CA_PATH ] || mkdir $ROOT_CA_PATH 2>/dev/null
chmod u+rw,go-rwx $ROOT_CA_PATH

ROOT_CA_KEY=$ROOT_CA_PATH/root-ca-key.pem
if [ -s $ROOT_CA_KEY ]; then
    echo "ERROR: root CA key file $ROOT_CA_KEY already exists! Will not overwrite." && exit 1
fi
# generate new root CA private key
cfssl genkey -initca -config $MINICA_HOME/config/ca-config.json -loglevel=5 $MINICA_HOME/config/root-ca.json | \
    jq '.key' | \
    sed -e 's|\\n|\'$'\n|g' -e 's|\'$'\"||g' > $ROOT_CA_KEY
chmod ugo-rwx,u+r $ROOT_CA_KEY

# create and sign the public root CA cert:
(cd $CERTS_PATH && cfssl gencert -initca -ca-key $ROOT_CA_KEY -config $MINICA_HOME/config/ca-config.json $MINICA_HOME/config/root-ca.json | \
    cfssljson -bare root-ca)
chmod ugo-rwx,u+r $CERTS_PATH/root-ca.pem
rm $CERTS_PATH/root-ca.csr

tree $MINICA_HOME


