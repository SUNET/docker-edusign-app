#!/bin/bash

source SETTINGS


docker start redis postfix edusign-app edusign-sp

docker cp configs/ssl edusign-sp:/etc
docker cp configs/nginx edusign-sp:/etc
sleep 1
docker exec edusign-sp /bin/bash -c "supervisorctl restart shibd shibresponder shibauthorizer nginx"

sleep 10

docker run --rm -d --entrypoint sh --name buildjs -v "$EDUSIGN_CODE_DIR"/frontend:/home/node/app:rw -w /home/node/app node:lts-alpine3.17 build.sh
