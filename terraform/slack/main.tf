locals {
  lambda_layers       = var.lambda_layers
  lambda_role_arn     = var.lambda_role_arn
  lambda_s3_bucket    = var.lambda_s3_bucket
  lambda_s3_key       = var.lambda_s3_key
  slack_s3_bucket     = var.slack_s3_bucket
  slack_s3_prefix     = var.slack_s3_prefix
  slack_sns_topic_arn = var.slack_sns_topic_arn
  tags                = var.tags

  filter_policy_slack_install = {
    type = ["oauth"]
  }

  filter_policy_slack_uninstall = {
    id   = ["app_uninstalled"]
    type = ["event"]
  }
}

module install {
  source = "../lambda"

  description   = "Install app to Slack workspace"
  function_name = "brutalismbot-slack-install"
  handler       = "lambda.slack_install"

  layers    = local.lambda_layers
  role      = local.lambda_role_arn
  s3_bucket = local.lambda_s3_bucket
  s3_key    = local.lambda_s3_key
  tags      = local.tags

  environment_variables = {
    SLACK_S3_BUCKET = local.slack_s3_bucket
    SLACK_S3_PREFIX = local.slack_s3_prefix
  }
}

module list {
  source = "../lambda"

  description   = "Get slack authorizations"
  function_name = "brutalismbot-slack-list"
  handler       = "lambda.slack_list"

  layers    = local.lambda_layers
  role      = local.lambda_role_arn
  s3_bucket = local.lambda_s3_bucket
  s3_key    = local.lambda_s3_key
  tags      = local.tags
}

module push {
  source = "../lambda"

  description   = "Push posts from /r/brutalism to Slack"
  function_name = "brutalismbot-slack-push"
  handler       = "lambda.slack_push"

  layers    = local.lambda_layers
  role      = local.lambda_role_arn
  s3_bucket = local.lambda_s3_bucket
  s3_key    = local.lambda_s3_key
  tags      = local.tags
}

module uninstall {
  source = "../lambda"

  description   = "Uninstall brutalismbot from Slack workspace"
  function_name = "brutalismbot-slack-uninstall"
  handler       = "lambda.slack_uninstall"

  layers    = local.lambda_layers
  role      = local.lambda_role_arn
  s3_bucket = local.lambda_s3_bucket
  s3_key    = local.lambda_s3_key
  tags      = local.tags

  environment_variables = {
    SLACK_S3_BUCKET = local.slack_s3_bucket
    SLACK_S3_PREFIX = local.slack_s3_prefix
  }
}

resource aws_lambda_permission install {
  action        = "lambda:InvokeFunction"
  function_name = module.install.lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = local.slack_sns_topic_arn
}

resource aws_lambda_permission uninstall {
  action        = "lambda:InvokeFunction"
  function_name = module.uninstall.lambda.arn
  principal     = "sns.amazonaws.com"
  source_arn    = local.slack_sns_topic_arn
}

resource aws_sns_topic_subscription install {
  endpoint      = module.install.lambda.arn
  filter_policy = jsonencode(local.filter_policy_slack_install)
  protocol      = "lambda"
  topic_arn     = local.slack_sns_topic_arn
}

resource aws_sns_topic_subscription uninstall {
  endpoint      = module.uninstall.lambda.arn
  filter_policy = jsonencode(local.filter_policy_slack_uninstall)
  protocol      = "lambda"
  topic_arn     = local.slack_sns_topic_arn
}
