init: .terraform

plan: .terraform
	terraform plan

apply: .terraform
	terraform apply -auto-approve

clean:
	rm -rf .terraform*

.PHONY: init plan apply clean reset

.terraform: lib/vendor
	terraform init
	touch $@

lib/vendor: lib/Gemfile
	cd $$(dirname $@) && bundle
	touch $@
