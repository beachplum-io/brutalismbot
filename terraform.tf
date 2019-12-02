terraform {
  backend s3 {
    bucket = "brutalismbot"
    key    = "terraform/brutalismbot.tfstate"
    region = "us-east-1"
  }
}

provider aws {
  version = "~> 2.7"
}

provider null {
  version = "~> 2.1"
}

locals {
  release                     = var.release
  repo                        = "https://github.com/brutalismbot/brutalismbot"
  lag_time                    = "9000"
  lambda_s3_key               = "terraform/pkg/brutalismbot-${local.release}.zip"
  role_name                   = "brutalismbot"
  s3_bucket                   = "brutalismbot"
  s3_prefix_posts             = "data/v1/posts/"
  s3_prefix_slack             = "data/v1/auths/"
  topic_name                  = "brutalismbot-slack"
  twitter_access_token        = var.twitter_access_token
  twitter_access_token_secret = var.twitter_access_token_secret
  twitter_consumer_key        = var.twitter_consumer_key
  twitter_consumer_secret     = var.twitter_consumer_secret

  filter_policy_slack_install = {
    type = ["oauth"]
  }

  filter_policy_slack_uninstall = {
    id   = ["app_uninstalled"]
    type = ["event"]
  }

  tags = {
    App     = "core"
    Name    = "brutalismbot"
    Release = local.release
    Repo    = local.repo
  }
}

data aws_iam_role role {
  name = local.role_name
}

data aws_iam_policy_document s3 {
  statement {
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.brutalismbot.arn,
      "${aws_s3_bucket.brutalismbot.arn}/*",
    ]
  }
}

data aws_sns_topic topic {
  name = local.topic_name
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

resource aws_cloudwatch_log_group push {
  name              = "/aws/lambda/${aws_lambda_function.push.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_cloudwatch_log_group slack_install {
  name              = "/aws/lambda/${aws_lambda_function.slack_install.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_cloudwatch_log_group slack_uninstall {
  name              = "/aws/lambda/${aws_lambda_function.slack_uninstall.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_iam_role_policy s3_access {
  name   = "s3"
  policy = data.aws_iam_policy_document.s3.json
  role   = data.aws_iam_role.role.id
}

resource aws_lambda_function pull {
  description   = "Pull posts from /r/brutalism"
  function_name = "brutalismbot-pull"
  handler       = "lambda.pull"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = aws_s3_bucket.brutalismbot.bucket
  s3_key        = null_resource.lambda.triggers.lambda_s3_key
  tags          = local.tags
  timeout       = 30

  environment {
    variables = {
      BRUTALISMBOT_LAG_TIME = local.lag_time
      POSTS_S3_BUCKET       = aws_s3_bucket.brutalismbot.bucket
      POSTS_S3_PREFIX       = local.s3_prefix_posts
    }
  }
}

resource aws_lambda_function push {
  description   = "Push posts from /r/brutalism"
  function_name = "brutalismbot-push"
  handler       = "lambda.push"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = aws_s3_bucket.brutalismbot.bucket
  s3_key        = null_resource.lambda.triggers.lambda_s3_key
  tags          = local.tags
  timeout       = 30

  environment {
    variables = {
      POSTS_S3_BUCKET             = aws_s3_bucket.brutalismbot.bucket
      POSTS_S3_PREFIX             = local.s3_prefix_posts
      SLACK_S3_BUCKET             = aws_s3_bucket.brutalismbot.bucket
      SLACK_S3_PREFIX             = local.s3_prefix_slack
      TWITTER_ACCESS_TOKEN        = local.twitter_access_token
      TWITTER_ACCESS_TOKEN_SECRET = local.twitter_access_token_secret
      TWITTER_CONSUMER_KEY        = local.twitter_consumer_key
      TWITTER_CONSUMER_SECRET     = local.twitter_consumer_secret
    }
  }
}

resource aws_lambda_function slack_install {
  description   = "Install app to Slack workspace"
  function_name = "brutalismbot-slack-install"
  handler       = "lambda.slack_install"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = aws_s3_bucket.brutalismbot.bucket
  s3_key        = null_resource.lambda.triggers.lambda_s3_key
  tags          = local.tags
  timeout       = 3

  environment {
    variables = {
      SLACK_S3_BUCKET = aws_s3_bucket.brutalismbot.bucket
      SLACK_S3_PREFIX = local.s3_prefix_slack
    }
  }
}

resource aws_lambda_function slack_uninstall {
  description   = "Uninstall brutalismbot from Slack workspace"
  function_name = "brutalismbot-slack-uninstall"
  handler       = "lambda.slack_uninstall"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = aws_s3_bucket.brutalismbot.bucket
  s3_key        = null_resource.lambda.triggers.lambda_s3_key
  tags          = local.tags
  timeout       = 3

  environment {
    variables = {
      SLACK_S3_BUCKET = aws_s3_bucket.brutalismbot.bucket
      SLACK_S3_PREFIX = local.s3_prefix_slack
    }
  }
}

resource aws_lambda_permission pull {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pull.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.pull.arn
}

resource aws_lambda_permission push {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.push.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.brutalismbot.arn
}

resource aws_lambda_permission slack_install {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_install.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = data.aws_sns_topic.topic.arn
}

resource aws_lambda_permission slack_uninstall {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_uninstall.arn
  principal     = "sns.amazonaws.com"
  source_arn    = data.aws_sns_topic.topic.arn
}

resource aws_s3_bucket brutalismbot {
  acl           = "private"
  bucket        = local.s3_bucket
  force_destroy = false
}

resource aws_s3_bucket_notification push {
  bucket = aws_s3_bucket.brutalismbot.id

  lambda_function {
    id                  = "push"
    lambda_function_arn = aws_lambda_function.push.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = local.s3_prefix_posts
    filter_suffix       = ".json"
  }
}

resource aws_s3_bucket_public_access_block brutalismbot {
  bucket                  = aws_s3_bucket.brutalismbot.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource aws_sns_topic_subscription install {
  endpoint      = aws_lambda_function.slack_install.arn
  filter_policy = jsonencode(local.filter_policy_slack_install)
  protocol      = "lambda"
  topic_arn     = data.aws_sns_topic.topic.arn
}

resource aws_sns_topic_subscription uninstall {
  endpoint      = aws_lambda_function.slack_uninstall.arn
  filter_policy = jsonencode(local.filter_policy_slack_uninstall)
  protocol      = "lambda"
  topic_arn     = data.aws_sns_topic.topic.arn
}

resource null_resource lambda {
  triggers = {
    lambda_s3_key = local.lambda_s3_key
  }

  provisioner "local-exec" {
    command = "aws s3 cp lambda.zip s3://${aws_s3_bucket.brutalismbot.bucket}/${local.lambda_s3_key}"
  }
}

variable release {
  description = "Release tag."
}

variable twitter_access_token {
  description = "Twitter API access token."
}

variable twitter_access_token_secret {
  description = "Twitter API access token secret."
}

variable twitter_consumer_key {
  description = "Twitter API Consumer Key."
}

variable twitter_consumer_secret {
  description = "Twitter API Consumer Secret."
}

output lambda_s3_url {
  description = "Lambda function package S3 URL."
  value       = "s3://${aws_s3_bucket.brutalismbot.bucket}/${local.lambda_s3_key}"
}
