##############
#   LOCALS   #
##############

locals {
  enabled = true

  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.region

  app        = basename(path.module)
  name       = "${terraform.workspace}-${local.app}"
  tags       = { "brutalismbot:app" = local.app }
  param_path = "/${replace(terraform.workspace, "-", "/")}/bluesky/"

  functions = {
    post = {
      description = "Post to Bluesky"
      handler     = "index.post"
      memory_size = 1024
      timeout     = 60
    }
  }

  state_machines = {
    post = "STANDARD"
  }
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {
}

data "aws_region" "current" {
}

data "aws_cloudwatch_event_bus" "bus" {
  name = terraform.workspace
}

data "aws_dynamodb_table" "table" {
  name = terraform.workspace
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
      Resource = values(aws_sfn_state_machine.states).*.arn
    }
  })
}

resource "aws_cloudwatch_event_rule" "events" {
  for_each = {
    post = {
      description = "Post to Bluesky"
      state       = local.enabled ? "ENABLED" : "DISABLED"
      event_pattern = {
        source      = ["Pipe ${terraform.workspace}"]
        detail-type = ["Event from aws:dynamodb"]
        detail = {
          eventName = ["INSERT"]
          dynamodb  = { Keys = { Kind = { S = ["reddit.post"] } } }
        }
      }
    }
  }

  description    = each.value.description
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  event_pattern  = jsonencode(each.value.event_pattern)
  name           = "${local.name}-${each.key}"
  state          = each.value.state
  tags           = local.tags
}

resource "aws_cloudwatch_event_target" "events" {
  for_each = aws_cloudwatch_event_rule.events

  arn            = aws_sfn_state_machine.states[each.key].arn
  input_path     = "$.detail"
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  role_arn       = aws_iam_role.events.arn
  rule           = each.value.name
  target_id      = each.key
}

######################
#   STATE MACHINES   #
######################

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
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = data.aws_dynamodb_table.table.arn
      },
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = values(aws_lambda_function.lambda).*.arn
      }
    ]
  })
}

resource "aws_sfn_state_machine" "states" {
  for_each = local.state_machines

  name     = "${local.name}-${each.key}"
  role_arn = aws_iam_role.states.arn
  tags     = local.tags
  type     = each.value

  definition = jsonencode(yamldecode(templatefile("${path.module}/state-machines/${each.key}.asl.yml", {
    function_arns = { for key, function in aws_lambda_function.lambda : key => function.arn }
    table_name    = data.aws_dynamodb_table.table.name
  })))
}

##############
#   LAMBDA   #
##############

data "archive_file" "lambda" {
  for_each = local.functions

  source_dir  = "${path.module}/functions/${each.key}"
  output_path = "${path.module}/functions/${each.key}.zip"
  type        = "zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = aws_lambda_function.lambda

  name              = "/aws/lambda/${each.value.function_name}"
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
        Sid      = "SSM"
        Effect   = "Allow"
        Action   = "ssm:GetParametersByPath"
        Resource = "arn:aws:ssm:${local.region}:${local.account}:parameter${local.param_path}"
      }
    ]
  })
}

resource "aws_lambda_function" "lambda" {
  for_each = local.functions

  architectures    = ["arm64"]
  description      = each.value.description
  filename         = data.archive_file.lambda[each.key].output_path
  function_name    = "${local.name}-${each.key}"
  handler          = each.value.handler
  memory_size      = each.value.memory_size
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby4.0"
  source_code_hash = data.archive_file.lambda[each.key].output_base64sha256
  tags             = local.tags
  timeout          = each.value.timeout

  environment {
    variables = {
      PARAM_PATH = local.param_path
    }
  }
}
