
EduSign app docker environment
==============================

Docker environment for the deployment of an instance of edusign-app.

The environment will consist on 2 docker containers, one running a front facing
NGINX server protected by a Shibboleth SP and proxying the app (edusign-sp),
and another with the eduSign app as a WSGI app driven by Gunicorn
(edusign-app).

This repo also provides the means to buid the docker images and publish them to
docker.sunet.se.

Deployment and building tasks are provided as make targets; type :code:`make
help` at the root of the repository to find out about them.

Building and publishing the apps
--------------------------------

To build the image for edusign-sp, use the target `build-sp`. You can update the
image with `update-sp`, and push it to docker.sunet.se with `push-sp`.

For the edusign-app image, the corresponding targets would be `build-app`,
`update-app`, and `push-app`.

It is also possible to build both images with :code:`make build`, push both
images with :code:`make push`, and build and push both images with :code:`make
publish`.

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

We provide a few configuration values in the form of exported environment
variables in the host. These are listed and explained below. These values can
also reside in an :code:`.env` file in the same directory as the
:code:`docker-compose.yml` file.

After providing these configuration values, we start the environment with
:code:`make env-start`, and stop it with :code:`make env-stop`.

Once the environment is up and running, there are a few files we may want to
update / provide, mainly certificates and metadata:

* SSL certificate for HTTPS, at :code:`/etc/ssl/certs/<SP_HOSTNAME>.crt` and
  :code:`/etc/ssl/private/<SP_HOSTNAME>.key`

* SSL certificate for the Shibboleth SP, at
  :code:`/etc/ssl/certs/shibsp-<SP_HOSTNAME>.crt` and
  :code:`/etc/ssl/private/shibsp-<SP_HOSTNAME>.key`

* Possibly a SAML IdP metadata file, placed at :code:`/etc/shibboleth` and
  referenced in the configuration variable :code:`METADATA_FILE`.

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

Access logs
...........

The available logs can be listed via the command :code:`make logs-list`. They can be
tailed with :code:`make logs-tailf <logfile>`.

Configuration variables
.......................

SP_HOSTNAME
    String. FQDN for the service, as used in the SSL certificate for the NGINX.

DISCO_URL
    String. URL of SAML discovery service to provide to Shibboleth SP.

METADATA_FILE:
    String. If a metadata file is provided to the SP, set the path here.

SECRET_KEY
    String. Key used by the webapp for encryption, e.g. for the sessions.

MAX_FILE_SIZE
    String. Maximum size of uploadable documents, in a format that NGINX understands, e.g. `20M`.

EDUSIGN_API_BASE_URL
    String. Base URL for the eduSign API.

EDUSIGN_API_PROFILE
    String. Profile to use in the eduSign API.

EDUSIGN_API_USERNAME
    String. Username for Basic Auth for the eduSign API.

EDUSIGN_API_PASSWORD
    String. Password for Basic Auth for the eduSign API.

SIGNER_ATTRIBUTES
    String. The attributes to be used for signing, given as
    :code:`<name>,<friendlyName>`, and separated by semicolons. For example:
    :code:`"urn:oid:2.5.4.42,givenName;urn:oid:2.5.4.4,sn"`
