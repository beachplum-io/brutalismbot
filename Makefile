name    := brutalismbot
runtime := ruby2.5
build   := $(shell git describe --tags --always)

.PHONY: all apply clean shell test

all: Gemfile.lock lambda.zip .docker/$(build)@plan

.docker:
	mkdir -p $@

.docker/%: Gemfile | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TF_VAR_release=$(firstword $(subst @, ,$*)) \
	--iidfile $@ \
	--target $(lastword $(subst @, ,$*)) \
	--tag brutalismbot/$(name):$(subst @,_,$*) .

Gemfile.lock: .docker/$(build)@build
	docker run --rm -w /var/task/ $(shell cat $<) cat $@ > $@

lambda.zip: .docker/$(build)@build
	docker run --rm -w /var/task/ $(shell cat $<) zip -r - Gemfile* lambda.rb vendor > $@

apply: .docker/$(build)@plan | .docker/$(build)@build
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(shell cat $<)

clean:
	-docker rmi -f \
	$(foreach i,\
	$(shell docker image ls -q --no-trunc),\
	$(shell [ -d .docker ] && grep -ho "$i" .docker/*))
	-rm -rf .docker .terraform *.zip

shell: .docker/$(build)@plan | .env .docker/$(build)@build
	docker run --rm -it --env-file .env $(shell cat $<) /bin/bash

test: .docker/$(build)@runtime | .env .docker/$(build)@build .docker/$(build)@plan
	echo "\nTEST"
	docker run --rm --env-file .env --env DRYRUN=1 $(shell cat $<) lambda.test
	echo "\nINSTALL"
	docker run --rm --env-file .env --env DRYRUN=1 $(shell cat $<) lambda.install \
	'{"Records":[{"Sns":{"Message":"{\"ok\":true,\"access_token\":\"<token>\",\"scope\":\"identify,incoming-webhook\",\"user_id\":\"<user>\",\"team_name\":\"<team>\",\"team_id\":\"T12345678\",\"incoming_webhook\":{\"channel\":\"#brutalism\",\"channel_id\":\"C12345678\",\"configuration_url\":\"https://team.slack.com/services/B12345678\",\"url\":\"https://hooks.slack.com/services/T12345678/B12345678/123456781234567812345678\"},\"scopes\":[\"identify\",\"incoming-webhook\"]}"}}]}'
	echo "\nCACHE"
	docker run --rm --env-file .env --env DRYRUN=1 $(shell cat $<) lambda.cache
	echo "\nMIRROR"
	docker run --rm --env-file .env --env DRYRUN=1 $(shell cat $<) lambda.mirror \
	'{"Records":[{"s3":{"bucket":{"name":"brutalismbot"},"object":{"key":"posts/v1/year%3D2019/month%3D2019-04/day%3D2019-04-20/1555799559.json"}}}]}'
	echo "\nUNINSTALL"
	docker run --rm --env-file .env --env DRYRUN=1 $(shell cat $<) lambda.uninstall \
	'{"Records":[{"Sns":{"Message":"{\"token\":\"<token>\",\"team_id\":\"T1234568\",\"api_app_id\":\"A12345678\",\"event\":{\"type\":\"app_uninstalled\"},\"type\":\"event_callback\",\"event_id\":\"Ev12345678\",\"event_time\":1553557314}"}}]}'
