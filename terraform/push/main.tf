locals {
  lambda_layer_arn            = var.lambda_layer_arn
  lambda_role_arn             = var.lambda_role_arn
  lambda_s3_bucket            = var.lambda_s3_bucket
  lambda_s3_key               = var.lambda_s3_key
  posts_s3_bucket             = var.posts_s3_bucket
  posts_s3_prefix             = var.posts_s3_prefix
  slack_s3_bucket             = var.slack_s3_bucket
  slack_s3_prefix             = var.slack_s3_prefix
  twitter_access_token        = var.twitter_access_token
  twitter_access_token_secret = var.twitter_access_token_secret
  twitter_consumer_key        = var.twitter_consumer_key
  twitter_consumer_secret     = var.twitter_consumer_secret
  tags                        = var.tags
}

data aws_s3_bucket brutalismbot {
  bucket = local.posts_s3_bucket
}

resource aws_cloudwatch_log_group push {
  name              = "/aws/lambda/${aws_lambda_function.push.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_lambda_function push {
  description   = "Push posts from /r/brutalism"
  function_name = "brutalismbot-push"
  handler       = "lambda.push"
  layers        = [local.lambda_layer_arn]
  role          = local.lambda_role_arn
  runtime       = "ruby2.5"
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  tags          = local.tags
  timeout       = 30

  environment {
    variables = {
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
}

resource aws_lambda_permission push {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.push.arn
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.brutalismbot.arn
}

resource aws_s3_bucket_notification push {
  bucket = data.aws_s3_bucket.brutalismbot.id

  lambda_function {
    id                  = "push"
    lambda_function_arn = aws_lambda_function.push.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = local.posts_s3_prefix
    filter_suffix       = ".json"
  }
}
