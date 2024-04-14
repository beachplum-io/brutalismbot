#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "beachplum"

    workspaces { name = "brutalismbot-blue" }
  }

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
  region = local.region
  default_tags { tags = local.tags }
}

##############
#   LOCALS   #
##############

locals {
  region = "us-west-2"

  tags = {
    "brutalismbot:env"       = split("-", terraform.workspace)[1]
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = terraform.workspace
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

###############
#   MODULES   #
###############

module "shared" { source = "./shared" }
module "bluesky" { source = "./bluesky" }
module "dashboard" { source = "./dashboard" }
module "mail" { source = "./mail" }
module "reddit" { source = "./reddit" }
module "slack" { source = "./slack" }
module "slack-beta" { source = "./slack-beta" }
module "twitter" { source = "./twitter" }
module "website" { source = "./website" }
