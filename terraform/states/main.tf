locals {
  is_enabled              = var.is_enabled
  lambda_arns             = var.lambda_arns
  lambda_filename         = var.lambda_filename
  lambda_layers           = var.lambda_layers
  lambda_role_arn         = var.lambda_role_arn
  lambda_runtime          = var.lambda_runtime
  lambda_source_code_hash = var.lambda_source_code_hash
  tags                    = var.tags
}

# EVENTS

resource aws_cloudwatch_event_rule pull {
  description         = "Start Brutalismbot state machine"
  is_enabled          = local.is_enabled
  name                = aws_sfn_state_machine.main.name
  schedule_expression = "rate(1 hour)"
  tags                = local.tags
}

data aws_iam_role events {
  name = "brutalismbot-events"
}

resource aws_cloudwatch_event_target pull {
  arn      = aws_sfn_state_machine.main.id
  input    = jsonencode({})
  role_arn = data.aws_iam_role.events.arn
  rule     = aws_cloudwatch_event_rule.pull.name
}

# LOGS

resource aws_cloudwatch_log_group fetch {
  name              = "/aws/lambda/${aws_lambda_function.fetch.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

# LAMBDAS

resource aws_lambda_function fetch {
  description      = "Fetch S3 object"
  filename         = local.lambda_filename
  function_name    = "brutalismbot-fetch"
  handler          = "lambda.fetch"
  layers           = local.lambda_layers
  role             = local.lambda_role_arn
  runtime          = local.lambda_runtime
  source_code_hash = local.lambda_source_code_hash
  tags             = local.tags
}

# STATE MACHINES

data aws_iam_role states {
  name = "brutalismbot-states"
}

resource aws_sfn_state_machine main {
  name     = "brutalismbot"
  role_arn = data.aws_iam_role.states.arn
  tags     = local.tags

  definition = templatefile(
    "${path.module}/brutalismbot.json", {
      fetch_lambda_arn          = aws_lambda_function.fetch.arn
      reddit_pull_lambda_arn    = local.lambda_arns.reddit_pull
      slack_list_lambda_arn     = local.lambda_arns.slack_list
      slack_state_machine_arn   = aws_sfn_state_machine.slack.id
      twitter_state_machine_arn = aws_sfn_state_machine.twitter.id
    }
  )
}

resource aws_sfn_state_machine slack {
  name     = "brutalismbot-slack"
  role_arn = data.aws_iam_role.states.arn
  tags     = local.tags

  definition = templatefile(
    "${path.module}/brutalismbot-slack.json", {
      dead_letter_queue_url = aws_sqs_queue.slack_dlq.id
      slack_push_lambda_arn = local.lambda_arns.slack_push
    }
  )
}

resource aws_sfn_state_machine twitter {
  name     = "brutalismbot-twitter"
  role_arn = data.aws_iam_role.states.arn
  tags     = local.tags

  definition = templatefile(
    "${path.module}/brutalismbot-twitter.json", {
      dead_letter_queue_url   = aws_sqs_queue.twitter_dlq.id
      twitter_push_lambda_arn = local.lambda_arns.twitter_push
    }
  )
}

# SQS DLQs

resource aws_sqs_queue slack_dlq {
  name = "brutaliambot-slack-failures"
}

resource aws_sqs_queue twitter_dlq {
  name = "brutaliambot-twitter-failures"
}
