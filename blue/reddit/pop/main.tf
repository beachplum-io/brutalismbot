##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name

  app        = dirname(path.module)
  name       = "${terraform.workspace}-${local.app}-${basename(path.module)}"
  param_path = "/${replace(terraform.workspace, "-", "/")}/${local.app}/"
  tags       = { "brutalismbot:app" = local.app }
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_cloudwatch_event_bus" "bus" {
  name = terraform.workspace
}

data "aws_dynamodb_table" "table" {
  name = terraform.workspace
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
  tags              = local.tags
}

resource "aws_iam_role" "lambda" {
  name = "${local.region}-${local.name}-lambda"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeLambda"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "*"
      },
      {
        Sid      = "GetParams"
        Effect   = "Allow"
        Action   = "ssm:GetParametersByPath"
        Resource = "arn:aws:ssm:${local.region}:${local.account}:parameter${local.param_path}"
      }
    ]
  })
}

resource "aws_lambda_function" "lambda" {
  architectures    = ["arm64"]
  description      = "Pop next post from r/brutalism"
  filename         = data.archive_file.lambda.output_path
  function_name    = local.name
  handler          = "index.pop"
  memory_size      = 512
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby3.4"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags             = local.tags
  timeout          = 10

  environment {
    variables = {
      MIN_AGE_HOURS = "4"
      PARAM_PATH    = local.param_path
    }
  }
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
      Sid       = "AssumeEvents"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "events.amazonaws.com" }
    }
  })
}

resource "aws_iam_role_policy" "events" {
  name = "access"
  role = aws_iam_role.events.id

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


resource "aws_cloudwatch_event_rule" "events" {
  description    = "Capture delete_me Slack callback"
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  name           = local.name
  state          = "ENABLED"
  tags           = local.tags

  event_pattern = jsonencode({
    source      = ["slack/beta"]
    detail-type = ["POST /callbacks"]

    detail = {
      type = ["block_actions"]
      actions = {
        action_id = ["pop"]
        value     = ["r/brutalism"]
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

#################
#   SCHEDULER   #
#################

resource "aws_iam_role" "scheduler" {
  name = "${local.region}-${local.name}-scheduler"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeScheduler"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "scheduler.amazonaws.com" }
    }
  })
}

resource "aws_iam_role_policy" "scheduler" {
  name = "access"
  role = aws_iam_role.scheduler.id

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

resource "aws_scheduler_schedule" "scheduler" {
  name                = local.name
  group_name          = terraform.workspace
  schedule_expression = "rate(1 hour)"
  state               = "DISABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_sfn_state_machine.states.arn
    role_arn = aws_iam_role.scheduler.arn
  }

  lifecycle {
    ignore_changes = [state]
  }
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
}

resource "aws_iam_role_policy" "states" {
  name = "access"
  role = aws_iam_role.states.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CloudWatch"
        Effect   = "Allow"
        Action   = "cloudwatch:PutMetricData"
        Resource = "*"
      },
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Resource = data.aws_dynamodb_table.table.arn
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
        ]
      },
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.lambda.arn
      }
    ]
  })
}

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn
  tags     = local.tags

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yml", {
    cloudwatch_namespace = terraform.workspace
    reddit_pop_arn       = aws_lambda_function.lambda.arn
    table_name           = data.aws_dynamodb_table.table.name
  })))
}
