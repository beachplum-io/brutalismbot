release := $(shell git describe --tags --always)
package := brutalismbot-$(release).zip
bucket  := brutalismbot
key     := terraform/pkg/$(package)

.PHONY: lock deploy init plan apply test clean

Gemfile.lock: Gemfile
	bundle install

lock: Gemfile.lock

pkg:
	mkdir pkg
	docker-compose run --rm -T build zip -r - . > pkg/$(package)

deploy: pkg
	aws s3 cp pkg/$(package) s3://$(bucket)/$(key)

.terraform:
	docker-compose run --rm terraform init

init: .terraform

plan: .terraform
	docker-compose run --rm terraform plan -var release=$(release) -out .terraform/planfile

apply: plan
	docker-compose run --rm terraform apply -auto-approve .terraform/planfile

test:
	docker-compose run --rm install
	docker-compose run --rm cache
	docker-compose run --rm mirror
	docker-compose run --rm uninstall

clean:
	rm -rf .terraform pkg
	docker-compose down
