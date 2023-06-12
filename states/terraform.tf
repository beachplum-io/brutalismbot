#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "beachplum"

    workspaces { name = "brutalismbot-states" }
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
variable "wait_time_seconds" { default = 14400 }

##############
#   LOCALS   #
##############

locals {
  team_id = "THAQ99JLW"

  apps = {
    beta = "A020594EPJQ"
    prod = "AH0KW28C9"
  }

  conversations = {
    messages  = "DH6UK5Q0Y"
    brutalism = "CH0KP5789"
  }

  tags = {
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = "brutalismbot-states"
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

############
#   MAIL   #
############

module "mail" {
  source = "./state-machine"
  name   = "mail"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid      = "SendEmail"
      Effect   = "Allow"
      Action   = "ses:SendEmail"
      Resource = "*"
    }
  })
}

#############
#   QUERY   #
#############

module "query" {
  source = "./state-machine"
  name   = "query"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = "dynamodb:Query"
        Resource = "*"
      },
      {
        Sid      = "StepFunctions"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = "*"
      }
    ]
  })
}

module "callback" {
  source = "./state-machine"
  name   = "callback"
  policy = jsonencode({})
}
