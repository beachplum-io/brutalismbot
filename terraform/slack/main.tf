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

module slack_install {
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

module slack_uninstall {
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

resource aws_lambda_permission slack_install {
  action        = "lambda:InvokeFunction"
  function_name = module.slack_install.lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = local.slack_sns_topic_arn
}

resource aws_lambda_permission slack_uninstall {
  action        = "lambda:InvokeFunction"
  function_name = module.slack_uninstall.lambda.arn
  principal     = "sns.amazonaws.com"
  source_arn    = local.slack_sns_topic_arn
}

resource aws_sns_topic_subscription slack_install {
  endpoint      = module.slack_install.lambda.arn
  filter_policy = jsonencode(local.filter_policy_slack_install)
  protocol      = "lambda"
  topic_arn     = local.slack_sns_topic_arn
}

resource aws_sns_topic_subscription slack_uninstall {
  endpoint      = module.slack_uninstall.lambda.arn
  filter_policy = jsonencode(local.filter_policy_slack_uninstall)
  protocol      = "lambda"
  topic_arn     = local.slack_sns_topic_arn
}
