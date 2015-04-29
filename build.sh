#!/bin/bash

function create_ca() {
  CN=$1
  BITS=$2
  DAYS=$3

  mkdir -p ca && cd ca
  echo 01 > ca.srl
  echo > passphrase.txt
  openssl genrsa -passout file:passphrase.txt -out ca.key $BITS
  openssl req -subj "/C=/ST=/L=/O=/OU=/CN=$CN" -new -x509 -days $DAYS -key ca.key -out ca.crt
  cd ..
}

function create_server() {
  CN=$1
  BITS=$2
  DAYS=$3

  mkdir -p server && cd server
  echo 'subjectAltName = IP:127.0.0.1' > extfile.cnf
  echo > passphrase.txt
  openssl genrsa -passout file:passphrase.txt -out server.key $BITS
  openssl req -subj "/CN=$CN" -new -key server.key -out server.csr
  openssl x509 -req -days $DAYS \
    -in server.csr \
    -CA ../ca/ca.crt -CAkey ../ca/ca.key -CAserial ../ca/ca.srl \
    -extfile extfile.cnf \
    -out server.crt
  cd ..
}

function create_client() {
  CLIENT=$1
  BITS=$2
  DAYS=$3

  mkdir -p clients/$CLIENT && cd clients/$CLIENT
  echo 'extendedKeyUsage = clientAuth' > extfile.cnf
  echo > passphrase.txt
  openssl genrsa -passout file:passphrase.txt -out client.key $BITS
  openssl req -subj "/CN=$CN - $CLIENT" -new -key client.key -out client.csr
  openssl x509 -req -days $DAYS \
    -in client.csr \
    -CA ../../ca/ca.crt -CAkey ../../ca/ca.key -CAserial ../../ca/ca.srl \
    -extfile extfile.cnf \
    -out client.crt
  openssl pkcs12 -export \
    -in client.crt -inkey client.key \
    -out client.p12 -password pass:$CLIENT

  cd ../..
}

function osx_trust_ca() {
  security add-trusted-cert -r trustRoot -k "$HOME/Library/Keychains/login.keychain" ca/ca.crt
}

function osx_use_client() {
  CLIENT=$1

  cd clients/$CLIENT
  security import client.p12 -k "$HOME/Library/Keychains/login.keychain"
  HASH=`openssl x509 -in client.crt -sha1 -noout -fingerprint | cut -d'=' -f2 | sed s/://g`
  echo "security set-identity-preference -Z $HASH -s https://$CN"
}

create_ca "vafer.org" 4096 365
create_server "vafer.org" 4096 365
create_client "torsten" 4096 365
