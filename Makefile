name    := brutalismbot
runtime := ruby2.5
build   := $(shell git describe --tags --always)

digests = $(foreach i,\
	$(shell docker image ls -q --no-trunc),\
	$(shell [ -d .docker ] && grep -ho "$i" .docker/*))
runtest = docker run --rm --env-file .env --env DRYRUN=1 $(shell cat $<)

.PHONY: all apply clean plan shell@%

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

apply: plan | .docker/$(build)@deploy
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(shell cat $|)

clean:
	-docker rmi -f $(digests)
	-rm -rf .docker *.zip

shell@%: .docker/$(build)@% | .env
	docker run --rm -it --env-file .env --entrypoint /bin/bash $(shell cat $<)
