#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  # cloud {
  #   organization = "beachplum"

  #   workspaces { name = "brutalismbot-${local.env}-slack" }
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

##############
#   LOCALS   #
##############

locals {
  env = "blue"
  app = "slack"

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
  env    = local.env
  app    = local.app
}

module "create-posts" {
  source = "./create-posts"
  env    = local.env
  app    = local.app
}

module "install" {
  source = "./install"
  env    = local.env
  app    = local.app
}

module "uninstall" {
  source = "./uninstall"
  env    = local.env
  app    = local.app
}

module "send-post" {
  source = "./send-post"
  env    = local.env
  app    = local.app
}
