##############
#   LOCALS   #
##############

locals {
  name   = "brutalismbot-${var.env}-${var.app}-states-errors"
  region = data.aws_region.current.name
}

############
#   DATA   #
############

data "aws_region" "current" {}

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

resource "aws_iam_role" "events" {
  name = "${local.region}-${local.name}-events"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
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
  description = "Capture state machine error events"
  is_enabled  = true
  name        = local.name

  event_pattern = jsonencode({
    source      = ["aws.states"]
    detail-type = ["Step Functions Execution Status Change"]

    detail = {
      stateMachineArn = [{ anything-but = [aws_sfn_state_machine.states.arn] }]
      status          = ["FAILED", "TIMED_OUT"]
    }
  })
}

resource "aws_cloudwatch_event_target" "events" {
  arn       = aws_sfn_state_machine.states.arn
  role_arn  = aws_iam_role.events.arn
  rule      = aws_cloudwatch_event_rule.events.name
  target_id = "state-machine"
}

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
          Sid      = "PostSlack"
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = data.aws_lambda_function.shared["http"].arn
        }
      ]
    })
  }
}

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yaml", {
    channel_id        = var.channel_id
    http_function_arn = data.aws_lambda_function.shared["http"].arn
    secret_id         = data.aws_secretsmanager_secret.secret.id
  })))
}
