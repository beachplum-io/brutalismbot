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

data "terraform_remote_state" "events" {
  backend = "remote"

  config = {
    organization = "beachplum"

    workspaces = { name = "brutalismbot-events" }
  }
}

data "terraform_remote_state" "functions" {
  backend = "remote"

  config = {
    organization = "beachplum"

    workspaces = { name = "brutalismbot-functions" }
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

#############
#   TABLE   #
#############

resource "aws_dynamodb_table" "table" {
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "GUID"
  name           = "Brutalismbot"
  range_key      = "SORT"
  read_capacity  = 0
  write_capacity = 0

  attribute {
    name = "GUID"
    type = "S"
  }

  attribute {
    name = "SORT"
    type = "S"
  }

  attribute {
    name = "NAME"
    type = "S"
  }

  attribute {
    name = "CREATED_UTC"
    type = "S"
  }

  attribute {
    name = "TEAM_ID"
    type = "S"
  }

  ttl {
    attribute_name = "TTL"
    enabled        = true
  }

  global_secondary_index {
    name            = "Chrono"
    hash_key        = "SORT"
    range_key       = "CREATED_UTC"
    projection_type = "ALL"
    read_capacity   = 0
    write_capacity  = 0
  }

  global_secondary_index {
    name            = "RedditName"
    hash_key        = "NAME"
    range_key       = "GUID"
    projection_type = "ALL"
    read_capacity   = 0
    write_capacity  = 0
  }

  global_secondary_index {
    name            = "SlackTeam"
    hash_key        = "TEAM_ID"
    projection_type = "ALL"
    read_capacity   = 0
    write_capacity  = 0
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
      Action   = "ses:SendRawEmail"
      Resource = "*"
    }
  })
}

######################
#   REDDIT DEQUEUE   #
######################

module "reddit_dequeue" {
  source = "./state-machine"
  name   = "reddit-dequeue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CloudWatch"
        Effect   = "Allow"
        Action   = "cloudwatch:PutMetricData"
        Resource = "*"
      },
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = "dynamodb:GetItem"
        Resource = aws_dynamodb_table.table.arn
      },
      {
        Sid      = "EventBridge"
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = data.terraform_remote_state.events.outputs.event_bus.arn
      },
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = data.terraform_remote_state.functions.outputs.functions.reddit_dequeue.arn
      }
    ]
  })

  variables = {
    cloudwatch_namespace = "Brutalismbot"
    event_bus_name       = data.terraform_remote_state.events.outputs.event_bus.name
    reddit_dequeue_arn   = data.terraform_remote_state.functions.outputs.functions.reddit_dequeue.arn
    table_name           = aws_dynamodb_table.table.name
  }
}

###################
#   REDDIT POST   #
###################

module "reddit_post" {
  source = "./state-machine"
  name   = "reddit-post"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.table.arn
      },
      {
        Sid      = "EventBridge"
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = data.terraform_remote_state.events.outputs.event_bus.arn
      },
      {
        Sid    = "Lambda"
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          data.terraform_remote_state.functions.outputs.functions.slack_transform.arn,
          data.terraform_remote_state.functions.outputs.functions.twitter_transform.arn,
        ]
      }
    ]
  })

  variables = {
    event_bus_name                 = data.terraform_remote_state.events.outputs.event_bus.name
    slack_transform_function_arn   = data.terraform_remote_state.functions.outputs.functions.slack_transform.arn
    table_name                     = aws_dynamodb_table.table.name
    twitter_transform_function_arn = data.terraform_remote_state.functions.outputs.functions.twitter_transform.arn
    wait_time_seconds              = var.wait_time_seconds
  }
}

#####################
#   REDDIT REJECT   #
#####################

module "reddit_reject" {
  source = "./state-machine"
  name   = "reddit-reject"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = data.terraform_remote_state.functions.outputs.functions.http.arn
      },
      {
        Sid      = "States"
        Effect   = "Allow"
        Action   = "states:StopExecution"
        Resource = "*"
      }
    ]
  })

  variables = {
    http_function_arn = data.terraform_remote_state.functions.outputs.functions.http.arn
  }
}

#####################
#   REDDIT SCREEN   #
#####################

module "reddit_screen" {
  source = "./state-machine"
  name   = "reddit-screen"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem"]
        Resource = aws_dynamodb_table.table.arn
      },
      {
        Sid    = "Lambda"
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          data.terraform_remote_state.functions.outputs.functions.array.arn,
          data.terraform_remote_state.functions.outputs.functions.http.arn,
        ]
      }
    ]
  })

  variables = {
    app_id             = local.apps.beta
    team_id            = local.team_id
    conversation_id    = local.conversations.messages
    wait_time_seconds  = var.wait_time_seconds
    array_function_arn = data.terraform_remote_state.functions.outputs.functions.array.arn
    http_function_arn  = data.terraform_remote_state.functions.outputs.functions.http.arn
    table_name         = aws_dynamodb_table.table.name
  }
}

#################################
#   SLACK BETA ENABLE DISABLE   #
#################################

module "slack_beta_enable_disable" {
  source = "./state-machine"
  name   = "slack-beta-enable-disable"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = "dynamodb:Query"
        Resource = "${aws_dynamodb_table.table.arn}/index/Chrono"
      },
      {
        Sid    = "EventBridge"
        Effect = "Allow"
        Action = [
          "events:DescribeRule",
          "events:DisableRule",
          "events:EnableRule",
          "events:PutEvents",
        ]
        Resource = [
          data.terraform_remote_state.events.outputs.event_bus.arn,
          data.terraform_remote_state.events.outputs.rules.reddit_dequeue.arn,
        ]
      },
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = data.terraform_remote_state.functions.outputs.functions.http.arn
      }
    ]
  })

  variables = {
    event_bus_name           = data.terraform_remote_state.events.outputs.event_bus.name
    http_function_arn        = data.terraform_remote_state.functions.outputs.functions.http.arn
    reddit_dequeue_rule_name = data.terraform_remote_state.events.outputs.rules.reddit_dequeue.name
    table_name               = aws_dynamodb_table.table.name
  }
}

##############################
#   SLACK BETA LINK SHARED   #
##############################

module "slack_beta_link_shared" {
  source = "./state-machine"
  name   = "slack-beta-link-shared"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDB"
        Effect = "Allow"
        Action = "dynamodb:Query"
        Resource = [
          aws_dynamodb_table.table.arn,
          "${aws_dynamodb_table.table.arn}/index/Chrono",
        ]
      },
      {
        Sid    = "Lambda"
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          data.terraform_remote_state.functions.outputs.functions.http.arn,
          data.terraform_remote_state.functions.outputs.functions.slack_link_unfurl.arn,
        ]
      }
    ]
  })

  variables = {
    http_function_arn     = data.terraform_remote_state.functions.outputs.functions.http.arn
    slack_link_unfurl_arn = data.terraform_remote_state.functions.outputs.functions.slack_link_unfurl.arn
    table_name            = aws_dynamodb_table.table.name
  }
}

##########################
#   SLACK BETA REFRESH   #
##########################

module "slack_beta_refresh_home" {
  source = "./state-machine"
  name   = "slack-beta-refresh-home"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = "dynamodb:Query"
        Resource = "${aws_dynamodb_table.table.arn}/index/Chrono"
      },
      {
        Sid      = "EventBridge"
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = data.terraform_remote_state.events.outputs.event_bus.arn
      },
      {
        Sid    = "Lambda"
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          data.terraform_remote_state.functions.outputs.functions.http.arn,
          data.terraform_remote_state.functions.outputs.functions.slack_beta_home.arn,
        ]
      }
    ]
  })

  variables = {
    slack_beta_home_function_arn = data.terraform_remote_state.functions.outputs.functions.slack_beta_home.arn
    http_function_arn            = data.terraform_remote_state.functions.outputs.functions.http.arn
    event_bus_name               = data.terraform_remote_state.events.outputs.event_bus.name
    table_name                   = aws_dynamodb_table.table.name
  }
}

#####################
#   SLACK INSTALL   #
#####################

module "slack_install" {
  source = "./state-machine"
  name   = "slack-install"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDB"
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:Query"]
        Resource = [
          aws_dynamodb_table.table.arn,
          "${aws_dynamodb_table.table.arn}/index/Chrono",
        ]
      },
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = data.terraform_remote_state.functions.outputs.functions.slack_transform.arn
      },
      {
        Sid      = "EventBridge"
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = data.terraform_remote_state.events.outputs.event_bus.arn
      }
    ]
  })

  variables = {
    event_bus_name               = data.terraform_remote_state.events.outputs.event_bus.name
    slack_transform_function_arn = data.terraform_remote_state.functions.outputs.functions.slack_transform.arn
    table_name                   = aws_dynamodb_table.table.name
  }
}

##################
#   SLACK POST   #
##################

module "slack_post" {
  source = "./state-machine"
  name   = "slack-post"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = "dynamodb:Query"
        Resource = "${aws_dynamodb_table.table.arn}/index/Chrono"
      },
      {
        Sid      = "EventBridge"
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = data.terraform_remote_state.events.outputs.event_bus.arn
      },
      {
        Sid      = "States"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = "*"
      }
    ]
  })

  variables = {
    app_id                       = local.apps.prod
    event_bus_name               = data.terraform_remote_state.events.outputs.event_bus.name
    slack_transform_function_arn = data.terraform_remote_state.functions.outputs.functions.slack_transform.arn
    table_name                   = aws_dynamodb_table.table.name
  }
}

##########################
#   SLACK POST CHANNEL   #
##########################

module "slack_post_channel" {
  source = "./state-machine"
  name   = "slack-post-channel"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.table.arn
      },
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = data.terraform_remote_state.functions.outputs.functions.http.arn
      }
    ]
  })

  variables = {
    http_function_arn = data.terraform_remote_state.functions.outputs.functions.http.arn
    table_name        = aws_dynamodb_table.table.name
  }
}

#######################
#   SLACK UNINSTALL   #
#######################

module "slack_uninstall" {
  source = "./state-machine"
  name   = "slack-uninstall"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDB"
        Effect = "Allow"
        Action = ["dynamodb:BatchWriteItem", "dynamodb:Query", ]
        Resource = [
          "${aws_dynamodb_table.table.arn}",
          "${aws_dynamodb_table.table.arn}/index/SlackTeam",
        ]
      },
      {
        Sid      = "States"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = "*"
      }
    ]
  })

  variables = {
    table_name = aws_dynamodb_table.table.name
  }
}

############################
#   STATE MACHINE ERRORS   #
############################

module "state_machine_errors" {
  source = "./state-machine"
  name   = "state-machine-errors"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = "dynamodb:GetItem"
        Resource = aws_dynamodb_table.table.arn
      },
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = data.terraform_remote_state.functions.outputs.functions.http.arn
      }
    ]
  })

  variables = {
    app_id            = local.apps.beta
    team_id           = local.team_id
    conversation_id   = local.conversations.messages
    http_function_arn = data.terraform_remote_state.functions.outputs.functions.http.arn
    table_name        = aws_dynamodb_table.table.name
  }
}

####################
#   TWITTER POST   #
####################

module "twitter_post" {
  source = "./state-machine"
  name   = "twitter-post"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.table.arn
      },
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = data.terraform_remote_state.functions.outputs.functions.twitter_post.arn
      }
    ]
  })

  variables = {
    table_name                = aws_dynamodb_table.table.name
    twitter_post_function_arn = data.terraform_remote_state.functions.outputs.functions.twitter_post.arn
  }
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
        Sid    = "DynamoDB"
        Effect = "Allow"
        Action = "dynamodb:Query"
        Resource = [
          "${aws_dynamodb_table.table.arn}",
          "${aws_dynamodb_table.table.arn}/index/Chrono",
        ]
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

###############
#   OUTPUTS   #
###############

output "state_machines" {
  value = {
    for key, val in {
      reddit_dequeue            = module.reddit_dequeue.state_machine
      reddit_post               = module.reddit_post.state_machine
      reddit_reject             = module.reddit_reject.state_machine
      reddit_screen             = module.reddit_screen.state_machine
      slack_beta_enable_disable = module.slack_beta_enable_disable.state_machine
      slack_beta_link_shared    = module.slack_beta_link_shared.state_machine
      slack_beta_refresh_home   = module.slack_beta_refresh_home.state_machine
      slack_install             = module.slack_install.state_machine
      slack_post                = module.slack_post.state_machine
      slack_post_channel        = module.slack_post_channel.state_machine
      slack_uninstall           = module.slack_uninstall.state_machine
      state_machine_errors      = module.state_machine_errors.state_machine
      twitter_post              = module.twitter_post.state_machine
    } : key => { arn : val.arn, name : val.name }
  }
}
