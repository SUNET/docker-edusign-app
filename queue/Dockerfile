FROM debian:buster

MAINTAINER eperez@emergya.com

# This will create an image with a virtualenv containing the edusign backend
# sources and gunicorn, and with a script to start a gunicorn process running
# the edusign backend app.

ENV DEBIAN_FRONTEND noninteractive

# Environment attributes

ENV SP_HOSTNAME=sp.edusign.docker
ENV SECRET_KEY=supersecret
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

# Install needed software

RUN apt -y update && apt -y upgrade && \
    apt -y install libffi-dev libssl-dev supervisor \
      git build-essential libpython3-dev python3-cffi python3-venv iputils-ping \
      procps bind9-host netcat-openbsd net-tools curl locales && \
    apt -y clean && \
    rm -rf /var/lib/apt/lists/*

# Set the locale

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Add edusign user to run the service as

RUN addgroup --system edusign
RUN adduser --system --shell /bin/false edusign

# Get the edusign sources from github, pick the backend sources
# and put them in /opt/edusign, and get rid of the rest.

ENV EDUSIGN_APP_VERSION v1.1.0rc13

RUN git clone --depth 1 --branch $EDUSIGN_APP_VERSION https://github.com/SUNET/edusign-app /tmp/edusign-app && \
      mkdir /opt/edusign && \
      mv -f /tmp/edusign-app/backend /opt/edusign/edusign-webapp && \
      chown -R edusign /opt/edusign && \
      rm -rf /tmp/edusign-app

WORKDIR /opt/edusign/edusign-webapp

# Make a python virtualenv, update pip, and install the edusign backend code
# and gunicorn.

RUN python3 -m venv venv
RUN venv/bin/pip install -U pip wheel

RUN venv/bin/pip install -r requirements.txt
RUN venv/bin/python setup.py install

# Copy the supervisor configuration file into its place

COPY ./start.sh /start.sh
COPY ./docker/supervisord.conf /etc/supervisor/conf.d/

CMD ["bash", "/start.sh"]
