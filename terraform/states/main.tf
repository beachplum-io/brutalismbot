locals {
  enabled = true

  lambda_filename         = var.lambda_filename
  lambda_layers           = var.lambda_layers
  lambda_role_arn         = var.lambda_role_arn
  lambda_runtime          = var.lambda_runtime
  lambda_source_code_hash = var.lambda_source_code_hash
  tags                    = var.tags

  reddit_pull_lambda_arn  = var.reddit_pull_lambda_arn
  slack_list_lambda_arn   = var.slack_list_lambda_arn
  slack_push_lambda_arn   = var.slack_push_lambda_arn
  twitter_push_lambda_arn = var.twitter_push_lambda_arn

  main_definition = templatefile(
    "${path.module}/brutalismbot.json",
    {
      fetch_lambda_arn          = aws_lambda_function.fetch.arn
      reddit_pull_lambda_arn    = local.reddit_pull_lambda_arn
      slack_list_lambda_arn     = local.slack_list_lambda_arn
      slack_state_machine_arn   = aws_sfn_state_machine.slack.id
      twitter_state_machine_arn = aws_sfn_state_machine.twitter.id
    }
  )

  slack_definition = templatefile(
    "${path.module}/brutalismbot-slack.json",
    {
      dead_letter_queue_url = aws_sqs_queue.slack_dlq.id
      slack_push_lambda_arn = local.slack_push_lambda_arn
    }
  )

  twitter_definition = templatefile(
    "${path.module}/brutalismbot-twitter.json",
    {
      dead_letter_queue_url   = aws_sqs_queue.twitter_dlq.id
      twitter_push_lambda_arn = local.twitter_push_lambda_arn
    }
  )
}

data aws_iam_policy_document assume_role {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"

      identifiers = [
        "events.amazonaws.com",
        "states.amazonaws.com",
      ]
    }
  }
}

data aws_iam_policy_document states {
  statement {
    sid       = "InvokeFunction"
    actions   = ["lambda:InvokeFunction"]
    resources = ["*"]
  }

  statement {
    sid     = "QueueMessage"
    actions = ["sqs:SendMessage"]

    resources = [
      aws_sqs_queue.slack_dlq.arn,
      aws_sqs_queue.twitter_dlq.arn,
    ]
  }

  statement {
    sid     = "StartStateMachine"
    actions = ["states:StartExecution"]

    resources = [
      aws_sfn_state_machine.main.id,
      aws_sfn_state_machine.slack.id,
      aws_sfn_state_machine.twitter.id,
    ]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:*"]
    resources = ["*"]
  }
}

resource aws_cloudwatch_event_rule pull {
  description         = "Start Brutalismbot state machine"
  is_enabled          = local.enabled
  name                = aws_sfn_state_machine.main.name
  schedule_expression = "rate(1 hour)"
  tags                = local.tags
}

resource aws_cloudwatch_event_target pull {
  arn      = aws_sfn_state_machine.main.id
  input    = jsonencode({})
  role_arn = aws_iam_role.role.arn
  rule     = aws_cloudwatch_event_rule.pull.name
}

resource aws_cloudwatch_log_group fetch {
  name              = "/aws/lambda/${aws_lambda_function.fetch.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_iam_role role {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  name               = "brutalismbot-states"
  tags               = local.tags
}

resource aws_iam_role_policy states {
  name   = "brutalismbot-states"
  policy = data.aws_iam_policy_document.states.json
  role   = aws_iam_role.role.name
}

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

resource aws_sfn_state_machine main {
  definition = local.main_definition
  name       = "brutalismbot"
  role_arn   = aws_iam_role.role.arn
  tags       = local.tags
}

resource aws_sfn_state_machine slack {
  definition = local.slack_definition
  name       = "brutalismbot-slack"
  role_arn   = aws_iam_role.role.arn
  tags       = local.tags
}

resource aws_sfn_state_machine twitter {
  definition = local.twitter_definition
  name       = "brutalismbot-twitter"
  role_arn   = aws_iam_role.role.arn
  tags       = local.tags
}

resource aws_sqs_queue slack_dlq {
  name = "brutaliambot-slack-failures"
}

resource aws_sqs_queue twitter_dlq {
  name = "brutaliambot-twitter-failures"
}
