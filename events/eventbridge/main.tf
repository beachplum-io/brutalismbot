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
      identifiers = ["events.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "access" {
  statement {
    sid       = "StatesStartExecution"
    actions   = ["states:StartExecution"]
    resources = [var.state_machine_arn]
  }
}

resource "aws_iam_role" "role" {
  assume_role_policy = data.aws_iam_policy_document.trust.json
  description        = var.description
  name               = "brutalismbot-${data.aws_region.current.name}-events-${var.identifier}"

  inline_policy {
    name   = "access"
    policy = data.aws_iam_policy_document.access.json
  }
}

####################
#   EVENTIBRIDGE   #
####################

resource "aws_cloudwatch_event_rule" "rule" {
  description    = var.description
  event_bus_name = var.event_bus_name
  event_pattern  = jsonencode(var.pattern)
  is_enabled     = var.is_enabled
  name           = var.identifier
}

resource "aws_cloudwatch_event_target" "target" {
  arn            = var.state_machine_arn
  event_bus_name = aws_cloudwatch_event_rule.rule.event_bus_name
  input_path     = var.input_path
  role_arn       = aws_iam_role.role.arn
  rule           = aws_cloudwatch_event_rule.rule.name
  target_id      = "state-machine"
}
