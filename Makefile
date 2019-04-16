release ?= $(shell git describe --tags --always)

.PHONY: init plan apply install cache mirror uninstall clean

install:
	docker-compose run --rm install

cache:
	docker-compose run --rm cache

mirror:
	docker-compose run --rm mirror

uninstall:
	docker-compose run --rm uninstall

.terraform:
	docker-compose run --rm terraform init

init: .terraform

plan: init
	docker-compose run --rm -e TF_VAR_release=$(release) terraform plan

apply: init
	docker-compose run --rm -e TF_VAR_release=$(release) terraform apply -auto-approve

clean:
	rm -rf .terraform
	docker-compose down --volumes
