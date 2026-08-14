FROM debian:bookworm

# This will create an image with a virtualenv containing the edusign backend
# sources and gunicorn, and with a script to start a gunicorn process running
# the edusign backend app.

ENV DEBIAN_FRONTEND=noninteractive

# Environment attributes

ENV SP_HOSTNAME=sp.edusign.docker
ENV SESSION_COOKIE_NAME=session
ENV SECRET_KEY=supersecret
ENV EDUSIGN_API_BASE_URL=https://sig.idsec.se/signint/v1/
ENV EDUSIGN_API_PROFILE=edusign-test
ENV EDUSIGN_API_USERNAME=dummy
ENV EDUSIGN_API_PASSWORD=dummy
ENV EDUSIGN_API_PROFILE_BANKID=edusign-bankid-test
ENV EDUSIGN_API_USERNAME_BANKID=dummy
ENV EDUSIGN_API_PASSWORD_BANKID=dummy
ENV EDUSIGN_API_PROFILE_FREJA=edusign-freja-test
ENV EDUSIGN_API_USERNAME_FREJA=dummy
ENV EDUSIGN_API_PASSWORD_FREJA=dummy
ENV MULTISIGN_BUTTONS=yes
ENV SIGNER_ATTRIBUTES=urn:oid:2.16.840.1.113730.3.1.241,displayName
ENV SIGNER_ATTRIBUTES_20=urn:oid:2.16.840.1.113730.3.1.241,displayName
ENV SIGNER_ATTRIBUTES_BANKID=urn:oid:2.16.840.1.113730.3.1.241,displayName
ENV SIGNER_ATTRIBUTES_FREJA=urn:oid:2.16.840.1.113730.3.1.241,displayName
ENV AUTHN_ATTRIBUTES_BANKID=urn:oid:1.2.752.29.4.13,personalIdentityNumber
ENV AUTHN_ATTRIBUTES_FREJA=urn:oid:1.2.752.29.4.13,personalIdentityNumber
ENV SIGN_REQUESTER_ID=https://sig.idsec.se/shibboleth
ENV SCOPE_WHITELIST=sunet.se,eduid.se
ENV USER_BLACKLIST=blacklisted@eduid.se
ENV STORAGE_CLASS_PATH=edusign_webapp.document.storage.local.LocalStorage
ENV LOCAL_STORAGE_BASE_DIR=/tmp
ENV AWS_ENDPOINT_URL=none
ENV AWS_ACCESS_KEY=dummy
ENV AWS_SECRET_ACCESS_KEY=dummy
ENV AWS_REGION_NAME=eu-north-1
ENV AWS_BUCKET_NAME=edusign-storage
ENV DOC_METADATA_CLASS_PATH=edusign_webapp.document.metadata.sqlite.SqliteMD
ENV SQLITE_MD_DB_PATH=/tmp/test.db
ENV REDIS_URL=redis://localhost:6379/0
ENV MAIL_SERVER=localhost
ENV MAIL_PORT=25
ENV MAIL_USERNAME=dummy
ENV MAIL_PASSWORD=dummy
ENV MAIL_DEFAULT_SENDER=no-reply@localhost
ENV MAIL_USE_TLS=false
ENV MAIL_USE_SSL=false
ENV MAIL_SUPPRESS_SEND=false
ENV MAIL_ASCII_ATTACHMENTS=false
ENV POLLING=always
# 20M:
ENV MAX_FILE_SIZE=28730982
ENV MAX_FILE_SIZE_FRONT=20971520
ENV HASH_METHOD=scrypt

ENV ALLOW_BANKID=true
ENV EID_WHITELIST=sunet.se,eduid.se
ENV BANKID_IDP=https://sandbox.swedenconnect.se/bankid/idp
ENV BANKID_SSN_ATTR=urn:oid:1.2.752.29.4.13
ENV FREJA_IDP=https://idp-sweden-connect-valfr-2017-sandbox.test.frejaeid.com
ENV FREJA_SSN_ATTR=urn:oid:1.2.752.29.4.13

# Gunicorn tuning
ENV GUNICORN_WORKERS=5
ENV GUNICORN_WORKER_CLASS=gthread
ENV GUNICORN_WORKER_THREADS=4
ENV GUNICORN_WORKER_TIMEOUT=30

# Install needed software

RUN apt -y update && apt -y upgrade && \
    apt -y install libffi-dev libfreetype6-dev libjpeg62-turbo-dev libssl-dev \
      libtiff5-dev libxml2-dev libxml2-utils libxslt1-dev swig xmlsec1 zlib1g-dev \
      git build-essential iputils-ping libcairo2-dev pkg-config \
      procps bind9-host netcat-openbsd net-tools curl locales \
      libpq-dev && \
    apt -y clean && \
    rm -rf /var/lib/apt/lists/*

# Set the locale

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# install uv; it manages the virtualenv and downloads the CPython pinned
# in the backend's .python-version file.

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# The default python install dir is under /root, which the edusign user
# that runs gunicorn cannot read.
ENV UV_PYTHON_INSTALL_DIR=/opt/edusign/python


# Add edusign user to run the service as

RUN addgroup --system edusign
RUN adduser --system --shell /bin/false edusign

# Create run and log directories

RUN mkdir -p /var/log/edusign
RUN chown -R edusign /var/log/edusign
RUN chmod -R 770 /var/log/edusign

RUN mkdir -p /opt/edusign/run
RUN chown -R edusign /opt/edusign/run
RUN chmod -R 770 /opt/edusign/run

# Add custom markdown pages

RUN mkdir -p /etc/edusign
RUN chown -R edusign /etc/edusign
RUN chmod -R 770 /etc/edusign

COPY custom/*.md /etc/edusign

# Get the edusign sources from github, pick the backend sources
# and put them in /opt/edusign, and get rid of the rest.

ENV EDUSIGN_APP_VERSION=v1.6.2b35

RUN git clone --depth 1 --branch $EDUSIGN_APP_VERSION https://github.com/SUNET/edusign-app /tmp/edusign-app
RUN mv -f /tmp/edusign-app/backend /opt/edusign/edusign-webapp
RUN rm -rf /tmp/edusign-app

WORKDIR /opt/edusign/edusign-webapp

# Create the venv at /opt/edusign/venv with the locked dependencies and the
# edusign backend code (installed editable, pointing at
# /opt/edusign/edusign-webapp/src). pip is seeded into the venv because
# start.sh runs `pip freeze`; gunicorn is a deployment concern kept out of
# the project dependencies.

ENV UV_PROJECT_ENVIRONMENT=/opt/edusign/venv
RUN uv sync --frozen --no-dev
RUN uv pip install --python /opt/edusign/venv pip gunicorn

# Add the script with the main command.

COPY ./start.sh /start.sh

EXPOSE 8080

ENV DEBUG=false

CMD ["bash", "/start.sh"]
