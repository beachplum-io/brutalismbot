runtime  := ruby2.5
name     := brutalismbot
build    := $(shell git describe --tags --always)
planfile := $(name)-$(build).tfplan

image   := brutalismbot/$(name)
iidfile := .docker/$(build)
digest   = $(shell cat $<)

$(planfile): $(iidfile)-build Gemfile.lock lambda.zip
	docker run --rm $(digest) cat /var/task/$@ > $@

lambda.zip: $(iidfile)-build
	docker run --rm $(digest) cat /var/task/lambda.zip > $@

Gemfile.lock: $(iidfile)-build
	docker run --rm $(digest) cat /var/task/$@ > $@

$(iidfile)-%: Gemfile | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg PLANFILE=$(planfile) \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TF_VAR_release=$(build) \
	--iidfile $(iidfile)-$* \
	--target $* \
	--tag $(image):$(build)-$* .

.docker:
	mkdir -p $@

.env:
	echo "AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID" >> $@
	echo "AWS_DEFAULT_REGION=us-east-1" >> $@
	echo "AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY" >> $@
	echo "DRYRUN=1" >> $@
	echo "S3_BUCKET=brutalismbot" >> $@
	echo "MIN_TIME=" >> $@

.PHONY: shell test apply clean

shell: $(iidfile)-build .env
	docker run --rm -it --env-file .env $(digest) /bin/bash

test: $(iidfile)-runtime .env
	echo "\nTEST"
	docker run --rm --env-file .env --env DRYRUN=1 $(digest) lambda.test
	echo "\nINSTALL"
	docker run --rm --env-file .env --env DRYRUN=1 $(digest) lambda.install \
	'{"Records":[{"Sns":{"Message":"{\"ok\":true,\"access_token\":\"<token>\",\"scope\":\"identify,incoming-webhook\",\"user_id\":\"<user>\",\"team_name\":\"<team>\",\"team_id\":\"T12345678\",\"incoming_webhook\":{\"channel\":\"#brutalism\",\"channel_id\":\"C12345678\",\"configuration_url\":\"https://team.slack.com/services/B12345678\",\"url\":\"https://hooks.slack.com/services/T12345678/B12345678/123456781234567812345678\"},\"scopes\":[\"identify\",\"incoming-webhook\"]}"}}]}'
	echo "\nCACHE"
	docker run --rm --env-file .env --env DRYRUN=1 $(digest) lambda.cache
	echo "\nMIRROR"
	docker run --rm --env-file .env --env DRYRUN=1 $(digest) lambda.mirror \
	'{"Records":[{"s3":{"bucket":{"name":"brutalismbot"},"object":{"key":"posts/v1/year%3D2019/month%3D2019-04/day%3D2019-04-20/1555799559.json"}}}]}'
	echo "\nUNINSTALL"
	docker run --rm --env-file .env --env DRYRUN=1 $(digest) lambda.uninstall \
	'{"Records":[{"Sns":{"Message":"{\"token\":\"<token>\",\"team_id\":\"T1234568\",\"api_app_id\":\"A12345678\",\"event\":{\"type\":\"app_uninstalled\"},\"type\":\"event_callback\",\"event_id\":\"Ev12345678\",\"event_time\":1553557314}"}}]}'

apply: $(iidfile)-build $(planfile) .env
	docker run --rm --env-file .env $(digest) \
	terraform apply $(planfile)

clean:
	docker image rm -f $(image) $(shell sed G .docker/*)
	rm -rf .docker *.tfplan *.zip
