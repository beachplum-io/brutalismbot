release := $(shell git describe --tags --always)
package := brutalismbot-$(release).zip
bucket  := brutalismbot
prefix  := terraform/pkg/

.PHONY: default lock init plan apply sync sync-dryrun test clean

default: sync-dryrun plan

Gemfile.lock: Gemfile
	bundle install

lock: Gemfile.lock

.terraform:
	docker-compose run --rm terraform init

init: .terraform

plan: .terraform
	docker-compose run --rm terraform plan -var release=$(release) -out .terraform/$(release).planfile

apply: plan
	docker-compose run --rm terraform apply -auto-approve .terraform/$(release).planfile

pkg:
	mkdir pkg
	docker-compose run --rm -T build zip -r - . > pkg/$(package)

sync: pkg
	aws s3 sync pkg s3://$(bucket)/$(prefix)

sync-dryrun: pkg
	aws s3 sync pkg s3://$(bucket)/$(prefix) --dryrun

test:
	docker-compose run --rm install
	docker-compose run --rm cache
	docker-compose run --rm mirror
	docker-compose run --rm uninstall

clean:
	rm -rf .terraform pkg
