#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "beachplum"

    workspaces { name = "brutalismbot-green" }
  }
}

###########
#   AWS   #
###########

provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

##############
#   LOCALS   #
##############

locals {
  region = "us-west-2"

  tags = {
    "brutalismbot:env"       = trimprefix("brutalismbot-", terraform.workspace)
    "git:repo"               = "beachplum-io/brutalismbot"
    "terraform:organization" = "beachplum"
    "terraform:project"      = "Brutalismbot"
    "terraform:workspace"    = terraform.workspace
  }
}

###############
#   MODULES   #
###############

module "backup" { source = "./modules/backup" }
module "bluesky" { source = "./modules/bluesky" }
module "params" { source = "./modules/params" }
module "reddit" { source = "./modules/reddit" }
module "shared" { source = "./modules/shared" }
module "slack" { source = "./modules/slack" }
module "slack_beta_api" { source = "./modules/slack-beta-api" }
