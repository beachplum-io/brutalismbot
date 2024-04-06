###############
#   LOCALS    #
###############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name

  name       = "brutalismbot-${var.env}-${var.app}-api"
  param_path = "/brutalismbot/${var.env}/${var.app}/"

  routes = [
    "GET /health",
    "GET /install",
    "GET /oauth/v2",
    "HEAD /health",
    "HEAD /install",
    "POST /callbacks",
    "POST /events",
    "POST /health",
    "POST /slash/{cmd}",
  ]
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_cloudwatch_event_bus" "bus" {
  name = "brutalismbot-${var.env}"
}

################
#   HTTP API   #
################

resource "aws_apigatewayv2_api" "http_api" {
  description                  = "Brutalismbot Slack Beta API"
  disable_execute_api_endpoint = true
  name                         = local.name
  protocol_type                = "HTTP"
  tags                         = var.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  auto_deploy = true
  description = "Brutalismbot Slack Beta API default stage"
  name        = "$default"
  tags        = var.tags

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.http_api.arn

    format = jsonencode({
      httpMethod     = "$context.httpMethod"
      ip             = "$context.identity.sourceIp"
      protocol       = "$context.protocol"
      requestId      = "$context.requestId"
      requestTime    = "$context.requestTime"
      responseLength = "$context.responseLength"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
    })
  }

  lifecycle { ignore_changes = [deployment_id] }
}

resource "aws_apigatewayv2_integration" "proxy" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  connection_type        = "INTERNET"
  description            = "Brutalismbot Slack API Lambda proxy"
  integration_method     = "POST"
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lambda.arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 3000
}

resource "aws_apigatewayv2_route" "routes" {
  for_each           = toset(local.routes)
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = each.key
  authorization_type = "NONE"
  target             = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_cloudwatch_log_group" "http_api" {
  name              = "/aws/apigatewayv2/${aws_apigatewayv2_api.http_api.name}"
  retention_in_days = 14
  tags              = var.tags
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
          Sid      = "PutEvents"
          Effect   = "Allow"
          Action   = "events:PutEvents"
          Resource = data.aws_cloudwatch_event_bus.bus.arn
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
  description      = "Handle Slack events"
  filename         = data.archive_file.lambda.output_path
  function_name    = local.name
  handler          = "index.proxy"
  memory_size      = 3072
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby3.3"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags             = var.tags
  timeout          = 30

  environment {
    variables = {
      EVENT_BUS    = data.aws_cloudwatch_event_bus.bus.name
      EVENT_SOURCE = "slack/beta"
      PARAM_PATH   = local.param_path
    }
  }
}

resource "aws_lambda_permission" "lambda" {
  for_each      = { for route in local.routes : route => replace(route, " ", "") }
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/${aws_apigatewayv2_stage.default.name}/${each.value}"
}
