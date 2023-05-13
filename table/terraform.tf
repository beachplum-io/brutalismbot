#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "beachplum"

    workspaces { name = "brutalismbot-table" }
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

#################
#   VARIABLES   #
#################

variable "AWS_ROLE_ARN" {}

##############
#   LOCALS   #
##############

locals {
  tags = {
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = "brutalismbot-table"
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

#############
#   TABLE   #
#############

resource "aws_dynamodb_table" "table" {
  name           = "Brutalismbot-v2"
  hash_key       = "Id"
  range_key      = "Kind"
  billing_mode   = "PAY_PER_REQUEST"
  read_capacity  = 0
  write_capacity = 0

  attribute {
    name = "Id"
    type = "S"
  }

  attribute {
    name = "Kind"
    type = "S"
  }

  ttl {
    attribute_name = "TTL"
    enabled        = true
  }

  global_secondary_index {
    name            = "Kind"
    hash_key        = "Kind"
    range_key       = "Id"
    projection_type = "ALL"
    read_capacity   = 0
    write_capacity  = 0
  }
}
