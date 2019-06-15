name      := brutalismbot
runtime   := ruby2.5
build     := $(shell git describe --tags --always)
s3_bucket := brutalismbot
s3_prefix := data/v1/
digest     = $(shell cat .docker/$(build)$(1))

rmi = docker image rm -f $(shell cat $(1)) && rm $(i);

.PHONY: all apply clean plan shell@% test

all: Gemfile.lock lambda.zip

.docker:
	mkdir -p $@

.docker/$(build)@test: .docker/$(build)@build
.docker/$(build)@plan: .docker/$(build)@test
.docker/$(build)@%: .dockerignore Dockerfile Gemfile | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg RUNTIME=$(runtime) \
	--build-arg S3_BUCKET=$(s3_bucket) \
	--build-arg S3_PREFIX=$(s3_prefix) \
	--build-arg TF_VAR_release=$(build) \
	--iidfile $@ \
	--tag brutalismbot/$(name):$(build)-$* \
	--target $* .

Gemfile.lock lambda.zip: .docker/$(build)@build
	docker run --rm -w /var/task/ $(call digest,@build) cat $@ > $@

test: .docker/$(build)@test

plan: .docker/$(build)@plan | all

apply: .docker/$(build)@plan | all
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(call digest,@plan)

clean:
	-docker image rm -f $(shell awk {print} .docker/*)
	-rm -rf .docker *.zip

shell@%: .docker/$(build)@% .env
	docker run --rm -it \
	--env-file .env \
	--entrypoint /bin/bash \
	$(call digest,@$*)
