provider archive {
  version = "~> 1.2"
}

provider aws {
  access_key = "${var.aws_access_key_id}"
  profile    = "${var.aws_profile}"
  region     = "${var.aws_region}"
  secret_key = "${var.aws_secret_access_key}"
  version    = "~> 2.4"
}

locals {
  tags {
    App     = "brutalismbot"
    Name    = "brutalismbot.com"
    Release = "${var.release}"
    Repo    = "${var.repo}"
  }
}

data archive_file package {
  output_path = "${path.module}/dist/package.zip"
  source_dir  = "${path.module}/lib"
  type        = "zip"
}

data aws_kms_key key {
  key_id = "alias/brutalismbot"
}

data aws_iam_policy_document s3 {
  statement {
    actions   = ["s3:*"]
    resources = [
      "${aws_s3_bucket.brutalismbot.arn}",
      "${aws_s3_bucket.brutalismbot.arn}/*",
    ]
  }
}

resource aws_acm_certificate cert {
  domain_name       = "brutalismbot.com"
  tags              = "${local.tags}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_acm_certificate_validation cert {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert.fqdn}"]
}

resource aws_cloudfront_distribution website {
  aliases             = ["brutalismbot.com", "www.brutalismbot.com"]
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_code         = 404
    response_page_path    = "/error.html"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    default_ttl            = 86400
    max_ttl                = 31536000
    min_ttl                = 0
    target_origin_id       = "${aws_s3_bucket.website.bucket}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  origin {
    domain_name = "${aws_s3_bucket.website.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.website.bucket}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = "${aws_acm_certificate_validation.cert.certificate_arn}"
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method       = "sni-only"
  }
}

resource aws_api_gateway_base_path_mapping api {
  api_id      = "${module.slackbot.api_id}"
  domain_name = "${aws_api_gateway_domain_name.api.domain_name}"
  stage_name  = "${module.slackbot.api_stage_name}"
  base_path   = "slack"
}

resource aws_api_gateway_domain_name api {
  certificate_arn = "${aws_acm_certificate_validation.cert.certificate_arn}"
  domain_name     = "api.brutalismbot.com"
}

resource aws_cloudwatch_dashboard dash {
  dashboard_name = "Brutalismbot"
  dashboard_body = "${file("${path.module}/dashboard.json")}"
}

resource aws_cloudwatch_event_rule cache {
  description         = "Cache posts from /r/brutalism to S3"
  name                = "${aws_lambda_function.cache.function_name}"
  schedule_expression = "rate(1 hour)"
}

resource aws_cloudwatch_event_target cache {
  rule  = "${aws_cloudwatch_event_rule.cache.name}"
  arn   = "${aws_lambda_function.cache.arn}"
}

resource aws_cloudwatch_log_group install {
  name              = "/aws/lambda/${aws_lambda_function.install.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

resource aws_cloudwatch_log_group cache {
  name              = "/aws/lambda/${aws_lambda_function.cache.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

resource aws_cloudwatch_log_group mirror {
  name              = "/aws/lambda/${aws_lambda_function.mirror.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

resource aws_cloudwatch_log_group uninstall {
  name              = "/aws/lambda/${aws_lambda_function.uninstall.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

/*
resource aws_kms_key brutalismbot {
  description = "Brutalismbot Slack App"
  tags        = "${local.tags}"
}

resource aws_kms_alias brutalismbot {
  name          = "alias/brutalismbot"
  target_key_id = "${aws_kms_key.brutalismbot.key_id}"
}
*/

resource aws_iam_role_policy s3_access {
  name   = "s3"
  policy = "${data.aws_iam_policy_document.s3.json}"
  role   = "${module.slackbot.role_name}"
}

resource aws_lambda_function install {
  description      = "Install OAuth credentials"
  filename         = "${data.archive_file.package.output_path}"
  function_name    = "brutalismbot-install"
  handler          = "handlers.install"
  role             = "${module.slackbot.role_arn}"
  runtime          = "ruby2.5"
  source_code_hash = "${filebase64sha256("${data.archive_file.package.output_path}")}"
  tags             = "${local.tags}"

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_function cache {
  description      = "Cache posts from /r/brutalism"
  filename         = "${data.archive_file.package.output_path}"
  function_name    = "brutalismbot-cache"
  handler          = "handlers.cache"
  role             = "${module.slackbot.role_arn}"
  runtime          = "ruby2.5"
  source_code_hash = "${filebase64sha256("${data.archive_file.package.output_path}")}"
  tags             = "${local.tags}"
  timeout          = 15

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_function mirror {
  description      = "Mirror posts from /r/brutalism"
  filename         = "${data.archive_file.package.output_path}"
  function_name    = "brutalismbot-mirror"
  handler          = "handlers.mirror"
  role             = "${module.slackbot.role_arn}"
  runtime          = "ruby2.5"
  source_code_hash = "${filebase64sha256("${data.archive_file.package.output_path}")}"
  tags             = "${local.tags}"
  timeout          = 30

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_function uninstall {
  description      = "Uninstall brutalismbot from workspace"
  filename         = "${data.archive_file.package.output_path}"
  function_name    = "brutalismbot-uninstall"
  handler          = "handlers.uninstall"
  role             = "${module.slackbot.role_arn}"
  runtime          = "ruby2.5"
  source_code_hash = "${filebase64sha256("${data.archive_file.package.output_path}")}"
  tags             = "${local.tags}"

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_permission install {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.install.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${module.slackbot.oauth_topic_arn}"
}

resource aws_lambda_permission cache {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.cache.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.cache.arn}"
}

resource aws_lambda_permission mirror {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.mirror.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.brutalismbot.arn}"
}

resource aws_lambda_permission uninstall {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.uninstall.arn}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.uninstall.arn}"
}

resource aws_route53_zone website {
  comment = "HostedZone created by Route53 Registrar"
  name    = "brutalismbot.com"
}

resource aws_route53_record cert {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 300
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${aws_route53_zone.website.id}"
}

resource aws_route53_record api {
  name    = "${aws_api_gateway_domain_name.api.domain_name}"
  type    = "A"
  zone_id = "${aws_route53_zone.website.id}"

  alias {
    evaluate_target_health = true
    name                   = "${aws_api_gateway_domain_name.api.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.api.cloudfront_zone_id}"
  }
}

resource aws_s3_bucket brutalismbot {
  acl           = "private"
  bucket        = "brutalismbot"
  force_destroy = false

  /*server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${data.aws_kms_key.key.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }*/
}

resource aws_s3_bucket website {
  acl           = "public-read"
  bucket        = "brutalismbot.com"
  force_destroy = false
}

resource aws_s3_bucket_notification mirror {
  bucket = "${aws_s3_bucket.brutalismbot.id}"

  lambda_function {
    id                  = "mirror"
    lambda_function_arn = "${aws_lambda_function.mirror.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "posts/v1/"
    filter_suffix       = ".json"
  }
}

resource aws_sns_topic uninstall {
  name = "brutalismbot_event_app_uninstalled"
}

resource aws_sns_topic_subscription install {
  endpoint  = "${aws_lambda_function.install.arn}"
  protocol  = "lambda"
  topic_arn = "${module.slackbot.oauth_topic_arn}"
}

resource aws_sns_topic_subscription uninstall {
  endpoint  = "${aws_lambda_function.uninstall.arn}"
  protocol  = "lambda"
  topic_arn = "${aws_sns_topic.uninstall.arn}"
}

module slackbot {
  source               = "amancevice/slackbot/aws"
  version              = "13.3.0"
  api_description      = "Brutalismbot REST API"
  api_name             = "brutalismbot"
  api_stage_name       = "v1"
  api_stage_tags       = "${local.tags}"
  base_url             = "/slack"
  kms_key_id           = "${data.aws_kms_key.key.key_id}"
  lambda_function_name = "brutalismbot-api"
  lambda_tags          = "${local.tags}"
  log_group_tags       = "${local.tags}"
  role_name            = "brutalismbot"
  role_tags            = "${local.tags}"
  secret_name          = "brutalismbot"
  sns_topic_prefix     = "brutalismbot_"
}
