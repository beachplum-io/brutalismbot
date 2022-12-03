PROJECTS = $(shell find * -name terraform.tf -depth 1 | xargs dirname | xargs)

all: $(PROJECTS)

.PHONY: all $(PROJECTS)

$(PROJECTS):
	make -C $@
