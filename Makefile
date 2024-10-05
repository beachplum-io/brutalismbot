GEMFILES  ?= $(shell find . -name Gemfile -maxdepth 5 | sort)
LOCKFILES ?= $(foreach GEMFILE,$(GEMFILES),$(GEMFILE).lock)

.PHONY: blue build clean global logs

blue:
	terraform -chdir=$@ apply

build: $(LOCKFILES)

clean:
	find . -type d -name vendor | xargs rm -rf

global:
	terraform -chdir=$@ apply

logs:
	aws logs tail --follow $(shell aws logs describe-log-groups | jq -r '.logGroups[].logGroupName' | grep brutalismbot | fzf --no-info --reverse --sync --height 10%)

$(LOCKFILES): %.lock: % .ruby-version
	BUNDLE_APP_CONFIG=$(PWD)/.bundle BUNDLE_GEMFILE=$< bundle update
	BUNDLE_APP_CONFIG=$(PWD)/.bundle BUNDLE_GEMFILE=$< bundle install
