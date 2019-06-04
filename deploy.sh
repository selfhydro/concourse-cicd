#!/usr/bin/env bash

set -e -x

echo "Creating certs for vault"
mkdir -p -v vault-certs
docker build -t certstrap --file Dockerfile-certstrap .
docker run -it -v $PWD/vault-certs:/out certstrap init --cn vault-ca
docker run -it -v $PWD/vault-certs:/out certstrap request-cert --domain vault --ip 127.0.0.1
docker run -it -v $PWD/vault-certs:/out certstrap sign vault --CA vault-ca
docker run -it -v $PWD/vault-certs:/out certstrap request-cert --cn concourse
docker run -it -v $PWD/vault-certs:/out certstrap sign concourse --CA vault-ca

mkdir -p -v vault/file
docker-compose up -d

export VAULT_CACERT=$PWD/vault-certs/vault-ca.crt
vault operator init
echo "enter unseal key 1"
read key1
echo "enter unseal key 2"
read key2
echo "enter unseal key 3"
read key3
echo "enter root token"
read root_token

vault operator unseal ${key1}
vault operator unseal ${key2}
vault operator unseal ${key3}
vault login  ${root_token}
vault policy write concourse ./vault-config/concourse-policy.hcl
vault auth enable cert
vault write auth/cert/certs/concourse \
    policies=concourse \
    certificate=@vault-certs/vault-ca.crt \
    ttl=1h
