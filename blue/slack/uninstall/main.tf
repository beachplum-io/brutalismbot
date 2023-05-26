##############
#   LOCALS   #
##############

locals {
  name    = "brutalismbot-${var.env}-${var.app}-uninstall"
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_cloudwatch_event_bus" "bus" {
  name = "brutalismbot"
}

data "aws_dynamodb_table" "table" {
  name = "brutalismbot-${var.env}"
}

data "aws_secretsmanager_secret" "secret" {
  name = "brutalismbot"
}

##############
#   EVENTS   #
##############

resource "aws_iam_role" "events" {
  name = "${local.region}-${local.name}-events"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "events.amazonaws.com" }
    }
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = {
        Sid      = "StartExecution"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.states.arn
      }
    })
  }
}

resource "aws_cloudwatch_event_rule" "events" {
  description    = "Handle Slack installation events"
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  is_enabled     = true
  name           = local.name

  event_pattern = jsonencode({
    source      = ["slack", "slack/beta"]
    detail-type = ["POST /events"]

    detail = {
      type  = ["event_callback"]
      event = { type = ["app_uninstalled"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "events" {
  arn            = aws_sfn_state_machine.states.arn
  event_bus_name = aws_cloudwatch_event_rule.events.event_bus_name
  role_arn       = aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.events.name
  target_id      = "state-machine"

  input_transformer {
    input_paths = {
      AppId     = "$.detail.api_app_id"
      TeamId    = "$.detail.team_id"
      EventTime = "$.detail.event_time"
    }
    input_template = <<-JSON
      {
        "EventTime": <EventTime>,
        "Query": {
          "TableName": "${data.aws_dynamodb_table.table.name}",
          "IndexName": "Kind",
          "KeyConditionExpression": "Kind=:Kind AND begins_with(Id,:IdPrefix)",
          "ProjectionExpression": "Id,Kind",
          "ExclusiveStartKey": null,
          "ExpressionAttributeValues": {
            ":Kind": { "S": "slack/token" },
            ":IdPrefix": { "S": "<AppId>/<TeamId>/" }
          }
        }
      }
    JSON
  }
}

#####################
#   STATE MACHINE   #
#####################

resource "aws_iam_role" "states" {
  name = "${local.region}-${local.name}-states"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeStates"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "states.amazonaws.com" }
    }
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "UpdateItem"
          Effect   = "Allow"
          Action   = "dynamodb:UpdateItem"
          Resource = data.aws_dynamodb_table.table.arn
        },
        {
          Sid      = "QueryKind"
          Effect   = "Allow"
          Action   = "dynamodb:Query"
          Resource = "${data.aws_dynamodb_table.table.arn}/index/Kind"
        },
        {
          Sid      = "StartSelf"
          Effect   = "Allow"
          Action   = "states:StartExecution"
          Resource = "arn:aws:states:${local.region}:${local.account}:stateMachine:${local.name}"
        }
      ]
    })
  }
}

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yaml", {
    table_name = data.aws_dynamodb_table.table.name
  })))
}
