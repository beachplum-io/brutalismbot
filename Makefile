release ?= $(shell git describe --tags --always)

.PHONY: init plan apply install cache mirror uninstall

install:
	docker-compose run --rm $@

cache:
	docker-compose run --rm $@

mirror:
	docker-compose run --rm $@

uninstall:
	docker-compose run --rm $@

init:
	docker-compose run --rm terraform $@

plan:
	docker-compose run --rm -e TF_VAR_release=$(release) terraform $@

apply:
	docker-compose run --rm -e TF_VAR_release=$(release) terraform $@ -auto-approve

clean:
	rm -rf .terraform
	docker-compose down --volumes
