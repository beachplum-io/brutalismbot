name    := brutalismbot
runtime := ruby2.5
build   := $(shell git describe --tags --always)

digests = $(foreach i,\
	$(shell docker image ls -q --no-trunc),\
	$(shell [ -d .docker ] && grep -ho "$i" .docker/*))
runtest = docker run --rm --env-file .env --env DRYRUN=1 $(shell cat $<)

.PHONY: all apply clean plan shell shell@% test

all: Gemfile.lock lambda.zip

.docker:
	mkdir -p $@

.docker/$(build)@%: Gemfile | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TF_VAR_release=$(build) \
	--iidfile $@ \
	--tag brutalismbot/$(name):$(build)-$* \
	--target $* .

Gemfile.lock lambda.zip: .docker/$(build)@build
	docker run --rm -w /var/task/ $(shell cat $<) cat $@ > $@

plan: all .docker/$(build)@deploy

apply: .docker/$(build)@deploy
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(shell cat $<)

clean:
	-docker rmi -f $(digests)
	-rm -rf .docker *.zip

shell: shell@deploy

shell@%: .docker/$(build)@% | .env
	docker run --rm -it --env-file .env --entrypoint /bin/bash $(shell cat $<)

test: .docker/$(build)@runtime | .env
	@echo "\n=> TEST"
	$(runtest) lambda.test
	@echo "\n=> INSTALL"
	$(runtest) lambda.install '{"Records":[{"Sns":{"Message":"{\"ok\":true,\"access_token\":\"<token>\",\"scope\":\"identify,incoming-webhook\",\"user_id\":\"<user>\",\"team_name\":\"<team>\",\"team_id\":\"T12345678\",\"incoming_webhook\":{\"channel\":\"#brutalism\",\"channel_id\":\"C12345678\",\"configuration_url\":\"https://team.slack.com/services/B12345678\",\"url\":\"https://hooks.slack.com/services/T12345678/B12345678/123456781234567812345678\"},\"scopes\":[\"identify\",\"incoming-webhook\"]}"}}]}'
	@echo "\n=> CACHE"
	$(runtest) lambda.cache
	@echo "\n=> MIRROR"
	$(runtest) lambda.mirror '{"Records":[{"s3":{"bucket":{"name":"brutalismbot"},"object":{"key":"data/v1/posts/year%3D2019/month%3D2019-04/day%3D2019-04-20/1555799559.json"}}}]}'
	@echo "\n=> UNINSTALL"
	$(runtest) lambda.uninstall '{"Records":[{"Sns":{"Message":"{\"token\":\"<token>\",\"team_id\":\"T1234568\",\"api_app_id\":\"A12345678\",\"event\":{\"type\":\"app_uninstalled\"},\"type\":\"event_callback\",\"event_id\":\"Ev12345678\",\"event_time\":1553557314}"}}]}'
