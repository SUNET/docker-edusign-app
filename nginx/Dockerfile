# Builder stage
FROM debian:bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpcre3-dev \
    zlib1g-dev \
    libssl-dev \
    libgd-dev \
    libgeoip-dev \
    wget \
    git \
    checkinstall \
    curl \
    gnupg \
    ca-certificates \
    tar \
    gzip \
    mercurial \
    quilt \
    sudo \
    fakeroot \
    apt-utils \
    lsb-release \
    devscripts \
    libparse-recdescent-perl \
    libpcrecpp0v5 \
    libxml2-utils \
    xsltproc \
    && rm -rf /var/lib/apt/lists/*

# Set nginx version
ENV NGINX_VERSION=1.29.2

# Download and extract nginx
WORKDIR /tmp
RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar -xzf nginx-${NGINX_VERSION}.tar.gz

# Clone the modules
RUN git clone https://github.com/nginx-shib/nginx-http-shibboleth.git \
    && git clone https://github.com/openresty/headers-more-nginx-module.git

# Compile nginx with modules
WORKDIR /tmp/nginx-${NGINX_VERSION}
RUN ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-http_v2_module \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-http_slice_module \
    --with-file-aio \
    --add-module=/tmp/nginx-http-shibboleth \
    --add-module=/tmp/headers-more-nginx-module \
    && make

# Install to a staging directory
RUN make install DESTDIR=/tmp/nginx-install

# Create directory structure for the package
RUN mkdir -p /tmp/nginx-package/DEBIAN \
    && mkdir -p /tmp/nginx-package \
    && mkdir -p /packages

# Copy installed files to package directory
RUN cp -a /tmp/nginx-install/* /tmp/nginx-package/

# Create control file
RUN echo "Package: nginx-custom\n\
Version: ${NGINX_VERSION}-1\n\
Section: web\n\
Priority: optional\n\
Architecture: amd64\n\
Depends: libpcre3, zlib1g, libssl3, libgd3, libgeoip1\n\
Maintainer: Custom <custom@example.com>\n\
Description: Nginx with Shibboleth and Headers More modules\n\
 Custom build of nginx ${NGINX_VERSION} with additional modules:\n\
 - nginx-http-shibboleth\n\
 - headers-more-nginx-module" > /tmp/nginx-package/DEBIAN/control

# Build the .deb package
RUN dpkg-deb --build /tmp/nginx-package /packages/nginx-custom_${NGINX_VERSION}-1_amd64.deb

# Build JS bundle

RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
ENV NODE_MAJOR=20
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

RUN apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Get the edusign code from github, pick just the frontend code, and remove the
# rest.
#
ENV EDUSIGN_APP_VERSION=v1.5.2b45

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

# Final stage
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

ENV DEBIAN_FRONTEND=noninteractive

ENV SP_HOSTNAME=sp.edusign.docker
ENV DISCO_URL=https://md.nordu.net/role/idp.ds
ENV BANKID_ENTITY_ID=https://bankidp.qa.swamid.se/bankid/idp
ENV BANKID_MD_PATH=/etc/shibboleth/bankid-metadata.xml
ENV FREJA_ENTITY_ID=https://idp-sweden-connect-valfr-2017-sandbox.test.frejaeid.com
ENV MDQ_BASE_URL=https://mds.swamid.se/qa/
ENV MDQ_SIGNER_CERT=md-signer2.crt
ENV MDQ_SIGNER_CERT_URL=https://mds.swamid.se/qa/md/swamid-qa.crt
ENV MDQ_BASE_URL_EID=https://mds.swamid.se/qa/
ENV MDQ_SIGNER_CERT_EID=md-signer2.crt
ENV MDQ_SIGNER_CERT_URL_EID=https://mds.swamid.se/qa/md/swamid-qa.crt

# 20M:
ENV MAX_FILE_SIZE=28730982

ENV BACKEND_HOST=edusign-app
ENV BACKEND_PORT=8080
ENV BACKEND_SCHEME=http
ENV SSL_CERT_DIR=./ssl

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpcre3 \
    zlib1g \
    libssl3 \
    libgd3 \
    libgeoip1 \
    apt-utils  \
    opensaml-schemas \
    opensaml-tools \
    xmltooling-schemas \
    ssl-cert \
    less \
    libshibsp11 \
    libshibsp-plugins \
    shibboleth-sp-common \
    shibboleth-sp-utils \
    procps \
    libpcrecpp0v5 \
    openssl \
    libxml2-utils \
    xsltproc \
    supervisor \
    locales \
    wget \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Set the locale
#
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Copy the .deb package from builder
COPY --from=builder /packages/*.deb /tmp/

# Install the package
RUN dpkg -i /tmp/*.deb \
    && rm /tmp/*.deb

# Create nginx user and required directories
RUN useradd -r -s /bin/false nginx || true \
    && mkdir -p /var/cache/nginx/client_temp \
    && mkdir -p /var/cache/nginx/proxy_temp \
    && mkdir -p /var/cache/nginx/fastcgi_temp \
    && mkdir -p /var/cache/nginx/uwsgi_temp \
    && mkdir -p /var/cache/nginx/scgi_temp \
    && mkdir -p /var/log/nginx \
    && mkdir -p /var/log/supervisor \
    && mkdir -p /var/log/edusign \
    && mkdir -p /usr/lib/nginx/modules \
    && mkdir -p /var/run/shibboleth \
    && chown -R www-data:www-data /usr/lib/nginx/modules \
    && chown -R www-data:www-data /var/cache/nginx \
    && chown -R www-data:www-data /var/log/nginx \
    && chmod -R 777 /var/log

# Expose ports
EXPOSE 80 443

WORKDIR /opt

# Get the js bundle built in the builder image
#
COPY --from=builder /opt/frontend/build jsbuild
COPY --from=builder /opt/frontend/public public
COPY docker/assets assets
COPY custom/* assets/*

# Create run directory for shibboleth

RUN mkdir -p /var/run/shibboleth

# Copy NGINX configuration files into /etc/nginx/

COPY ./docker/fastcgi.conf /etc/nginx/
COPY ./docker/shib_fastcgi_params /etc/nginx/
COPY ./docker/shib_clear_headers /etc/nginx/

# Copy the supervisor configuration file into its place

COPY ./docker/supervisord.conf /etc/supervisor/conf.d/

# Add the shibboleth attribute map

COPY ./docker/attribute-map.xml /etc/shibboleth/

COPY $SSL_CERT_DIR /etc
RUN curl $MDQ_SIGNER_CERT_URL -o /etc/shibboleth/$MDQ_SIGNER_CERT
RUN curl $MDQ_SIGNER_CERT_URL_EID -o /etc/shibboleth/$MDQ_SIGNER_CERT_EID

# Copy start script and set it as entry point
#
COPY ./start.sh /start.sh

CMD ["bash", "/start.sh"]
