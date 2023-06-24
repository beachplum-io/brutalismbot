#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "beachplum"

    workspaces { name = "brutalismbot-dns" }
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
  region = "us-west-2"
  assume_role { role_arn = var.AWS_ROLE_ARN }
  default_tags { tags = local.tags }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
  assume_role { role_arn = var.AWS_ROLE_ARN }
  default_tags { tags = local.tags }
}

#################
#   VARIABLES   #
#################

variable "AWS_ROLE_ARN" {}

##############
#   LOCALS   #
##############

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  env = "blue"

  website_bucket = "${local.region}-brutalismbot-${local.env}-website"

  domain_validation_options = {
    for x in aws_acm_certificate.us-east-1.domain_validation_options :
    x.domain_name => x
  }

  tags = {
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = "brutalismbot-dns"
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_s3_bucket" "website" {
  bucket = local.website_bucket
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

resource "aws_route53_record" "bluesky" {
  name    = "_atproto.brutalismbot.com"
  records = ["did=did:plc:ss234xtabshxpidtaa5kbnt2"]
  ttl     = 300
  type    = "TXT"
  zone_id = aws_route53_zone.zone.id
}
