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

  env  = "global"
  app  = "website"
  name = "brutalismbot-${local.app}"

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
    "beachplum:env"          = local.env
    "beachplum:app"          = local.app
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = local.name
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
  comment = "access-identity-${aws_s3_bucket.website.bucket}.s3.amazonaws.com"
}

#################
#   S3 BUCKET   #
#################

resource "aws_s3_bucket" "website" {
  bucket = "${local.region}-${local.name}"
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
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AllowCloudFront"
      Effect    = "Allow"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.website.arn}/*"
      Principal = { AWS = aws_cloudfront_origin_access_identity.website.iam_arn }
    }
  })
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
