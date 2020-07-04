locals {
  lambda_layers       = var.lambda_layers
  lambda_role_arn     = var.lambda_role_arn
  lambda_runtime      = var.lambda_runtime
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

resource aws_cloudwatch_log_group install {
  name              = "/aws/lambda/${aws_lambda_function.install.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_cloudwatch_log_group list {
  name              = "/aws/lambda/${aws_lambda_function.list.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_cloudwatch_log_group push {
  name              = "/aws/lambda/${aws_lambda_function.push.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_cloudwatch_log_group uninstall {
  name              = "/aws/lambda/${aws_lambda_function.uninstall.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_lambda_function install {
  description   = "Install app to Slack workspace"
  function_name = "brutalismbot-slack-install"
  handler       = "lambda.slack_install"
  layers        = local.lambda_layers
  role          = local.lambda_role_arn
  runtime       = local.lambda_runtime
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  tags          = local.tags

  environment {
    variables = {
      SLACK_S3_BUCKET = local.slack_s3_bucket
      SLACK_S3_PREFIX = local.slack_s3_prefix
    }
  }
}

resource aws_lambda_function list {
  description   = "Get slack authorizations"
  function_name = "brutalismbot-slack-list"
  handler       = "lambda.slack_list"
  layers        = local.lambda_layers
  role          = local.lambda_role_arn
  runtime       = local.lambda_runtime
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  tags          = local.tags
}

resource aws_lambda_function push {
  description   = "Push posts from /r/brutalism to Slack"
  function_name = "brutalismbot-slack-push"
  handler       = "lambda.slack_push"
  layers        = local.lambda_layers
  role          = local.lambda_role_arn
  runtime       = local.lambda_runtime
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  tags          = local.tags
}

resource aws_lambda_function uninstall {
  description   = "Uninstall brutalismbot from Slack workspace"
  function_name = "brutalismbot-slack-uninstall"
  handler       = "lambda.slack_uninstall"
  layers        = local.lambda_layers
  role          = local.lambda_role_arn
  runtime       = local.lambda_runtime
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  tags          = local.tags

  environment {
    variables = {
      SLACK_S3_BUCKET = local.slack_s3_bucket
      SLACK_S3_PREFIX = local.slack_s3_prefix
    }
  }
}

resource aws_lambda_permission install {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.install.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = local.slack_sns_topic_arn
}

resource aws_lambda_permission uninstall {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.uninstall.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = local.slack_sns_topic_arn
}

resource aws_sns_topic_subscription install {
  endpoint      = aws_lambda_function.install.arn
  filter_policy = jsonencode(local.filter_policy_slack_install)
  protocol      = "lambda"
  topic_arn     = local.slack_sns_topic_arn
}

resource aws_sns_topic_subscription uninstall {
  endpoint      = aws_lambda_function.uninstall.arn
  filter_policy = jsonencode(local.filter_policy_slack_uninstall)
  protocol      = "lambda"
  topic_arn     = local.slack_sns_topic_arn
}
