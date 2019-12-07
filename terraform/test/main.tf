locals {
  lambda_layer_arn = var.lambda_layer_arn
  lambda_role_arn  = var.lambda_role_arn
  lambda_s3_bucket = var.lambda_s3_bucket
  lambda_s3_key    = var.lambda_s3_key
  tags             = var.tags
}

resource aws_lambda_function test {
  description   = "Test brutalismbot gem"
  function_name = "brutalismbot-test"
  handler       = "lambda.test"
  layers        = [local.lambda_layer_arn]
  role          = local.lambda_role_arn
  runtime       = "ruby2.5"
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  tags          = local.tags
  timeout       = 3
}
