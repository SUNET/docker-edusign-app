#!/bin/sh -x


printenv

if [ "x$SP_HOSTNAME" = "x" ]; then
   SP_HOSTNAME="sp.edusign.docker"
fi

if [ "x$CERTNAME" = "x" ]; then
   CERTNAME=$SP_HOSTNAME
fi

if [ "x$DISCO_URL" = "x" ]; then
   DISCO_URL="https://md.nordu.net/role/idp.ds"
fi

if [ "x$SP_ABOUT" = "x" ]; then
   SP_ABOUT="/about"
fi

if [ "x$MAX_FILE_SIZE" = "x" ]; then
   MAX_FILE_SIZE="20M"
fi

if [ "x$BACKEND_HOST" = "x" ]; then
   BACKEND_HOST="www"
fi

if [ "x$BACKEND_PORT" = "x" ]; then
   BACKEND_PORT="8080"
fi

if [ "x$BACKEND_PROTO" = "x" ]; then
   BACKEND_PROTO="http"
fi

if [ "x$BACKEND_URL" = "x" ]; then
   BACKEND_URL="$BACKEND_PROTO://$BACKEND_HOST:$BACKEND_PORT"
fi

if [ -z "$KEYDIR" ]; then
   KEYDIR=/etc/ssl
   mkdir -p $KEYDIR
   export KEYDIR
fi

if [ ! -f "$KEYDIR/private/shibsp-${SP_HOSTNAME}.key" -o ! -f "$KEYDIR/certs/shibsp-${SP_HOSTNAME}.crt" ]; then
   shib-keygen -o /tmp -h $SP_HOSTNAME 2>/dev/null
   mv /tmp/sp-key.pem "$KEYDIR/private/shibsp-${SP_HOSTNAME}.key"
   mv /tmp/sp-cert.pem "$KEYDIR/certs/shibsp-${SP_HOSTNAME}.crt"
fi

if [ ! -f "$KEYDIR/private/${CERTNAME}.key" -o ! -f "$KEYDIR/certs/${CERTNAME}.crt" ]; then
   make-ssl-cert generate-default-snakeoil --force-overwrite
   cp /etc/ssl/private/ssl-cert-snakeoil.key "$KEYDIR/private/${CERTNAME}.key"
   cp /etc/ssl/certs/ssl-cert-snakeoil.pem "$KEYDIR/certs/${CERTNAME}.crt"
fi

cp /etc/shibboleth/shibboleth2.xml /etc/shibboleth/shibboleth2.xml.bak
cat>/etc/shibboleth/shibboleth2.xml<<EOF
<SPConfig xmlns="urn:mace:shibboleth:3.0:native:sp:config"
    xmlns:conf="urn:mace:shibboleth:3.0:native:sp:config"
    clockSkew="180">
    <OutOfProcess tranLogFormat="%u|%s|%IDP|%i|%ac|%t|%attr|%n|%b|%E|%S|%SS|%L|%UA|%a" />
  
    <!--
    By default, in-memory StorageService, ReplayCache, ArtifactMap, and SessionCache
    are used. See example-shibboleth2.xml for samples of explicitly configuring them.
    -->
    <!-- The ApplicationDefaults element is where most of Shibboleth's SAML bits are defined. -->
    <ApplicationDefaults entityID="https://${SP_HOSTNAME}/shibboleth"
        REMOTE_USER="eppn subject-id pairwise-id persistent-id"
        attributePrefix="AJP_"
        cipherSuites="DEFAULT:!EXP:!LOW:!aNULL:!eNULL:!DES:!IDEA:!SEED:!RC4:!3DES:!kRSA:!SSLv2:!SSLv3:!TLSv1:!TLSv1.1">
        <!--
        Controls session lifetimes, address checks, cookie handling, and the protocol handlers.
        Each Application has an effectively unique handlerURL, which defaults to "/Shibboleth.sso"
        and should be a relative path, with the SP computing the full value based on the virtual
        host. Using handlerSSL="true" will force the protocol to be https. You should also set
        cookieProps to "https" for SSL-only sites. Note that while we default checkAddress to
        "false", this makes an assertion stolen in transit easier for attackers to misuse.
        -->
        <Sessions lifetime="28800" timeout="3600" relayState="ss:mem"
                  checkAddress="false" handlerSSL="false" cookieProps="http">
            <!--
            Configures SSO for a default IdP. To properly allow for >1 IdP, remove
            entityID property and adjust discoveryURL to point to discovery service.
            You can also override entityID on /Login query string, or in RequestMap/htaccess.
            -->
            <SSO discoveryProtocol="SAMLDS" discoveryURL="${DISCO_URL}">
              SAML2
            </SSO>
            <!-- SAML and local-only logout. -->
            <Logout>SAML2 Local</Logout>
            <!-- Administrative logout. -->
            <LogoutInitiator type="Admin" Location="/Logout/Admin" acl="127.0.0.1 ::1" />
          
            <!-- Extension service that generates "approximate" metadata based on SP configuration. -->
            <Handler type="MetadataGenerator" Location="/Metadata" signing="false"/>
            <!-- Status reporting service. -->
            <Handler type="Status" Location="/Status" acl="127.0.0.1 ::1"/>
            <!-- Session diagnostic service. -->
            <Handler type="Session" Location="/Session" showAttributeValues="false"/>
            <!-- JSON feed of discovery information. -->
            <Handler type="DiscoveryFeed" Location="/DiscoFeed"/>
        </Sessions>
        <!--
        Allows overriding of error template information/filenames. You can
        also add your own attributes with values that can be plugged into the
        templates, e.g., helpLocation below.
        -->
        <Errors supportContact="root@localhost"
            helpLocation="${SP_ABOUT}"
            styleSheet="/shibboleth-sp/main.css"/>
        <MetadataProvider type="XML" validate="false" path="${METADATA_FILE}" maxRefreshDelay="7200">
            <MetadataFilter type="RequireValidUntil" maxValidityInterval="2419200"/>
            <DiscoveryFilter type="Blacklist" matcher="EntityAttributes" trimTags="true" 
              attributeName="http://macedir.org/entity-category"
              attributeNameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri"
              attributeValue="http://refeds.org/category/hide-from-discovery" />
        </MetadataProvider>
        <!-- Example of remotely supplied "on-demand" signed metadata. -->
        <!--
        <MetadataProvider type="MDQ" validate="true" cacheDirectory="mdq"
	            baseUrl="http://mdq.federation.org" ignoreTransport="true">
            <MetadataFilter type="RequireValidUntil" maxValidityInterval="2419200"/>
            <MetadataFilter type="Signature" certificate="mdqsigner.pem" />
        </MetadataProvider>
        -->
        <!-- Map to extract attributes from SAML assertions. -->
        <AttributeExtractor type="XML" validate="true" reloadChanges="false" path="attribute-map.xml"/>
        <!-- Default filtering policy for recognized attributes, lets other data pass. -->
        <AttributeFilter type="XML" validate="true" path="attribute-policy.xml"/>
        <!-- Simple file-based resolvers for separate signing/encryption keys. -->
        <CredentialResolver type="File" use="signing"
            key="${KEYDIR}/private/shibsp-${SP_HOSTNAME}.key" certificate="${KEYDIR}/certs/shibsp-${SP_HOSTNAME}.crt"/>
        <CredentialResolver type="File" use="encryption"
            key="${KEYDIR}/private/shibsp-${SP_HOSTNAME}.key" certificate="${KEYDIR}/certs/shibsp-${SP_HOSTNAME}.crt"/>
        
    </ApplicationDefaults>
    
    <!-- Policies that determine how to process and authenticate runtime messages. -->
    <SecurityPolicyProvider type="XML" validate="true" path="security-policy.xml"/>
    <!-- Low-level configuration about protocols and bindings available for use. -->
    <ProtocolProvider type="XML" validate="true" reloadChanges="false" path="protocols.xml"/>
</SPConfig>
EOF

cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
cat>/etc/nginx/nginx.conf<<EOF
load_module modules/ngx_http_shibboleth_module.so;
load_module modules/ngx_http_headers_more_filter_module.so;

user www-data;
worker_processes  1;

events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    charset utf-8;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;
    client_max_body_size ${MAX_FILE_SIZE};

    fastcgi_read_timeout 3000;
    proxy_read_timeout 3000;

    access_log /var/log/edusign/nginx-access.log;
    error_log /var/log/edusign/nginx-error.log crit;

    server {
      listen 80 default_server;
      server_name ${SP_HOSTNAME};
      location ^~ /.well-known/acme-challenge/ {
          proxy_pass http://${ACMEPROXY}/.well-known/acme-challenge/;
      }
      location / {
          return 301 https://\$host\$request_uri;
      }
    }

    server {
      listen 443 ssl;
      server_name ${SP_HOSTNAME};
      root /opt/public;

      ssl_certificate ${KEYDIR}/certs/${CERTNAME}.crt;
      ssl_certificate_key ${KEYDIR}/private/${CERTNAME}.key;
      ssl_session_timeout 1d;
      ssl_session_cache shared:SSL:50m;
      ssl_session_tickets off;

      ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
      ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
      ssl_prefer_server_ciphers on;
 
      location ^~ /.well-known/acme-challenge/ {
          proxy_pass http://${ACMEPROXY}/.well-known/acme-challenge/;
      }

    # FastCGI authorizer for Shibboleth Auth Request module
      location = /shibauthorizer {
        internal;
        include shib_fastcgi_params;
        fastcgi_pass unix:/var/run/shibboleth/shibauthorizer.sock;
      }

    # FastCGI responder for SSO
      location /Shibboleth.sso {
        include shib_fastcgi_params;
        fastcgi_pass unix:/var/run/shibboleth/shibresponder.sock;
      }

    # Location secured by Shibboleth
      location /sign {
        shib_request /shibauthorizer;
        shib_request_use_headers on;
        include shib_clear_headers;
        proxy_pass ${BACKEND_URL};
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
        proxy_redirect default;
        proxy_buffering off;
      }

      location /js {
          alias /opt/jsbuild;
      }
    }
}
EOF

echo "----"
cat /etc/shibboleth/shibboleth2.xml
echo "----"
cat /etc/nginx/nginx.conf

exec /usr/bin/supervisord
