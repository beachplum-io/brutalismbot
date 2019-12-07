locals {
  lag_time         = var.lag_time
  lambda_role      = var.lambda_role
  lambda_s3_bucket = var.lambda_s3_bucket
  lambda_s3_key    = var.lambda_s3_key
  posts_s3_bucket  = var.posts_s3_bucket
  posts_s3_prefix  = var.posts_s3_prefix
  tags             = var.tags
}

data aws_iam_role role {
  name = local.lambda_role
}

resource aws_cloudwatch_event_rule pull {
  description         = "Pull posts from /r/brutalism to S3"
  name                = aws_lambda_function.pull.function_name
  schedule_expression = "rate(1 hour)"
  tags                = local.tags
}

resource aws_cloudwatch_event_target pull {
  rule = aws_cloudwatch_event_rule.pull.name
  arn  = aws_lambda_function.pull.arn
}

resource aws_cloudwatch_log_group pull {
  name              = "/aws/lambda/${aws_lambda_function.pull.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_lambda_function pull {
  description   = "Pull posts from /r/brutalism"
  function_name = "brutalismbot-pull"
  handler       = "lambda.pull"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  tags          = local.tags
  timeout       = 30

  environment {
    variables = {
      BRUTALISMBOT_LAG_TIME = local.lag_time
      POSTS_S3_BUCKET       = local.posts_s3_bucket
      POSTS_S3_PREFIX       = local.posts_s3_prefix
    }
  }
}

resource aws_lambda_permission pull {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pull.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.pull.arn
}
