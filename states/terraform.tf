#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  cloud {
    organization = "brutalismbot"

    workspaces { name = "states" }
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
    organization = "brutalismbot"

    workspaces = { name = "events" }
  }
}

data "terraform_remote_state" "functions" {
  backend = "remote"

  config = {
    organization = "brutalismbot"

    workspaces = { name = "functions" }
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
  tags = {
    "terraform:organization" = "brutalismbot"
    "terraform:workspace"    = "states"
    "git:repo"               = "brutalismbot/states"
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

data "aws_iam_policy_document" "mail" {
  statement {
    sid       = "SendEmail"
    actions   = ["ses:SendRawEmail"]
    resources = ["*"]
  }
}

module "mail" {
  source = "./state-machine"

  name   = "mail"
  policy = data.aws_iam_policy_document.mail.json
}

######################
#   REDDIT DEQUEUE   #
######################

data "aws_iam_policy_document" "reddit_dequeue" {
  statement {
    sid       = "CloudWatch"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  statement {
    sid       = "EventBridge"
    actions   = ["events:PutEvents"]
    resources = [data.terraform_remote_state.events.outputs.event_bus.arn]
  }

  statement {
    sid       = "Lambda"
    actions   = ["lambda:InvokeFunction"]
    resources = [data.terraform_remote_state.functions.outputs.functions.reddit_dequeue.arn]
  }
}

module "reddit_dequeue" {
  source = "./state-machine"

  name   = "reddit-dequeue"
  policy = data.aws_iam_policy_document.reddit_dequeue.json

  variables = {
    cloudwatch_namespace = "Brutalismbot"
    event_bus_name       = data.terraform_remote_state.events.outputs.event_bus.name
    reddit_dequeue_arn   = data.terraform_remote_state.functions.outputs.functions.reddit_dequeue.arn
  }
}

###################
#   REDDIT POST   #
###################

data "aws_iam_policy_document" "reddit_post" {
  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.table.arn]
  }

  statement {
    sid       = "EventBridge"
    actions   = ["events:PutEvents"]
    resources = [data.terraform_remote_state.events.outputs.event_bus.arn]
  }

  statement {
    sid     = "Lambda"
    actions = ["lambda:InvokeFunction"]

    resources = [
      data.terraform_remote_state.functions.outputs.functions.slack_transform.arn,
      data.terraform_remote_state.functions.outputs.functions.twitter_transform.arn,
    ]
  }
}

module "reddit_post" {
  source = "./state-machine"

  name   = "reddit-post"
  policy = data.aws_iam_policy_document.reddit_post.json

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

data "aws_iam_policy_document" "reddit_reject" {
  statement {
    sid       = "Lambda"
    actions   = ["lambda:InvokeFunction"]
    resources = [data.terraform_remote_state.functions.outputs.functions.http.arn]
  }

  statement {
    sid       = "States"
    actions   = ["states:StopExecution"]
    resources = ["*"]
  }
}

module "reddit_reject" {
  source = "./state-machine"

  name   = "reddit-reject"
  policy = data.aws_iam_policy_document.reddit_reject.json

  variables = {
    http_function_arn = data.terraform_remote_state.functions.outputs.functions.http.arn
  }
}

#####################
#   REDDIT SCREEN   #
#####################

data "aws_iam_policy_document" "reddit_screen" {
  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem"]
    resources = [aws_dynamodb_table.table.arn]
  }

  statement {
    sid     = "Lambda"
    actions = ["lambda:InvokeFunction"]

    resources = [
      data.terraform_remote_state.functions.outputs.functions.array.arn,
      data.terraform_remote_state.functions.outputs.functions.http.arn,
    ]
  }
}

module "reddit_screen" {
  source = "./state-machine"

  name   = "reddit-screen"
  policy = data.aws_iam_policy_document.reddit_screen.json

  variables = {
    array_function_arn = data.terraform_remote_state.functions.outputs.functions.array.arn
    http_function_arn  = data.terraform_remote_state.functions.outputs.functions.http.arn
    table_name         = aws_dynamodb_table.table.name
    wait_time_seconds  = var.wait_time_seconds
  }
}

#################################
#   SLACK BETA ENABLE DISABLE   #
#################################

data "aws_iam_policy_document" "slack_beta_enable_disable" {
  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:Query"]
    resources = ["${aws_dynamodb_table.table.arn}/index/Chrono"]
  }

  statement {
    sid = "EventBridge"

    actions = [
      "events:DescribeRule",
      "events:DisableRule",
      "events:EnableRule",
      "events:PutEvents",
    ]

    resources = [
      data.terraform_remote_state.events.outputs.event_bus.arn,
      data.terraform_remote_state.events.outputs.rules.reddit_dequeue.arn,
    ]
  }

  statement {
    sid       = "Lambda"
    actions   = ["lambda:InvokeFunction"]
    resources = [data.terraform_remote_state.functions.outputs.functions.http.arn]
  }
}

module "slack_beta_enable_disable" {
  source = "./state-machine"

  name   = "slack-beta-enable-disable"
  policy = data.aws_iam_policy_document.slack_beta_enable_disable.json

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

data "aws_iam_policy_document" "slack_beta_link_shared" {
  statement {
    sid     = "DynamoDB"
    actions = ["dynamodb:Query"]

    resources = [
      aws_dynamodb_table.table.arn,
      "${aws_dynamodb_table.table.arn}/index/Chrono",
    ]
  }

  statement {
    sid     = "Lambda"
    actions = ["lambda:InvokeFunction"]
    resources = [
      data.terraform_remote_state.functions.outputs.functions.http.arn,
      data.terraform_remote_state.functions.outputs.functions.slack_link_unfurl.arn,
    ]
  }
}

module "slack_beta_link_shared" {
  source = "./state-machine"

  name   = "slack-beta-link-shared"
  policy = data.aws_iam_policy_document.slack_beta_link_shared.json

  variables = {
    http_function_arn     = data.terraform_remote_state.functions.outputs.functions.http.arn
    slack_link_unfurl_arn = data.terraform_remote_state.functions.outputs.functions.slack_link_unfurl.arn
    table_name            = aws_dynamodb_table.table.name
  }
}

##########################
#   SLACK BETA REFRESH   #
##########################

data "aws_iam_policy_document" "slack_beta_refresh_home" {
  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:Query"]
    resources = ["${aws_dynamodb_table.table.arn}/index/Chrono"]
  }

  statement {
    sid       = "EventBridge"
    actions   = ["events:PutEvents"]
    resources = [data.terraform_remote_state.events.outputs.event_bus.arn]
  }

  statement {
    sid     = "Lambda"
    actions = ["lambda:InvokeFunction"]

    resources = [
      data.terraform_remote_state.functions.outputs.functions.http.arn,
      data.terraform_remote_state.functions.outputs.functions.slack_beta_home.arn,
    ]
  }
}

module "slack_beta_refresh_home" {
  source = "./state-machine"

  name   = "slack-beta-refresh-home"
  policy = data.aws_iam_policy_document.slack_beta_refresh_home.json

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

data "aws_iam_policy_document" "slack_install" {
  statement {
    sid     = "DynamoDB"
    actions = ["dynamodb:PutItem", "dynamodb:Query"]

    resources = [
      aws_dynamodb_table.table.arn,
      "${aws_dynamodb_table.table.arn}/index/Chrono",
    ]
  }

  statement {
    sid       = "Lambda"
    actions   = ["lambda:InvokeFunction"]
    resources = [data.terraform_remote_state.functions.outputs.functions.slack_transform.arn]
  }

  statement {
    sid       = "EventBridge"
    actions   = ["events:PutEvents"]
    resources = [data.terraform_remote_state.events.outputs.event_bus.arn]
  }
}

module "slack_install" {
  source = "./state-machine"

  name   = "slack-install"
  policy = data.aws_iam_policy_document.slack_install.json

  variables = {
    event_bus_name               = data.terraform_remote_state.events.outputs.event_bus.name
    slack_transform_function_arn = data.terraform_remote_state.functions.outputs.functions.slack_transform.arn
    table_name                   = aws_dynamodb_table.table.name
  }
}

##################
#   SLACK POST   #
##################

data "aws_iam_policy_document" "slack_post" {
  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:Query"]
    resources = ["${aws_dynamodb_table.table.arn}/index/Chrono"]
  }

  statement {
    sid       = "EventBridge"
    actions   = ["events:PutEvents"]
    resources = [data.terraform_remote_state.events.outputs.event_bus.arn]
  }

  statement {
    sid       = "States"
    actions   = ["states:StartExecution"]
    resources = ["*"]
  }
}

module "slack_post" {
  source = "./state-machine"

  name   = "slack-post"
  policy = data.aws_iam_policy_document.slack_post.json

  variables = {
    event_bus_name               = data.terraform_remote_state.events.outputs.event_bus.name
    slack_transform_function_arn = data.terraform_remote_state.functions.outputs.functions.slack_transform.arn
    table_name                   = aws_dynamodb_table.table.name
  }
}

##########################
#   SLACK POST CHANNEL   #
##########################

data "aws_iam_policy_document" "slack_post_channel" {
  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.table.arn]
  }

  statement {
    sid       = "Lambda"
    actions   = ["lambda:InvokeFunction"]
    resources = [data.terraform_remote_state.functions.outputs.functions.http.arn]
  }
}

module "slack_post_channel" {
  source = "./state-machine"

  name   = "slack-post-channel"
  policy = data.aws_iam_policy_document.slack_post_channel.json

  variables = {
    http_function_arn = data.terraform_remote_state.functions.outputs.functions.http.arn
    table_name        = aws_dynamodb_table.table.name
  }
}

#######################
#   SLACK UNINSTALL   #
#######################

data "aws_iam_policy_document" "slack_uninstall" {
  statement {
    sid     = "DynamoDB"
    actions = ["dynamodb:BatchWriteItem", "dynamodb:Query"]

    resources = [
      aws_dynamodb_table.table.arn,
      "${aws_dynamodb_table.table.arn}/index/SlackTeam"
    ]
  }

  statement {
    sid       = "States"
    actions   = ["states:StartExecution"]
    resources = ["*"]
  }
}

module "slack_uninstall" {
  source = "./state-machine"

  name   = "slack-uninstall"
  policy = data.aws_iam_policy_document.slack_uninstall.json

  variables = {
    table_name = aws_dynamodb_table.table.name
  }
}

####################
#   TWITTER POST   #
####################

data "aws_iam_policy_document" "twitter_post" {
  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.table.arn]
  }

  statement {
    sid       = "Lambda"
    actions   = ["lambda:InvokeFunction"]
    resources = [data.terraform_remote_state.functions.outputs.functions.twitter_post.arn]
  }
}

module "twitter_post" {
  source = "./state-machine"

  name   = "twitter-post"
  policy = data.aws_iam_policy_document.twitter_post.json

  variables = {
    table_name                = aws_dynamodb_table.table.name
    twitter_post_function_arn = data.terraform_remote_state.functions.outputs.functions.twitter_post.arn
  }
}

###############
#   OUTPUTS   #
###############

output "state_machines" {
  value = {
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
    twitter_post              = module.twitter_post.state_machine
  }
}
