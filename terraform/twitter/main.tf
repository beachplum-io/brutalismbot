locals {
  lambda_layers               = var.lambda_layers
  lambda_role_arn             = var.lambda_role_arn
  lambda_s3_bucket            = var.lambda_s3_bucket
  lambda_s3_key               = var.lambda_s3_key
  tags                        = var.tags
  twitter_access_token        = var.twitter_access_token
  twitter_access_token_secret = var.twitter_access_token_secret
  twitter_consumer_key        = var.twitter_consumer_key
  twitter_consumer_secret     = var.twitter_consumer_secret
}

module push {
  source = "../lambda"

  description   = "Push posts from /r/brutalism"
  function_name = "brutalismbot-twitter-push"
  handler       = "lambda.twitter_push"
  timeout       = 30

  layers    = local.lambda_layers
  role      = local.lambda_role_arn
  s3_bucket = local.lambda_s3_bucket
  s3_key    = local.lambda_s3_key
  tags      = local.tags

  environment_variables = {
    TWITTER_ACCESS_TOKEN        = local.twitter_access_token
    TWITTER_ACCESS_TOKEN_SECRET = local.twitter_access_token_secret
    TWITTER_CONSUMER_KEY        = local.twitter_consumer_key
    TWITTER_CONSUMER_SECRET     = local.twitter_consumer_secret
  }
}
