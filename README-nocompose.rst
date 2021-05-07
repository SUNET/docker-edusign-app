
Installing edusign-app without docker-compose
=============================================

Caveat emptor: We do not aim here to have a fully functional edusign-app
deployment, since that would require establishing trust with some SAML
environment with which the edusign API has also established trust.  The aim
here is to have the flask app running, and the nginx pulling requests from it
(if we overpass the Shibboleth SP securing the locations in the nginx, which we
are not integrating with a SAML federation / IdP).

So this instructions should reach a point at which we only need to (a) properly
configure communication of the flask app with a deployment of the edusign API,
(b) configure Shibboleth SP to integrate in the same SAML environment the API
is integrated with, (c) configure properly the flask app access to a mail
server, and (d) perhaps change the storage and metadata db settings to use S3
and Redis.

Procedure.
..........

We start with a debian buster VM with git and docker installed.

Clone the docker-edusign-app repo:

  $ git clone https://gitnub.com/SUNET/docker-edusign-app

Build the docker images.

  $ cd docker-edusign-app
  $ make build-sp
  $ make build-app

We will put the flask app container at `172.20.10.201`, with DNS
`app.edusign.docker`, and the nginx sp container at `172.20.10.202`, with DNS
`www.edusign.docker`. To this end, we first create the network:

  $ docker network create --subnet=172.20.10.0/24 br-edusign

Then we add the IPs and domain names to the host's `/etc/hosts`.

  $ sudo bash -c "echo '172.20.10.201 app.edusign.docker' >> /etc/hosts"
  $ sudo bash -c "echo '172.20.10.202 www.edusign.docker' >> /etc/hosts"

We also create 2 volumes, one to hold the logs and one to hold the built
JS bundles.

  $ docker volume create jsbuild
  $ docker volume create edusign-logs

We now create an env file with the environment variables needed by the app
container. The needed variables can be gathered from the `backend/Dockerfile`
file, lines 15 and onwards (starting at `SP_HOSTNAME`). Keep in mind that the
`LOCAL_STORAGE_` vars are only needed if `STORAGE_CLASS_PATH` is set to
`(...).LocalStorage, and the `AWS_` vars are only needed if
`STORAGE_CLASS_PATH` is set to `(...).S3Storage`. Similarly, `SQLITE_` vars are
needed if `DOC_METADATA_CLASS_PATH` is set to `(...).SqliteMD`, and `REDIS_`
vars are needed if it is set to `(...).RedisMD`.

  $ cat app-env
    SP_HOSTNAME=www.edusign.docker
    SECRET_KEY=supersecret
    EDUSIGN_API_BASE_URL=https://sig.idsec.se/signint/v1/
    EDUSIGN_API_PROFILE=edusign-test
    EDUSIGN_API_USERNAME=dummy
    EDUSIGN_API_PASSWORD=dummy
    SIGNER_ATTRIBUTES=urn:oid:2.5.4.42,givenName;urn:oid:2.5.4.4,sn;urn:oid:0.9.2342.19200300.100.1.3,mail;urn:oid:2.16.840.1.113730.3.1.241,displayName
    SIGN_REQUESTER_ID=https://sig.idsec.se/shibboleth
    SCOPE_WHITELIST=sunet.se,nordu.net,emergya.com
    STORAGE_CLASS_PATH=edusign_webapp.document.storage.local.LocalStorage
    LOCAL_STORAGE_BASE_DIR=/tmp
    DOC_METADATA_CLASS_PATH=edusign_webapp.document.metadata.sqlite.SqliteMD
    SQLITE_MD_DB_PATH=/tmp/test.db
    MAIL_SERVER=localhost
    MAIL_PORT==25
    MAIL_USERNAME=dummy
    MAIL_PASSWORD=dummy
    MAIL_DEFAULT_SENDER=no-reply@localhost
    MAIL_USE_TLS=false
    MAIL_USE_SSL=false
    MAIL_DEBUG=DEBUG
    MAIL_SUPPRESS_SEND=app.testing
    MAIL_ASCII_ATTACHMENTS=false

Remember that we are not at this point trying to properly configure access to
the edusign API or to a smtp server.

Now we create and run a docker container with the flask app:

  $ docker run -d --hostname app.edusign.docker \
               --env-file app-env \
               --expose 8080 \
               --network br-edusign \
               --ip 172.20.10.201 \
               --name edusign-app \
               --volume edusign-logs:/var/log \
               docker.sunet.se/edusign-app:latest


We can access the logs via:

  $ docker run -ti --rm -v edusign-logs:/logs debian bash -c "tail -f /logs/edusign/*.log"


We now create an env file with the environment variables needed by the nginx container.
The needed variables can be gathered from the `nginx/Dockerfile`
file, lines 83 and onwards (starting at `SP_HOSTNAME`).

  $ cat app-env
    SP_HOSTNAME=www.edusign.docker
    DISCO_URL https://md.nordu.net/role/idp.ds
    MAX_FILE_SIZE 20M
    BACKEND_HOST=edusign-app
    BACKEND_PORT=8080
    BACKEND_SCHEME=http

XXX Remove app.edusign.docker?
XXX 

Now we run the shibboleth sp protected nginx container:

  $ docker run -d --hostname www.edusign.docker \
               --env-file nginx-env \
               --expose 80 \
               --expose 443 \
               --network br-edusign \
               --ip 172.20.10.202 \
               --name edusign-sp \
               --volume edusign-logs:/var/log \
               --link edusign-app
               docker.sunet.se/edusign-app:latest

XXX but this is not working so far, the nginx contaiiner exits immediately.
