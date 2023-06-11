#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  # cloud {
  #   organization = "beachplum"

  #   workspaces { name = "brutalismbot-dns" }
  # }

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
  env = "blue"

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  acm = {
    us-east-1 = element(tolist(aws_acm_certificate.us-east-1.domain_validation_options), 0)
    us-west-2 = element(tolist(aws_acm_certificate.us-west-2.domain_validation_options), 0)
  }

  apis = {
    "slack"           = "brutalismbot/slack"
    "slack/beta"      = "brutalismbot/slack/beta"
    "blue/slack"      = "brutalismbot-${local.env}-slack-api"
    "blue/slack/beta" = "brutalismbot-${local.env}-slack-beta-api"
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

data "aws_apigatewayv2_apis" "apis" {
  for_each = local.apis
  name     = each.value
}

data "aws_apigatewayv2_api" "apis" {
  for_each = { for k, v in data.aws_apigatewayv2_apis.apis : k => tolist(v.ids)[0] }
  api_id   = each.value
}

data "aws_cloudfront_distribution" "website" {
  id = "E56K5Y115KDS"
}

#######################
#   ACM :: US-EAST-1  #
#######################

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

#######################
#   ACM :: US-WEST-2  #
#######################

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

###################
#   API GATEWAY   #
###################

resource "aws_apigatewayv2_domain_name" "us-west-2" {
  domain_name = "api.brutalismbot.com"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.us-west-2.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "mappings" {
  for_each        = { for k, v in data.aws_apigatewayv2_api.apis : k => v.id }
  api_mapping_key = each.key
  api_id          = each.value
  domain_name     = "api.brutalismbot.com"
  stage           = "$default"
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
  name    = local.acm.us-east-1.resource_record_name
  records = [local.acm.us-east-1.resource_record_value]
  ttl     = 300
  type    = local.acm.us-east-1.resource_record_type
  zone_id = aws_route53_zone.zone.id
}

resource "aws_route53_record" "api" {
  for_each       = { us-west-2 = aws_apigatewayv2_domain_name.us-west-2 }
  name           = each.value.domain_name
  set_identifier = "${each.key}.${each.value.domain_name}"
  type           = "A"
  zone_id        = aws_route53_zone.zone.id

  # health_check_id = aws_route53_health_check.healthcheck.id

  alias {
    evaluate_target_health = true
    name                   = each.value.domain_name_configuration.0.target_domain_name
    zone_id                = each.value.domain_name_configuration.0.hosted_zone_id
  }

  latency_routing_policy {
    region = each.key
  }
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
    name                   = data.aws_cloudfront_distribution.website.domain_name
    zone_id                = data.aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource "aws_route53_record" "bluesky" {
  name    = "_atproto.brutalismbot.com"
  records = ["did=did:plc:ss234xtabshxpidtaa5kbnt2"]
  ttl     = 300
  type    = "TXT"
  zone_id = aws_route53_zone.zone.id
}

###############################
#   ROUTE53 :: HEALTHCHECKS   #
###############################

# resource "aws_route53_health_check" "healthcheck" {
#   failure_threshold = "3"
#   fqdn              = "api.brutalismbot.com"
#   measure_latency   = true
#   port              = 443
#   request_interval  = "30"
#   resource_path     = "/slack/health"
#   type              = "HTTPS"
# }
