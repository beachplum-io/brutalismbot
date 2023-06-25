gemfiles  = $(wildcard */*/lib/Gemfile)
lockfiles = $(foreach gemfile,$(gemfiles),$(gemfile).lock)

build: $(lockfiles)

apply: validate
	terraform apply

plan: validate
	terraform plan -detailed-exitcode

validate: build .terraform
	terraform validate

.PHONY: apply build plan validate

$(lockfiles): %/Gemfile.lock: %/Gemfile
	cd $* && bundle install
	touch $@

.terraform: $(wildcard **/terraform.tf)
	terraform init
	touch $@
