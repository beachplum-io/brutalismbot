gemfiles  = $(wildcard */*/lib/Gemfile)
lockfiles = $(foreach gemfile,$(gemfiles),$(gemfile).lock)

build: $(lockfiles) .terraform

.PHONY: build

$(lockfiles): %/Gemfile.lock: %/Gemfile
	cd $* && bundle install
	touch $@

# Init project by monitoring **/terraform.tf
.terraform: $(wildcard **/terraform.tf)
	terraform init
	touch $@
