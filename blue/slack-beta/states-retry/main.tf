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

data "aws_lambda_function" "http" {
  function_name = "${terraform.workspace}-shared-http"
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
      Resource = aws_sfn_state_machine.states.arn
    }
  })
}


resource "aws_cloudwatch_event_rule" "events" {
  description    = "Reject post for republishing"
  event_bus_name = data.aws_cloudwatch_event_bus.bus.name
  name           = local.name
  state          = "ENABLED"
  tags           = local.tags

  event_pattern = jsonencode({
    source      = ["slack/beta"]
    detail-type = ["POST /callbacks"]

    detail = {
      type    = ["block_actions"]
      actions = { action_id = ["retry"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "events" {
  arn            = aws_sfn_state_machine.states.arn
  event_bus_name = aws_cloudwatch_event_rule.events.event_bus_name
  role_arn       = aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.events.name
  target_id      = "state-machine"
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
        Sid      = "PostSlack"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = data.aws_lambda_function.http.arn
      },
      {
        Sid      = "DescribeExecution"
        Effect   = "Allow"
        Action   = "states:DescribeExecution"
        Resource = "arn:aws:states:${local.region}:${local.account}:execution:${terraform.workspace}-*"
      },
      {
        Sid      = "StartExecution"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = "arn:aws:states:${local.region}:${local.account}:stateMachine:${terraform.workspace}-*",
      }
    ]
  })
}


resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn
  tags     = local.tags

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yml", {
    http_function_arn = data.aws_lambda_function.http.arn
  })))
}
