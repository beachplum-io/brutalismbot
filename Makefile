gemfiles  = $(shell find . -name Gemfile -maxdepth 5 | sort)
lockfiles = $(foreach gemfile,$(gemfiles),$(gemfile).lock)

.PHONY: build clean logs

build: $(lockfiles)

clean:
	find . -type d -name vendor | xargs rm -rf

$(lockfiles): %.lock: % .ruby-version
	BUNDLE_APP_CONFIG=$(PWD)/.bundle bundle install --gemfile $<

logs:
	aws logs tail --follow $(shell aws logs describe-log-groups | jq -r '.logGroups[].logGroupName' | grep brutalismbot | fzf --no-info --reverse --sync --height 10%)
