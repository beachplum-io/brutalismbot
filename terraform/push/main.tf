locals {
  lambda_layers               = var.lambda_layers
  lambda_role_arn             = var.lambda_role_arn
  lambda_s3_bucket            = var.lambda_s3_bucket
  lambda_s3_key               = var.lambda_s3_key
  posts_s3_bucket             = var.posts_s3_bucket
  posts_s3_prefix             = var.posts_s3_prefix
  slack_s3_bucket             = var.slack_s3_bucket
  slack_s3_prefix             = var.slack_s3_prefix
  tags                        = var.tags
  twitter_access_token        = var.twitter_access_token
  twitter_access_token_secret = var.twitter_access_token_secret
  twitter_consumer_key        = var.twitter_consumer_key
  twitter_consumer_secret     = var.twitter_consumer_secret
}

data aws_s3_bucket brutalismbot {
  bucket = local.posts_s3_bucket
}

module push {
  source = "../lambda"

  description   = "Push posts from /r/brutalism"
  function_name = "brutalismbot-push"
  handler       = "lambda.push"
  timeout       = "30"

  layers    = local.lambda_layers
  role      = local.lambda_role_arn
  s3_bucket = local.lambda_s3_bucket
  s3_key    = local.lambda_s3_key
  tags      = local.tags

  environment_variables = {
    POSTS_S3_BUCKET             = local.posts_s3_bucket
    POSTS_S3_PREFIX             = local.posts_s3_prefix
    SLACK_S3_BUCKET             = local.slack_s3_bucket
    SLACK_S3_PREFIX             = local.slack_s3_prefix
    TWITTER_ACCESS_TOKEN        = local.twitter_access_token
    TWITTER_ACCESS_TOKEN_SECRET = local.twitter_access_token_secret
    TWITTER_CONSUMER_KEY        = local.twitter_consumer_key
    TWITTER_CONSUMER_SECRET     = local.twitter_consumer_secret
  }
}

resource aws_lambda_permission push {
  action        = "lambda:InvokeFunction"
  function_name = module.push.lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.brutalismbot.arn
}

resource aws_s3_bucket_notification push {
  bucket = data.aws_s3_bucket.brutalismbot.id

  lambda_function {
    id                  = "push"
    lambda_function_arn = module.push.lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = local.posts_s3_prefix
    filter_suffix       = ".json"
  }
}
