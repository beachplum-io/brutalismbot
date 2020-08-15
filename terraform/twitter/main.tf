locals {
  lambda_environment      = var.lambda_environment
  lambda_filename         = var.lambda_filename
  lambda_layers           = var.lambda_layers
  lambda_role_arn         = var.lambda_role_arn
  lambda_runtime          = var.lambda_runtime
  lambda_source_code_hash = var.lambda_source_code_hash
  tags                    = var.tags
}

resource aws_cloudwatch_log_group push {
  name              = "/aws/lambda/${aws_lambda_function.push.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_lambda_function push {
  description      = "Push posts from /r/brutalism"
  filename         = local.lambda_filename
  function_name    = "brutalismbot-twitter-push"
  handler          = "lambda.twitter_push"
  layers           = local.lambda_layers
  role             = local.lambda_role_arn
  runtime          = local.lambda_runtime
  source_code_hash = local.lambda_source_code_hash
  tags             = local.tags
  timeout          = 30

  environment {
    variables = local.lambda_environment
  }
}
