##############
#   LOCALS   #
##############

locals {
  name    = "brutalismbot-${var.env}-${var.app}-enable"
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_cloudwatch_event_bus" "bus" {
  name = "brutalismbot-${var.env}"
}

data "aws_sfn_state_machine" "app-home" {
  name = "brutalismbot-${var.env}-${var.app}-app-home"
}

##############
#   EVENTS   #
##############

resource "aws_iam_role" "events" {
  name = "${local.region}-${local.name}-events"
  tags = var.tags

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
        Sid      = "StartExecution"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.states.arn
      }
    })
  }
}

resource "aws_cloudwatch_event_rule" "events" {
  description    = "Reject post for republishing"
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  is_enabled     = true
  name           = local.name
  tags           = var.tags

  event_pattern = jsonencode({
    source      = ["slack/beta"]
    detail-type = ["POST /callbacks"]

    detail = {
      type = ["block_actions"]
      actions = {
        action_id = [
          "enable_rule",
          "enable_schedule",
        ]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "events" {
  arn            = aws_sfn_state_machine.states.arn
  event_bus_name = aws_cloudwatch_event_rule.events.event_bus_name
  role_arn       = aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.events.name
  target_id      = "state-machine"
}

#####################
#   STATE MACHINE   #
#####################

resource "aws_iam_role" "states" {
  name = "${local.region}-${local.name}-states"
  tags = var.tags

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
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "EnableRule"
          Effect   = "Allow"
          Action   = ["events:EnableRule"]
          Resource = "arn:aws:events:${local.region}:${local.account}:rule/brutalismbot-${var.env}/*"
        },
        {
          Sid    = "EnableSchedule"
          Effect = "Allow"
          Action = [
            "iam:PassRole",
            "scheduler:GetSchedule",
            "scheduler:UpdateSchedule",
          ]
          Resource = [
            "arn:aws:iam::${local.account}:role/${local.region}-brutalismbot-${var.env}-*",
            "arn:aws:scheduler:${local.region}:${local.account}:schedule/brutalismbot-${var.env}/*",
          ]
        },
        {
          Sid      = "StartExecution"
          Effect   = "Allow"
          Action   = "states:StartExecution"
          Resource = data.aws_sfn_state_machine.app-home.arn
        }
      ]
    })
  }
}

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn
  tags     = var.tags

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yml", {
    app_home_arn = data.aws_sfn_state_machine.app-home.arn
  })))
}
