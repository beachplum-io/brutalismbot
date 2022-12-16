PROJECTS  = $(shell ls */terraform.tf | xargs dirname | xargs)
WORKFLOWS = $(shell ls .github/workflows/* | xargs)

all: $(WORKFLOWS)

.PHONY: all $(PROJECTS)

$(PROJECTS): %: .github/workflows/%.yml
	make -C $@ apply

.github/workflows/%.yml: .github/workflow.yml.erb
	erb workspace=$* .github/workflow.yml.erb > $@
