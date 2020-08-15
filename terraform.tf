terraform {
  backend s3 {
    bucket = "brutalismbot"
    key    = "terraform/brutalismbot.tfstate"
    region = "us-east-1"
  }
}

provider aws {
  region  = "us-east-1"
  version = "~> 3.2"
}

locals {
  lambda_filename         = "${path.module}/pkg/function.zip"
  lambda_layers           = [data.aws_lambda_layer_version.brutalismbot.arn]
  lambda_source_code_hash = filebase64sha256(local.lambda_filename)

  tags = {
    App  = "core"
    Name = "brutalismbot"
    Repo = "https://github.com/brutalismbot/brutalismbot"
  }
}

data aws_iam_role brutalismbot {
  name = "brutalismbot"
}

data aws_iam_policy_document inline {
  statement {
    sid     = "AccessS3"
    actions = ["s3:*"]

    resources = [
      "${aws_s3_bucket.brutalismbot.arn}",
      "${aws_s3_bucket.brutalismbot.arn}/*",
    ]
  }

  statement {
    sid       = "AccessSecrets"
    actions   = ["secretsmanager:*"]
    resources = [data.aws_secretsmanager_secret.twitter.arn]
  }
}

data aws_lambda_layer_version brutalismbot {
  layer_name = "brutalismbot"
  version    = null
}

data aws_secretsmanager_secret twitter {
  name = "brutalismbot/twitter"
}

data aws_sns_topic brutalismbot_slack {
  name = "brutalismbot-slack"
}

module reddit {
  source = "./terraform/reddit"

  lambda_filename         = local.lambda_filename
  lambda_layers           = [data.aws_lambda_layer_version.brutalismbot.arn]
  lambda_role_arn         = data.aws_iam_role.brutalismbot.arn
  lambda_source_code_hash = local.lambda_source_code_hash
  tags                    = local.tags

  lambda_environment = {
    MIN_AGE         = "9000"
    POSTS_S3_BUCKET = aws_s3_bucket.brutalismbot.bucket
    POSTS_S3_PREFIX = "data/v1/posts/"
  }
}

module slack {
  source = "./terraform/slack"

  lambda_filename         = local.lambda_filename
  lambda_layers           = [data.aws_lambda_layer_version.brutalismbot.arn]
  lambda_role_arn         = data.aws_iam_role.brutalismbot.arn
  lambda_source_code_hash = local.lambda_source_code_hash
  slack_sns_topic_arn     = data.aws_sns_topic.brutalismbot_slack.arn
  tags                    = local.tags

  lambda_environment = {
    SLACK_S3_BUCKET = aws_s3_bucket.brutalismbot.bucket
    SLACK_S3_PREFIX = "data/v1/auths/"
  }
}

module states {
  source = "./terraform/states"

  lambda_filename         = local.lambda_filename
  lambda_layers           = [data.aws_lambda_layer_version.brutalismbot.arn]
  lambda_role_arn         = data.aws_iam_role.brutalismbot.arn
  lambda_source_code_hash = local.lambda_source_code_hash
  tags                    = local.tags

  reddit_pull_lambda_arn  = module.reddit.pull.arn
  slack_list_lambda_arn   = module.slack.list.arn
  slack_push_lambda_arn   = module.slack.push.arn
  twitter_push_lambda_arn = module.twitter.push.arn
}

module test {
  source = "./terraform/test"

  lambda_filename         = local.lambda_filename
  lambda_layers           = [data.aws_lambda_layer_version.brutalismbot.arn]
  lambda_role_arn         = data.aws_iam_role.brutalismbot.arn
  lambda_source_code_hash = local.lambda_source_code_hash
  tags                    = local.tags

  lambda_environment = {
    DRYRUN = "1"
  }
}

module twitter {
  source = "./terraform/twitter"

  lambda_filename         = local.lambda_filename
  lambda_layers           = [data.aws_lambda_layer_version.brutalismbot.arn]
  lambda_role_arn         = data.aws_iam_role.brutalismbot.arn
  lambda_source_code_hash = local.lambda_source_code_hash
  tags                    = local.tags

  lambda_environment = {
    TWITTER_SECRET = "brutalismbot/twitter"
  }
}

resource aws_iam_role_policy inline {
  name   = "s3"
  policy = data.aws_iam_policy_document.inline.json
  role   = data.aws_iam_role.brutalismbot.id
}

resource aws_s3_bucket brutalismbot {
  acl           = "private"
  bucket        = "brutalismbot"
  force_destroy = false
}

resource aws_s3_bucket_public_access_block brutalismbot {
  bucket                  = aws_s3_bucket.brutalismbot.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
