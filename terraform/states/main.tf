locals {
  lambda_layers    = var.lambda_layers
  lambda_role_arn  = var.lambda_role_arn
  lambda_s3_bucket = var.lambda_s3_bucket
  lambda_s3_key    = var.lambda_s3_key
  tags             = var.tags

  reddit_pull_lambda_arn  = var.reddit_pull_lambda_arn
  slack_list_lambda_arn   = var.slack_list_lambda_arn
  slack_push_lambda_arn   = var.slack_push_lambda_arn
  twitter_push_lambda_arn = var.twitter_push_lambda_arn
}

data aws_iam_policy_document assume_role {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

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

data template_file main {
  template = file("${path.module}/brutalismbot.json")

  vars = {
    slack_list_lambda_arn     = local.slack_list_lambda_arn
    reddit_pull_lambda_arn    = local.reddit_pull_lambda_arn
    twitter_state_machine_arn = aws_sfn_state_machine.twitter.id
    slack_state_machine_arn   = aws_sfn_state_machine.slack.id
  }
}

data template_file slack {
  template = file("${path.module}/brutalismbot-slack.json")

  vars = {
    fetch_lambda_arn      = module.fetch.lambda.arn
    slack_push_lambda_arn = local.slack_push_lambda_arn
  }
}

data template_file twitter {
  template = file("${path.module}/brutalismbot-twitter.json")

  vars = {
    fetch_lambda_arn        = module.fetch.lambda.arn
    twitter_push_lambda_arn = local.twitter_push_lambda_arn
  }
}

module fetch {
  source = "../lambda"

  description   = "Fetch S3 object"
  function_name = "brutalismbot-fetch"
  handler       = "lambda.s3_fetch"

  layers    = local.lambda_layers
  role      = local.lambda_role_arn
  s3_bucket = local.lambda_s3_bucket
  s3_key    = local.lambda_s3_key
  tags      = local.tags
}

resource aws_cloudwatch_event_rule pull {
  description         = "Start Brutalismbot state machine"
  is_enabled          = false
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

resource aws_sfn_state_machine main {
  definition = data.template_file.main.rendered
  name       = "brutalismbot"
  role_arn   = aws_iam_role.role.arn
  tags       = local.tags
}

resource aws_sfn_state_machine slack {
  definition = data.template_file.slack.rendered
  name       = "brutalismbot-slack"
  role_arn   = aws_iam_role.role.arn
  tags       = local.tags
}

resource aws_sfn_state_machine twitter {
  definition = data.template_file.twitter.rendered
  name       = "brutalismbot-twitter"
  role_arn   = aws_iam_role.role.arn
  tags       = local.tags
}
