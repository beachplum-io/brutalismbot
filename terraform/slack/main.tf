locals {
  lambda_environment      = var.lambda_environment
  lambda_filename         = var.lambda_filename
  lambda_layers           = var.lambda_layers
  lambda_role_arn         = var.lambda_role_arn
  lambda_runtime          = var.lambda_runtime
  lambda_source_code_hash = var.lambda_source_code_hash
  slack_sns_topic_arn     = var.slack_sns_topic_arn
  tags                    = var.tags
}

# LOGS

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
  description      = "Install app to Slack workspace"
  filename         = local.lambda_filename
  function_name    = "brutalismbot-slack-install"
  handler          = "lambda.slack_install"
  layers           = local.lambda_layers
  role             = local.lambda_role_arn
  runtime          = local.lambda_runtime
  source_code_hash = local.lambda_source_code_hash
  tags             = local.tags

  environment {
    variables = local.lambda_environment
  }
}

resource aws_lambda_function list {
  description      = "Get slack authorizations"
  function_name    = "brutalismbot-slack-list"
  handler          = "lambda.slack_list"
  filename         = local.lambda_filename
  source_code_hash = local.lambda_source_code_hash
  layers           = local.lambda_layers
  role             = local.lambda_role_arn
  runtime          = local.lambda_runtime
  tags             = local.tags
}

resource aws_lambda_function push {
  description      = "Push posts from /r/brutalism to Slack"
  function_name    = "brutalismbot-slack-push"
  handler          = "lambda.slack_push"
  filename         = local.lambda_filename
  source_code_hash = local.lambda_source_code_hash
  layers           = local.lambda_layers
  role             = local.lambda_role_arn
  runtime          = local.lambda_runtime
  tags             = local.tags
}

resource aws_lambda_function uninstall {
  description      = "Uninstall brutalismbot from Slack workspace"
  function_name    = "brutalismbot-slack-uninstall"
  handler          = "lambda.slack_uninstall"
  filename         = local.lambda_filename
  source_code_hash = local.lambda_source_code_hash
  layers           = local.lambda_layers
  role             = local.lambda_role_arn
  runtime          = local.lambda_runtime
  tags             = local.tags

  environment {
    variables = local.lambda_environment
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
  filter_policy = jsonencode({ type = ["oauth"] })
  protocol      = "lambda"
  topic_arn     = local.slack_sns_topic_arn
}

resource aws_sns_topic_subscription uninstall {
  endpoint      = aws_lambda_function.uninstall.arn
  filter_policy = jsonencode({ type = ["event"], id = ["app_uninstalled"] })
  protocol      = "lambda"
  topic_arn     = local.slack_sns_topic_arn
}
