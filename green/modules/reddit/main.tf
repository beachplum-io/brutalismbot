##############
#   LOCALS   #
##############

locals {
  enabled = true

  region = data.aws_region.current.region

  app  = basename(path.module)
  name = "${terraform.workspace}-${local.app}"
  tags = { "brutalismbot:app" = local.app }

  state_machines = {
    accept-auto = "STANDARD"
    accept      = "STANDARD"
    reject      = "STANDARD"
    screen      = "STANDARD"
  }
}

############
#   DATA   #
############

data "aws_region" "current" {
}

data "aws_cloudwatch_event_bus" "bus" {
  name = terraform.workspace
}

data "aws_cloudwatch_event_connection" "slack" {
  name = "${terraform.workspace}-slack-beta-api"
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
      Sid       = "AssumeEvents"
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
      Resource = values(aws_sfn_state_machine.states).*.arn
    }
  })
}

resource "aws_cloudwatch_event_rule" "events" {
  for_each = {
    accept-auto = {
      description = "Auto-accept Reddit screener"
      event_pattern = {
        source      = ["Pipe ${terraform.workspace}"]
        detail-type = ["Event from aws:dynamodb"]
        detail = {
          eventName = ["REMOVE"]
          dynamodb = {
            Keys     = { Kind = { S = ["reddit.post.screener"] } }
            OldImage = { TTL = { N = [{ exists = true }] } }
          }
        }
      }
    }

    accept = {
      description = "Accept Reddit screener"
      event_pattern = {
        source      = ["api.brutalismbot.com/slack/beta"]
        detail-type = ["POST /callbacks"]

        detail = {
          type    = ["block_actions"]
          actions = { action_id = ["reddit_screen_accept"] }
        }
      }
    }

    reject = {
      description = "Reject Reddit screener"
      event_pattern = {
        source      = ["api.brutalismbot.com/slack/beta"]
        detail-type = ["POST /callbacks"]

        detail = {
          type    = ["block_actions"]
          actions = { action_id = ["reddit_screen_reject"] }
        }
      }
    }
  }

  description    = each.value.description
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  event_pattern  = jsonencode(each.value.event_pattern)
  name           = "${local.name}-${each.key}"
  state          = local.enabled ? "ENABLED" : "DISABLED"
  tags           = local.tags
}

resource "aws_cloudwatch_event_target" "events" {
  for_each = aws_cloudwatch_event_rule.events

  arn            = aws_sfn_state_machine.states[each.key].arn
  input_path     = "$.detail"
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  role_arn       = aws_iam_role.events.arn
  rule           = each.value.name
  target_id      = each.key
}

#################
#   SCHEDULER   #
#################

resource "aws_iam_role" "scheduler" {
  name = "${local.region}-${local.name}-scheduler"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeScheduler"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "scheduler.amazonaws.com" }
    }
  })
}

resource "aws_iam_role_policy" "scheduler" {
  name = "access"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid      = "StartExecution"
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.states["screen"].arn
    }
  })
}

resource "aws_scheduler_schedule" "scheduler" {
  name                = local.name
  group_name          = terraform.workspace
  schedule_expression = "rate(1 hour)"
  state               = local.enabled ? "ENABLED" : "DISABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_sfn_state_machine.states["screen"].arn
    role_arn = aws_iam_role.scheduler.arn
  }
}

######################
#   STATE MACHINES   #
######################

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
        Sid    = "DynamoDB"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
        ]
        Resource = [
          data.aws_dynamodb_table.table.arn,
          "${data.aws_dynamodb_table.table.arn}/index/Kind",
        ]
      },
      {
        Sid      = "InvokeHttp"
        Effect   = "Allow"
        Action   = "states:InvokeHTTPEndpoint"
        Resource = "*"
        Condition = {
          StringEquals = { "states:HTTPMethod" = ["GET", "POST"] }
          StringLike   = { "states:HTTPEndpoint" = ["https://slack.com/api/*", "https://*.slack.com/*"] }
        }
      },
      {
        Sid      = "GetConnection"
        Effect   = "Allow"
        Action   = "events:RetrieveConnectionCredentials"
        Resource = data.aws_cloudwatch_event_connection.slack.arn
      },
      {
        Sid      = "GetSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue"]
        Resource = data.aws_cloudwatch_event_connection.slack.secret_arn
      }
    ]
  })
}

resource "aws_sfn_state_machine" "states" {
  for_each = local.state_machines

  name     = "${local.name}-${each.key}"
  role_arn = aws_iam_role.states.arn
  tags     = local.tags
  type     = each.value

  definition = jsonencode(yamldecode(templatefile("${path.module}/state-machines/${each.key}.asl.yml", {
    connection_arn = data.aws_cloudwatch_event_connection.slack.arn
    table_name     = data.aws_dynamodb_table.table.name
  })))
}
