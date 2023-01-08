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

module "api_slack" { source = "./functions/api-slack" }

module "api_slack_beta" { source = "./functions/api-slack-beta" }

module "array" { source = "./functions/array" }

module "http" { source = "./functions/http" }

module "mail" {
  source  = "./functions/mail"
  MAIL_TO = var.MAIL_TO
}

module "slack_beta_home" { source = "./functions/slack-beta-home" }

module "slack_link_unfurl" { source = "./functions/slack-link-unfurl" }

module "slack_transform" { source = "./functions/slack-transform" }

module "reddit_dequeue" { source = "./functions/reddit-dequeue" }

module "twitter_post" { source = "./functions/twitter-post" }

module "twitter_transform" { source = "./functions/twitter-transform" }

###############
#   OUTPUTS   #
###############

output "functions" {
  value = {
    api_slack = {
      arn           = module.api_slack.lambda_function.arn
      function_name = module.api_slack.lambda_function.function_name
    }

    api_slack_beta = {
      arn           = module.api_slack_beta.lambda_function.arn
      function_name = module.api_slack_beta.lambda_function.function_name
    }

    array = {
      arn           = module.array.lambda_function.arn
      function_name = module.array.lambda_function.function_name
    }

    http = {
      arn           = module.http.lambda_function.arn
      function_name = module.http.lambda_function.function_name
    }

    mail = {
      arn           = module.mail.lambda_function.arn
      function_name = module.mail.lambda_function.function_name
    }

    reddit_dequeue = {
      arn           = module.reddit_dequeue.lambda_function.arn
      function_name = module.reddit_dequeue.lambda_function.function_name
    }

    slack_beta_home = {
      arn           = module.slack_beta_home.lambda_function.arn
      function_name = module.slack_beta_home.lambda_function.function_name
    }

    slack_link_unfurl = {
      arn           = module.slack_link_unfurl.lambda_function.arn
      function_name = module.slack_link_unfurl.lambda_function.function_name
    }

    slack_transform = {
      arn           = module.slack_transform.lambda_function.arn
      function_name = module.slack_transform.lambda_function.function_name
    }

    twitter_post = {
      arn           = module.twitter_post.lambda_function.arn
      function_name = module.twitter_post.lambda_function.function_name
    }

    twitter_transform = {
      arn           = module.twitter_transform.lambda_function.arn
      function_name = module.twitter_transform.lambda_function.function_name
    }
  }
}

output "roles" {
  value = {
    api_slack = {
      arn  = module.api_slack.iam_role.arn
      name = module.api_slack.iam_role.name
    }

    api_slack_beta = {
      arn  = module.api_slack_beta.iam_role.arn
      name = module.api_slack_beta.iam_role.name
    }

    array = {
      arn  = module.array.iam_role.arn
      name = module.array.iam_role.name
    }

    http = {
      arn  = module.http.iam_role.arn
      name = module.http.iam_role.name
    }

    mail = {
      arn  = module.mail.iam_role.arn
      name = module.mail.iam_role.name
    }

    reddit_dequeue = {
      arn  = module.reddit_dequeue.iam_role.arn
      name = module.reddit_dequeue.iam_role.name
    }

    slack_link_unfurl = {
      arn  = module.slack_link_unfurl.iam_role.arn
      name = module.slack_link_unfurl.iam_role.name
    }

    slack_transform = {
      arn  = module.slack_transform.iam_role.arn
      name = module.slack_transform.iam_role.name
    }

    twitter_post = {
      arn  = module.twitter_post.iam_role.arn
      name = module.twitter_post.iam_role.name
    }

    twitter_transform = {
      arn  = module.twitter_transform.iam_role.arn
      name = module.twitter_transform.iam_role.name
    }
  }
}
