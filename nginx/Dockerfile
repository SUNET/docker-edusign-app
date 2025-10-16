FROM debian:bookworm AS builder

# In this temp container we build the frontside bundle and
# the NGINX modules nginx-http-shibboleth and headers-more-nginx

ENV DEBIAN_FRONTEND noninteractive

# Install needed software


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
    && rm -rf /var/lib/apt/lists/*

# Set nginx version
ENV NGINX_VERSION=1.26.2

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

# Create a .deb package using checkinstall
RUN checkinstall -y \
    --pkgname=nginx-custom \
    --pkgversion=${NGINX_VERSION} \
    --pkgrelease=1 \
    --pkggroup=web \
    --maintainer="custom@example.com" \
    --requires="libpcre3,zlib1g,libssl3" \
    --nodoc \
    --strip=yes \
    --stripso=yes \
    --install=no \
    make install

# Create post-install script
RUN mkdir -p /packages
RUN mv *.deb /packages/

# Final stage
FROM debian:bookworm

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpcre3 \
    zlib1g \
    libssl3 \
    libgd3 \
    libgeoip1 \
    && rm -rf /var/lib/apt/lists/*

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
    && chown -R nginx:nginx /var/cache/nginx

# Expose ports
EXPOSE 80 443

# Stop signal
STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]








RUN apt -y update && apt -y upgrade && apt install -y curl gnupg ca-certificates

RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
ENV NODE_MAJOR 20
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

RUN curl -fSsL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /etc/apt/keyrings/nginx-keyring.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/nginx-keyring.gpg] http://nginx.org/packages/mainline/debian bookworm nginx" | tee /etc/apt/sources.list.d/nginx.list

RUN apt -y update && \
    apt -y install git nodejs nginx=1.27.1-1~bookworm build-essential fakeroot \
                   libpcre3 libpcre3-dev libpcre2-dev libparse-recdescent-perl libpcrecpp0v5 libssl-dev \
                   openssl zlib1g-dev tar gzip mercurial curl wget libxml2-utils xsltproc \
                   apt-utils lsb-release devscripts quilt sudo && \
    apt -y clean && \
    rm -rf /var/lib/apt/lists/*

# Get software that builds NGINX modules

RUN mkdir -p /opt/backend/build
WORKDIR /opt/backend

RUN curl -OL http://hg.nginx.org/pkg-oss/archive/tip.tar.gz
RUN tar -xzf tip.tar.gz
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
ENV EDUSIGN_APP_VERSION v1.4.0b303

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
ENV MDQ_BASE_URL=https://mds.swamid.se/
ENV MDQ_SIGNER_CERT=md-signer2.crt
# 20M:
ENV MAX_FILE_SIZE=28730982

# Add the official NGINX sources repositories and public signing key

RUN apt -y update && apt -y upgrade && apt install -y curl gnupg

RUN curl -fSsL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /etc/apt/keyrings/nginx-keyring.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/nginx-keyring.gpg] http://nginx.org/packages/mainline/debian bookworm nginx" | tee /etc/apt/sources.list.d/nginx.list

# Install needed software.

RUN apt update -y && \
    apt install -y apt-utils  opensaml-schemas opensaml-tools xmltooling-schemas ssl-cert less \
                   libshibsp11 libshibsp-plugins shibboleth-sp-common shibboleth-sp-utils procps \
                   libpcre3 libpcrecpp0v5 openssl libxml2-utils xsltproc supervisor locales nginx=1.27.1-1~bookworm wget curl vim && \
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

WORKDIR /opt

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
