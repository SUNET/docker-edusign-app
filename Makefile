.DEFAULT_GOAL := help

# Document each target with one or more comments prefixed with 2 hashes
# right above the target definition.

# Get any extra command line arguments
args=`arg="$(filter-out $@,$(MAKECMDGOALS))" && echo $${arg:-${1}}`

VERSION_SP=latest
NAME_SP=edusign-sp
DIR_SP=nginx

VERSION_APP=latest
NAME_APP=edusign-app
DIR_APP=backend

## Build and publish to docker.sunet.se the APP image
.PHONY: publish-app
publish-app: build-app push-app

## Build the APP image
.PHONY: build-app
build-app:
	@cd $(DIR_APP)
	docker build --no-cache=false -t $(NAME_APP):$(VERSION_APP) .
	docker tag $(NAME_APP):$(VERSION_APP) docker.sunet.se/$(NAME_APP):$(VERSION_APP)

## Update the APP image
.PHONY: update-app
update-app:
	@cd $(DIR_APP)
	docker build -t $(NAME_APP):$(VERSION_APP) .
	docker tag $(NAME_APP):$(VERSION_APP) docker.sunet.se/$(NAME_APP):$(VERSION_APP)

## Publish the APP image to docker.sunet.se
.PHONY: push-app
push-app:
	@cd $(DIR_APP)
	docker push docker.sunet.se/$(NAME_APP):$(VERSION_APP)

## Build and publish to docker.sunet.se the SP image
.PHONY: publish-sp
publish-sp: build-sp push-sp

## Build the SP image
.PHONY: build-sp
build-sp:
	@cd $(DIR_SP)
	docker build --no-cache=false -t $(NAME_SP):$(VERSION_SP) .
	docker tag $(NAME_SP):$(VERSION_SP) docker.sunet.se/$(NAME_SP):$(VERSION_SP)

## Update the SP image
.PHONY: update-sp
update-sp:
	@cd $(DIR_SP)
	docker build -t $(NAME_SP):$(VERSION_SP) .
	docker tag $(NAME_SP):$(VERSION_SP) docker.sunet.se/$(NAME_SP):$(VERSION_SP)

## Publish the SP image to docker.sunet.se
.PHONY: push-sp
push-sp:
	@cd $(DIR_SP)
	docker push docker.sunet.se/$(NAME_SP):$(VERSION_SP)

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
