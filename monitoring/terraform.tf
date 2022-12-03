#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "brutalismbot"

    workspaces { name = "monitoring" }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

data "terraform_remote_state" "functions" {
  backend = "remote"

  config = {
    organization = "brutalismbot"

    workspaces = { name = "functions" }
  }
}

data "terraform_remote_state" "states" {
  backend = "remote"

  config = {
    organization = "brutalismbot"

    workspaces = { name = "states" }
  }
}

###########
#   AWS   #
###########

provider "aws" {
  region = "us-west-2"
  assume_role { role_arn = var.AWS_ROLE_ARN }
  default_tags { tags = local.tags }
}

#################
#   VARIABLES   #
#################

variable "AWS_ROLE_ARN" {}

##############
#   LOCALS   #
##############

locals {
  tags = {
    "terraform:organization" = "brutalismbot"
    "terraform:workspace"    = "monitoring"
    "git:repo"               = "brutalismbot/monitoring"
  }
}

############################
#   CLOUDWATCH DASHBOARD   #
############################

resource "aws_cloudwatch_dashboard" "dash" {
  dashboard_name = "Brutalismbot"
  dashboard_body = jsonencode(yamldecode(templatefile("${path.module}/dashboard.yml", {
    duration = jsonencode([
      for function in data.terraform_remote_state.functions.outputs.functions :
      [
        "AWS/Lambda",
        "Duration",
        "FunctionName",
        function.function_name
      ]
    ])

    lambda_errors = jsonencode([
      for function in data.terraform_remote_state.functions.outputs.functions :
      [
        "AWS/Lambda",
        "Errors",
        "FunctionName",
        function.function_name
      ]
    ])

    state_machine_errors = jsonencode([
      for name, state_machine in data.terraform_remote_state.states.outputs.state_machines :
      [
        "AWS/States",
        "ExecutionsFailed",
        "StateMachineArn",
        state_machine.arn,
        { label = state_machine.name }
      ]
    ])
  })))
}
