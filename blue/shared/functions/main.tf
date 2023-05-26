##############
#   LOCALS   #
##############

locals {
  name   = "brutalismbot-${var.env}-${var.app}-${var.name}"
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
  source_dir  = "${path.module}/${var.name}"
  output_path = "${path.module}/${var.name}/package.zip"
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
  description      = var.data.description
  filename         = data.archive_file.package.output_path
  function_name    = local.name
  handler          = var.data.handler
  memory_size      = var.data.memory_size
  role             = aws_iam_role.role.arn
  runtime          = var.data.runtime
  source_code_hash = data.archive_file.package.output_base64sha256
  timeout          = var.data.timeout
}
