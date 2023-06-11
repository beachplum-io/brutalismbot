#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  # cloud {
  #   organization = "beachplum"

  #   workspaces { name = "brutalismbot-${local.env}-bluesky" }
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
  app = "bluesky"

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

module "send-post" {
  source = "./send-post"
  env    = local.env
  app    = local.app
}
