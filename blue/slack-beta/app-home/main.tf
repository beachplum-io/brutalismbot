##############
#   LOCALS   #
##############

locals {
  name    = "brutalismbot-${var.env}-${var.app}-app-home"
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# data "aws_cloudwatch_event_bus" "bus" {
#   # name = "brutalismbot-${var.env}"
#   name = "brutalismbot"
# }

data "aws_lambda_function" "shared" {
  for_each      = toset(["http"])
  function_name = "brutalismbot-${var.env}-shared-${each.key}"
}

data "aws_secretsmanager_secret" "secret" {
  name = "brutalismbot/beta"
}

##############
#   EVENTS   #
##############

# resource "aws_iam_role" "events" {
#   name = "${local.region}-${local.name}-events"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = {
#       Sid       = "AssumeEvents"
#       Effect    = "Allow"
#       Action    = "sts:AssumeRole"
#       Principal = { Service = "events.amazonaws.com" }
#     }
#   })

#   inline_policy {
#     name = "access"
#     policy = jsonencode({
#       Version = "2012-10-17"
#       Statement = {
#         Sid      = "StartExecution"
#         Effect   = "Allow"
#         Action   = "states:StartExecution"
#         Resource = aws_sfn_state_machine.states.arn
#       }
#     })
#   }
# }

# resource "aws_cloudwatch_event_rule" "events" {
#   description    = "Update app home"
#   event_bus_name = data.aws_cloudwatch_event_bus.bus.name
#   is_enabled     = true
#   name           = local.name

#   event_pattern = jsonencode({
#     source      = ["slack/beta"]
#     detail-type = ["POST /callbacks"]

#     detail = {
#       type = ["block_actions"]
#       view = { type = ["home"] }
#     }
#   })
# }

# resource "aws_cloudwatch_event_target" "events" {
#   arn            = aws_sfn_state_machine.states.arn
#   event_bus_name = aws_cloudwatch_event_rule.events.event_bus_name
#   role_arn       = aws_iam_role.events.arn
#   rule           = aws_cloudwatch_event_rule.events.name
#   target_id      = "state-machine"
# }

#####################
#   STATE MACHINE   #
#####################

resource "aws_iam_role" "states" {
  name = "${local.region}-${local.name}-states"

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
          Sid      = "GetSecret"
          Effect   = "Allow"
          Action   = "secretsmanager:GetSecretValue"
          Resource = data.aws_secretsmanager_secret.secret.arn
        },
        {
          Sid      = "InvokeHttp"
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = data.aws_lambda_function.shared["http"].arn
        },
        {
          Sid      = "DescribeRule"
          Effect   = "Allow"
          Action   = "events:DescribeRule"
          Resource = "arn:aws:events:${local.region}:${local.account}:rule/brutalismbot-${var.env}/*"
        },
        {
          Sid      = "GetSchedule"
          Effect   = "Allow"
          Action   = "scheduler:GetSchedule"
          Resource = "arn:aws:scheduler:${local.region}:${local.account}:schedule/brutalismbot-${var.env}/*"
        }
      ]
    })
  }
}

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yaml", {
    env               = var.env
    http_function_arn = data.aws_lambda_function.shared["http"].arn
    secret_id         = data.aws_secretsmanager_secret.secret.id
    user_id           = var.user_id
  })))
}
