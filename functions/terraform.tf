#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "beachplum"

    workspaces { name = "brutalismbot-functions" }
  }

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
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

variable "AWS_ROLE_ARN" {}
variable "MAIL_TO" {}

##############
#   LOCALS   #
##############

locals {
  tags = {
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = "brutalismbot-functions"
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

###############
#   MODULES   #
###############

module "mail" {
  source  = "./functions/mail"
  MAIL_TO = var.MAIL_TO
}
