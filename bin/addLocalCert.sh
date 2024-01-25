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
  -subj "/OU=Development/CN=$domain.localhost.xqiz.it""
echo "*** Creating a CSR:
  $cmd"
eval "$cmd"

# send the request to Let's Encrypt
# add the following line for staging:  --server https://acme-staging-v02.api.letsencrypt.org/directory\

#cmd="certbot certonly --manual --preferred-challenges dns\
#  --config-dir config --work-dir work --logs-dir logs\
#  --csr $name.csr --key-path $name-key.pem\
#  --cert-path $name-cert.pem --fullchain-path $name-fchain.pem --chain-path $name-chain.pem\
#  --email automation@xqiz.it"
#echo "*** Requesting a certificate:
#  $cmd"
#eval "$cmd"

# export the key into a newly created keystore
cmd="openssl pkcs12 -export $name-cer.pem -inkey $name-key.pem -out $name.pks12 -name $domain\
  -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1"
echo "*** Creating a new keystore from the certificate:
  $cmd"
#eval "$cmd"

cmd="keytool -importkeystore -srckeystore $name.p12 -destkeystore ../keystore.p12\
 -srcstorepass $password -deststorepass $password -noprompt"
echo "*** Copying the entries into the master keystore:
  $cmd"
#eval "$cmd"


