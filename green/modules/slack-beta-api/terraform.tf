#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.6"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
