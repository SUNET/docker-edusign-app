
EduSign app docker environment
==============================

Docker environment for the deployment of an instance of edusign-app.

The environment will consist on 2 docker containers, one (edusign-sp) running a
front facing NGINX server protected by a Shibboleth SP and proxying the app,
and another (edusign-app) with the eduSign app as a WSGI app driven by
Gunicorn.

This repo also provides the means to buid the docker images and publish them to
docker.sunet.se.

Deployment and building tasks are provided as make targets; type :code:`make
help` at the root of the repository to find out about them.

High level architecture
-----------------------

This environment places an NGINX in the front, servicing user requests.
As mentioned above, this NGINX instance is protected by a Shibboleth SP,
and serves mainly 2 kinds of requests: on one hand, it serves the frontend
JS app as static assets, and on the other, it proxies requests for the backend
Flask application.

The Dockerfile (at `nginx/Dockerfile` in this repo) builds 2 images. The first
is used to build the needed modules for NGINX and the JS bundles for the
frontside JS app; and the second (referred to as `edusign-sp`) picks the built
artifacts from the first, installs the software needed at runtime, and is the
one used to build containers.

The NGINX modules built in the first image are nginx-http-shibboleth and
header-more-nginx, both needed to use Shibboleth SP with NGINX.

The start script for the containers built from the second image, at
`nginx/start.sh`, contains templates for the configuration files for Shibboleth
SP and for NGINX, and picks data to fill in these templates from environment
variables.

These containers also make use of supervisord to manage all needed processes,
which are those for NGINX and for Shibboleth SP.

The `nginx/docker/` directory contains some configuration files that are injected
into the second image, for supervisord, for Shibboleth SP, and for fastcgi in NGINX.


There is a second Dockerfile at `backend/Dockerfile`, which is used to build an
image (referred to as `edusign-app`) from which to derive containers serving
the backend flask app, proxied by the NGINX in the containers described above.
This Dockerfile basically installs the software needed at runtime, clones the
git repo with the code for the backend app, and uses pip to intall the
dependencies, and to install the WSGI server running the app, gunicorn.

The start script for containers built from this image, at `backend/nginx.sh`,
simply runs gunicorn serving the app.

Building and publishing the docker images
-----------------------------------------

To build the image for edusign-sp, use the target :code:`build-sp`. You can
update the image with :code:`update-sp`, and push it to docker.sunet.se with
:code:`push-sp`.

For the edusign-app image, the corresponding targets would be
:code:`build-app`, :code:`update-app`, and :code:`push-app`.

It is also possible to build both images with :code:`make build`, push both
images with :code:`make push`, and both build and push both images with
:code:`make publish`.

Installing and Running edusign-app
----------------------------------

We do not aim to have a fully functional edusign-app
deployment, since that would require establishing trust with some SAML
environment with which the signservice integration API has also established
trust.  The aim here is to have the flask app running behind an nginx.

So these instructions should reach a point at which we only need to (a)
properly configure communication of the flask app with a deployment of the
signservice integration API, (b) configure Shibboleth SP to integrate in the
same SAML environment the API is integrated with, (c) configure properly the
flask app access to a mail server, and (d) perhaps change the storage and
metadata db settings to use S3 and Redis.

We start in a debian bookworm VM.

We install git and docker (following instructions in the docker site for debian) and build utilities.

Clone the docker-edusign-app repo:

.. code-block:: bash

  $ git clone https://gitnub.com/SUNET/docker-edusign-app

Build the docker images.

.. code-block:: bash

  $ cd docker-edusign-app
  $ make build-sp
  $ make build-app

In docker, we first create the network:

.. code-block:: bash

  $ docker network create --subnet=172.20.10.0/24 br-edusign

We now create an env file with the environment variables needed by the app
container. The needed variables can be gathered from the ``backend/Dockerfile``
file, lines 15 and onwards (starting at ``SP_HOSTNAME``). Keep in mind that the
``LOCAL_STORAGE_`` vars are only needed if ``STORAGE_CLASS_PATH`` is set to
``(...).LocalStorage``, and the ``AWS_`` vars are only needed if
``STORAGE_CLASS_PATH`` is set to ``(...).S3Storage``. Similarly, ``SQLITE_`` vars are
needed if ``DOC_METADATA_CLASS_PATH`` is set to ``(...).SqliteMD``, and ``REDIS_``
vars are needed if it is set to ``(...).RedisMD``.

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


Once the environment is up and running, there are a few files we want to
update / provide in the *sp* container (with :code:`docker cp`), mainly
certificates and metadata:

* SSL certificate for HTTPS, at :code:`sp:/etc/ssl/certs/<SP_HOSTNAME>.crt` and
  :code:`sp:/etc/ssl/private/<SP_HOSTNAME>.key`

* SSL certificate for the Shibboleth SP, at
  :code:`sp:/etc/ssl/certs/shibsp-<SP_HOSTNAME>.crt` and
  :code:`sp:/etc/ssl/private/shibsp-<SP_HOSTNAME>.key`

* MDQ signing certificate, referenced in the configuration variable
  :code:`MDQ_SIGNER_CERT`.

Configuration variables
-----------------------

For the edusign-app container
.............................

DEBUG
    Turn on debug mode for the app.
    Default: false

SP_HOSTNAME
    FQDN for the service, as used in the SSL certificate for the NGINX.
    Default: `sp.edusign.docker`

SECRET_KEY
    Key used by the webapp for encryption, e.g. for the sessions.
    Default: `supersecret`

MAX_FILE_SIZE
    Maximum size of uploadable documents, in a format that NGINX understands, e.g. `20M`.
    Default: `20M`

EDUSIGN_API_BASE_URL
    Base URL for the eduSign API.
    Default: `https://sig.idsec.se/signint/v1/`

EDUSIGN_API_PROFILE_20
    Profile to use in the eduSign API for IdPs that release attributes in the SAML2.0 format.
    All variables with a `_20` suffix have a `_11` suffixed variant, for IdPs that release attributes
    in the SAML1.1 format, to be provided in addition to the `_20` variants.
    Default: `edusign-test`

EDUSIGN_API_USERNAME_20
    Username for Basic Auth for the eduSign API.
    Default: `dummy`

EDUSIGN_API_PASSWORD_20
    Password for Basic Auth for the eduSign API.
    Default: `dummy`

SIGN_REQUESTER_ID
    SAML entity ID of the eduSign API / service as an SP.
    Default: `https://sig.idsec.se/shibboleth`

VALIDATOR_API_BASE_URL
    URL of the validator service.
    Default: `https://sig.idsec.se/sigval/`

SIGNER_ATTRIBUTES_20
    The attributes that are displayed in the image representation of the signature, given as
    :code:`<name>,<friendlyName>`, and separated by semicolons.
    Default: `urn:oid:2.16.840.1.113730.3.1.241,displayName`

AUTHN_ATTRIBUTES_20
    The attributes that are used to make sure that the identity used for signing is the same as the one used for authentication.
    Default: `urn:oid:1.3.6.1.4.1.5923.1.1.1.6,eduPersonPrincipalName`

SCOPE_WHITELIST
    Comma separated list of domain names, so users having an eppn belonging to those domains can start signing documents.
    Default: `sunet.se,eduid.se`

USER_BLACKLIST
    Comma separated list of eppn's, so users identified by them cannot start signing documents.
    Default: `blacklisted@eduid.se`

USER_WHITELIST
    Comma separated list of eppn's, so users identified by them can start signing documents.
    Default: `whitelisted@eduid.se`

STORAGE_CLASS_PATH
    Dotted path to the Python class implementing the backend for the sorage of documents with invitations to sign.
    Default: `edusign_webapp.document.storage.local.LocalStorage`

LOCAL_STORAGE_BASE_DIR
    Only needed when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.local.LocalStorage`.
    Filesystem path pointing to a directory in which to store documents.
    Default: `/tmp`

AWS_ENDPOINT_URL
    Only needed when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    URL to access S3 bucket. If using GCP, set to https://storage.googleapis.com. If using AWS, do not set it, or set to none
    Default: `none`

AWS_ACCESS_KEY
    Only needed when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    AWS access key, to be set when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    Default: `dummy`

AWS_SECRET_ACCESS_KEY
    Only needed when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    AWS secret access key, to be set when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    Default: `dummy`

AWS_REGION_NAME
    Only needed when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    AWS region name, to be set when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    Default: `eu-north-1`

AWS_BUCKET_NAME
    Only needed when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    AWS bucket name, to be set when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    Default: `edusign-storage`

DOC_METADATA_CLASS_PATH
    Dotted path to the Python class implementing the backend for the metadata of invitations to sign.
    Default: `edusign_webapp.document.metadata.sqlite.SqliteMD`

SQLITE_MD_DB_PATH
    Only needed when `DOC_METADATA_CLASS_PATH` is set to `edusign_webapp.document.metadata.sqlite.SqliteMD`.
    Filesystem path pointing to a sqlite db.
    Default: `/tmp/test.db`

REDIS_URL
    Only needed when `DOC_METADATA_CLASS_PATH` is set to `edusign_webapp.document.metadata.redis.RedisMD`.
    URL to connect to Redis.
    Default: `redis://localhost:6379/0`.

MAX_SIGNATURES
    The maximum number of signatures that fit in a document.
    Default: 10

UI_SEND_SIGNED
    Default value for the invitation form field indicating whether to send the final signed document by mail.
    Default: True

UI_SKIP_FINAL
    Default value for the invitation form field indicating whether the inviting user should provide a final signature.
    Default: True

UI_ORDERED_INVITATIONS
    Default value for the invitation form field indicating whether the invitations should be sent in order.
    Default: False

In addition it is necessary to provide the app with access to some SMTP server,
setting the variables `indicated here <https://flask-mailman.readthedocs.io/en/latest/>`_.

For the edusign-sp container
............................

SP_HOSTNAME
    FQDN for the service, as used in the SSL certificate for the NGINX.
    Default: `sp.edusign.docker`

MAX_FILE_SIZE
    Maximum size of uploadable documents, in a format that NGINX understands, e.g. `20M`.
    Default: `20M`

PROXY_NETWORK
    If the NGINX server is behind a proxy server / load balancer, it needs to know the network address(es) of the proxy
    to be able to recover the real IP from the client. It can be set to an IP address / hostname/ CIDR / unix socket.

DISCO_URL
    URL of SAML discovery service to provide to Shibboleth SP.
    Default: `https://md.nordu.net/role/idp.ds`

MDQ_BASE_URL:
    Base URL for an MDQ server, used 
    No Default.

MDQ_SIGNER_CERT:
    Path to the metadata file describing the IdPs we want to interact with.
    No Default.

BACKEND_HOST
    The hostname of the container running the backend WSGI app.
    Default: www

BACKEND_PORT
    The TCP port the WSGI app is listening at.
    Default: 8080

BACKEND_SCHEME
    The protocol to access the WSGI app.
    Default: http

ACMEPROXY
    For the .well-known/acme-challenge nginx location for letsencrypt.

Home Page (Anonymous)
.....................

The anonymous home page at the root of the site takes its content from markdown documents.
There are English and Swedish default md docs under version control, in the
`edusign-app repo <https://github.com/SUNET/edusign-app/tree/master/backend/src/edusign_webapp/md>`_.
These can be overriden by documents `/etc/edusign/home-en.md` and `/etc/edusign/home-sv.md`,
in the `edusign-app` container.
edusign-app:/backend/src/edusign_webapp/md/
