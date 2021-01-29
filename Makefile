.DEFAULT_GOAL := help

# Document each target with one or more comments prefixed with 2 hashes
# right above the target definition.

ENV_DIR=docker/

BACK_DIR=backend/
BACK_SOURCE=src/

# Get any extra command line arguments
args=`arg="$(filter-out $@,$(MAKECMDGOALS))" && echo $${arg:-${1}}`

## -- Configuration commands --

## Build configuration with values from env file (environment-current). If file provided, vars in the diff with the environment-devel provided file must be in the environment. Otherwise environment-devel is used.
.PHONY: config-build
config-build:
	@if [ ! -f environment-current ]; then cp environment environment-current; fi && \
	  if ! grep -q 'DUMMY=dummy' environment-current; then export $$(cat environment-current | xargs); fi && \
		if [ ! -d config-current ]; then mkdir -p config-current/ssl; fi && \
		if [ ! -e config-current/supervisord.conf ]; then cp config-templates/supervisord.conf config-current/supervisord.conf; fi && \
		if [ ! -e config-current/idp-metadata.xml ]; then cp config-templates/idp-metadata.xml config-current/idp-metadata.xml; fi && \
		if [ ! -e config-current/attribute-map.xml ]; then cp config-templates/attribute-map.xml config-current/attribute-map.xml; fi && \
		if [ ! -e config-current/fastcgi.conf ]; then cp config-templates/fastcgi.conf config-current/fastcgi.conf; fi && \
		if [ ! -e config-current/shib_clear_headers ]; then cp config-templates/shib_clear_headers config-current/shib_clear_headers; fi && \
		if [ ! -e config-current/shib_fastcgi_params ]; then cp config-templates/shib_fastcgi_params config-current/shib_fastcgi_params; fi && \
		if [ ! -e config-current/ssl/nginx.crt ]; then cp config-templates/ssl/nginx.crt config-current/ssl/nginx.crt; fi && \
		if [ ! -e config-current/ssl/nginx.key ]; then cp config-templates/ssl/nginx.key config-current/ssl/nginx.key; fi && \
		if [ ! -e config-current/ssl/sp-cert.pem ]; then cp config-templates/ssl/sp-cert.pem config-current/ssl/sp-cert.pem; fi && \
		if [ ! -e config-current/ssl/sp-key.pem ]; then cp config-templates/ssl/sp-key.pem config-current/ssl/sp-key.pem; fi && \
		if [ ! -e config-current/shibd.logger ]; then cp config-templates/shibd.logger config-current/shibd.logger; fi && \
		if [ ! -e config-current/nginx.conf ]; then perl -p -e 's/\$$\{([^}]+)\}/defined $$ENV{$$1} ? $$ENV{$$1} : $$&/eg' < config-templates/nginx.conf > config-current/nginx.conf; fi && \
		if [ ! -e config-current/shibboleth2.xml ]; then perl -p -e 's/\$$\{([^}]+)\}/defined $$ENV{$$1} ? $$ENV{$$1} : $$&/eg' < config-templates/shibboleth2.xml > config-current/shibboleth2.xml; fi && \
		perl -p -e 's/\$$\{([^}]+)\}/defined $$ENV{$$1} ? $$ENV{$$1} : $$&/eg' < config-templates/environment-compose > .env && \
		cp -Rp config-current nginx/

## Build configuration with values from the environment. All env variables present in the provided environment-devel file must be present in the environment.
.PHONY: config-build-from-env
config-build-from-env:
	@echo "DUMMY=dummy" > environment-current
	config-build

## Remove built configuration (NOTE that this command will remove anything provided in ./config-current/).
.PHONY: config-clean
config-clean:
	@rm -rf config-current/ nginx/config-current/ .env

## Build the docker images
.PHONY: build
build:
	@docker-compose build

## Start the docker environment
.PHONY: env-start
env-start:
	@docker-compose rm -s -f; \
		docker-compose up --build --detach

## Stop the docker environment
.PHONY: env-stop
env-stop:
	@docker-compose rm -s -f; \

## Tail some log file
.PHONY: logs-tailf
logs-tailf:
	@docker run -it --rm --init -v edusignlogs:/var/log/edusign debian:buster bash -c "tail -F /var/log/edusign/*$(call args)*"

## List available log files
.PHONY: logs-list
logs-list:
	@docker run -it --rm --init -v edusignlogs:/var/log/edusign debian:buster bash -c "ls /var/log/edusign/"

## Print this help message
.PHONY: help
help:
	@printf "\nUsage: make <target>\n\nTargets:\n";

	@awk '{ \
			if ($$0 ~ /^.PHONY: [a-zA-Z\-_0-9]+$$/) { \
				helpCommand = substr($$0, index($$0, ":") + 2); \
				if (helpMessage) { \
					printf "\033[36m%-20s\033[0m %s\n", \
						helpCommand, helpMessage; \
					helpMessage = ""; \
				} \
			} else if ($$0 ~ /^[a-zA-Z\-_0-9.]+:/) { \
				helpCommand = substr($$0, 0, index($$0, ":")); \
				if (helpMessage) { \
					printf "\033[36m%-20s\033[0m %s\n", \
						helpCommand, helpMessage; \
					helpMessage = ""; \
				} \
			} else if ($$0 ~ /^##/) { \
				if (helpMessage) { \
					helpMessage = helpMessage"\n                     "substr($$0, 3); \
				} else { \
					helpMessage = substr($$0, 3); \
				} \
			} else { \
				if (helpMessage) { \
					print "\n       "helpMessage"\n" \
				} \
				helpMessage = ""; \
			} \
		}' \
		$(MAKEFILE_LIST)
