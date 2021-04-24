locals {
  lambda_environment      = var.lambda_environment
  lambda_filename         = var.lambda_filename
  lambda_layers           = var.lambda_layers
  lambda_role_arn         = var.lambda_role_arn
  lambda_runtime          = var.lambda_runtime
  lambda_source_code_hash = var.lambda_source_code_hash
  tags                    = var.tags
}

# LAMBDA

resource "aws_lambda_function" "test" {
  description      = "Test brutalismbot gem"
  filename         = local.lambda_filename
  function_name    = "brutalismbot-test"
  handler          = "lambda.test"
  layers           = local.lambda_layers
  memory_size      = 128
  role             = local.lambda_role_arn
  runtime          = local.lambda_runtime
  source_code_hash = local.lambda_source_code_hash
  tags             = local.tags
  timeout          = 3

  environment {
    variables = local.lambda_environment
  }
}

# LOGS

resource "aws_cloudwatch_log_group" "test" {
  name              = "/aws/lambda/${aws_lambda_function.test.function_name}"
  retention_in_days = 30
  tags              = local.tags
}
