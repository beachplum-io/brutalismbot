#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.2"
    }
  }
}

############
#   DATA   #
############

data "aws_region" "current" {}

data "aws_apigatewayv2_apis" "apis" {
  for_each = var.mappings
  name     = each.value
}

data "aws_apigatewayv2_api" "apis" {
  for_each = { for k, v in data.aws_apigatewayv2_apis.apis : k => tolist(v.ids)[0] }
  api_id   = each.value
}

##############
#   LOCALS   #
##############

locals {
  region = data.aws_region.current.name
}

###################
#   API GATEWAY   #
###################

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = "api.brutalismbot.com"

  domain_name_configuration {
    certificate_arn = var.acm_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "mappings" {
  for_each        = { for k, v in data.aws_apigatewayv2_api.apis : k => v.id }
  api_mapping_key = each.key
  api_id          = each.value
  domain_name     = aws_apigatewayv2_domain_name.api.domain_name
  stage           = "$default"
}

##########################
#   ROUTE53 :: RECORDS   #
##########################

resource "aws_route53_record" "api" {
  name           = aws_apigatewayv2_domain_name.api.domain_name
  set_identifier = "${local.region}.${aws_apigatewayv2_domain_name.api.domain_name}"
  type           = "A"
  zone_id        = var.zone_id

  # health_check_id = aws_route53_health_check.healthcheck.id

  alias {
    evaluate_target_health = true
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
  }

  latency_routing_policy {
    region = local.region
  }
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
