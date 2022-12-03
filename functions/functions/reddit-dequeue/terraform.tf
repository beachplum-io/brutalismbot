############
#   DATA   #
############

data "aws_dynamodb_table" "table" {
  name = "Brutalismbot"
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

data "aws_region" "current" {}

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
    sid       = "DynamoDB"
    actions   = ["dynamodb:GetItem"]
    resources = [data.aws_dynamodb_table.table.arn]
  }

  statement {
    sid       = "Logs"
    actions   = ["logs:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "role" {
  assume_role_policy = data.aws_iam_policy_document.trust.json
  name               = "brutalismbot-${data.aws_region.current.name}-lambda-reddit-dequeue"

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
  description      = "Dequeue next post from /r/brutalism"
  filename         = data.archive_file.package.output_path
  function_name    = "brutalismbot-reddit-dequeue"
  handler          = "index.reddit_dequeue"
  memory_size      = 512
  role             = aws_iam_role.role.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.package.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      AGE_HOURS         = "4"
      REDDIT_USER_AGENT = "Brutalismbot"
      TABLE_NAME        = data.aws_dynamodb_table.table.name
      TTL_DAYS          = "14"
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
