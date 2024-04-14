############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name

  app  = basename(path.module)
  name = terraform.workspace

  tags = {
    "brutalismbot:app" = local.app
  }
}

#################
#   EVENT BUS   #
#################

resource "aws_cloudwatch_event_bus" "bus" {
  name = local.name
  tags = local.tags
}

#################
#   SCHEDULER   #
#################

resource "aws_scheduler_schedule_group" "group" {
  name = local.name
  tags = local.tags
}

#############
#   TABLE   #
#############

resource "aws_dynamodb_table" "table" {
  name = local.name
  tags = local.tags

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
  tags = local.tags

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

resource "aws_pipes_pipe" "pipes" {
  description = "Pipe DynamoDB streams to EventBridge"
  name        = local.name
  role_arn    = aws_iam_role.pipes.arn
  source      = aws_dynamodb_table.table.stream_arn
  target      = aws_cloudwatch_event_bus.bus.arn
  tags        = local.tags
}

#################
#   FUNCTIONS   #
#################

module "http" { source = "./http" }
