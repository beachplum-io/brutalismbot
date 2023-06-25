##############
#   LOCALS   #
##############

locals {
  name    = "brutalismbot-${var.env}-${var.app}-create-posts"
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
  is_enabled     = true
  name           = local.name
  tags           = var.tags

  event_pattern = jsonencode({
    source      = ["Pipe brutalismbot-${var.env}-shared-streams"]
    detail-type = ["Event from aws:dynamodb"]
    detail = {
      eventName = ["MODIFY"]
      dynamodb = {
        Keys     = { Kind = { S = ["reddit/post"] } }
        NewImage = { Status = { S = ["Approved"] } }
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
      Id        = "$.detail.dynamodb.Keys.Id.S"
      Title     = "$.detail.dynamodb.NewImage.Title.S"
      Media     = "$.detail.dynamodb.NewImage.Media.S"
      Name      = "$.detail.dynamodb.NewImage.Name.S"
      Permalink = "$.detail.dynamodb.NewImage.Permalink.S"
    }
    input_template = <<-JSON
      {
        "Query": {
          "TableName": "${data.aws_dynamodb_table.table.name}",
          "IndexName": "Kind",
          "KeyConditionExpression": "Kind=:Kind AND begins_with(Id,:IdPrefix)",
          "FilterExpression": "Enabled=:Enabled",
          "ProjectionExpression": "AccessToken,AppId,ChannelId,ChannelName,#Scope,TeamId,TeamName,UserId,WebhookUrl",
          "ExpressionAttributeNames": {"#Scope": "Scope"},
          "ExpressionAttributeValues": {
            ":Enabled": {"Bool": true },
            ":Kind": {"S": "slack/token"},
            ":IdPrefix": {"S": "AH0KW28C9/"}
          },
          "ExclusiveStartKey": null,
          "Limit": 25
        },
        "Post": {
          "Title": <Title>,
          "Media": <Media>,
          "Name": <Name>,
          "Permalink": <Permalink>
        }
      }
    JSON
  }
}

##############
#   LAMBDA   #
##############

data "archive_file" "lambda" {
  excludes    = ["package.zip"]
  source_dir  = "${path.module}/lib"
  output_path = "${path.module}/lib/package.zip"
  type        = "zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_iam_role" "lambda" {
  name = "${local.region}-${local.name}-lambda"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Sid       = "AssumeLambda"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "*"
      }
    })
  }
}

resource "aws_lambda_function" "lambda" {
  architectures    = ["arm64"]
  description      = "Create bluesky post item"
  filename         = data.archive_file.lambda.output_path
  function_name    = local.name
  handler          = "index.get_post"
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby3.2"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags             = var.tags
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
          Resource = aws_lambda_function.lambda.arn
        },
        {
          Sid      = "PutItem"
          Effect   = "Allow"
          Action   = "dynamodb:PutItem"
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
  tags     = var.tags

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.yml", {
    create_post_arn = aws_lambda_function.lambda.arn
    table_name      = data.aws_dynamodb_table.table.name
  })))
}
