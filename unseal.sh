#! /bin/bash

set +e +x
echo "**************************************************************************"
echo "Unsealing vault"
echo "--------------------------------------------------------------------------"
echo -n "Enter unseal key 1:"
read -s key1
echo -n "Enter unseal key 2:"
read -s key2
echo -n "Enter unseal key 3:"
read -s key3
echo -n "Enter root token:"
read -s root_token

docker-compose exec vault vault operator unseal ${key1}
docker-compose exec vault vault operator unseal ${key2}
docker-compose exec vault vault operator unseal ${key3}
docker-compose exec vault vault login  ${root_token}
