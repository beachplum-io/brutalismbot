#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "beachplum"

    workspaces { name = "brutalismbot-website" }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
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
  alias  = "us_east_1"
  region = "us-east-1"
  assume_role { role_arn = var.AWS_ROLE_ARN }
  default_tags { tags = local.tags }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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

  s3_bucket_name            = "brutalismbot-${local.region}-website"
  s3_bucket_object_arn_glob = "arn:aws:s3:::${local.s3_bucket_name}/*"

  acm = {
    us_east_1 = element(tolist(aws_acm_certificate.us_east_1.domain_validation_options), 0)
    us_west_2 = element(tolist(aws_acm_certificate.us_west_2.domain_validation_options), 0)
  }

  mime_map = {
    css         = "text/css"
    html        = "text/html"
    ico         = "image/x-icon"
    png         = "image/png"
    svg         = "image/svg+xml"
    webmanifest = "application/manifest+json"
    xml         = "application/xml"
  }

  tags = {
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = "brutalismbot-website"
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

###########
#   ACM   #
###########

data "aws_acm_certificate" "ssl" {
  provider = aws.us_east_1
  domain   = "brutalismbot.com"
  statuses = ["ISSUED"]
}

##########################
#    ACM :: US-EAST-1    #
##########################

resource "aws_acm_certificate" "us_east_1" {
  provider                  = aws.us_east_1
  domain_name               = aws_route53_zone.zone.name
  subject_alternative_names = ["*.${aws_route53_zone.zone.name}"]
  validation_method         = "DNS"

  lifecycle { create_before_destroy = true }
}

resource "aws_acm_certificate_validation" "us_east_1" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.us_east_1.arn
  validation_record_fqdns = [aws_route53_record.acm_us_east_1.fqdn]
}

##########################
#    ACM :: US-WEST-2    #
##########################

resource "aws_acm_certificate" "us_west_2" {
  domain_name               = aws_route53_zone.zone.name
  subject_alternative_names = ["*.${aws_route53_zone.zone.name}"]
  validation_method         = "DNS"

  lifecycle { create_before_destroy = true }
}

resource "aws_acm_certificate_validation" "us_west_2" {
  certificate_arn         = aws_acm_certificate.us_west_2.arn
  validation_record_fqdns = [aws_route53_record.acm_us_east_1.fqdn]
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
    target_origin_id       = aws_s3_bucket.website.bucket
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies { forward = "none" }
    }
  }

  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.website.bucket

    s3_origin_config { origin_access_identity = aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.ssl.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "access-identity-${local.s3_bucket_name}.s3.amazonaws.com"
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

resource "aws_route53_record" "acm_us_east_1" {
  name    = local.acm.us_east_1.resource_record_name
  records = [local.acm.us_east_1.resource_record_value]
  ttl     = 300
  type    = local.acm.us_east_1.resource_record_type
  zone_id = aws_route53_zone.zone.id
}

resource "aws_route53_record" "a" {
  name    = "brutalismbot.com"
  type    = "A"
  zone_id = aws_route53_zone.zone.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource "aws_route53_record" "aaaa" {
  name    = "brutalismbot.com"
  type    = "AAAA"
  zone_id = aws_route53_zone.zone.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource "aws_route53_record" "www_a" {
  name    = "www.brutalismbot.com"
  type    = "A"
  zone_id = aws_route53_zone.zone.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource "aws_route53_record" "www_aaaa" {
  name    = "www.brutalismbot.com"
  type    = "AAAA"
  zone_id = aws_route53_zone.zone.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource "aws_route53_record" "github" {
  name    = "_github-challenge-brutalismbot.brutalismbot.com"
  records = ["0981d41914"]
  ttl     = 300
  type    = "TXT"
  zone_id = aws_route53_zone.zone.id
}

#################
#   S3 BUCKET   #
#################

data "aws_iam_policy_document" "website" {
  statement {
    sid       = "AllowCloudFront"
    actions   = ["s3:GetObject"]
    resources = [local.s3_bucket_object_arn_glob]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.website.iam_arn]
    }
  }
}

resource "aws_s3_bucket" "website" {
  bucket = local.s3_bucket_name
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document { suffix = "index.html" }

  error_document { key = "error.html" }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json
}

resource "aws_s3_object" "objects" {
  for_each = {
    for x in fileset("${path.module}/www", "**") :
    x => lookup(local.mime_map, reverse(split(".", x))[0])
  }

  bucket       = aws_s3_bucket.website.id
  key          = each.key
  content_type = each.value
  source       = "${path.module}/www/${each.key}"
  source_hash  = filemd5("${path.module}/www/${each.key}")
}

###############
#   OUTPUTS   #
###############

output "cloudfront_distribution_id" { value = aws_cloudfront_distribution.website.id }
output "cloudfront_distribution_domain_name" { value = aws_cloudfront_distribution.website.domain_name }
output "s3_bucket" { value = { arn : aws_s3_bucket.website.arn, bucket : aws_s3_bucket.website.bucket } }
