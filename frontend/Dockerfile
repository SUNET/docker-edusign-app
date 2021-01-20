FROM debian:buster

MAINTAINER eperez@emergya.com

ENV DEBIAN_FRONTEND noninteractive

RUN /bin/sed -i s/deb.debian.org/ftp.se.debian.org/g /etc/apt/sources.list

RUN apt -y update && apt -y upgrade && \
    apt -y install npm git && \
    apt -y clean

RUN npm install -U npm -g
RUN rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/SUNET/edusign-app@release /tmp
RUN mv -f /tmp/edusign-app/frontend /opt
RUN rm -rf /tmp/edusign-app

WORKDIR /opt/frontend

RUN npm install && npm run build-pro && rm -rf node_modules

ENTRYPOINT ["bash", "/opt/frontend/install.sh"]
