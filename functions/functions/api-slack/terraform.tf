############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_secretsmanager_secret" "secret" {
  name = "brutalismbot"
}

###############
#   PACKAGE   #
###############

data "archive_file" "package" {
  source_dir  = "${path.module}/lib"
  output_path = "${path.module}/package.zip"
  type        = "zip"
}

###########
#   IAM   #
###########

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AssumeEvents"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "access" {
  statement {
    sid       = "Events"
    actions   = ["events:PutEvents"]
    resources = ["arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/brutalismbot"]
  }

  statement {
    sid       = "Logs"
    actions   = ["logs:*"]
    resources = ["*"]
  }

  statement {
    sid       = "Secrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [data.aws_secretsmanager_secret.secret.arn]
  }
}

resource "aws_iam_role" "role" {
  assume_role_policy = data.aws_iam_policy_document.trust.json
  name               = "brutalismbot-${data.aws_region.current.name}-lambda-api-slack"

  inline_policy {
    name   = "access"
    policy = data.aws_iam_policy_document.access.json
  }
}

################
#   FUNCTION   #
################

resource "aws_lambda_function" "function" {
  architectures    = ["arm64"]
  description      = "Handle Slack events"
  filename         = data.archive_file.package.output_path
  function_name    = "brutalismbot-api-slack"
  handler          = "index.proxy"
  memory_size      = 3072
  role             = aws_iam_role.role.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.package.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      EVENT_BUS    = "brutalismbot"
      EVENT_SOURCE = "slack"
      SECRET_ID    = data.aws_secretsmanager_secret.secret.name
    }
  }
}

############
#   LOGS   #
############

resource "aws_cloudwatch_log_group" "logs" {
  name              = "/aws/lambda/${aws_lambda_function.function.function_name}"
  retention_in_days = 14
}

###############
#   OUTPUTS   #
###############

output "iam_role" { value = aws_iam_role.role }
output "lambda_function" { value = aws_lambda_function.function }
output "log_group" { value = aws_cloudwatch_log_group.logs }
