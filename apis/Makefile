init: .terraform

plan: .terraform
	terraform plan

apply: .terraform
	terraform apply

clean:
	rm -rf .terraform*

.PHONY: init plan apply clean

.terraform:
	terraform init
	touch $@
