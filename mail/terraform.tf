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
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

data "terraform_remote_state" "functions" {
  backend = "remote"

  config = {
    organization = "beachplum"

    workspaces = { name = "brutalismbot-functions" }
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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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

  s3_bucket_name            = "brutalismbot-${local.region}-mail"
  s3_bucket_arn             = "arn:aws:s3:::${local.s3_bucket_name}"
  s3_bucket_object_arn_glob = "arn:aws:s3:::${local.s3_bucket_name}/*"

  tags = {
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = "brutalismbot-mail"
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

#######################
#   ROUTE53 :: ZONE   #
#######################

data "aws_route53_zone" "zone" {
  name = "brutalismbot.com."
}

##########################
#   ROUTE53 :: RECORDS   #
##########################

resource "aws_route53_record" "dkims" {
  count   = 3
  zone_id = data.aws_route53_zone.zone.id
  name    = "${element(aws_ses_domain_dkim.brutalismbot.dkim_tokens, count.index)}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.brutalismbot.dkim_tokens, count.index)}.dkim.amazonses.com"]
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
  ttl     = 300
  type    = "MX"
  zone_id = data.aws_route53_zone.zone.id
}

#########################
#   SES :: IDENTITIES   #
#########################

resource "aws_ses_domain_identity" "brutalismbot" {
  domain = data.aws_route53_zone.zone.name
}

resource "aws_ses_email_identity" "destination" {
  email = var.MAIL_TO
}

resource "aws_ses_email_identity" "help" {
  email = "help@brutalismbot.com"
}

resource "aws_ses_email_identity" "no_reply" {
  email = "no-reply@brutalismbot.com"
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

data "aws_iam_policy_document" "mail" {
  statement {
    sid       = "AllowSES"
    actions   = ["s3:PutObject"]
    resources = [local.s3_bucket_object_arn_glob]

    condition {
      test     = "StringEquals"
      variable = "aws:Referer"
      values   = [local.account_id]
    }

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket" "mail" {
  bucket = "brutalismbot-${data.aws_region.current.name}-mail"
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
  policy = data.aws_iam_policy_document.mail.json
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
  function_name = data.terraform_remote_state.functions.outputs.functions.mail.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.mail.arn
}

resource "aws_sns_topic" "mail" {
  name = "brutalismbot-mail"
}

resource "aws_sns_topic_subscription" "mail" {
  endpoint  = data.terraform_remote_state.functions.outputs.functions.mail.arn
  protocol  = "lambda"
  topic_arn = aws_sns_topic.mail.arn
}

###############
#   OUTPUTS   #
###############

output "s3_bucket_arn" { value = aws_s3_bucket.mail.arn }
output "sns_mail_topic_arn" { value = aws_sns_topic.mail.arn }
