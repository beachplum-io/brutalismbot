##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name

  app        = dirname(path.module)
  name       = "${terraform.workspace}-${local.app}-${basename(path.module)}"
  param_path = "/${replace(terraform.workspace, "-", "/")}/${local.app}/"
  tags       = { "brutalismbot:app" = local.app }
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_cloudwatch_event_bus" "bus" {
  name = terraform.workspace
}

data "aws_dynamodb_table" "table" {
  name = terraform.workspace
}

##############
#   EVENTS   #
##############

resource "aws_iam_role" "events" {
  name = "${local.region}-${local.name}-events"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "events.amazonaws.com" }
    }
  })
}

resource "aws_iam_role_policy" "events" {
  name = "access"
  role = aws_iam_role.events.id

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

resource "aws_cloudwatch_event_rule" "events" {
  description    = "Handle Slack installation events"
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  name           = local.name
  state          = "ENABLED"
  tags           = local.tags

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
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeStates"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "states.amazonaws.com" }
    }
  })
}

resource "aws_iam_role_policy" "states" {
  name = "access"
  role = aws_iam_role.states.id

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

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn
  tags     = local.tags

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yml", {
    table_name = data.aws_dynamodb_table.table.name
  })))
}
