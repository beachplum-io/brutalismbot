VENDOR_DIRS = $(shell ls functions/**/lib/Gemfile | xargs dirname | xargs printf '%s/vendor ')

init: .terraform

plan: .terraform
	terraform plan

apply: .terraform
	terraform apply

clean:
	rm -rf .terraform*

.PHONY: init plan apply clean

.terraform: $(VENDOR_DIRS)
	terraform init
	touch $@

functions/%/lib/vendor: functions/%/lib/Gemfile
	cd $$(dirname $@) && bundle
	touch $@
