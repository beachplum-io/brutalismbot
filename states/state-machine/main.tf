#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

###########
#   IAM   #
###########

data "aws_region" "current" {}

resource "aws_iam_role" "role" {
  name = "brutalismbot-${data.aws_region.current.name}-states-${var.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeStates"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "states.amazonaws.com" }
    }
  })

  inline_policy {
    name   = "access"
    policy = var.policy
  }
}

#####################
#   STATE MACHINE   #
#####################

resource "aws_sfn_state_machine" "state_machine" {
  definition = jsonencode(yamldecode(templatefile("${path.module}/../definitions/${var.name}.yaml", var.variables)))
  name       = "brutalismbot-${var.name}"
  role_arn   = aws_iam_role.role.arn
}
