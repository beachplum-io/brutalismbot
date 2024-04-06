#################
#   VARIABLES   #
#################

variable "env" { type = string }

##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name

  env   = var.env
  app   = basename(path.module)
  name  = "brutalismbot-${local.env}-${local.app}"
  param = "/brutalismbot/${local.env}/${local.app}/MAIL_TO"
  tags  = { "brutalismbot:app" = local.app }
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##############
#   LAMBDA   #
##############

data "archive_file" "lambda" {
  excludes    = ["package.zip"]
  source_dir  = "${path.module}/lib"
  output_path = "${path.module}/lib/package.zip"
  type        = "zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
}

resource "aws_iam_role" "lambda" {
  name = "${local.region}-${local.name}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeEvents"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }
  })

  inline_policy {
    name = "access"
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
          Sid      = "GetParameter"
          Effect   = "Allow"
          Action   = "ssm:GetParameter"
          Resource = "arn:aws:ssm:${local.region}:${local.account}:parameter${local.param}"
        },
        {
          Sid      = "S3"
          Effect   = "Allow"
          Action   = "s3:GetObject"
          Resource = "${aws_s3_bucket.mail.arn}/*"
        },
        {
          Sid      = "StepFunctions"
          Effect   = "Allow"
          Action   = "states:StartExecution"
          Resource = aws_sfn_state_machine.states.arn
        }
      ]
    })
  }
}

resource "aws_lambda_function" "lambda" {
  architectures    = ["arm64"]
  description      = "Forward incoming messages to @brutalismbot.com"
  filename         = data.archive_file.lambda.output_path
  function_name    = local.name
  handler          = "index.mail"
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby3.3"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      MAIL_TO_PARAM     = local.param
      STATE_MACHINE_ARN = aws_sfn_state_machine.states.arn
    }
  }
}

resource "aws_lambda_permission" "mail" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.mail.arn
}

##########
#   S3   #
##########

resource "aws_s3_bucket" "mail" {
  bucket        = "${local.region}-${local.name}"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "mail" {
  bucket = aws_s3_bucket.mail.id

  rule {
    id     = "expire"
    status = "Enabled"

    expiration { days = 90 }

    filter {}
  }
}

resource "aws_s3_bucket_policy" "mail" {
  bucket = aws_s3_bucket.mail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSES"
      Effect    = "Allow"
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.mail.arn}/*"
      Principal = { Service = "ses.amazonaws.com" }
      Condition = { StringEquals = { "aws:Referer" = local.account } }
    }]
  })
}

resource "aws_s3_bucket_public_access_block" "mail" {
  bucket                  = aws_s3_bucket.mail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###########
#   SES   #
###########

resource "aws_ses_receipt_rule" "mail" {
  depends_on    = [aws_lambda_permission.mail]
  enabled       = true
  name          = local.name
  recipients    = ["brutalismbot.com"]
  rule_set_name = aws_ses_receipt_rule_set.mail.rule_set_name
  scan_enabled  = true

  s3_action {
    bucket_name = aws_s3_bucket.mail.bucket
    position    = 1
    topic_arn   = aws_sns_topic.mail.arn
  }
}

resource "aws_ses_receipt_rule_set" "mail" {
  rule_set_name = local.name
}

###########
#   SNS   #
###########

resource "aws_sns_topic" "mail" {
  name = local.name
}

resource "aws_sns_topic_subscription" "mail" {
  endpoint  = aws_lambda_function.lambda.arn
  protocol  = "lambda"
  topic_arn = aws_sns_topic.mail.arn
}

#####################
#   STATE MACHINE   #
#####################

resource "aws_iam_role" "states" {
  name = "${local.region}-${local.name}-states"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeStates"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "states.amazonaws.com" }
    }
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = {
        Sid      = "SendEmail"
        Effect   = "Allow"
        Action   = "ses:SendEmail"
        Resource = "*"
      }
    })
  }
}

resource "aws_sfn_state_machine" "states" {
  definition = jsonencode(yamldecode(file("${path.module}/states.yml")))
  name       = local.name
  role_arn   = aws_iam_role.states.arn
}
