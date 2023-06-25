PROJECTS = $(shell find * -maxdepth 0 -type d)

logs:
	aws logs tail --follow $(shell aws logs describe-log-groups | jq -r '.logGroups[].logGroupName' | grep brutalismbot | fzf --no-info --reverse --sync --height 10%)

$(PROJECTS):
	make -C $@ apply

.PHONY: logs $(PROJECTS)
