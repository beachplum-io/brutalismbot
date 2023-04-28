PROJECTS = $(shell ls */terraform.tf | xargs dirname | xargs)

all:

logs:
	aws logs describe-log-groups \
	| jq -r '.logGroups[].logGroupName' \
	| grep brutalismbot \
	| fzf --no-info --reverse \
	| xargs aws logs tail --follow

$(PROJECTS):
	make -C $@ apply

.PHONY: all logs $(PROJECTS)
