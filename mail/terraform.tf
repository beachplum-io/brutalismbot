#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "beachplum"

    workspaces { name = "brutalismbot-mail" }
  }

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.2"
    }
  }
}

###########
#   AWS   #
###########

provider "aws" {
  region = "us-west-2"
  assume_role { role_arn = var.AWS_ROLE_ARN }
  default_tags { tags = local.tags }
}

#################
#   VARIABLES   #
#################

variable "AWS_ROLE_ARN" {}
variable "MAIL_TO" {}

##############
#   LOCALS   #
##############

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  env  = "global"
  app  = "mail"
  name = "brutalismbot-${local.app}"

  tags = {
    "brutalismbot:env"       = local.env
    "brutalismbot:app"       = local.app
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = local.name
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_route53_zone" "zone" {
  name = "brutalismbot.com."
}

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
  runtime          = "ruby3.2"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      MAIL_TO           = var.MAIL_TO
      STATE_MACHINE_ARN = aws_sfn_state_machine.states.arn
    }
  }
}

##########################
#   ROUTE53 :: RECORDS   #
##########################

resource "aws_route53_record" "dkims" {
  for_each = toset(aws_ses_domain_dkim.brutalismbot.dkim_tokens)
  zone_id  = data.aws_route53_zone.zone.id
  name     = "${each.value}._domainkey"
  type     = "CNAME"
  ttl      = "600"
  records  = ["${each.value}.dkim.amazonses.com"]
}

resource "aws_route53_record" "mail_from_mx" {
  name    = aws_ses_domain_mail_from.brutalismbot.mail_from_domain
  records = ["10 feedback-smtp.${data.aws_region.current.name}.amazonses.com"]
  ttl     = "600"
  type    = "MX"
  zone_id = data.aws_route53_zone.zone.id
}

resource "aws_route53_record" "mail_to_mx" {
  name    = data.aws_route53_zone.zone.name
  records = ["10 inbound-smtp.${data.aws_region.current.name}.amazonaws.com"]
  ttl     = "300"
  type    = "MX"
  zone_id = data.aws_route53_zone.zone.id
}

#########################
#   SES :: IDENTITIES   #
#########################

resource "aws_ses_domain_identity" "brutalismbot" {
  domain = data.aws_route53_zone.zone.name
}

resource "aws_ses_email_identity" "identities" {
  for_each = {
    bluesky     = "bluesky@brutalismbot.com"
    destination = var.MAIL_TO
    help        = "help@brutalismbot.com"
    no-reply    = "no-reply@brutalismbot.com"
    slack       = "slack@brutalismbot.com"
    twitter     = "twitter@brutalismbot.com"
  }
  email = each.value
}

#####################
#    SES :: DKIM    #
#####################

resource "aws_ses_domain_dkim" "brutalismbot" {
  domain = aws_ses_domain_identity.brutalismbot.domain
}

#######################
#   SES :: OUTBOUND   #
#######################

resource "aws_ses_domain_mail_from" "brutalismbot" {
  domain           = aws_ses_domain_identity.brutalismbot.domain
  mail_from_domain = "bounce.${aws_ses_domain_identity.brutalismbot.domain}"
}

######################
#   SES :: INBOUND   #
######################

resource "aws_ses_receipt_rule" "default" {
  enabled       = true
  name          = "default"
  recipients    = [data.aws_route53_zone.zone.name]
  rule_set_name = aws_ses_receipt_rule_set.default.rule_set_name
  scan_enabled  = true

  s3_action {
    bucket_name = aws_s3_bucket.mail.bucket
    position    = 1
    topic_arn   = aws_sns_topic.mail.arn
  }
}

resource "aws_ses_receipt_rule_set" "default" {
  rule_set_name = "default-rule-set"
}

resource "aws_ses_active_receipt_rule_set" "default" {
  rule_set_name = aws_ses_receipt_rule_set.default.rule_set_name
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
      Condition = { StringEquals = { "aws:Referer" = local.account_id } }
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
#   SNS   #
###########

resource "aws_lambda_permission" "mail" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.mail.arn
}

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
  definition = jsonencode(yamldecode(file("${path.module}/states.yaml")))
  name       = local.name
  role_arn   = aws_iam_role.states.arn
}
