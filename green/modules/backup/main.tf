##############
#   LOCALS   #
##############

locals {
  region = data.aws_region.current.region

  app  = basename(path.module)
  name = "${terraform.workspace}-${local.app}"
  tags = { "brutalismbot:app" = local.app }
}

############
#   DATA   #
############

data "aws_region" "current" {}

data "aws_dynamodb_table" "table" {
  name = "brutalismbot-blue"
}

data "aws_s3_bucket" "bucket" {
  bucket = "brutalismbot"
}

##############
#   LAMBDA   #
##############

data "archive_file" "lambda" {
  source_file = "${path.module}/index.rb"
  output_path = "${path.module}/package.zip"
  type        = "zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_iam_role" "lambda" {
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

resource "aws_iam_role_policy" "lambda" {
  name = "access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "*"
      },
      {
        Sid      = "S3"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${data.aws_s3_bucket.bucket.arn}/r/brutalism/*"
      }
    ]
  })
}

resource "aws_lambda_function" "lambda" {
  architectures    = ["arm64"]
  description      = "Download and backup to S3"
  filename         = data.archive_file.lambda.output_path
  function_name    = local.name
  handler          = "index.backup"
  memory_size      = 1024
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby3.4"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags             = local.tags
  timeout          = 60
}

#####################
#   STATE MACHINE   #
#####################

resource "aws_iam_role" "states" {
  name = "${local.region}-${local.name}-states"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeStates"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "states.amazonaws.com" }
    }
  })
}

resource "aws_iam_role_policy" "states" {
  name = "access"
  role = aws_iam_role.states.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDB"
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:UpdateItem",
        ]
        Resource = [
          data.aws_dynamodb_table.table.arn,
          "${data.aws_dynamodb_table.table.arn}/index/Kind",
        ]
      },
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.lambda.arn
      },
      {
        Sid      = "States"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.states.arn
      }
    ]
  })
}

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn
  tags     = local.tags

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yml", {
    s3_bucket    = data.aws_s3_bucket.bucket.bucket
    table_name   = data.aws_dynamodb_table.table.name
    function_arn = aws_lambda_function.lambda.arn
  })))
}
