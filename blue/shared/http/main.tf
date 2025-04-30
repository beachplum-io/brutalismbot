##############
#   LOCALS   #
##############

locals {
  app    = dirname(path.module)
  name   = "${terraform.workspace}-${local.app}-${basename(path.module)}"
  region = data.aws_region.current.name
  tags   = { "brutalismbot:app" = local.app }
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
  tags              = local.tags
}

resource "aws_iam_role" "role" {
  name = "${local.region}-${local.name}-lambda"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeLambda"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }
  })
}

resource "aws_iam_role_policy" "policy" {
  name = "access"
  role = aws_iam_role.role.id

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

resource "aws_lambda_function" "function" {
  architectures    = ["arm64"]
  description      = "Make generic HTTP request"
  filename         = data.archive_file.package.output_path
  function_name    = local.name
  handler          = "index.http"
  memory_size      = 512
  role             = aws_iam_role.role.arn
  runtime          = "ruby3.4"
  source_code_hash = data.archive_file.package.output_base64sha256
  tags             = local.tags
  timeout          = 30
}
