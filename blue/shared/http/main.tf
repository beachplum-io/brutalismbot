##############
#   LOCALS   #
##############

locals {
  name   = "brutalismbot-${var.env}-${var.app}-http"
  region = data.aws_region.current.name
}

############
#   DATA   #
############

data "aws_region" "current" {}

########################
#   LAMBDA FUNCTIONS   #
########################

data "archive_file" "package" {
  excludes    = ["package.zip"]
  source_dir  = "${path.module}/lib"
  output_path = "${path.module}/lib/package.zip"
  type        = "zip"
}

resource "aws_cloudwatch_log_group" "logs" {
  name              = "/aws/lambda/${aws_lambda_function.function.function_name}"
  retention_in_days = 14
}

resource "aws_iam_role" "role" {
  name = "${local.region}-${local.name}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeLambda"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "*"
      }
    })
  }
}

resource "aws_lambda_function" "function" {
  architectures    = ["arm64"]
  description      = "Make generic HTTP request"
  filename         = data.archive_file.package.output_path
  function_name    = local.name
  handler          = "index.http"
  memory_size      = 512
  role             = aws_iam_role.role.arn
  runtime          = "ruby3.2"
  source_code_hash = data.archive_file.package.output_base64sha256
  timeout          = 30
}
