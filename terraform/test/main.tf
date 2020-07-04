locals {
  lambda_layers    = var.lambda_layers
  lambda_role_arn  = var.lambda_role_arn
  lambda_s3_bucket = var.lambda_s3_bucket
  lambda_s3_key    = var.lambda_s3_key
  tags             = var.tags
}

resource aws_cloudwatch_log_group test {
  name              = "/aws/lambda/${aws_lambda_function.test.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_lambda_function test {
  description   = "Test brutalismbot gem"
  function_name = "brutalismbot-test"
  handler       = "lambda.test"
  layers        = local.lambda_layers
  role          = local.lambda_role_arn
  runtime       = "ruby2.7"
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  tags          = local.tags

  environment {
    variables = {
      DRYRUN = "1"
    }
  }
}
