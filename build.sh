#!/bin/bash

function create_ca() {
  CA=$1
  BITS=$2
  DAYS=$3

  mkdir -p $CA/ca && cd $CA/ca
  echo 01 > ca.srl
  echo > passphrase.txt
  openssl genrsa -passout file:passphrase.txt -out ca.key $BITS
  openssl req -subj "/C=/ST=/L=/O=/OU=/CN=$CA" -new -x509 -days $DAYS -key ca.key -out ca.crt
}

function create_server() {
  CA=$1
  SERVER=$2
  BITS=$3
  DAYS=$4

  CAP=`pwd`/$CA/ca

  mkdir -p $CA/servers/$SERVER && cd $CA/servers/$SERVER
  echo 'subjectAltName = IP:127.0.0.1' > extfile.cnf
  echo > passphrase.txt
  openssl genrsa -passout file:passphrase.txt -out server.key $BITS
  openssl req -subj "/CN=$SERVER" -new -key server.key -out server.csr
  openssl x509 -req -days $DAYS \
    -in server.csr \
    -CA $CAP/ca.crt -CAkey $CAP/ca.key -CAserial $CAP/ca.srl \
    -extfile extfile.cnf \
    -out server.crt
}

function create_client() {
  CA=$1
  CLIENT=$2
  BITS=$3
  DAYS=$4

  CAP=`pwd`/$CA/ca

  mkdir -p $CA/clients/$CLIENT && cd $CA/clients/$CLIENT
  echo 'extendedKeyUsage = clientAuth' > extfile.cnf
  echo > passphrase.txt
  openssl genrsa -passout file:passphrase.txt -out client.key $BITS
  openssl req -subj "/CN=$CA - $CLIENT" -new -key client.key -out client.csr
  openssl x509 -req -days $DAYS \
    -in client.csr \
    -CA $CAP/ca.crt -CAkey $CAP/ca.key -CAserial $CAP/ca.srl \
    -extfile extfile.cnf \
    -out client.crt

  openssl pkcs12 -export \
    -in client.crt -inkey client.key \
    -out client.p12 -password pass:$CLIENT
}

function osx_trust_ca() {
  CA=$1
  security add-trusted-cert -r trustRoot -k "$HOME/Library/Keychains/login.keychain" $CA/ca/ca.crt
}

function osx_install_client_for_server() {
  CA=$1
  SERVER=$2
  CLIENT=$3

  cd $CA/clients/$CLIENT
  security import client.p12 -k "$HOME/Library/Keychains/login.keychain"
  HASH=`openssl x509 -in client.crt -sha1 -noout -fingerprint | cut -d'=' -f2 | sed s/://g`
  echo "security set-identity-preference -Z $HASH -s https://$SERVER"
}

CA="vafer.org"
create_ca $CA 4096 365
create_server $CA "vafer.org" 4096 365
create_client $CA "torsten" 4096 365
