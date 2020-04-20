locals {
  min_age          = var.min_age
  lambda_layers    = var.lambda_layers
  lambda_role_arn  = var.lambda_role_arn
  lambda_s3_bucket = var.lambda_s3_bucket
  lambda_s3_key    = var.lambda_s3_key
  posts_s3_bucket  = var.posts_s3_bucket
  posts_s3_prefix  = var.posts_s3_prefix
  tags             = var.tags
}

module pull {
  source = "../lambda"

  description   = "Pull posts from /r/brutalism"
  function_name = "brutalismbot-reddit-pull"
  handler       = "lambda.reddit_pull"
  memory_size   = "1024"
  timeout       = "30"

  layers    = local.lambda_layers
  role      = local.lambda_role_arn
  s3_bucket = local.lambda_s3_bucket
  s3_key    = local.lambda_s3_key
  tags      = local.tags

  environment_variables = {
    MIN_AGE         = local.min_age
    POSTS_S3_BUCKET = local.posts_s3_bucket
    POSTS_S3_PREFIX = local.posts_s3_prefix
  }
}
