FROM debian:buster

MAINTAINER eperez@emergya.com

# This will produce an image to create containers that run a supervisor
# process, supervising 4 child processes:
# 1) A Shibboleth SP shibauthorizer process, used by NGINX to protect
#    certain path(s);
# 2) A Shibboleth SP shibresponder process, used by NGINX to respond for
#    Shibboleth metadata, status data, etc;
# 3) A Shibboleth SP shibd daemon, that does the SAML heavy lifting;
# 4) An NGINX that uses the previous processes to secure certain
#    locations, and proxies the edusign WSGI app at one of those
#    locations.

ENV DEBIAN_FRONTEND noninteractive

# Install needed software.

RUN /bin/sed -i s/deb.debian.org/ftp.se.debian.org/g /etc/apt/sources.list

RUN apt update -y && apt upgrade -y && \
    apt install -y apt-utils  opensaml2-schemas opensaml2-tools xmltooling-schemas libshibsp8 \
        libshibsp-plugins shibboleth-sp2-common shibboleth-sp2-utils procps curl git \
        build-essential fakeroot libpcre3 libpcre3-dev libpcrecpp0v5 libssl-dev \
        openssl zlib1g-dev tar gzip apt-utils mercurial wget libxml2-utils xsltproc \
        lsb-release devscripts quilt supervisor locales

# Set the locale
#
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Add the official NGINX sources repositories and public signing key

RUN touch /etc/apt/sources.list.d/nginx.list
RUN echo "deb http://nginx.org/packages/debian/ buster nginx" >> /etc/apt/sources.list.d/nginx.list
RUN echo "deb-src http://nginx.org/packages/debian/ buster nginx" >> /etc/apt/sources.list.d/nginx.list

WORKDIR /opt
RUN curl -OL  http://nginx.org/keys/nginx_signing.key
RUN apt-key add nginx_signing.key

RUN touch /etc/apt/preferences.d/nginx
RUN echo "Package: nginx" >> /etc/apt/preferences.d/nginx
RUN echo "Pin: release o=nginx" >> /etc/apt/preferences.d/nginx
RUN echo "Pin-Priority: 600" >> /etc/apt/preferences.d/nginx

# Install NGINX

RUN apt update -y && \
        apt install -y nginx && \
        apt clean -y && \
        rm -rf /var/lib/apt/lists/*

# Provide Shibboleth with their SSL certificate

COPY ./config-current/ssl/sp-* /etc/shibboleth/

# Get software that builds NGINX modules

RUN curl -OL http://hg.nginx.org/pkg-oss/archive/tip.tar.gz
RUN tar -xzf tip.tar.gz
RUN mv pkg-* tip

# Build and install the NGINX modules nginx-http-shibboleth and headers-more-nginx

RUN ./tip/build_module.sh -v 1.18.0 https://github.com/nginx-shib/nginx-http-shibboleth.git
RUN mv build-module-artifacts/nginx-module-shibboleth_1.18.0-1~buster_amd64.deb .
RUN rm -rf build-module-artifacts
RUN ./tip/build_module.sh -v 1.18.0 https://github.com/openresty/headers-more-nginx-module.git
RUN mv build-module-artifacts/nginx-module-headersmore_1.18.0-1~buster_amd64.deb .
RUN rm -rf build-module-artifacts
RUN dpkg -i nginx-module-shibboleth_1.18.0-1~buster_amd64.deb nginx-module-headersmore_1.18.0-1~buster_amd64.deb

# Create run directory for shibboleth

RUN mkdir -p /var/run/shibboleth

# Copy NGINX configuration files into /etc/nginx/

COPY ./config-current/nginx.conf /etc/nginx/
COPY ./config-current/shib_fastcgi_params /etc/nginx/
COPY ./config-current/shib_clear_headers /etc/nginx/
COPY ./config-current/fastcgi.conf /etc/nginx/

# Copy the supervisor configuration file into its place

COPY ./config-current/supervisord.conf /etc/supervisor/conf.d/

# Add the SSL certificate for HTTPS at NGINX

RUN mkdir /etc/nginx/ssl/

COPY ./config-current/ssl/nginx.* /etc/nginx/ssl/

# Add the shibboleth configuration files

COPY ./config-current/shibboleth2.xml /etc/shibboleth/
COPY ./config-current/attribute-map.xml /etc/shibboleth/
COPY ./config-current/idp-metadata.xml /etc/shibboleth/
COPY ./config-current/shibd.logger /etc/shibboleth/

# Set supervisord as default main process in containers.

CMD ["/usr/bin/supervisord"]
