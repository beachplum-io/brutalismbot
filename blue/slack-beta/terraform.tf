#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  # cloud {
  #   organization = "beachplum"

  #   workspaces { name = "brutalismbot-${local.env}-slack-beta" }
  # }

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.3"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
variable "USER_ID" { type = string }

##############
#   LOCALS   #
##############

locals {
  env = "blue"
  app = "slack-beta"

  tags = {
    "brutalismbot:env"       = local.env
    "brutalismbot:app"       = local.app
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = "brutalismbot-${local.env}-${local.app}"
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

###############
#   MODULES   #
###############

module "api" {
  source = "./api"
  app    = local.app
  env    = local.env
}


module "app-home" {
  source  = "./app-home"
  app     = local.app
  env     = local.env
  user_id = var.USER_ID
}

module "delete-message" {
  source = "./delete-message"
  app    = local.app
  env    = local.env
}

module "disable" {
  source = "./disable"
  app    = local.app
  env    = local.env
}

module "enable" {
  source = "./enable"
  app    = local.app
  env    = local.env
}

module "reject" {
  source = "./reject"
  app    = local.app
  env    = local.env
}

module "screen" {
  source     = "./screen"
  app        = local.app
  env        = local.env
  channel_id = var.USER_ID
}

module "states-errors" {
  source     = "./states-errors"
  app        = local.app
  env        = local.env
  channel_id = var.USER_ID
}
