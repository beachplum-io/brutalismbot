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
  description = var.description
  name        = "brutalismbot-${data.aws_region.current.name}-events-${var.identifier}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeEvents"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "events.amazonaws.com" }
    }
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = {
        Sid      = "StatesStartExecution"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = var.state_machine_arn
      }
    })
  }
}

####################
#   EVENTIBRIDGE   #
####################

resource "aws_cloudwatch_event_rule" "rule" {
  description         = var.description
  event_bus_name      = "default"
  is_enabled          = var.is_enabled
  name                = "brutalismbot-${var.identifier}"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "target" {
  arn            = var.state_machine_arn
  event_bus_name = aws_cloudwatch_event_rule.rule.event_bus_name
  input          = jsonencode(var.input)
  role_arn       = aws_iam_role.role.arn
  rule           = aws_cloudwatch_event_rule.rule.name
  target_id      = "state-machine"
}
