#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  # cloud {
  #   organization = "beachplum"

  #   workspaces { name = "brutalismbot-blue-shared" }
  # }

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.3"
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

variable "AWS_ROLE_ARN" {}
provider "aws" {
  region = "us-west-2"
  assume_role { role_arn = var.AWS_ROLE_ARN }
  default_tags { tags = local.tags }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#################
#   VARIABLES   #
#################


##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name

  env  = "blue"
  app  = "shared"
  name = "brutalismbot-${local.env}"

  tags = {
    "brutalismbot:env"       = "blue"
    "brutalismbot:app"       = "shared"
    "terraform:organization" = "beachplum"
    "terraform:workspace"    = "brutalismbot-blue-shared"
    "git:repo"               = "beachplum-io/brutalismbot"
  }
}

#################
#   EVENT BUS   #
#################

resource "aws_cloudwatch_event_bus" "bus" {
  name = local.name
}

#################
#   SCHEDULER   #
#################

resource "aws_scheduler_schedule_group" "group" {
  name = local.name
}

#############
#   TABLE   #
#############

resource "aws_dynamodb_table" "table" {
  name = local.name

  hash_key  = "Id"
  range_key = "Kind"

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  billing_mode   = "PAY_PER_REQUEST"
  read_capacity  = 0
  write_capacity = 0

  attribute {
    name = "Id"
    type = "S"
  }

  attribute {
    name = "Kind"
    type = "S"
  }

  ttl {
    attribute_name = "TTL"
    enabled        = true
  }

  global_secondary_index {
    name            = "Kind"
    hash_key        = "Kind"
    range_key       = "Id"
    projection_type = "ALL"
    read_capacity   = 0
    write_capacity  = 0
  }
}

resource "aws_dynamodb_table_item" "cursor" {
  table_name = aws_dynamodb_table.table.name
  hash_key   = aws_dynamodb_table.table.hash_key
  range_key  = aws_dynamodb_table.table.range_key

  item = jsonencode({
    Id                 = { S = "/r/brutalism" }
    Kind               = { S = "cursor" }
    ExclusiveStartTime = { S = "1970-01-01:00:00:00Z" }
  })

  lifecycle {
    ignore_changes = [item]
  }
}

#############
#   PIPES   #
#############

resource "aws_iam_role" "pipes" {
  name = "${local.region}-${local.name}-shared-pipes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "pipes.amazonaws.com" }
    }
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "DynamoDBListStreams"
          Effect   = "Allow"
          Action   = "dynamodb:ListStreams"
          Resource = "*"
        },
        {
          Sid      = "DynamoDBStreams"
          Effect   = "Allow"
          Resource = aws_dynamodb_table.table.stream_arn
          Action = [
            "dynamodb:DescribeStream",
            "dynamodb:GetRecords",
            "dynamodb:GetShardIterator",
          ]
        },
        {
          Sid      = "PutEvents"
          Effect   = "Allow"
          Action   = "events:PutEvents"
          Resource = aws_cloudwatch_event_bus.bus.arn
        }
      ]
    })
  }
}

#################
#   FUNCTIONS   #
#################

module "functions" {
  for_each = yamldecode(file("./functions/functions.yaml"))
  source   = "./functions"
  env      = local.env
  app      = local.app
  name     = each.key
  data     = each.value
}
