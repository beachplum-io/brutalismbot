#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "beachplum"

    workspaces { name = "brutalismbot-global" }
  }

  required_providers {
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
  region = local.region
  default_tags { tags = local.tags }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
  default_tags { tags = local.tags }
}

#################
#   VARIABLES   #
#################

variable "MAIL_TO" { type = string }

##############
#   LOCALS   #
##############

locals {
  region = "us-west-2"
  env    = "blue"

  domain_validation_options = {
    for x in aws_acm_certificate.us-east-1.domain_validation_options :
    x.domain_name => x
  }

  tags = {
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = "brutalismbot-global"
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

############
#   DATA   #
############

data "aws_s3_bucket" "website" {
  bucket = "${local.region}-brutalismbot-${local.env}-website"
}

########################
#   ACM :: US-EAST-1   #
########################

resource "aws_acm_certificate" "us-east-1" {
  provider                  = aws.us-east-1
  domain_name               = aws_route53_zone.zone.name
  subject_alternative_names = ["*.${aws_route53_zone.zone.name}"]
  validation_method         = "DNS"

  lifecycle { create_before_destroy = true }
}

resource "aws_acm_certificate_validation" "us-east-1" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.us-east-1.arn
  validation_record_fqdns = [aws_route53_record.acm.fqdn]
}

########################
#   ACM :: US-WEST-2   #
########################

resource "aws_acm_certificate" "us-west-2" {
  domain_name               = aws_route53_zone.zone.name
  subject_alternative_names = ["*.${aws_route53_zone.zone.name}"]
  validation_method         = "DNS"

  lifecycle { create_before_destroy = true }
}

resource "aws_acm_certificate_validation" "us-west-2" {
  certificate_arn         = aws_acm_certificate.us-west-2.arn
  validation_record_fqdns = [aws_route53_record.acm.fqdn]
}

############
#   APIS   #
############

module "api-us-west-2" {
  source              = "./api"
  acm_certificate_arn = aws_acm_certificate.us-west-2.arn
  zone_id             = aws_route53_zone.zone.id

  mappings = {
    "slack"      = "brutalismbot-${local.env}-slack-api"
    "slack/beta" = "brutalismbot-${local.env}-slack-beta-api"
  }
}

##################
#   CLOUDFRONT   #
##################

resource "aws_cloudfront_distribution" "website" {
  aliases             = ["brutalismbot.com", "www.brutalismbot.com"]
  comment             = "www.brutalismbot.com"
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"

  tags = {
    "beachplum:env" = "global"
    "beachplum:app" = "website"
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 403
    response_code         = 404
    response_page_path    = "/error.html"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    default_ttl            = 86400
    max_ttl                = 31536000
    min_ttl                = 0
    target_origin_id       = data.aws_s3_bucket.website.bucket
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies { forward = "none" }
    }
  }

  origin {
    domain_name = data.aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = data.aws_s3_bucket.website.bucket

    s3_origin_config { origin_access_identity = aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.us-east-1.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "access-identity-${data.aws_s3_bucket.website.bucket}.s3.amazonaws.com"
}

#######################
#   ROUTE53 :: ZONE   #
#######################

resource "aws_route53_zone" "zone" {
  comment = "HostedZone created by Route53 Registrar"
  name    = "brutalismbot.com"
}

##########################
#   ROUTE53 :: RECORDS   #
##########################

resource "aws_route53_record" "acm" {
  name    = local.domain_validation_options["brutalismbot.com"].resource_record_name
  records = [local.domain_validation_options["brutalismbot.com"].resource_record_value]
  ttl     = 300
  type    = local.domain_validation_options["brutalismbot.com"].resource_record_type
  zone_id = aws_route53_zone.zone.id
}

resource "aws_route53_record" "bluesky" {
  name    = "_atproto.brutalismbot.com"
  records = ["did=did:plc:ss234xtabshxpidtaa5kbnt2"]
  ttl     = 300
  type    = "TXT"
  zone_id = aws_route53_zone.zone.id
}

resource "aws_route53_record" "dkims" {
  for_each = toset(aws_ses_domain_dkim.domain.dkim_tokens)
  zone_id  = aws_route53_zone.zone.id
  name     = "${each.value}._domainkey"
  type     = "CNAME"
  ttl      = "600"
  records  = ["${each.value}.dkim.amazonses.com"]
}

# resource "aws_route53_record" "mx" {
#   for_each = {
#     aws_ses_domain_mail_from.domain.mail_from_domain = ["10 feedback-smtp.${local.region}.amazonses.com"]
#     aws_route53_zone.zone.name                       = ["10 inbound-smtp.${local.region}.amazonaws.com"]
#   }
#   name    = each.key
#   records = each.value
#   ttl     = "600"
#   type    = "MX"
#   zone_id = aws_route53_zone.zone.id
# }

resource "aws_route53_record" "mail_from_mx" {
  name    = aws_ses_domain_mail_from.domain.mail_from_domain
  records = ["10 feedback-smtp.${local.region}.amazonses.com"]
  ttl     = "600"
  type    = "MX"
  zone_id = aws_route53_zone.zone.id
}

resource "aws_route53_record" "mail_to_mx" {
  name    = aws_route53_zone.zone.name
  records = ["10 inbound-smtp.${local.region}.amazonaws.com"]
  ttl     = "300"
  type    = "MX"
  zone_id = aws_route53_zone.zone.id
}

resource "aws_route53_record" "website" {
  for_each = {
    A        = { name : "brutalismbot.com", type = "A" }
    AAAA     = { name : "brutalismbot.com", type = "AAAA" }
    www_A    = { name : "www.brutalismbot.com", type = "A" }
    www_AAAA = { name : "www.brutalismbot.com", type = "AAAA" }
  }
  name    = each.value.name
  type    = each.value.type
  zone_id = aws_route53_zone.zone.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

###########
#   SES   #
###########

resource "aws_ses_active_receipt_rule_set" "mail" {
  rule_set_name = "brutalismbot-${local.env}-mail"
}

resource "aws_ses_domain_identity" "domain" {
  domain = aws_route53_zone.zone.name
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

resource "aws_ses_domain_dkim" "domain" {
  domain = aws_ses_domain_identity.domain.domain
}

resource "aws_ses_domain_mail_from" "domain" {
  domain           = aws_ses_domain_identity.domain.domain
  mail_from_domain = "bounce.${aws_ses_domain_identity.domain.domain}"
}
