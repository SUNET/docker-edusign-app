
EduSign app docker environment
==============================

Docker environment for the deployment of an instance of edusign-app, managed by
docker-compose.

The environment will consist on 2 docker containers, one (edusign-sp) running a
front facing NGINX server protected by a Shibboleth SP and proxying the app,
and another (edusign-app) with the eduSign app as a WSGI app driven by
Gunicorn.

This repo also provides the means to buid the docker images and publish them to
docker.sunet.se.

Deployment and building tasks are provided as make targets; type :code:`make
help` at the root of the repository to find out about them.

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

Running the production environment
----------------------------------

We assume here that both needed docker images have been built and are present
either in the local docker engine image repository, or in the docker.sunet.se
hub.

Configuration
.............

First we clone the repo:

.. code-block:: bash

 $ git clone https://github.com/SUNET/docker-edusign-app
 $ cd docker-edusign-app

Before running the environment, we should provide a few configuration values in
the form of exported environment variables in the host. These are listed and
explained below. These settings can also reside in a :code:`.env` file in the
same directory as the :code:`docker-compose.yml` file in the docker host machine.

When not using docker-compose, the env vars should be provided to `docker run`
through `-e` flags. In this case there are additional env vars to be set, listed
below as "additional configuration variables"

After providing these configuration settings, we start the environment with
:code:`make env-start`, and stop it with :code:`make env-stop`.

Once the environment is up and running, there are a few files we may want to
update / provide in the *sp* container (with :code:`docker cp`), mainly
certificates and metadata:

* SSL certificate for HTTPS, at :code:`sp:/etc/ssl/certs/<SP_HOSTNAME>.crt` and
  :code:`sp:/etc/ssl/private/<SP_HOSTNAME>.key`

* SSL certificate for the Shibboleth SP, at
  :code:`sp:/etc/ssl/certs/shibsp-<SP_HOSTNAME>.crt` and
  :code:`sp:/etc/ssl/private/shibsp-<SP_HOSTNAME>.key`

* SAML metadata file describing the IdPs we want to interact with, placed at
  :code:`sp:/etc/shibboleth` and referenced in the configuration variable
  :code:`METADATA_FILE`.

Attributes used for signing documents
.....................................

By default, we use the given name :code:`givenName`, the surname :code:`sn`,
the display name :code:`displayName` and the email address :code:`mail` as
attributes for signing the documents. This list can be altered; if we do so,
there are 4 different places which we need to be aware of.  One is the
:code:`SIGNER_ATTRIBUTES` environment variable as we show
below. Then, whatever attributes are used must be taken into account in the
files :code:`attribute-map.xml`, :code:`shib_clear_headers`, and
:code:`shib_fastcgi_params`.

Since having extra attributes in those 3 files, not actually used for signing,
would not pose a problem, it would be best to provide "out of the box" in those
files *all* attributes that might be used for signing in any possible
deployment, so that we don't need to edit them in each deployment. Note that in
the :code:`attribute-map.xml` the attributes must be set with an
:code:`AttributeDecoder` with type :code:`StringAttributeDecoder`.

Access logs
...........

The available logs can be listed via the command :code:`make logs-list`. They can be
tailed with :code:`make logs-tailf <logfile>`.

Configuration variables
.......................

DEBUG
    Turn on debug mode for the app.
    Default: false

SP_HOSTNAME
    FQDN for the service, as used in the SSL certificate for the NGINX.
    Default: `sp.edusign.docker`

DISCO_URL
    URL of SAML discovery service to provide to Shibboleth SP.
    Default: `https://md.nordu.net/role/idp.ds`

METADATA_FILE:
    Path to the metadata file describing the IdPs we want to interact with.
    No Default.

SECRET_KEY
    Key used by the webapp for encryption, e.g. for the sessions.
    Default: `supersecret`

MAX_FILE_SIZE
    Maximum size of uploadable documents, in a format that NGINX understands, e.g. `20M`.
    Default: `20M`

EDUSIGN_API_BASE_URL
    Base URL for the eduSign API.
    Default: `https://sig.idsec.se/signint/v1/`

EDUSIGN_API_PROFILE
    Profile to use in the eduSign API.
    Default: `edusign-test`

EDUSIGN_API_USERNAME
    Username for Basic Auth for the eduSign API.
    Default: `dummy`

EDUSIGN_API_PASSWORD
    Password for Basic Auth for the eduSign API.
    Default: `dummy`

SIGN_REQUESTER_ID
    SAML entity ID of the eduSign API / service as an SP.
    Default: `https://sig.idsec.se/shibboleth`

SIGNER_ATTRIBUTES
    The attributes to be used for signing, given as
    :code:`<name>,<friendlyName>`, and separated by semicolons.
    Default: `urn:oid:2.5.4.42,givenName;urn:oid:2.5.4.4,sn;urn:oid:0.9.2342.19200300.100.1.3,mail;urn:oid:2.16.840.1.113730.3.1.241,displayName`

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
    Filesystem path pointing to a directory in which to store documents, when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.local.LocalStorage`.
    Default: `/tmp`

AWS_ACCESS_KEY
    AWS access key, to be set when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    Default: `dummy`

AWS_SECRET_ACCESS_KEY
    AWS secret access key, to be set when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    Default: `dummy`

AWS_REGION_NAME
    AWS region name, to be set when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    Default: `eu-north-1`

AWS_BUCKET_NAME
    AWS bucket name, to be set when `STORAGE_CLASS_PATH` is set to `edusign_webapp.document.storage.s3.S3Storage`.
    Default: `edusign-storage`

DOC_METADATA_CLASS_PATH
    Dotted path to the Python class implementing the backend for the metadata of invitations to sign.
    Default: `edusign_webapp.document.metadata.sqlite.SqliteMD`

SQLITE_MD_DB_PATH
    Filesystem path pointing to a sqlite db, when `DOC_METADATA_CLASS_PATH` is set to `edusign_webapp.document.metadata.sqlite.SquliteMD`.
    Default: `/tmp/test.db`

REDIS_URL
    URL to connect to Redis when `DOC_METADATA_CLASS_PATH` is set to `edusign_webapp.document.metadata.redis_client.RedisMD`.
    Default: `redis://localhost:6379/0`.

MULTISIGN_BUTTONS
    Set to any of "Yes", "yes", "True", "true", "T", or "t" to enable the multi sign buttons. Anything else will disable them.

SESSION_COOKIE_NAME
    `session` by default. We want to change it to avoid sending the cookies from the production domain (e.g. edusign.sunet.se) to the sataging domain (e.g. test.edusign.sunet.se).

Mail configuration
..................

It is necessary to provide the app with access to some SMTP server,
setting the variables `indicated here <https://flask-mail.readthedocs.io/en/latest/#configuring-flask-mail>`_.

Additional configuration variables
..................................

These need to be set when not using docker-compose to run the environment, but
rather bare `docker run` commands.

For the NGINX container, we need to set variables informing it where to find
the WSGI app, to relay dynamic requests to it:

BACKEND_HOST
    The hostname of the container running the backend WSGI app.
    Default: www

BACKEND_PORT
    The TCP port the WSGI app is listening at.
    Default: 8080

BACKEND_SCHEME
    The protocol to access the WSGI app.
    Default: http

Home Page (Anonymous)
.....................

The anonymous home page at the root of the site takes its content from markdown documents.
There are English and Swedish default md docs under version control, in the
`edusign-app repo <https://github.com/SUNET/edusign-app/tree/master/backend/src/edusign_webapp/md>`_.
These can be overriden by documents `/etc/edusign/home-en.md` and `/etc/edusign/home-sv.md`,
in the `edusign-app` container.
edusign-app:/backend/src/edusign_webapp/md/
