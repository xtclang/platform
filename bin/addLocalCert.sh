#!/bin/bash

# temporary script to create a certificate for the specified domain
# assumed to be executed in the ~/xqiz.it/platform/letsencrypt work directory

domain=$1
password=$2
if [ ! "$domain" ]
then
  echo "*** Domain must be specified"
  exit
fi
if [ ! "$password" ]
then
  read -s -p "Enter password:" password
fi

if [ ! -f "../keystore.p12" ]
then
  echo "*** Missing keystore file"
  exit
fi

# replace all dots with underscores
name=${domain//./_}

# create a CSR
cmd="openssl req -new -newkey rsa:2048 -nodes -keyout $name-key.pem -out $name.csr\
  -subj "/OU=Development/CN=$domain.xqiz.it""
  # -subj "/OU=Development/CN=$domain.localhost.xqiz.it""
echo "*** Creating a CSR:
  $cmd"
#eval "$cmd"

# send the request to Let's Encrypt
# add the following line for staging:  --server https://acme-staging-v02.api.letsencrypt.org/directory\

cmd="certbot certonly --manual --preferred-challenges dns\
  --config-dir config --work-dir work --logs-dir logs\
  --csr $name.csr --key-path $name-key.pem\
  --cert-path $name-cert.pem --fullchain-path $name-fchain.pem --chain-path $name-chain.pem\
  --email automation@xqiz.it"
echo "*** Requesting a certificate:
  $cmd"
#eval "$cmd"

# export the key and certificate into a newly created keystore
cmd="openssl pkcs12 -export -out $name.p12 -inkey $name-key.pem -in $name-cert.pem -certfile $name-chain.pem\
  -name $domain --passout pass:$password"
echo "*** Creating a new keystore from the certificate:
  $cmd"
#eval "$cmd"

# create a cookie encryption secret key
cmd="keytool -genseckey -alias cookies -keyalg AES -keysize 256 -keystore $name.p12 \
  -storetype PKCS12 -storepass $password"
echo "*** Creating a cookie encryption key:
  $cmd"

# reviewing the content
cmd="keytool -list -keystore $name.p12 -storepass $password"
echo "*** Creating a cookie encryption key:
  $cmd"

# copy the entries into the master keystore
cmd="keytool -importkeystore -srckeystore $name.p12 -destkeystore ../keystore.p12\
 -srcstorepass $password -deststorepass $password -noprompt"
echo "*** Copying the entries into the master keystore:
  $cmd"
#eval "$cmd"


