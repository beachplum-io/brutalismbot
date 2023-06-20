#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  # cloud {
  #   organization = "beachplum"

  #   workspaces { name = "brutalismbot-blue" }
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.3"
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

variable "AWS_ROLE_ARN" { type = string }

##############
#   LOCALS   #
##############

locals {
  env = "blue"

  tags = {
    "brutalismbot:env"       = local.env
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = "brutalismbot-${local.env}"
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

###############
#   MODULES   #
###############

module "shared" {
  source = "./shared"
  env    = local.env
}

module "bluesky" {
  source = "./bluesky"
  env    = local.env
}

module "reddit" {
  source = "./reddit"
  env    = local.env
}

module "slack" {
  source = "./slack"
  env    = local.env
}

module "slack-beta" {
  source = "./slack-beta"
  env    = local.env
}

module "twitter" {
  source = "./twitter"
  env    = local.env
}
