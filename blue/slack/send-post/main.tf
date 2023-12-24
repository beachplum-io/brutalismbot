##############
#   LOCALS   #
##############

locals {
  name    = "brutalismbot-${var.env}-${var.app}-send-post"
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.name
}

############
#   DATA   #
############

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_cloudwatch_event_bus" "bus" {
  name = "brutalismbot-${var.env}"
}

data "aws_dynamodb_table" "table" {
  name = "brutalismbot-${var.env}"
}

data "aws_lambda_function" "http" {
  function_name = "brutalismbot-${var.env}-shared-http"
}

##############
#   EVENTS   #
##############

resource "aws_iam_role" "events" {
  name = "${local.region}-${local.name}-events"
  tags = var.tags

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
  description    = "Capture approved reddit posts to send to Slack"
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  name           = local.name
  state          = "ENABLED"
  tags           = var.tags

  event_pattern = jsonencode({
    source      = ["Pipe brutalismbot-${var.env}"]
    detail-type = ["Event from aws:dynamodb"]
    detail = {
      eventName = ["INSERT"]
      dynamodb = {
        Keys = { Kind = { S = ["slack/post"] } }
        # NewImage = { TeamId = { S = ["THAQ99JLW"] } } # Remove this
      }
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
      Id      = "$.detail.dynamodb.Keys.Id.S"
      Kind    = "$.detail.dynamodb.Keys.Kind.S"
      Request = "$.detail.dynamodb.NewImage.Request.S"
    }
    input_template = <<-JSON
      {
        "Id": <Id>,
        "Kind": <Kind>,
        "Request": <Request>
      }
    JSON
  }
}

#####################
#   STATE MACHINE   #
#####################

resource "aws_iam_role" "states" {
  name = "${local.region}-${local.name}-states"
  tags = var.tags

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
          Sid      = "InvokeFunction"
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = data.aws_lambda_function.http.arn
        },
        {
          Sid      = "UpdateItem"
          Effect   = "Allow"
          Action   = "dynamodb:UpdateItem"
          Resource = data.aws_dynamodb_table.table.arn
        }
      ]
    })
  }
}

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn
  tags     = var.tags

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yml", {
    http_function_arn = data.aws_lambda_function.http.arn
    table_name        = data.aws_dynamodb_table.table.name
  })))
}
