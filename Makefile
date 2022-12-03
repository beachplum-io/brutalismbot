PROJECTS = $(shell find * -name terraform.tf -depth 1 | xargs dirname | xargs)

all: $(PROJECTS)

.PHONY: all $(PROJECTS)

$(PROJECTS): %: .github/workflows/%.yml
	make -C $@

.github/workflows/%.yml: .github/workflow.yml.erb
	erb workspace=$* .github/workflow.yml.erb > $@
