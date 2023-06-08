# Find all projects in this directory
projects := $(shell find * -type d -maxdepth 0)

# Mark all + projects as phony
.PHONY: all upgrade $(projects)

# Default task is to apply all projects
all: $(projects)

upgrade:
	$(foreach dir, $(projects), terraform -chdir=$(dir) init -upgrade ; )

# Apply a project
$(projects): %: %/.terraform
	terraform -chdir=$@ apply -auto-approve

# Init a project by monitoring {project}/terraform.tf
%/.terraform: %/terraform.tf
	terraform -chdir=$* init
	touch $@
