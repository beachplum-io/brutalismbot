gemfiles  = $(wildcard */*/lib/Gemfile)
lockfiles = $(foreach gemfile,$(gemfiles),$(gemfile).lock)

build: $(lockfiles)

apply: build .terraform
	terraform apply

plan: build .terraform
	terraform plan -detailed-exitcode

.PHONY: apply build plan

$(lockfiles): %/Gemfile.lock: %/Gemfile
	cd $* && bundle install
	touch $@

.terraform: $(wildcard **/terraform.tf)
	terraform init
	touch $@
