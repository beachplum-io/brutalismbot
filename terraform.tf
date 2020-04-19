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

provider template {
  version = "~> 2.1"
}

locals {
  release              = var.RELEASE
  repo                 = "https://github.com/brutalismbot/brutalismbot"
  lag_time             = "9000"
  lambda_layer_name    = "brutalismbot"
  lambda_layer_version = "32"
  lambda_s3_key        = "pkg/brutalismbot-${local.release}/function.zip"
  posts_s3_prefix      = "data/v1/posts/"
  role_name            = "brutalismbot"
  s3_bucket            = "brutalismbot"
  slack_s3_prefix      = "data/v1/auths/"
  slack_sns_topic_name = "brutalismbot-slack"

  twitter_access_token        = var.TWITTER_ACCESS_TOKEN
  twitter_access_token_secret = var.TWITTER_ACCESS_TOKEN_SECRET
  twitter_consumer_key        = var.TWITTER_CONSUMER_KEY
  twitter_consumer_secret     = var.TWITTER_CONSUMER_SECRET

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

data aws_lambda_layer_version layer {
  layer_name = local.lambda_layer_name
  version    = local.lambda_layer_version
}

data aws_sns_topic slack {
  name = local.slack_sns_topic_name
}

module reddit {
  source           = "./terraform/reddit"
  lag_time         = local.lag_time
  lambda_layers    = [data.aws_lambda_layer_version.layer.arn]
  lambda_role_arn  = data.aws_iam_role.role.arn
  lambda_s3_bucket = aws_s3_bucket.brutalismbot.bucket
  lambda_s3_key    = local.lambda_s3_key
  posts_s3_bucket  = aws_s3_bucket.brutalismbot.bucket
  posts_s3_prefix  = local.posts_s3_prefix
  tags             = local.tags
}

module slack {
  source              = "./terraform/slack"
  lambda_layers       = [data.aws_lambda_layer_version.layer.arn]
  lambda_role_arn     = data.aws_iam_role.role.arn
  lambda_s3_bucket    = aws_s3_bucket.brutalismbot.bucket
  lambda_s3_key       = local.lambda_s3_key
  slack_s3_bucket     = aws_s3_bucket.brutalismbot.bucket
  slack_s3_prefix     = local.slack_s3_prefix
  slack_sns_topic_arn = data.aws_sns_topic.slack.arn
  tags                = local.tags
}

module states {
  source           = "./terraform/states"
  lambda_layers    = [data.aws_lambda_layer_version.layer.arn]
  lambda_role_arn  = data.aws_iam_role.role.arn
  lambda_s3_bucket = aws_s3_bucket.brutalismbot.bucket
  lambda_s3_key    = local.lambda_s3_key
  tags             = local.tags

  reddit_pull_lambda_arn  = module.reddit.pull.lambda.arn
  slack_list_lambda_arn   = module.slack.list.lambda.arn
  slack_push_lambda_arn   = module.slack.push.lambda.arn
  twitter_push_lambda_arn = module.twitter.push.lambda.arn
}

module test {
  source           = "./terraform/test"
  lambda_layers    = [data.aws_lambda_layer_version.layer.arn]
  lambda_role_arn  = data.aws_iam_role.role.arn
  lambda_s3_bucket = aws_s3_bucket.brutalismbot.bucket
  lambda_s3_key    = local.lambda_s3_key
  tags             = local.tags
}

module twitter {
  source                      = "./terraform/twitter"
  lambda_layers               = [data.aws_lambda_layer_version.layer.arn]
  lambda_role_arn             = data.aws_iam_role.role.arn
  lambda_s3_bucket            = aws_s3_bucket.brutalismbot.bucket
  lambda_s3_key               = local.lambda_s3_key
  twitter_access_token        = local.twitter_access_token
  twitter_access_token_secret = local.twitter_access_token_secret
  twitter_consumer_key        = local.twitter_consumer_key
  twitter_consumer_secret     = local.twitter_consumer_secret
  tags                        = local.tags
}

resource aws_iam_role_policy s3_access {
  name   = "s3"
  policy = data.aws_iam_policy_document.s3.json
  role   = data.aws_iam_role.role.id
}

resource aws_s3_bucket brutalismbot {
  acl           = "private"
  bucket        = local.s3_bucket
  force_destroy = false
}

resource aws_s3_bucket_public_access_block brutalismbot {
  bucket                  = aws_s3_bucket.brutalismbot.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

variable RELEASE {
  description = "Release tag."
}

variable TWITTER_ACCESS_TOKEN {
  description = "Twitter API access token."
}

variable TWITTER_ACCESS_TOKEN_SECRET {
  description = "Twitter API access token secret."
}

variable TWITTER_CONSUMER_KEY {
  description = "Twitter API Consumer Key."
}

variable TWITTER_CONSUMER_SECRET {
  description = "Twitter API Consumer Secret."
}
