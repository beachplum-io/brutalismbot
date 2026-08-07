#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  backend "s3" {
    bucket = "beachplum-terraform"
    key    = "beachplum-io/brutalismbot/green/terraform.tfstate"
    region = "us-west-2"
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
    "brutalismbot:env" = "green"
    "git:repo"         = "beachplum-io/brutalismbot"
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
