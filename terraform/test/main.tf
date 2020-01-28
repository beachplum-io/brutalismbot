locals {
  lambda_layers    = var.lambda_layers
  lambda_role_arn  = var.lambda_role_arn
  lambda_s3_bucket = var.lambda_s3_bucket
  lambda_s3_key    = var.lambda_s3_key
  tags             = var.tags
}

module test {
  source = "../lambda"

  description   = "Test brutalismbot gem"
  function_name = "brutalismbot-test"
  handler       = "lambda.test"
  runtime       = "ruby2.5"

  layers    = local.lambda_layers
  role      = local.lambda_role_arn
  s3_bucket = local.lambda_s3_bucket
  s3_key    = local.lambda_s3_key
  tags      = local.tags

  environment_variables = {
    DRYRUN = "1"
  }
}
