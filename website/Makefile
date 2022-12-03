DISTRIBUTION_ID = $(shell terraform output -raw cloudfront_distribution_id)

init: .terraform

plan: .terraform
	terraform plan

apply: .terraform
	terraform apply

clean:
	rm -rf .terraform*

cachebust:
	aws cloudfront create-invalidation --paths '/*' --distribution-id $(DISTRIBUTION_ID)

up:
	python -m http.server --directory www

.PHONY: init plan apply clean up

.terraform:
	terraform init
	touch $@
