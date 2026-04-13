LOCKFILES ?= $(shell git ls-tree -r --name-only @ | grep Gemfile.lock$)

.PHONY: blue build clean global logs

build: $(LOCKFILES)
	docker compose down --rmi local

apply:
	terraform -chdir=blue apply
	terraform -chdir=global apply

clean:
	find * -name vendor -type d | xargs rm -rf
	find * -name Gemfile.lock | xargs rm

logs:
	aws logs tail --follow $(shell aws logs describe-log-groups | jq -r '.logGroups[].logGroupName' | grep brutalismbot | fzf --no-info --reverse --sync --height 10%)

$(LOCKFILES): %.lock: % .ruby-version
	BUNDLE=$(shell dirname $<) docker compose run --rm build update --all
	BUNDLE=$(shell dirname $<) docker compose run --rm build install
