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
    sid       = "Logs"
    actions   = ["logs:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "role" {
  assume_role_policy = data.aws_iam_policy_document.trust.json
  name               = "brutalismbot-${data.aws_region.current.name}-lambda-array"

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
  description      = "Array pop/push operations"
  filename         = data.archive_file.package.output_path
  function_name    = "brutalismbot-array"
  handler          = "index.array"
  role             = aws_iam_role.role.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.package.output_base64sha256
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
