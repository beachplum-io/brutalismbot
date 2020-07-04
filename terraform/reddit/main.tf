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

resource aws_cloudwatch_log_group pull {
  name              = "/aws/lambda/${aws_lambda_function.pull.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_lambda_function pull {
  description   = "Pull posts from /r/brutalism"
  function_name = "brutalismbot-reddit-pull"
  handler       = "lambda.reddit_pull"
  layers        = local.lambda_layers
  memory_size   = 1024
  role          = local.lambda_role_arn
  runtime       = "ruby2.7"
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  tags          = local.tags
  timeout       = 30

  environment {
    variables = {
      MIN_AGE         = local.min_age
      POSTS_S3_BUCKET = local.posts_s3_bucket
      POSTS_S3_PREFIX = local.posts_s3_prefix
    }
  }
}
