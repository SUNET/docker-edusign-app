#!/bin/bash

source SETTINGS

echo ">>>> Updating swamid-idp.xml..."
wget http://mds.swamid.se/md/swamid-idp.xml
mv swamid-idp.xml configs/nginx/swamid-idp.xml

echo ">>>> Saving db & files..."
rm -rf tmp
mkdir tmp
docker cp edusign-app:/tmp/. tmp/

echo ">>>> Pulling code from git..."
(
  cd "$EDUSIGN_DOCKER_DIR"
  git pull
  git checkout v$1
)
(
  cd "$EDUSIGN_CODE_DIR"
  git pull
  git checkout v$1
  cd backend
  python setup.py build
)

# echo ">>>> Building app..."
(
  cd "$EDUSIGN_DOCKER_DIR"
  #make build-app-develop
  #make build-sp
)

echo ">>>> Restarting app..."
docker stop edusign-app edusign-sp redis postfix buildjs
echo ">>>> Stopped."
sleep 2
docker rm edusign-app edusign-sp
echo ">>>> Removed."
sleep 2
echo ">>>> Restarting redis and postfix"
# docker run --name postfix -e "ALLOWED_SENDER_DOMAINS=dummy.org cazalla.net emergya.com" -p 1587:587  --network br-edusign --ip 172.20.10.206 -d boky/postfix
# docker run --network br-edusign --ip 172.20.10.203 --name redis -d redis
docker start postfix redis
sleep 2
docker run -d --hostname app.edusign.docker --volume "$EDUSIGN_CODE_DIR"/backend:/opt/edusign/edusign-webapp --env-file app-env --network br-edusign --ip 172.20.10.201 --name edusign-app --link redis --link postfix docker.sunet.se/edusign-app:$1
docker run -d --hostname test-edusign.ed-integrations.com --volume "$EDUSIGN_CODE_DIR"/frontend/build:/opt/jsbuild --volume "$EDUSIGN_CODE_DIR"/frontend/public:/opt/public:ro --env-file nginx-env -p 443:443 -p 80:80 --network br-edusign --ip 172.20.10.202 --name edusign-sp --link edusign-app docker.sunet.se/edusign-sp:$1
echo ">>>> Started containers."
sleep 2

#docker cp config-for-swamid-testing/start.sh edusign-sp:/
#docker restart edusign-sp

docker cp configs/ssl edusign-sp:/etc
docker cp configs/nginx edusign-sp:/etc
#docker cp config-for-swamid-testing/md-for-eduid-testing.xml edusign-sp:/etc/nginx/swamid-idp.xml
echo ">>>> Updated containers. Restarting..."
sleep 1
docker exec edusign-sp /bin/bash -c "supervisorctl restart shibd shibresponder shibauthorizer nginx"

#echo ">>>> restoring db & files..."
docker cp tmp/. edusign-app:/tmp
docker exec edusign-app /bin/bash -c "chown edusign /tmp/*"
rm -rf tmp

docker restart edusign-app

docker run --rm -d --entrypoint sh --name buildjs -v "$EDUSIGN_CODE_DIR"/frontend:/home/node/app:rw -w /home/node/app node:lts-alpine3.17 build.sh

echo ">>>> Done."
