locals {
  lambda_role      = var.lambda_role
  lambda_s3_bucket = var.lambda_s3_bucket
  lambda_s3_key    = var.lambda_s3_key
  slack_s3_bucket  = var.slack_s3_bucket
  slack_s3_prefix  = var.slack_s3_prefix
  topic            = var.topic
  tags             = var.tags

  filter_policy_slack_install = {
    type = ["oauth"]
  }

  filter_policy_slack_uninstall = {
    id   = ["app_uninstalled"]
    type = ["event"]
  }
}

data aws_iam_role role {
  name = local.lambda_role
}

data aws_sns_topic topic {
  name = local.topic
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

resource aws_lambda_function slack_install {
  description   = "Install app to Slack workspace"
  function_name = "brutalismbot-slack-install"
  handler       = "lambda.slack_install"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  tags          = local.tags
  timeout       = 3

  environment {
    variables = {
      SLACK_S3_BUCKET = local.slack_s3_bucket
      SLACK_S3_PREFIX = local.slack_s3_prefix
    }
  }
}

resource aws_lambda_function slack_uninstall {
  description   = "Uninstall brutalismbot from Slack workspace"
  function_name = "brutalismbot-slack-uninstall"
  handler       = "lambda.slack_uninstall"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_s3_key
  tags          = local.tags
  timeout       = 3

  environment {
    variables = {
      SLACK_S3_BUCKET = local.slack_s3_bucket
      SLACK_S3_PREFIX = local.slack_s3_prefix
    }
  }
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

resource aws_sns_topic_subscription slack_install {
  endpoint      = aws_lambda_function.slack_install.arn
  filter_policy = jsonencode(local.filter_policy_slack_install)
  protocol      = "lambda"
  topic_arn     = data.aws_sns_topic.topic.arn
}

resource aws_sns_topic_subscription slack_uninstall {
  endpoint      = aws_lambda_function.slack_uninstall.arn
  filter_policy = jsonencode(local.filter_policy_slack_uninstall)
  protocol      = "lambda"
  topic_arn     = data.aws_sns_topic.topic.arn
}
