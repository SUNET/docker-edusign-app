
EduSign app docker environment
==============================

Docker environment for the deployment of an instance of edusign-app.

The environment will consist on 2 docker containers, one running a front facing
NGINX server protected by a Shibboleth SP and proxying the app, and another
with the eduSign app as a WSGI app driven by Gunicorn.

Essentially, deployment will involve providing configuration and starting a
docker compose environment.

Deployment tasks are provided as make commands; type :code:`make help` at the
root of the repository to find out about them.

Prerequisites
.............

* A server with a public IP and domain name.
* An SSL certificate for the domain name.
* Docker daemon running on the server, and docker-compose available (tested with docker engine 20.10.2
  and 20.20.2, and docker-compose 1.27.4).
* A SAML2 IdP/federation that has established trust with the API and is ready to do the same with us.
* A clone of the SUNET/docker-edusign-app repository in the server.

Configuration
.............

First we need to provide the SSL certificates for NGINX and for the Shibboleth
SP. These need to be named :code:`nginx.crt`, :code:`nginx.key`, :code:`sp-cert.pem`, and
:code:`sp-key.pem`.

.. code-block:: bash

 $ cd docker-edusign-app
 $ mkdir -p config-current/ssl
 $ cp <wherever>/nginx.* config-current/ssl/
 $ cp <wherever>/sp-* config-current/ssl/

Then we need to provide the IdP metadata, in a file named idp-metadata.xml. If
we are instead dealing with a federation, we would need to configure it by
editing the configuration at :code:`shibboleth2.xml`, see below.

.. code-block:: bash

 $ cp <wherever>/idp-metadata.xml config-current/

Then we need to provide values to some settings. These can reside in an
environment file :code:`environment-current` or be exported as environment variables.
The settings needed are listed in the file :code:`environment` at the root of the
repo, see below for an explanation of each of them.  So to add them in a file,
do:

.. code-block:: bash

 $ cp environment environment-current
 $ vim environment-current

And then we build the configuration files using these values:

.. code-block:: bash

 $ make config-build

This command will pick the files in :code:`config-templates`, replace in them
the variables in :code:`environment-current` with their values, and (when not
yet present there) place them in :code:`config-current`. These are files that
the Dockerfiles will :code:`COPY` into the containers as appropriate. The
command will also use the contents of :code:`environment-current` to produce an
:code:`.env` file that will inject environment variables into
:code:`docker-compose`.

If, instead, we want to provide the settings as exported environment variables,
we would export them and then run:

.. code-block:: bash

 $ make config-build-from-env

We may now want to edit any of the configuration files in
:code:`config-current/` (e.g., if we deal with a federation instead of an IdP,
we would edit :code:`config-current/shibboleth2.xml`). If we do so, after
editing them we would again execute :code:`make config-build` to again
distribute the files for the Dockerfiles to be able to pick them.

Attributes used for signing
...........................

By default, we use the given name :code:`givenName`, the surname :code:`sn` and
the email address :code:`mail` as attributes for signing the documents. This
list can be altered; if we do so, there are 4 different places which we need to
be aware of.  One is the :code:`SIGNER_ATTRIBUTES` setting in
:code:`environment-current` as we show below. Then, whatever attributes are
used must be taken into account in the files :code:`attribute-map.xml`,
:code:`shib_clear_headers`, and :code:`shib_fastcgi_params`.

Since having extra attributes in those 3 files, not actually used for signing,
would not pose a problem, it would be best to provide "out of the box" in those
files *all* attributes that might be used for signing in any possible
deployment, so that we don't need to edit them in each deployment. Note that in
the :code:`attribute-map.xml` the attributes must be set with an
:code:`AttributeDecoder` with type :code:`StringAttributeDecoder`.

Start docker compose environment
................................

Execute the command :code:`make env-start`. To stop the environment, the
:code:`make env-stop` command should be used.

Access logs
...........

The available logs can be listed via the command :code:`make logs-list`. They can be
tailed with :code:`make logs-tailf <logfile>`.

Configuration variables
.......................

SERVER_NAME
    String. FQDN for the service, as used in the SSL certificate for the NGINX.

SECRET_KEY
    String. Key used by the webapp for encryption, e.g. for the sessions.

EDUSIGN_API_BASE_URL
    String. Base URL for the eduSign API.

EDUSIGN_API_PROFILE
    String. Profile to use in the eduSign API.

EDUSIGN_API_USERNAME
    String. Username for Basic Auth for the eduSign API.

EDUSIGN_API_PASSWORD
    String. Password for Basic Auth for the eduSign API.

SP_ENTITY_ID
    String. SAML2 Entity ID of the service as an SP.

IDP_ENTITY_ID
    String. SAML2 Entity ID of the IdP, used to configure the
    :code:`shibboleth2.xml` file for the Shibboleth SP. It may be necessary to
    actually edit the file if we have >1 IdP and need to configure a discovery
    service.

SIGNER_ATTRIBUTES
    String. The attributes to be used for signing, given as
    :code:`<name>,<friendlyName>`, and separated by semicolons. For example:
    :code:`"urn:oid:2.5.4.42,givenName;urn:oid:2.5.4.4,sn"`
