##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name

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

data "aws_cloudwatch_event_bus" "bus" {
  name = terraform.workspace
}

data "aws_dynamodb_table" "table" {
  name = terraform.workspace
}

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
  description    = "Refresh app home"
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  name           = local.name
  state          = "ENABLED"
  tags           = local.tags

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
        Sid      = "DescribeRule"
        Effect   = "Allow"
        Action   = "events:DescribeRule"
        Resource = "arn:aws:events:${local.region}:${local.account}:rule/${terraform.workspace}/*"
      },
      {
        Sid      = "GetItem"
        Effect   = "Allow"
        Action   = "dynamodb:GetItem"
        Resource = data.aws_dynamodb_table.table.arn
        # Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = ["backlog", "r/brutalism"] } }
      },
      {
        Sid      = "GetSchedule"
        Effect   = "Allow"
        Action   = "scheduler:GetSchedule"
        Resource = "arn:aws:scheduler:${local.region}:${local.account}:schedule/${terraform.workspace}/*"
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

resource "aws_lambda_function" "lambda" {
  architectures    = ["arm64"]
  description      = "Get Home view"
  filename         = data.archive_file.lambda.output_path
  function_name    = local.name
  handler          = "index.home"
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby3.4"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags             = local.tags
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME     = data.aws_dynamodb_table.table.name
      EVENT_BUS_NAME = data.aws_cloudwatch_event_bus.bus.name
      SCHEDULE_GROUP = terraform.workspace
    }
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
        Sid      = "GetToken"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${local.region}:${local.account}:parameter${local.param}"
      },
      {
        Sid    = "InvokeFunction"
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.lambda.arn,
          data.aws_lambda_function.http.arn,
        ]
      }
    ]
  })
}

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn
  tags     = local.tags

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yml", {
    home_view_arn     = aws_lambda_function.lambda.arn
    http_function_arn = data.aws_lambda_function.http.arn
    param             = local.param
  })))
}
