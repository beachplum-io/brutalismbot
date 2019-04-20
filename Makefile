release := $(shell git describe --tags --abbrev=0)
package := brutalismbot-$(shell git describe --tags --always).zip
bucket  := brutalismbot
key     := terraform/pkg/$(package)

.PHONY: lock deploy init plan apply test clean

lock:
	bundle install

pkg:
	mkdir pkg && (cd lib && zip -r - .) > pkg/$(package)

deploy:
	(cd lib && zip -r - .) | aws s3 cp - s3://$(bucket)/$(key)

init:
	docker-compose run --rm terraform init

plan:
	docker-compose run --rm terraform plan -var release=$(release)

apply: plan
	docker-compose run --rm terraform apply -var release=$(release) -auto-approve

test:
	docker-compose run --rm install
	docker-compose run --rm cache
	docker-compose run --rm mirror
	docker-compose run --rm uninstall

clean:
	rm -rf .terraform pkg
	docker-compose down --volumes
