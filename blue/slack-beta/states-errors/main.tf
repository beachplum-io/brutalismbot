##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name

  name  = "brutalismbot-${var.env}-${var.app}-states-errors"
  param = "/brutalismbot/${var.env}/${var.app}/SLACK_API_TOKEN"
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_lambda_function" "http" {
  function_name = "brutalismbot-${var.env}-shared-http"
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
  name        = local.name
  state       = "ENABLED"
  tags        = var.tags

  event_pattern = jsonencode({
    source      = ["aws.states"]
    detail-type = ["Step Functions Execution Status Change"]

    detail = {
      executionArn    = [{ prefix = "arn:aws:states:${local.region}:${local.account}:execution:brutalismbot-${var.env}-" }]
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
          Sid      = "GetToken"
          Effect   = "Allow"
          Action   = "ssm:GetParameter"
          Resource = "arn:aws:ssm:${local.region}:${local.account}:parameter${local.param}"
        },
        {
          Sid      = "PostSlack"
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = data.aws_lambda_function.http.arn
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
    channel_id        = var.channel_id
    http_function_arn = data.aws_lambda_function.http.arn
    param             = local.param
  })))
}
