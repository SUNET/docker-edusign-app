FROM debian:buster

MAINTAINER eperez@emergya.com

# This will provide an image to create temporary containers that build the
# frontend JS edusign app bundle, place it in an external volume, and exit.
# The volume, named jsbuild, is created and mounted at /opt/jsbuild by
# docker-compose.

ENV DEBIAN_FRONTEND noninteractive

# Intall git and npm

RUN /bin/sed -i s/deb.debian.org/ftp.se.debian.org/g /etc/apt/sources.list

RUN apt -y update && apt -y upgrade && \
    apt -y install npm git && \
    apt -y clean

RUN npm install -U npm -g
RUN rm -rf /var/lib/apt/lists/*

# Get the edusign code from github, pick just the frontend code, and remove the
# rest.

RUN git clone -b release https://github.com/SUNET/edusign-app /tmp/edusign-app
RUN mv -f /tmp/edusign-app/frontend /opt
RUN rm -rf /tmp/edusign-app

WORKDIR /opt/frontend

# Install the needed JS dependencies, build the bundle, and remove said
# dependencies

RUN npm install && npm run build-pro && rm -rf node_modules

# Add the script that will just pick the built bundle, put it in the volume,
# and exit.

COPY ./install.sh /install.sh

ENTRYPOINT ["bash", "/install.sh"]
