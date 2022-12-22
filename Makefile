PROJECTS  = $(shell ls */terraform.tf | xargs dirname | xargs)
WORKFLOWS = $(shell ls .github/workflows/* | xargs)

all: $(WORKFLOWS)

logs:
	aws logs describe-log-groups \
	| jq -r '.logGroups[].logGroupName' \
	| grep brutalismbot \
	| fzf --no-info --reverse \
	| xargs aws logs tail --follow

$(PROJECTS): %: .github/workflows/%.yml
	make -C $@ apply

.PHONY: all logs $(PROJECTS)

.github/workflows/%.yml: .github/workflow.yml.erb
	erb workspace=$* .github/workflow.yml.erb > $@
