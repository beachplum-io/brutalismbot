##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name

  name       = "brutalismbot-${var.env}-${var.app}-send-post"
  param_path = "/brutalismbot/${var.env}/${var.app}/"
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
  description    = "Capture approved reddit posts to send to bluesky"
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  is_enabled     = true
  name           = local.name
  tags           = var.tags

  event_pattern = jsonencode({
    source      = ["Pipe brutalismbot-${var.env}-shared-streams"]
    detail-type = ["Event from aws:dynamodb"]
    detail = {
      eventName = ["MODIFY"]
      dynamodb = {
        Keys     = { Kind = { S = ["reddit/post"] } }
        NewImage = { Status = { S = ["Approved"] } }
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
      Media     = "$.detail.dynamodb.NewImage.Media.S"
      Name      = "$.detail.dynamodb.NewImage.Name.S"
      Permalink = "$.detail.dynamodb.NewImage.Permalink.S"
      Title     = "$.detail.dynamodb.NewImage.Title.S"
    }
    input_template = <<-JSON
      {
        "Media": <Media>,
        "Name": <Name>,
        "Permalink": <Permalink>,
        "Title": <Title>
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
}

resource "aws_lambda_function" "lambda" {
  architectures    = ["arm64"]
  description      = "Create bluesky post item"
  filename         = data.archive_file.lambda.output_path
  function_name    = local.name
  handler          = "index.send_post"
  memory_size      = 1024
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby3.2"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags             = var.tags
  timeout          = 60

  environment {
    variables = { PARAM_PATH = local.param_path }
  }
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
          Sid      = "InvokeFunction"
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = aws_lambda_function.lambda.arn
        },
        {
          Sid      = "PutItem"
          Effect   = "Allow"
          Action   = "dynamodb:PutItem"
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

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yml", {
    send_post_arn = aws_lambda_function.lambda.arn
    table_name    = data.aws_dynamodb_table.table.name
  })))
}
