name    := brutalismbot
runtime := ruby2.5
build   := $(shell git describe --tags --always)

.PHONY: all apply clean plan shell@%

all: Gemfile.lock lambda.zip

.docker:
	mkdir -p $@

.docker/$(build)@deploy: .docker/$(build)@build
.docker/$(build)@runtime: .docker/$(build)@deploy
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
	-docker rmi -f $(shell awk {print} .docker/*)
	-rm -rf .docker *.zip

shell@%: .docker/$(build)@% .env
	docker run --rm -it \
	--env-file .env \
	--entrypoint /bin/bash \
	$(shell cat $<)
