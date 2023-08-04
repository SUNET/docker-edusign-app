FROM debian:buster

ARG INSTALL_PACKAGE=install

# This will create an image with a virtualenv containing the edusign backend
# sources and gunicorn, and with a script to start a gunicorn process running
# the edusign backend app.

ENV DEBIAN_FRONTEND noninteractive

# Environment attributes

ENV SP_HOSTNAME=sp.edusign.docker
ENV SESSION_COOKIE_NAME=session
ENV SECRET_KEY=supersecret
ENV EDUSIGN_API_BASE_URL=https://sig.idsec.se/signint/v1/
ENV EDUSIGN_API_PROFILE=edusign-test
ENV EDUSIGN_API_USERNAME=dummy
ENV EDUSIGN_API_PASSWORD=dummy
ENV MULTISIGN_BUTTONS=yes
ENV SIGNER_ATTRIBUTES=urn:oid:2.16.840.1.113730.3.1.241,displayName
ENV AUTHN_ATTRIBUTES=urn:oid:1.2.752.201.3.7,eidasPersonIdentifier
ENV FORCE_AUTHN_CONTEXT=
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
# 20M:
ENV MAX_FILE_SIZE=20971520
ENV APP_IN_TWO_PATHS=False

# Install needed software

RUN apt -y update && apt -y upgrade && \
    apt -y install libffi-dev libfreetype6-dev libjpeg62-turbo-dev libssl-dev \
      libtiff5-dev libxml2-dev libxml2-utils libxslt1-dev swig xmlsec1 zlib1g-dev \
      git build-essential iputils-ping libcairo2-dev pkg-config \
      procps bind9-host netcat-openbsd net-tools curl locales libncurses5-dev \
      libgdbm-dev libnss3-dev libsqlite3-dev libreadline-dev libbz2-dev liblzma-dev && \
    apt -y clean && \
    rm -rf /var/lib/apt/lists/*

# Set the locale

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# install python

RUN curl -O https://www.python.org/ftp/python/3.8.9/Python-3.8.9.tar.xz && \
    tar -xf Python-3.8.9.tar.xz && \
    cd Python-3.8.9 && \
    ./configure --enable-optimizations --enable-loadable-sqlite-extensions && \
    make -j 4 && \
    make install && \
    cd .. && \
    rm -rf Python-3.8.9 Python-3.8.9.tar.xz  


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

ENV EDUSIGN_APP_VERSION v2.0.0b30

RUN git clone --depth 1 --branch $EDUSIGN_APP_VERSION https://github.com/SUNET/edusign-app /tmp/edusign-app
RUN mv -f /tmp/edusign-app/backend /opt/edusign/edusign-webapp
RUN rm -rf /tmp/edusign-app

WORKDIR /opt/edusign

# Make a python virtualenv, update pip, and install the edusign backend code
# and gunicorn.

RUN python3 -m venv venv
RUN venv/bin/pip install -U pip wheel

WORKDIR /opt/edusign/edusign-webapp

RUN ../venv/bin/pip install -r requirements.txt
RUN ../venv/bin/python setup.py $INSTALL_PACKAGE
RUN ../venv/bin/pip install gunicorn

# Add the script with the main command.

COPY ./start.sh /start.sh

EXPOSE 8080

ENV DEBUG=false

CMD ["bash", "/start.sh"]
