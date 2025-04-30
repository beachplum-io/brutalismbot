LOCKFILES ?= $(shell git ls-tree -r --name-only @ | grep Gemfile.lock$)

.PHONY: blue build clean global logs

blue:
	terraform -chdir=$@ apply

build: $(LOCKFILES)
	docker compose down --rmi local

clean:
	rm -rf **/vendor
	rm -rf **/Gemfile.lock

global:
	terraform -chdir=$@ apply

logs:
	aws logs tail --follow $(shell aws logs describe-log-groups | jq -r '.logGroups[].logGroupName' | grep brutalismbot | fzf --no-info --reverse --sync --height 10%)

$(LOCKFILES): %.lock: % .ruby-version
	BUNDLE=$(shell dirname $<) docker compose run --rm build update
	BUNDLE=$(shell dirname $<) docker compose run --rm build install
