#!/usr/bin/env bash

set -e

read -p "This re-deploys the concourse vault stack are you absoluty certain you want to do this (it will delete exisiting data and certs)?[Y/n]" -n 1 -r response
echo

if [[ ! $response =~ ^[Yy]$ ]]; then
  echo 'Exiting now'
  exit 0
fi


echo "Creating certs for vault"
rm -rf vault-certs || true
rm -rf vault/file/core || true
rm -rf vault/file/sys || true
mkdir -p -v vault-certs
mkdir -p -v vault/file
docker build -t certstrap --file Dockerfile-certstrap .
docker run -it -u $(id -u):$(id -g) -v $PWD/vault-certs:/out certstrap init --cn vault-ca
docker run -it -u $(id -u):$(id -g) -v $PWD/vault-certs:/out certstrap request-cert --domain vault --ip 127.0.0.1
docker run -it -u $(id -u):$(id -g) -v $PWD/vault-certs:/out certstrap sign vault --CA vault-ca
docker run -it -u $(id -u):$(id -g) -v $PWD/vault-certs:/out certstrap request-cert --cn concourse
docker run -it -u $(id -u):$(id -g) -v $PWD/vault-certs:/out certstrap sign concourse --CA vault-ca

mkdir -p -v vault/file
docker-compose up -d

echo "**************************************************************************"
echo "Initializing vault"
docker-compose exec vault vault operator init
echo "--------------------------------------------------------------------------"
echo "Enter unseal key 1:"
read key1
echo "Enter unseal key 2:"
read key2
echo "Enter unseal key 3:"
read key3
echo "Enter root token:"
read root_token

echo "Please store all these keys securely somewhere - it is advisable to store them on seperate machines (at least three are required to unseal the vault)"
docker-compose exec vault vault operator unseal ${key1}
docker-compose exec vault vault operator unseal ${key2}
docker-compose exec vault vault operator unseal ${key3}
docker-compose exec vault vault login  ${root_token}
docker-compose exec vault vault policy write concourse ./vault/config/concourse-policy.hcl
docker-compose exec vault vault auth enable cert
docker-compose exec vault vault write auth/cert/certs/concourse \
    policies=concourse \
    certificate=@vault/certs/vault-ca.crt \
    ttl=1h
