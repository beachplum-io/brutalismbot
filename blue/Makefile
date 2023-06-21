gemfiles  = $(wildcard */*/lib/Gemfile)
lockfiles = $(foreach gemfile,$(gemfiles),$(gemfile).lock)

build: $(lockfiles)

apply: build .terraform
	terraform apply

.PHONY: apply build

$(lockfiles): %/Gemfile.lock: %/Gemfile
	cd $* && bundle install
	touch $@

.terraform: $(wildcard **/terraform.tf)
	terraform init
	touch $@
