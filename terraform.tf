terraform {
  required_version = "~> 0.14"

  backend "s3" {
    bucket = "brutalismbot"
    key    = "terraform/brutalismbot.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  dryrun                  = null
  is_enabled              = true
  lambda_filename         = "${path.module}/pkg/function.zip"
  lambda_layers           = [data.aws_lambda_layer_version.brutalismbot.arn]
  lambda_source_code_hash = filebase64sha256(local.lambda_filename)

  tags = {
    App  = "core"
    Name = "brutalismbot"
    Repo = "https://github.com/brutalismbot/brutalismbot"
  }
}

data "aws_lambda_layer_version" "brutalismbot" {
  layer_name = "brutalismbot"
}

data "aws_sns_topic" "brutalismbot_slack" {
  name = "brutalismbot-slack"
}

resource "aws_cloudwatch_event_bus" "brutalismbot" {
  name = "brutalismbot"
}

module "reddit" {
  source = "./terraform/reddit"

  lambda_filename         = local.lambda_filename
  lambda_layers           = local.lambda_layers
  lambda_role_arn         = aws_iam_role.lambda.arn
  lambda_source_code_hash = local.lambda_source_code_hash
  tags                    = local.tags

  lambda_environment = {
    MIN_AGE         = "9000"
    POSTS_S3_BUCKET = aws_s3_bucket.brutalismbot.bucket
    POSTS_S3_PREFIX = "data/v1/posts/"
  }
}

module "slack" {
  source = "./terraform/slack"

  lambda_filename         = local.lambda_filename
  lambda_layers           = local.lambda_layers
  lambda_role_arn         = aws_iam_role.lambda.arn
  lambda_source_code_hash = local.lambda_source_code_hash
  slack_sns_topic_arn     = data.aws_sns_topic.brutalismbot_slack.arn
  tags                    = local.tags

  lambda_environment = {
    DRYRUN          = local.dryrun
    SLACK_S3_BUCKET = aws_s3_bucket.brutalismbot.bucket
    SLACK_S3_PREFIX = "data/v1/auths/"
  }
}

module "states" {
  source = "./terraform/states"

  is_enabled = local.is_enabled

  lambda_filename         = local.lambda_filename
  lambda_layers           = local.lambda_layers
  lambda_role_arn         = aws_iam_role.lambda.arn
  lambda_source_code_hash = local.lambda_source_code_hash
  tags                    = local.tags

  lambda_arns = {
    reddit_pull  = module.reddit.pull.arn
    slack_list   = module.slack.list.arn
    slack_push   = module.slack.push.arn
    twitter_push = module.twitter.push.arn
  }
}

module "test" {
  source = "./terraform/test"

  lambda_environment      = { DRYRUN = "1" }
  lambda_filename         = local.lambda_filename
  lambda_layers           = local.lambda_layers
  lambda_role_arn         = aws_iam_role.lambda.arn
  lambda_source_code_hash = local.lambda_source_code_hash
  tags                    = local.tags
}

module "twitter" {
  source = "./terraform/twitter"

  lambda_filename         = local.lambda_filename
  lambda_layers           = local.lambda_layers
  lambda_role_arn         = aws_iam_role.lambda.arn
  lambda_source_code_hash = local.lambda_source_code_hash
  tags                    = local.tags

  lambda_environment = {
    DRYRUN         = local.dryrun
    TWITTER_SECRET = "brutalismbot/twitter"
  }
}

# S3

resource "aws_s3_bucket" "brutalismbot" {
  acl           = "private"
  bucket        = "brutalismbot"
  force_destroy = false

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "brutalismbot" {
  bucket                  = aws_s3_bucket.brutalismbot.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM :: EVENTS

data "aws_iam_policy_document" "events_trust_policy" {
  statement {
    sid     = "AssumeEvents"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events" {
  assume_role_policy = data.aws_iam_policy_document.events_trust_policy.json
  name               = "brutalismbot-events"
  tags               = local.tags
}

data "aws_iam_policy_document" "events_policy" {
  statement {
    sid       = "StartStateMachine"
    actions   = ["states:StartExecution"]
    resources = ["${module.states.state_machines.main.id}*"]
  }
}

resource "aws_iam_role_policy" "events" {
  name   = "events"
  policy = data.aws_iam_policy_document.events_policy.json
  role   = aws_iam_role.events.name
}

# IAM :: STATES

data "aws_dynamodb_table" "table" {
  name = "Brutalismbot"
}

data "aws_iam_policy_document" "states_trust_policy" {
  statement {
    sid     = "AssumeStateMachine"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "states" {
  assume_role_policy = data.aws_iam_policy_document.states_trust_policy.json
  name               = "brutalismbot-states"
  tags               = local.tags
}

data "aws_iam_policy_document" "states_policy" {
  statement {
    sid       = "DynamoDBAccess"
    actions   = ["dynamodb:*"]
    resources = [data.aws_dynamodb_table.table.arn]
  }

  statement {
    sid       = "InvokeFunction"
    actions   = ["lambda:InvokeFunction"]
    resources = ["*"]
  }

  statement {
    sid       = "QueueMessage"
    actions   = ["sqs:SendMessage"]
    resources = ["*"]
  }

  statement {
    sid       = "StartStateMachine"
    actions   = ["states:StartExecution"]
    resources = ["*"]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "states" {
  name   = "states"
  policy = data.aws_iam_policy_document.states_policy.json
  role   = aws_iam_role.states.name
}

# IAM :: LAMBDA

data "aws_iam_policy_document" "lambda_trust_policy" {
  statement {
    sid     = "AssumeLambda"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  assume_role_policy = data.aws_iam_policy_document.lambda_trust_policy.json
  name               = "brutalismbot-lambda"
  tags               = local.tags
}

data "aws_dynamodb_table" "brutalismbot" {
  name = "Brutalismbot"
}

data "aws_kms_alias" "brutalismbot" {
  name = "alias/brutalismbot"
}

data "aws_secretsmanager_secret" "twitter" {
  name = "brutalismbot/twitter"
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid       = "AccessDynamoDB"
    actions   = ["dynamodb:*"]
    resources = ["${data.aws_dynamodb_table.brutalismbot.arn}*"]
  }

  statement {
    sid     = "AccessS3"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.brutalismbot.arn,
      "${aws_s3_bucket.brutalismbot.arn}/*",
    ]
  }

  statement {
    sid       = "AccessSecrets"
    actions   = ["secretsmanager:*"]
    resources = [data.aws_secretsmanager_secret.twitter.arn]
  }

  statement {
    sid       = "DecryptKMS"
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_alias.brutalismbot.target_key_arn]
  }

  statement {
    sid       = "PublishEvents"
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.brutalismbot.arn]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "lambda"
  policy = data.aws_iam_policy_document.lambda_policy.json
  role   = aws_iam_role.lambda.name
}
