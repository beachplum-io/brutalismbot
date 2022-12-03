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

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AssumeEvents"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  assume_role_policy = data.aws_iam_policy_document.trust.json
  name               = "brutalismbot-${data.aws_region.current.name}-states-${var.name}"

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
