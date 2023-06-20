##############
#   LOCALS   #
##############

locals {
  name   = "brutalismbot-${var.env}-${var.app}-screen"
  region = data.aws_region.current.name
}

############
#   DATA   #
############

data "aws_region" "current" {}

data "aws_cloudwatch_event_bus" "bus" {
  name = "brutalismbot-${var.env}"
}

data "aws_dynamodb_table" "table" {
  name = "brutalismbot-${var.env}"
}

data "aws_lambda_function" "http" {
  function_name = "brutalismbot-${var.env}-shared-http"
}

data "aws_secretsmanager_secret" "secret" {
  name = "brutalismbot/beta"
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
  description    = "Capture new reddit posts"
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  is_enabled     = true
  name           = local.name
  tags           = var.tags

  event_pattern = jsonencode({
    source      = ["Pipe brutalismbot-${var.env}-shared-streams"]
    detail-type = ["Event from aws:dynamodb"]
    detail = {
      eventName = ["INSERT"]
      dynamodb = {
        Keys     = { Kind = { S = ["reddit/post"] } }
        NewImage = { Status = { S = ["New"] } }
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

  input_transformer {
    input_paths = {
      Key       = "$.detail.dynamodb.Keys"
      Title     = "$.detail.dynamodb.NewImage.Title.S"
      Media     = "$.detail.dynamodb.NewImage.Media.S"
      Permalink = "$.detail.dynamodb.NewImage.Permalink.S"
    }
    input_template = <<-JSON
      {
        "Key": <Key>,
        "Title": <Title>,
        "Media": <Media>,
        "Permalink": <Permalink>
      }
    JSON
  }
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
  tags              = var.tags
}

resource "aws_iam_role" "lambda" {
  name = "${local.region}-${local.name}-lambda"
  tags = var.tags

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
      Statement = {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "*"
      }
    })
  }
}

resource "aws_lambda_function" "lambda" {
  architectures    = ["arm64"]
  description      = "Send screener"
  filename         = data.archive_file.lambda.output_path
  function_name    = local.name
  handler          = "index.screen"
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby3.2"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags             = var.tags
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
          Sid      = "GetSecret"
          Effect   = "Allow"
          Action   = "secretsmanager:GetSecretValue"
          Resource = data.aws_secretsmanager_secret.secret.arn
        },
        {
          Sid    = "SendScreener"
          Effect = "Allow"
          Action = "lambda:InvokeFunction"
          Resource = [
            aws_lambda_function.lambda.arn,
            data.aws_lambda_function.http.arn,
          ]
        },
        {
          Sid      = "UpdateStatus"
          Effect   = "Allow"
          Action   = "dynamodb:UpdateItem"
          Resource = data.aws_dynamodb_table.table.arn
        }
      ]
    })
  }
}

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn
  tags     = var.tags

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yaml", {
    channel_id        = var.channel_id
    http_function_arn = data.aws_lambda_function.http.arn
    screen_arn        = aws_lambda_function.lambda.arn
    secret_id         = data.aws_secretsmanager_secret.secret.id
    table_name        = data.aws_dynamodb_table.table.name
    wait_time_seconds = 14400
  })))
}
