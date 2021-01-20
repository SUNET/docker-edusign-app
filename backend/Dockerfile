FROM debian:buster

MAINTAINER eperez@emergya.com

ENV DEBIAN_FRONTEND noninteractive

RUN /bin/sed -i s/deb.debian.org/ftp.se.debian.org/g /etc/apt/sources.list

RUN apt -y update && apt -y upgrade && \
    apt -y install libffi-dev libfreetype6-dev libjpeg62-turbo-dev libssl-dev \
      libtiff5-dev libxml2-dev libxml2-utils libxslt1-dev swig xmlsec1 zlib1g-dev \
      git build-essential libpython3-dev python3-cffi python3-venv iputils-ping \
      procps bind9-host netcat-openbsd net-tools curl locales && \
    apt -y clean

RUN apt clean
RUN rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN addgroup --system edusign
RUN adduser --system --shell /bin/false edusign

RUN mkdir -p /var/log/edusign
RUN chown -R edusign: /var/log/edusign
RUN chmod -R 770 /var/log/edusign

RUN mkdir -p /opt/edusign/run
RUN chown -R edusign: /opt/edusign/run
RUN chmod -R 770 /opt/edusign/run

RUN git clone https://github.com/SUNET/edusign-app@release /tmp
RUN mv -f /tmp/edusign-app/backend /opt/edusign/edusign-webapp
RUN rm -rf /tmp/edusign-app

WORKDIR /opt/edusign/edusign-webapp

RUN python3 -m venv venv
RUN venv/bin/pip install -U pip wheel

RUN venv/bin/python setup.py install
RUN venv/bin/pip install gunicorn

COPY ./start.sh /start.sh

EXPOSE 8080

CMD ["bash", "/start.sh"]
