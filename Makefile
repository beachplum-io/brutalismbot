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

.terraform/$(release).tfplan: .terraform
	docker-compose run --rm terraform plan -var release=$(release) -out $@

plan: .terraform/$(release).tfplan

apply: .terraform/$(release).tfplan
	docker-compose run --rm terraform apply -auto-approve $<

pkg:
	mkdir pkg
	docker-compose run --rm -T zip -r - . > $@/$(package)

sync: pkg
	docker-compose run --rm aws s3 sync $< s3://$(bucket)/$(prefix)

sync-dryrun: pkg
	docker-compose run --rm aws s3 sync $< s3://$(bucket)/$(prefix) --dryrun

test:
	docker-compose run --rm install
	docker-compose run --rm cache
	docker-compose run --rm mirror
	docker-compose run --rm uninstall

clean:
	rm -rf .terraform pkg
