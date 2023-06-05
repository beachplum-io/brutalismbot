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

data "aws_cloudwatch_event_bus" "bus" {
  name = "brutalismbot-${var.env}"
}

data "aws_dynamodb_table" "table" {
  name = "brutalismbot-${var.env}"
}

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
  description = "Refresh app home"
  # event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  event_bus_name = "brutalismbot"
  is_enabled     = true
  name           = local.name

  event_pattern = jsonencode({
    source      = ["slack/beta"]
    detail-type = ["POST /callbacks"]

    detail = {
      type    = ["block_actions"]
      actions = { action_id = ["refresh_home"] }
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

##############
#   LAMBDA   #
##############

data "archive_file" "lambda" {
  excludes    = ["package.zip"]
  source_dir  = "${path.module}/lib"
  output_path = "${path.module}/lib/package.zip"
  type        = "zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
}

resource "aws_iam_role" "lambda" {
  name = "${local.region}-${local.name}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeLambda"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "DescribeRule"
          Effect   = "Allow"
          Action   = "events:DescribeRule"
          Resource = "arn:aws:events:${local.region}:${local.account}:rule/brutalismbot-${var.env}/*"
        },
        {
          Sid       = "GetItem"
          Effect    = "Allow"
          Action    = "dynamodb:GetItem"
          Resource  = data.aws_dynamodb_table.table.arn
          Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = "/r/brutalism" } }
        },
        {
          Sid      = "GetSchedule"
          Effect   = "Allow"
          Action   = "scheduler:GetSchedule"
          Resource = "arn:aws:scheduler:${local.region}:${local.account}:schedule/brutalismbot-${var.env}/*"
        },
        {
          Sid      = "Logs"
          Effect   = "Allow"
          Action   = "logs:*"
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_lambda_function" "lambda" {
  architectures    = ["arm64"]
  description      = "Get Home view"
  filename         = data.archive_file.lambda.output_path
  function_name    = local.name
  handler          = "index.home"
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME     = data.aws_dynamodb_table.table.name
      EVENT_BUS_NAME = data.aws_cloudwatch_event_bus.bus.name
      SCHEDULE_GROUP = "brutalismbot-${var.env}"
    }
  }
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
          Sid      = "GetSecretValue"
          Effect   = "Allow"
          Action   = "secretsmanager:GetSecretValue"
          Resource = data.aws_secretsmanager_secret.secret.arn
        },
        {
          Sid    = "InvokeFunction"
          Effect = "Allow"
          Action = "lambda:InvokeFunction"
          Resource = [
            aws_lambda_function.lambda.arn,
            data.aws_lambda_function.shared["http"].arn,
          ]
        }
      ]
    })
  }
}

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yaml", {
    home_view_arn     = aws_lambda_function.lambda.arn
    http_function_arn = data.aws_lambda_function.shared["http"].arn
    secret_id         = data.aws_secretsmanager_secret.secret.id
    user_id           = var.user_id
  })))
}
