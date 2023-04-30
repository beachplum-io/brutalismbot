#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "beachplum"

    workspaces { name = "brutalismbot-events" }
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

##############
#   LOCALS   #
##############

locals {
  is_enabled = {
    reddit = {
      dequeue = true
      post    = true
      reject  = true
      screen  = true
    }

    slack = {
      beta_app_home_opened = true
      beta_enable_disable  = true
      beta_link_shared     = true
      beta_refresh_home    = true
      install              = true
      post                 = true
      post_channel         = true
      uninstall            = true
    }

    twitter = {
      post = true
    }
  }

  tags = {
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = "brutalismbot-events"
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

#################
#   EVENT BUS   #
#################

resource "aws_cloudwatch_event_bus" "bus" {
  name = "brutalismbot"
}

######################
#   STATE MACHINES   #
######################

data "aws_sfn_state_machine" "state_machines" {
  for_each = {
    reddit-dequeue            = "brutalismbot-reddit-dequeue"
    reddit-post               = "brutalismbot-reddit-post"
    reddit-reject             = "brutalismbot-reddit-reject"
    reddit-screen             = "brutalismbot-reddit-screen"
    slack-beta-enable-disable = "brutalismbot-slack-beta-enable-disable"
    slack-beta-refresh-home   = "brutalismbot-slack-beta-refresh-home"
    slack-beta-link-shared    = "brutalismbot-slack-beta-link-shared"
    slack-install             = "brutalismbot-slack-install"
    slack-post                = "brutalismbot-slack-post"
    slack-post-channel        = "brutalismbot-slack-post-channel"
    slack-uninstall           = "brutalismbot-slack-uninstall"
    state-machine-errors      = "brutalismbot-state-machine-errors"
    twitter-post              = "brutalismbot-twitter-post"
  }
  name = each.value
}

#########################
#   REDDIT :: DEQUEUE   #
#########################

module "reddit_dequeue" {
  source = "./schedule"

  description         = "Dequeue next post from /r/brutalism"
  identifier          = "reddit-dequeue"
  is_enabled          = local.is_enabled.reddit.dequeue
  schedule_expression = "rate(1 hour)"
  state_machine_arn   = data.aws_sfn_state_machine.state_machines["reddit-dequeue"].arn
}

######################
#   REDDIT :: POST   #
######################

module "reddit_post" {
  source = "./eventbridge"

  description       = "Handle new posts from Reddit"
  event_bus_name    = aws_cloudwatch_event_bus.bus.name
  identifier        = "reddit-post"
  is_enabled        = local.is_enabled.reddit.post
  state_machine_arn = data.aws_sfn_state_machine.state_machines["reddit-post"].arn

  pattern = {
    source      = ["reddit"]
    detail-type = ["post"]
  }
}

########################
#   REDDIT :: REJECT   #
########################

module "reddit_reject" {
  source = "./eventbridge"

  description       = "Reject posts from Reddit"
  event_bus_name    = aws_cloudwatch_event_bus.bus.name
  identifier        = "reddit-post-reject"
  is_enabled        = local.is_enabled.reddit.reject
  state_machine_arn = data.aws_sfn_state_machine.state_machines["reddit-reject"].arn

  pattern = {
    source      = ["slack/beta"]
    detail-type = ["callback", "POST /callbacks"]
    detail = {
      type    = ["block_actions"]
      actions = { action_id = ["reject"] }
    }
  }
}

#########################
#   REDDITY :: VERIFY   #
#########################

module "reddit_screen" {
  source = "./eventbridge"

  description       = "Verify new posts from Reddit"
  event_bus_name    = aws_cloudwatch_event_bus.bus.name
  identifier        = "reddit-post-screen"
  is_enabled        = local.is_enabled.reddit.screen
  state_machine_arn = data.aws_sfn_state_machine.state_machines["reddit-screen"].arn

  pattern = {
    source      = ["reddit"]
    detail-type = ["post/slack/screen"]
  }
}

####################################
#   SLACK :: BETA ENABLE/DISABLE   #
####################################

module "slack_beta_enable_disable" {
  source = "./eventbridge"

  description       = "Handle Slack beta enable/disable callbacks"
  event_bus_name    = aws_cloudwatch_event_bus.bus.name
  identifier        = "slack-beta-enable-disable"
  is_enabled        = local.is_enabled.slack.beta_enable_disable
  state_machine_arn = data.aws_sfn_state_machine.state_machines["slack-beta-enable-disable"].arn

  pattern = {
    source      = ["slack/beta"]
    detail-type = ["callback", "POST /callbacks", "block_actions"]

    detail = {
      actions = { action_id = ["enable_disable"] }
      view    = { callback_id = ["home"] }
    }
  }
}

##################################
#   SLACK :: BETA REFRESH HOME   #
##################################

module "slack_beta_refresh_home" {
  source = "./eventbridge"

  description       = "Handle Slack beta refresh callbacks"
  event_bus_name    = aws_cloudwatch_event_bus.bus.name
  identifier        = "slack-beta-refresh-home"
  is_enabled        = local.is_enabled.slack.beta_refresh_home
  state_machine_arn = data.aws_sfn_state_machine.state_machines["slack-beta-refresh-home"].arn

  pattern = {
    source      = ["slack/beta"]
    detail-type = ["POST /callbacks"]

    detail = {
      type    = ["block_actions"]
      actions = { action_id = ["refresh"] }
      view    = { callback_id = ["home"] }
    }
  }
}

############################
#   SLACK :: LINK SHARED   #
############################

module "slack_beta_link_shared" {
  source = "./eventbridge"

  description       = "Handle Slack link unfurls"
  event_bus_name    = aws_cloudwatch_event_bus.bus.name
  identifier        = "slack-beta-link-shared"
  is_enabled        = local.is_enabled.slack.beta_link_shared
  state_machine_arn = data.aws_sfn_state_machine.state_machines["slack-beta-link-shared"].arn

  pattern = {
    source      = ["slack/beta"]
    detail-type = ["POST /events"]

    detail = {
      type  = ["event_callback"]
      event = { type = ["link_shared"] }
    }
  }
}

########################
#   SLACK :: INSTALL   #
########################

module "slack_install" {
  source = "./eventbridge"

  description       = "Handle Slack install events"
  event_bus_name    = aws_cloudwatch_event_bus.bus.name
  identifier        = "slack-install"
  is_enabled        = local.is_enabled.slack.install
  state_machine_arn = data.aws_sfn_state_machine.state_machines["slack-install"].arn

  pattern = {
    source      = ["slack", "slack/beta"]
    detail-type = ["GET /oauth/v2"]
  }
}

#####################
#   SLACK :: POST   #
#####################

module "slack_post" {
  source = "./eventbridge"

  description       = "Handle new posts from Reddit for Slack"
  event_bus_name    = aws_cloudwatch_event_bus.bus.name
  identifier        = "slack-post"
  is_enabled        = local.is_enabled.slack.post
  state_machine_arn = data.aws_sfn_state_machine.state_machines["slack-post"].arn

  pattern = {
    source      = ["reddit"]
    detail-type = ["post/slack"]
  }
}

#############################
#   SLACK :: POST CHANNEL   #
#############################

module "slack_post_channel" {
  source = "./eventbridge"

  description       = "Handle new posts from Reddit for a Slack workspace"
  event_bus_name    = aws_cloudwatch_event_bus.bus.name
  identifier        = "slack-post-channel"
  is_enabled        = local.is_enabled.slack.post_channel
  state_machine_arn = data.aws_sfn_state_machine.state_machines["slack-post-channel"].arn

  pattern = {
    source      = ["reddit"]
    detail-type = ["post/slack/channel"]
  }
}

##########################
#   SLACK :: UNINSTALL   #
##########################

module "slack_uninstall" {
  source = "./eventbridge"

  description       = "Handle Slack uninstall events"
  event_bus_name    = aws_cloudwatch_event_bus.bus.name
  identifier        = "slack-uninstall"
  is_enabled        = local.is_enabled.slack.uninstall
  state_machine_arn = data.aws_sfn_state_machine.state_machines["slack-uninstall"].arn

  pattern = {
    source      = ["slack", "slack/beta"]
    detail-type = ["POST /events"]

    detail = {
      type  = ["event_callback"]
      event = { type = ["app_uninstalled"] }
    }
  }
}

############################
#   STATE MACHINE ERRORS   #
############################

module "state_machine_errors" {
  source = "./eventbridge"

  description       = "Handle state machine errors"
  event_bus_name    = "default"
  identifier        = "state-machine-errors"
  input_path        = null
  is_enabled        = local.is_enabled.slack.uninstall
  state_machine_arn = data.aws_sfn_state_machine.state_machines["state-machine-errors"].arn

  pattern = {
    source      = ["aws.states"]
    detail-type = ["Step Functions Execution Status Change"]

    detail = {
      stateMachineArn = [{ anything-but = data.aws_sfn_state_machine.state_machines["state-machine-errors"].arn }]
      status          = ["FAILED", "TIMED_OUT"]
    }
  }
}

#######################
#   TWITTER :: POST   #
#######################

module "twitter_post" {
  source = "./eventbridge"

  description       = "Handle new posts from Reddit for Twitter"
  event_bus_name    = aws_cloudwatch_event_bus.bus.name
  identifier        = "twitter-post"
  is_enabled        = local.is_enabled.twitter.post
  state_machine_arn = data.aws_sfn_state_machine.state_machines["twitter-post"].arn

  pattern = {
    source      = ["reddit"]
    detail-type = ["post/twitter"]
  }
}

###############
#   OUTPUTS   #
###############

output "event_bus" {
  value = {
    arn  = aws_cloudwatch_event_bus.bus.arn
    name = aws_cloudwatch_event_bus.bus.name
  }
}

output "roles" {
  value = {
    reddit_dequeue = {
      arn  = module.reddit_dequeue.role.arn
      name = module.reddit_dequeue.role.name
    }

    reddit_post = {
      arn  = module.reddit_post.role.arn
      name = module.reddit_post.role.name
    }

    reddit_reject = {
      arn  = module.reddit_reject.role.arn
      name = module.reddit_reject.role.name
    }

    reddit_screen = {
      arn  = module.reddit_screen.role.arn
      name = module.reddit_screen.role.name
    }

    slack_post = {
      arn  = module.slack_post.role.arn
      name = module.slack_post.role.name
    }

    slack_post_channel = {
      arn  = module.slack_post_channel.role.arn
      name = module.slack_post_channel.role.name
    }

    slack_uninstall = {
      arn  = module.slack_uninstall.role.arn
      name = module.slack_uninstall.role.name
    }

    twitter_post = {
      arn  = module.twitter_post.role.arn
      name = module.twitter_post.role.name
    }
  }
}

output "rules" {
  value = {
    for key, val in {
      reddit_dequeue     = module.reddit_dequeue.rule
      reddit_post        = module.reddit_post.rule
      reddit_reject      = module.reddit_reject.rule
      reddit_screen      = module.reddit_screen.rule
      slack_post         = module.slack_post.rule
      slack_post_channel = module.slack_post_channel.rule
      slack_uninstall    = module.slack_uninstall.rule
      twitter_post       = module.twitter_post.rule
    } : key => { arn : val.arn, name : val.name }
  }
}
