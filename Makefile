.DEFAULT_GOAL := help

# Document each target with one or more comments prefixed with 2 hashes
# right above the target definition.

# Get any extra command line arguments
args=`arg="$(filter-out $@,$(MAKECMDGOALS))" && echo $${arg:-${1}}`

VERSION=2.0.0b7

VERSION_SP=$(VERSION)
NAME_SP=edusign-sp
DIR_SP=nginx

VERSION_APP=$(VERSION)
NAME_APP=edusign-app
DIR_APP=backend
NO_CACHE=true

## Gather customizations from provided path to add them to docker images
.PHONY: customize
customize:
	cp "$(call args)"/md/*.md backend/custom 
	cp "$(call args)"/assets/* nginx/custom 

## Build and publish to docker.sunet.se the APP image
.PHONY: publish-app
publish-app: build-app push-app

## Build the APP image
.PHONY: build-app
build-app:
	docker build --no-cache=$(NO_CACHE) -t $(NAME_APP):$(VERSION_APP) $(DIR_APP)
	docker tag $(NAME_APP):$(VERSION_APP) docker.sunet.se/$(NAME_APP):$(VERSION_APP)

## Build the APP image for development
.PHONY: build-app-develop
build-app-develop:
	docker build --build-arg INSTALL_PACKAGE=develop --no-cache=$(NO_CACHE) -t $(NAME_APP):$(VERSION_APP) $(DIR_APP)
	docker tag $(NAME_APP):$(VERSION_APP) docker.sunet.se/$(NAME_APP):$(VERSION_APP)

## Update the APP image
.PHONY: update-app
update-app:
	docker build -t $(NAME_APP):$(VERSION_APP) $(DIR_APP)
	docker tag $(NAME_APP):$(VERSION_APP) docker.sunet.se/$(NAME_APP):$(VERSION_APP)

## Publish the APP image to docker.sunet.se
.PHONY: push-app
push-app:
	docker push docker.sunet.se/$(NAME_APP):$(VERSION_APP)

## Build the SP image
.PHONY: build-sp
build-sp:
	docker build --no-cache=$(NO_CACHE) -t $(NAME_SP):$(VERSION_SP) $(DIR_SP)
	docker tag $(NAME_SP):$(VERSION_SP) docker.sunet.se/$(NAME_SP):$(VERSION_SP)

## Update the SP image
.PHONY: update-sp
update-sp:
	docker build -t $(NAME_SP):$(VERSION_SP) $(DIR_SP)
	docker tag $(NAME_SP):$(VERSION_SP) docker.sunet.se/$(NAME_SP):$(VERSION_SP)

## Publish the SP image to docker.sunet.se
.PHONY: push-sp
push-sp:
	docker push docker.sunet.se/$(NAME_SP):$(VERSION_SP)

## Build both images
.PHONY: build
build: build-sp build-app

## Push both images to docker.sunet.se
.PHONY: push
push: push-sp push-app

## Build and push both images to docker.sunet.se
.PHONY: publish
publish: build push

## Start the docker environment
.PHONY: env-start
env-start:
	@docker-compose rm -s -f; \
		docker-compose up --detach

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
