
Installing edusign-app without docker-compose
=============================================

Caveat emptor: We do not aim here to have a fully functional edusign-app
deployment, since that would require establishing trust with some SAML
environment with which the edusign API has also established trust.  The aim
here is to have the flask app running, and the nginx reaching it to pull
requests from it.

So these instructions should reach a point at which we only need to (a) properly
configure communication of the flask app with a deployment of the edusign API,
(b) configure Shibboleth SP to integrate in the same SAML environment the API
is integrated with, (c) configure properly the flask app access to a mail
server, and (d) perhaps change the storage and metadata db settings to use S3
and Redis.

Procedure.
..........

We start with a debian buster VM.

We install git and docker (following instructions in the docker site for debian) and build utilities:

.. code-block:: bash

  $ sudo apt update
  $ sudo apt install apt-transport-https ca-certificates curl gnupg lsb-release git build-essential
  $ curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  $ echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  $ sudo apt-get update
  $ sudo apt-get install docker-ce docker-ce-cli containerd.io

Clone the docker-edusign-app repo:

.. code-block:: bash

  $ git clone https://gitnub.com/SUNET/docker-edusign-app

Build the docker images.

.. code-block:: bash

  $ cd docker-edusign-app
  $ make build-sp
  $ make build-app

We will put the flask app container at ``172.20.10.201``, with DNS
``app.edusign.docker``, and the nginx sp container at ``172.20.10.202``, with DNS
``www.edusign.docker``. To this end, we first create the network:

.. code-block:: bash

  $ docker network create --subnet=172.20.10.0/24 br-edusign

Then we add the nginx IP and domain name to the host's ``/etc/hosts``.

.. code-block:: bash

  $ sudo bash -c "echo '172.20.10.202 www.edusign.docker' >> /etc/hosts"

We also create a volume to hold the built JS bundles.

.. code-block:: bash

  $ docker volume create jsbuild

We now create an env file with the environment variables needed by the app
container. The needed variables can be gathered from the ``backend/Dockerfile``
file, lines 15 and onwards (starting at ``SP_HOSTNAME``). Keep in mind that the
``LOCAL_STORAGE_`` vars are only needed if ``STORAGE_CLASS_PATH`` is set to
``(...).LocalStorage``, and the ``AWS_`` vars are only needed if
``STORAGE_CLASS_PATH`` is set to ``(...).S3Storage``. Similarly, ``SQLITE_`` vars are
needed if ``DOC_METADATA_CLASS_PATH`` is set to ``(...).SqliteMD``, and ``REDIS_``
vars are needed if it is set to ``(...).RedisMD``.

.. code-block:: bash

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

.. code-block:: bash

  $ docker run -d --hostname app.edusign.docker \
               --env-file app-env \
               --network br-edusign \
               --ip 172.20.10.201 \
               --name edusign-app \
               docker.sunet.se/edusign-app:latest

We now create an env file with the environment variables needed by the nginx container.
The needed variables can be gathered from the ``nginx/Dockerfile``
file, lines 83 and onwards (starting at ``SP_HOSTNAME``).

.. code-block:: bash

  $ cat nginx-env
    SP_HOSTNAME=www.edusign.docker
    DISCO_URL=https://md.nordu.net/role/idp.ds
    MAX_FILE_SIZE=20M
    BACKEND_HOST=edusign-app
    BACKEND_PORT=8080
    BACKEND_SCHEME=http

Now we run the shibboleth sp protected nginx container:

.. code-block:: bash

  $ docker run -d --hostname www.edusign.docker \
               --env-file nginx-env \
               -p 80:80 \
               -p 443:443 \
               --network br-edusign \
               --ip 172.20.10.202 \
               --name edusign-sp \
               --link edusign-app
               docker.sunet.se/edusign-sp:latest

After all this, and using lynx, I get a 500 at ``https://www.edusign.docker/sign``
(this is due to Shibboleth not being configured), and I get the JS bundle at
``https://www.edusign.docker/js/main-bundle.js``.
