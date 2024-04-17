FROM debian:bookworm AS builder

MAINTAINER eperez@emergya.com

# In this temp container we build the frontside bundle and
# the NGINX modules nginx-http-shibboleth and headers-more-nginx

ENV DEBIAN_FRONTEND noninteractive

# Install needed software

RUN apt -y update && apt -y upgrade && apt install -y curl gnupg ca-certificates

RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
ENV NODE_MAJOR 20
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update && apt-get install nodejs -y

RUN touch /etc/apt/sources.list.d/nginx.list
RUN echo "deb http://nginx.org/packages/debian/ bookworm nginx" >> /etc/apt/sources.list.d/nginx.list
RUN echo "deb-src http://nginx.org/packages/debian/ bookworm nginx" >> /etc/apt/sources.list.d/nginx.list

WORKDIR /opt
RUN curl -OL  http://nginx.org/keys/nginx_signing.key
RUN apt-key add nginx_signing.key

RUN touch /etc/apt/preferences.d/nginx
RUN echo "Package: nginx" >> /etc/apt/preferences.d/nginx
RUN echo "Pin: release o=nginx" >> /etc/apt/preferences.d/nginx
RUN echo "Pin-Priority: 600" >> /etc/apt/preferences.d/nginx

RUN apt -y update && \
    apt -y install git nginx build-essential fakeroot \
                   libpcre3 libpcre3-dev libpcre2-dev libparse-recdescent-perl libpcrecpp0v5 libssl-dev \
                   openssl zlib1g-dev tar gzip mercurial curl wget libxml2-utils xsltproc \
                   apt-utils lsb-release devscripts quilt sudo && \
    apt -y clean && \
    rm -rf /var/lib/apt/lists/*

# Get software that builds NGINX modules

RUN mkdir -p /opt/backend/build
WORKDIR /opt/backend

RUN curl -OL http://hg.nginx.org/pkg-oss/archive/default.tar.gz
RUN tar -xzf default.tar.gz
RUN mv pkg-* tip

# Build the NGINX modules nginx-http-shibboleth and headers-more-nginx
# see https://tcg.stanford.edu/?p=131

RUN curl -X GET http://hg.nginx.org/xslscript/raw-file/tip/xslscript.pl -o /usr/local/bin/xslscript.pl
RUN chmod 755 /usr/local/bin/xslscript.pl

RUN ./tip/build_module.sh -v "$(echo $(nginx -v 2>&1) | grep -o '[0-9.]*$')" https://github.com/nginx-shib/nginx-http-shibboleth.git
#RUN mv build-module-artifacts/nginx-module-shibboleth_1.18.0-1~buster_amd64.deb build/
RUN mv build-module-artifacts/*.deb build/
RUN rm -rf build-module-artifacts
RUN ./tip/build_module.sh -v "$(echo $(nginx -v 2>&1) | grep -o '[0-9.]*$')" https://github.com/openresty/headers-more-nginx-module.git
#RUN mv build-module-artifacts/nginx-module-headersmore_1.18.0-1~buster_amd64.deb build/
RUN mv build-module-artifacts/*.deb build/
RUN rm -rf build-module-artifacts

# Get the edusign code from github, pick just the frontend code, and remove the
# rest.
#
ENV EDUSIGN_APP_VERSION v1.4.0b167

RUN git clone --depth 1 --branch $EDUSIGN_APP_VERSION https://github.com/SUNET/edusign-app /tmp/edusign-app
RUN mv -f /tmp/edusign-app/frontend /opt
RUN rm -rf /tmp/edusign-app

WORKDIR /opt/frontend

# Install the needed JS dependencies, build the bundle, and remove said
# dependencies

RUN npm install && npm run build-pro && npm run build-dev && cp node_modules/pdfjs-dist/build/pdf.worker* build/ && rm -rf node_modules

#----------------------------
# End builder image
#----------------------------

FROM debian:bookworm AS sp

# This will produce an image to create containers that run a supervisor
# process, supervising 4 child processes:
# 1) A Shibboleth SP shibauthorizer process, used by NGINX to protect
#    certain path(s);
# 2) A Shibboleth SP shibresponder process, used by NGINX to respond for
#    Shibboleth metadata, status data, etc;
# 3) A Shibboleth SP shibd daemon, that does the SAML heavy lifting;
# 4) An NGINX that uses the previous processes to secure certain
#    locations, proxies the edusign WSGI app at one of those
#    locations, and serves the JS bundles statically.

ENV DEBIAN_FRONTEND noninteractive

ENV SP_HOSTNAME=sp.edusign.docker
ENV DISCO_URL=https://md.nordu.net/role/idp.ds
# 20M:
ENV MAX_FILE_SIZE=20971520

# Add the official NGINX sources repositories and public signing key

RUN apt -y update && apt -y upgrade && apt install -y curl gnupg

RUN touch /etc/apt/sources.list.d/nginx.list
RUN echo "deb http://nginx.org/packages/debian/ bookworm nginx" >> /etc/apt/sources.list.d/nginx.list
RUN echo "deb-src http://nginx.org/packages/debian/ bookworm nginx" >> /etc/apt/sources.list.d/nginx.list

WORKDIR /opt
RUN curl -OL  http://nginx.org/keys/nginx_signing.key
RUN apt-key add nginx_signing.key

RUN touch /etc/apt/preferences.d/nginx
RUN echo "Package: nginx" >> /etc/apt/preferences.d/nginx
RUN echo "Pin: release o=nginx" >> /etc/apt/preferences.d/nginx
RUN echo "Pin-Priority: 600" >> /etc/apt/preferences.d/nginx

# Install needed software.

RUN apt update -y && \
    apt install -y apt-utils  opensaml-schemas opensaml-tools xmltooling-schemas ssl-cert less \
                   libshibsp11 libshibsp-plugins shibboleth-sp-common shibboleth-sp-utils procps \
                   libpcre3 libpcrecpp0v5 openssl libxml2-utils xsltproc supervisor locales nginx wget curl vim && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists/*

# Set the locale
#
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install the NGINX modules nginx-http-shibboleth and headers-more-nginx previously built in the builder image

RUN mkdir build
COPY --from=builder /opt/backend/build/* build/
RUN dpkg -i build/*.deb
#RUN dpkg -i build/nginx-module-shibboleth_1.18.0-1~buster_amd64.deb build/nginx-module-headersmore_1.18.0-1~buster_amd64.deb

# Get the js bundle built in the builder image
#
COPY --from=builder /opt/frontend/build jsbuild
COPY --from=builder /opt/frontend/public public
COPY docker/assets assets
COPY custom/* assets/*

# Create run directory for shibboleth

RUN mkdir -p /var/run/shibboleth

# Create log directories
#
RUN mkdir -p /var/log/supervisor
RUN mkdir -p /var/log/edusign
RUN mkdir -p /var/log/nginx
RUN chmod -R 777 /var/log

# Copy NGINX configuration files into /etc/nginx/

COPY ./docker/fastcgi.conf /etc/nginx/
COPY ./docker/shib_fastcgi_params /etc/nginx/
COPY ./docker/shib_clear_headers /etc/nginx/

# Copy the supervisor configuration file into its place

COPY ./docker/supervisord.conf /etc/supervisor/conf.d/

# Add the shibboleth attribute map

COPY ./docker/attribute-map.xml /etc/shibboleth/

# Copy start script and set it as entry point
#
COPY start.sh /start.sh

CMD ["bash", "/start.sh"]
