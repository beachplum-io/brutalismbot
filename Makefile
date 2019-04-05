release ?= $(shell date -u +%Y.%-m.%-d)

.PHONY: init plan apply install cache mirror uninstall

install:
	docker-compose run --rm $@

cache:
	docker-compose run --rm $@

mirror:
	docker-compose run --rm $@

uninstall:
	docker-compose run --rm $@

.terraform:
	docker-compose run --rm terraform init

init: .terraform

plan:
	docker-compose run --rm -e TF_VAR_release=$(release) terraform plan

apply:
	docker-compose run --rm -e TF_VAR_release=$(release) terraform apply -auto-approve

clean:
	rm -rf .terraform
	docker-compose down --volumes
