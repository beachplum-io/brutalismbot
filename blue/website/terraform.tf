##############
#   LOCALS   #
##############

locals {
  region = data.aws_region.current.region

  app  = basename(path.module)
  name = "${terraform.workspace}-${local.app}"
  tags = { "brutalismbot:app" = local.app }

  mime_map = {
    css         = "text/css"
    html        = "text/html"
    ico         = "image/x-icon"
    png         = "image/png"
    svg         = "image/svg+xml"
    webmanifest = "application/manifest+json"
    xml         = "application/xml"
  }

  keys = fileset("${path.module}/www", "**")
  objects = {
    for key in local.keys : key => {
      content_type = lookup(local.mime_map, reverse(split(".", key))[0], "text/plain")
      source       = "${path.module}/www/${key}"
    }
  }
}

############
#   DATA   #
############

data "aws_region" "current" {}

data "aws_cloudfront_origin_access_identities" "website" {
  comments = ["access-identity-${aws_s3_bucket.website.bucket}.s3.amazonaws.com"]
}

#################
#   S3 BUCKET   #
#################

resource "aws_s3_bucket" "website" {
  bucket = "${local.region}-${terraform.workspace}-${local.app}"
  tags   = local.tags
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
      Principal = { AWS = data.aws_cloudfront_origin_access_identities.website.iam_arns }
    }
  })
}

resource "aws_s3_object" "objects" {
  for_each = local.objects

  bucket       = aws_s3_bucket.website.id
  key          = each.key
  content_type = each.value.content_type
  source       = each.value.source
  source_hash  = filemd5(each.value.source)
  tags         = local.tags
}
