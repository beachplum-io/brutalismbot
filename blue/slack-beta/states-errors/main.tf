##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name
  user_id = "UH9M57X6Z"

  app        = dirname(path.module)
  name       = "${terraform.workspace}-${local.app}-${basename(path.module)}"
  param_path = "/${replace(terraform.workspace, "-", "/")}/${local.app}/"
  param      = "${local.param_path}SLACK_API_TOKEN"
  tags       = { "brutalismbot:app" = local.app }
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_lambda_function" "http" {
  function_name = "${terraform.workspace}-shared-http"
}

##############
#   EVENTS   #
##############

resource "aws_iam_role" "events" {
  name = "${local.region}-${local.name}-events"
  tags = local.tags

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
  tags        = local.tags

  event_pattern = jsonencode({
    source      = ["aws.states"]
    detail-type = ["Step Functions Execution Status Change"]

    detail = {
      executionArn    = [{ prefix = "arn:aws:states:${local.region}:${local.account}:execution:${terraform.workspace}-" }]
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
  tags = local.tags

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
  tags     = local.tags

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yml", {
    channel_id        = local.user_id
    http_function_arn = data.aws_lambda_function.http.arn
    param             = local.param
  })))
}
