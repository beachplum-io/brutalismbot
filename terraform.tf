terraform {
  required_version = "~> 1.0"

  backend "s3" {
    bucket = "brutalismbot"
    key    = "terraform/brutalismbot.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 3.38"
      configuration_aliases = [aws.v2]
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      App  = "Brutalismbot"
      Name = "Brutalismbot"
      Repo = "https://github.com/brutalismbot/brutalismbot"
    }
  }
}

locals {
  is_enabled = true

  tags = {
    App  = "core"
    Name = "brutalismbot"
    Repo = "https://github.com/brutalismbot/brutalismbot"
  }
}

# S3

resource "aws_s3_bucket" "brutalismbot" {
  acl           = "private"
  bucket        = "brutalismbot"
  force_destroy = false

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "brutalismbot" {
  bucket                  = aws_s3_bucket.brutalismbot.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DYNAMODB

resource "aws_dynamodb_table" "brutalismbot" {
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

# EVENTBRIDGE

resource "aws_cloudwatch_event_bus" "brutalismbot" {
  name = "brutalismbot"
}

# EVENTBRIDGE :: REDDIT DEQUEUE

resource "aws_cloudwatch_event_rule" "reddit_dequeue" {
  description         = "Dequeue next post from /r/brutalism"
  event_bus_name      = "default"
  is_enabled          = true
  name                = "brutalismbot-every-15m"
  schedule_expression = "rate(15 minutes)"
}

resource "aws_cloudwatch_event_target" "reddit_dequeue" {
  arn      = aws_sfn_state_machine.reddit_dequeue.id
  input    = jsonencode({})
  role_arn = aws_iam_role.events.arn
  rule     = aws_cloudwatch_event_rule.reddit_dequeue.name
}

# EVENTBRIDGE :: REDDIT POST

resource "aws_cloudwatch_event_rule" "reddit_post" {
  description    = "Handle new posts for Reddit"
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  is_enabled     = local.is_enabled
  name           = "reddit-post"

  event_pattern = jsonencode({
    source      = ["reddit"]
    detail-type = ["post"]
  })
}

resource "aws_cloudwatch_event_target" "reddit_post" {
  arn            = aws_sfn_state_machine.reddit_post.id
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  input_path     = "$.detail"
  role_arn       = aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.reddit_post.name
}

resource "aws_cloudwatch_event_target" "slack_post" {
  arn            = aws_sfn_state_machine.slack_post.id
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  input_path     = "$.detail"
  role_arn       = aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.reddit_post.name
}

resource "aws_cloudwatch_event_target" "twitter_post" {
  arn            = aws_sfn_state_machine.twitter_post.id
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  input_path     = "$.detail"
  role_arn       = aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.reddit_post.name
}

# EVENTBRIDGE :: SLACK POST AUTH

resource "aws_cloudwatch_event_rule" "reddit_post_slack" {
  description    = "Handle new posts for a Slack workspace"
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  is_enabled     = local.is_enabled
  name           = "reddit-post-slack"

  event_pattern = jsonencode({
    source      = ["reddit"]
    detail-type = ["post-slack"]
  })
}

resource "aws_cloudwatch_event_target" "reddit_post_slack" {
  arn            = aws_sfn_state_machine.slack_post_auth.id
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  input_path     = "$.detail"
  role_arn       = aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.reddit_post_slack.name
}

# EVENTBRIDGE :: SLACK INSTALL

resource "aws_cloudwatch_event_rule" "slack_install" {
  description    = "Slack install events"
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  is_enabled     = true
  name           = "slack-install"

  event_pattern = jsonencode({
    source      = ["slack"]
    detail-type = ["oauth"]
  })
}

resource "aws_cloudwatch_event_target" "slack_install" {
  arn            = aws_sfn_state_machine.slack_install.id
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  input_path     = "$.detail"
  role_arn       = aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.slack_install.name
}

# EVENTBRIDGE :: SLACK UNINSTALL

resource "aws_cloudwatch_event_rule" "slack_uninstall" {
  description    = "Slack uninstall events"
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  is_enabled     = true
  name           = "slack-uninstall"

  event_pattern = jsonencode({
    source      = ["slack"]
    detail-type = ["event"]
    detail      = { event = { type = ["app_uninstalled"] } }
  })
}

resource "aws_cloudwatch_event_target" "slack_uninstall" {
  arn            = aws_sfn_state_machine.slack_uninstall.id
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  input_path     = "$.detail"
  role_arn       = aws_iam_role.events.arn
  rule           = aws_cloudwatch_event_rule.slack_uninstall.name
}

# IAM :: EVENTS

data "aws_iam_policy_document" "trust_events" {
  statement {
    sid     = "AssumeEvents"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "access_events" {
  statement {
    sid     = "StatesStartExecution"
    actions = ["states:StartExecution"]

    resources = [
      aws_sfn_state_machine.reddit_dequeue.arn,
      aws_sfn_state_machine.reddit_post.arn,
      aws_sfn_state_machine.slack_install.arn,
      aws_sfn_state_machine.slack_post.arn,
      aws_sfn_state_machine.slack_post_auth.arn,
      aws_sfn_state_machine.slack_uninstall.arn,
      aws_sfn_state_machine.twitter_post.arn,
    ]
  }
}

resource "aws_iam_role" "events" {
  assume_role_policy = data.aws_iam_policy_document.trust_events.json
  name               = "brutalismbot-events"
}

resource "aws_iam_role_policy" "events" {
  name   = "access"
  policy = data.aws_iam_policy_document.access_events.json
  role   = aws_iam_role.events.name
}

# IAM :: LAMBDA

data "aws_kms_alias" "brutalismbot" { name = "alias/brutalismbot" }

data "aws_secretsmanager_secret" "twitter" { name = "brutalismbot/twitter" }

data "aws_iam_policy_document" "trust_lambda" {
  statement {
    sid     = "AssumeEvents"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "access_lambda" {
  statement {
    sid       = "CloudWatchPutMetricData"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:*"]
    resources = ["${aws_dynamodb_table.brutalismbot.arn}*"]
  }

  statement {
    sid       = "Logs"
    actions   = ["logs:*"]
    resources = ["*"]
  }

  statement {
    sid = "Secrets"

    actions = [
      "kms:Decrypt",
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      data.aws_kms_alias.brutalismbot.target_key_arn,
      data.aws_secretsmanager_secret.twitter.arn,
    ]
  }

  statement {
    sid       = "StatesSendTask"
    actions   = ["states:SendTask*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda" {
  assume_role_policy = data.aws_iam_policy_document.trust_lambda.json
  name               = "brutalismbot-lambda"
}

resource "aws_iam_role_policy" "lambda" {
  name   = "access"
  policy = data.aws_iam_policy_document.access_lambda.json
  role   = aws_iam_role.lambda.name
}

# IAM :: STATES

data "aws_iam_policy_document" "trust_states" {
  statement {
    sid     = "AssumeEvents"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "access_states" {
  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:*"]
    resources = ["${aws_dynamodb_table.brutalismbot.arn}*"]
  }

  statement {
    sid       = "EventBridge"
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.brutalismbot.arn]
  }

  statement {
    sid     = "Lambda"
    actions = ["lambda:InvokeFunction"]

    resources = [
      aws_lambda_function.dynamodb_query.arn,
      aws_lambda_function.reddit_dequeue.arn,
      aws_lambda_function.reddit_metrics.arn,
      aws_lambda_function.slack_post.arn,
      aws_lambda_function.twitter_post.arn,
    ]
  }
}

resource "aws_iam_role" "states" {
  assume_role_policy = data.aws_iam_policy_document.trust_states.json
  name               = "brutalismbot-states"
}

resource "aws_iam_role_policy" "states" {
  name   = "access"
  policy = data.aws_iam_policy_document.access_states.json
  role   = aws_iam_role.states.name
}

# LAMBDA FUNCTIONS

data "archive_file" "package" {
  output_path = "${path.module}/pkg/lambda.zip"
  source_dir  = "${path.module}/lib"
  type        = "zip"
}

# LAMBDA FUNCTIONS :: DYNAMODB QUERY

resource "aws_lambda_function" "dynamodb_query" {
  description      = "Execute query against DynamoDB Table"
  filename         = data.archive_file.package.output_path
  function_name    = "brutalismbot-dynamodb-query"
  handler          = "index.dynamodb_query"
  memory_size      = 512
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.package.output_base64sha256
  timeout          = 10
}

resource "aws_cloudwatch_log_group" "dynamodb_query" {
  name              = "/aws/lambda/${aws_lambda_function.dynamodb_query.function_name}"
  retention_in_days = 14
}

# LAMBDA FUNCTIONS :: REDDIT DEQUEUE

resource "aws_lambda_function" "reddit_dequeue" {
  description      = "Dequeue next post from /r/brutalism"
  filename         = data.archive_file.package.output_path
  function_name    = "brutalismbot-reddit-dequeue"
  handler          = "index.reddit_dequeue"
  memory_size      = 512
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.package.output_base64sha256
  timeout          = 10
}

resource "aws_cloudwatch_log_group" "reddit_dequeue" {
  name              = "/aws/lambda/${aws_lambda_function.reddit_dequeue.function_name}"
  retention_in_days = 14
}

# LAMBDA FUNCTIONS :: REDDIT METRICS

resource "aws_lambda_function" "reddit_metrics" {
  description      = "Publish Reddit metrics"
  filename         = data.archive_file.package.output_path
  function_name    = "brutalismbot-reddit-metrics"
  handler          = "index.reddit_metrics"
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.package.output_base64sha256
}

resource "aws_cloudwatch_log_group" "reddit_metrics" {
  name              = "/aws/lambda/${aws_lambda_function.reddit_metrics.function_name}"
  retention_in_days = 14
}

# LAMBDA FUNCTIONS :: SLACK POST

resource "aws_lambda_function" "slack_post" {
  description      = "Post to Slack workspace"
  filename         = data.archive_file.package.output_path
  function_name    = "brutalismbot-slack-post"
  handler          = "index.slack_post"
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.package.output_base64sha256
}

resource "aws_cloudwatch_log_group" "slack_post" {
  name              = "/aws/lambda/${aws_lambda_function.slack_post.function_name}"
  retention_in_days = 14
}

# LAMBDA FUNCTIONS :: TWITTER POST

data "aws_lambda_layer_version" "twitter" { layer_name = "twitter-ruby2-7" }

resource "aws_lambda_function" "twitter_post" {
  description      = "Post to Twitter"
  filename         = data.archive_file.package.output_path
  function_name    = "brutalismbot-twitter-post"
  handler          = "index.twitter_post"
  layers           = [data.aws_lambda_layer_version.twitter.arn]
  memory_size      = 512
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.package.output_base64sha256
  timeout          = 10
}

resource "aws_cloudwatch_log_group" "twitter_post" {
  name              = "/aws/lambda/${aws_lambda_function.twitter_post.function_name}"
  retention_in_days = 14
}

# STATE MACHINES :: REDDIT

resource "aws_sfn_state_machine" "reddit_dequeue" {
  name     = "brutalismbot-reddit-dequeue"
  role_arn = aws_iam_role.states.arn

  definition = jsonencode({
    StartAt = "DequeueNext"
    States = {
      DequeueNext = {
        Type     = "Task"
        Resource = aws_lambda_function.reddit_dequeue.arn
        Next     = "PutEventsAndMetrics"
      }
      PutEventsAndMetrics = {
        Type       = "Parallel"
        End        = true
        OutputPath = "$[0]"
        Branches = [
          {
            StartAt = "NextPost?"
            States = {
              "NextPost?" = {
                Type    = "Choice"
                Default = "Finish"
                Choices = [
                  {
                    Next      = "GetEvent"
                    Variable  = "$.NextPost"
                    IsPresent = true
                  }
                ]
              }
              GetEvent = {
                Type = "Pass"
                Next = "PutEvent"
                Parameters = {
                  EventBusName = aws_cloudwatch_event_bus.brutalismbot.name
                  Source       = "reddit"
                  DetailType   = "post"
                  Detail = {
                    "AWS_STEP_FUNCTIONS_STARTED_BY_EXECUTION_ID.$" = "$$.Execution.Id"
                    "CREATED_UTC.$"                                = "$.NextPost.CREATED_UTC"
                    "DATA.$"                                       = "$.NextPost.DATA"
                    "NAME.$"                                       = "$.NextPost.NAME"
                    "PERMALINK.$"                                  = "$.NextPost.PERMALINK"
                    "TITLE.$"                                      = "$.NextPost.TITLE"
                    "TTL.$"                                        = "States.JsonToString($.NextPost.TTL)"
                  }
                }
              }
              PutEvent = {
                Type       = "Task"
                Resource   = "arn:aws:states:::events:putEvents"
                End        = true
                Parameters = { "Entries.$" = "States.Array($)" }
              }
              Finish = { Type = "Succeed" }
            }
          },
          {
            StartAt = "SendMetrics"
            States = {
              SendMetrics = {
                Type     = "Task"
                Resource = aws_lambda_function.reddit_metrics.arn
                End      = true
                Parameters = {
                  namespace = "Brutalismbot"
                  metric_data = [
                    {
                      metric_name = "QueueSize"
                      unit        = "Count"
                      "value.$"   = "$.QueueSize"
                      dimensions = [
                        {
                          name  = "QueueName"
                          value = "/r/brutalism"
                        }
                      ]
                    }
                  ]
                }
              }
            }
          }
        ]
      }
    }
  })
}

resource "aws_sfn_state_machine" "reddit_post" {
  name     = "brutalismbot-reddit-post"
  role_arn = aws_iam_role.states.arn

  definition = jsonencode({
    StartAt = "GetItems"
    States = {
      GetItems = {
        Type = "Parallel"
        Next = "NewMaxCreatedUTC?"
        ResultSelector = {
          "Item.$"          = "$[0]"
          "MaxCreatedUTC.$" = "$[1]"
        }
        Branches = [
          {
            StartAt = "GetItem"
            States = {
              GetItem = {
                Type = "Pass"
                End  = true
                Parameters = {
                  SORT        = { "S" = "REDDIT/POST" }
                  GUID        = { "S.$" = "$.NAME" }
                  CREATED_UTC = { "S.$" = "$.CREATED_UTC" }
                  JSON        = { "S.$" = "States.JsonToString($.DATA)" }
                  NAME        = { "S.$" = "$.NAME" }
                  PERMALINK   = { "S.$" = "$.PERMALINK" }
                  TITLE       = { "S.$" = "$.TITLE" }
                  TTL         = { "N.$" = "$.TTL" }
                }
              }
            }
          },
          {
            StartAt = "GetMaxCreatedUTC"
            States = {
              GetMaxCreatedUTC = {
                Type       = "Task"
                Resource   = "arn:aws:states:::dynamodb:getItem"
                End        = true
                OutputPath = "$.Item.CREATED_UTC.S"
                Parameters = {
                  TableName            = aws_dynamodb_table.brutalismbot.name
                  ProjectionExpression = "CREATED_UTC"
                  Key = {
                    GUID = { S = "STATS/MAX" }
                    SORT = { S = "REDDIT/POST" }
                  }
                }
              }
            }
          }
        ]
      }
      "NewMaxCreatedUTC?" = {
        Type    = "Choice"
        Default = "InsertItem"
        Choices = [
          {
            Next               = "UpdateMaxCreatedUTC"
            Variable           = "$.MaxCreatedUTC"
            StringLessThanPath = "$.Item.CREATED_UTC.S"
          }
        ]
      }
      UpdateMaxCreatedUTC = {
        Type       = "Task"
        Resource   = "arn:aws:states:::dynamodb:updateItem"
        Next       = "InsertItem"
        ResultPath = "$.MaxCreatedUTC"
        Parameters = {
          TableName                = aws_dynamodb_table.brutalismbot.name
          UpdateExpression         = "SET CREATED_UTC = :CREATED_UTC, #NAME = :NAME"
          ExpressionAttributeNames = { "#NAME" = "NAME" }
          ExpressionAttributeValues = {
            ":CREATED_UTC.$" = "$.Item.CREATED_UTC"
            ":NAME.$"        = "$.Item.NAME"
          }
          Key = {
            GUID = { S = "STATS/MAX" }
            SORT = { S = "REDDIT/POST" }
          }
        }
      }
      InsertItem = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:putItem"
        End      = true
        Parameters = {
          TableName = aws_dynamodb_table.brutalismbot.name
          "Item.$"  = "$.Item"
        }
      }
    }
  })
}

# STATE MACHINES :: SLACK

resource "aws_sfn_state_machine" "slack_install" {
  name     = "brutalismbot-slack-install"
  role_arn = aws_iam_role.states.arn

  definition = jsonencode({
    StartAt = "Split"
    States = {
      Split = {
        Type = "Parallel"
        Next = "PutEvents"
        ResultSelector = {
          "AccessToken.$" = "$[0].AccessToken"
          "URL.$"         = "$[0].URL"
          "JSON.$"        = "$[1]"
        }
        Branches = [
          {
            StartAt = "GetAuth"
            States = {
              GetAuth = {
                Type = "Pass"
                End  = true
                Parameters = {
                  "AccessToken.$" = "$.access_token"
                  "URL.$"         = "$.incoming_webhook.url"
                }
              }
            }
          },
          {
            StartAt = "GetLastPostName"
            States = {
              GetLastPostName = {
                Type           = "Task"
                Resource       = "arn:aws:states:::dynamodb:getItem"
                Next           = "GetLastPost"
                ResultSelector = { "NAME.$" = "$.Item.NAME.S" }
                Parameters = {
                  TableName                = aws_dynamodb_table.brutalismbot.name
                  ProjectionExpression     = "#NAME"
                  ExpressionAttributeNames = { "#NAME" = "NAME" }
                  Key = {
                    GUID = { S = "STATS/MAX" }
                    SORT = { S = "REDDIT/POST" }
                  }
                }
              }
              GetLastPost = {
                Type           = "Task"
                Resource       = "arn:aws:states:::dynamodb:getItem"
                End            = true
                ResultSelector = { "JSON.$" = "$.Item.JSON.S" }
                Parameters = {
                  TableName            = aws_dynamodb_table.brutalismbot.name
                  ProjectionExpression = "JSON"
                  Key = {
                    GUID = { "S.$" = "$.NAME" }
                    SORT = { S = "REDDIT/POST" }
                  }
                }
              }
            }
          },
          {
            StartAt = "GetItem"
            States = {
              GetItem = {
                Type = "Pass"
                Next = "PutItem"
                Parameters = {
                  SORT         = { "S" = "SLACK/AUTH" }
                  ACCESS_TOKEN = { "S.$" = "$.access_token" }
                  APP_ID       = { "S.$" = "$.app_id" }
                  CHANNEL_ID   = { "S.$" = "$.incoming_webhook.channel_id" }
                  CHANNEL_NAME = { "S.$" = "$.incoming_webhook.channel" }
                  CREATED_UTC  = { "S.$" = "$$.Execution.StartTime" }
                  GUID         = { "S.$" = "States.Format('{}/{}', $.team.id, $.incoming_webhook.channel_id)" }
                  JSON         = { "S.$" = "States.JsonToString($)" }
                  SCOPE        = { "S.$" = "$.scope" }
                  TEAM_ID      = { "S.$" = "$.team.id" }
                  TEAM_NAME    = { "S.$" = "$.team.name" }
                  USER_ID      = { "S.$" = "$.authed_user.id" }
                  WEBHOOK_URL  = { "S.$" = "$.incoming_webhook.url" }
                }
              }
              PutItem = {
                Type     = "Task"
                Resource = "arn:aws:states:::dynamodb:putItem"
                End      = true
                Parameters = {
                  TableName = aws_dynamodb_table.brutalismbot.name
                  "Item.$"  = "$"
                }
              }
            }
          }
        ]
      }
      PutEvents = {
        Type     = "Task"
        Resource = "arn:aws:states:::events:putEvents"
        End      = true
        Parameters = {
          Entries = [
            {
              EventBusName = aws_cloudwatch_event_bus.brutalismbot.name
              Source       = "reddit"
              DetailType   = "post-slack"
              "Detail.$"   = "$"
            }
          ]
        }
      }
    }
  })
}

resource "aws_sfn_state_machine" "slack_post" {
  name     = "brutalismbot-slack-post"
  role_arn = aws_iam_role.states.arn

  definition = jsonencode({
    StartAt = "GetQuery"
    States = {
      GetQuery = {
        Type       = "Pass"
        Next       = "ListAuths"
        ResultPath = "$.QUERY"
        Parameters = {
          IndexName                 = "Chrono"
          Limit                     = 10
          KeyConditionExpression    = "SORT = :SORT"
          FilterExpression          = "attribute_not_exists(DISABLED)"
          ProjectionExpression      = "ACCESS_TOKEN,WEBHOOK_URL,TEAM_ID,CHANNEL_ID"
          ExpressionAttributeValues = { ":SORT" = "SLACK/AUTH" }
        }
      }
      ListAuths = {
        Type       = "Task"
        Resource   = aws_lambda_function.dynamodb_query.arn
        Next       = "GetEvents"
        InputPath  = "$.QUERY"
        ResultPath = "$.RESULT"
      }
      GetEvents = {
        Type       = "Map"
        Next       = "PublishEvents"
        ItemsPath  = "$.RESULT.Items"
        ResultPath = "$.ENTRIES"
        Parameters = {
          "AWS_STEP_FUNCTIONS_STARTED_BY_EXECUTION_ID.$" = "$$.Execution.Id"
          "ACCESS_TOKEN.$"                               = "$$.Map.Item.Value.ACCESS_TOKEN"
          "CHANNEL_ID.$"                                 = "$$.Map.Item.Value.CHANNEL_ID"
          "TEAM_ID.$"                                    = "$$.Map.Item.Value.TEAM_ID"
          "WEBHOOK_URL.$"                                = "$$.Map.Item.Value.WEBHOOK_URL"
          "CREATED_UTC.$"                                = "$.CREATED_UTC"
          "DATA.$"                                       = "$.DATA"
          "NAME.$"                                       = "$.NAME"
          "PERMALINK.$"                                  = "$.PERMALINK"
          "TITLE.$"                                      = "$.TITLE"
          "TTL.$"                                        = "$.TTL"
        }
        Iterator = {
          StartAt = "GetEvent"
          States = {
            GetEvent = {
              Type = "Pass"
              End  = true
              Parameters = {
                EventBusName = aws_cloudwatch_event_bus.brutalismbot.name
                Source       = "reddit"
                DetailType   = "post-slack"
                "Detail.$"   = "$"
              }
            }
          }
        }
      }
      PublishEvents = {
        Type       = "Task"
        Resource   = "arn:aws:states:::events:putEvents"
        Next       = "NextPage?"
        ResultPath = "$.ENTRIES"
        Parameters = { "Entries.$" = "$.ENTRIES" }
      }
      "NextPage?" = {
        Type    = "Choice"
        Default = "Finish"
        Choices = [
          {
            Next      = "NextPage"
            Variable  = "$.RESULT.LastEvaluatedKey"
            IsPresent = true
          }
        ]
      }
      NextPage = {
        Type       = "Pass"
        Next       = "ListAuths"
        InputPath  = "$.RESULT.LastEvaluatedKey"
        ResultPath = "$.QUERY.ExclusiveStartKey"
      }
      Finish = { Type = "Succeed" }
    }
  })
}

resource "aws_sfn_state_machine" "slack_post_auth" {
  name     = "brutalismbot-slack-post-auth"
  role_arn = aws_iam_role.states.arn

  definition = jsonencode({
    StartAt = "Post"
    States = {
      Post = {
        Type       = "Task"
        Resource   = aws_lambda_function.slack_post.arn
        Next       = "GetItem"
        ResultPath = "$.RESULT"
      }
      GetItem = {
        Type = "Pass"
        Next = "PutItem"
        Parameters = {
          SORT        = { "S" = "SLACK/POST" }
          CHANNEL_ID  = { "S.$" = "$.CHANNEL_ID" }
          CREATED_UTC = { "S.$" = "$.CREATED_UTC" }
          GUID        = { "S.$" = "States.Format('{}/{}', $.TEAM_ID, $.CHANNEL_ID)" }
          NAME        = { "S.$" = "$.NAME" }
          RESULT      = { "S.$" = "States.JsonToString($.RESULT)" }
          STATUS_CODE = { "S.$" = "$.RESULT.statusCode" }
          TEAM_ID     = { "S.$" = "$.TEAM_ID" }
          OK          = { "BOOL.$" = "States.JsonToString($.RESULT.ok)" }
        }
      }
      PutItem = {
        Type       = "Task"
        Resource   = "arn:aws:states:::dynamodb:putItem"
        Next       = "OK?"
        ResultPath = "$.RESULT.DYNAMODB"
        Parameters = {
          TableName = aws_dynamodb_table.brutalismbot.name
          "Item.$"  = "$"
        }
      }
      "OK?" = {
        Type    = "Choice"
        Default = "Fail"
        Choices = [
          {
            Next         = "Succeed"
            Variable     = "$.OK.BOOL"
            StringEquals = "true"
          }
        ]
      }
      Succeed = { Type = "Succeed" }
      Fail    = { Type = "Fail" }
    }
  })
}

resource "aws_sfn_state_machine" "slack_uninstall" {
  name     = "brutalismbot-slack-uninstall"
  role_arn = aws_iam_role.states.arn

  definition = jsonencode({
    StartAt = "GetQuery"
    States = {
      GetQuery = {
        Type = "Pass"
        Next = "GetItems"
        Parameters = {
          TableName                 = aws_dynamodb_table.brutalismbot.name
          IndexName                 = "SlackTeam"
          Limit                     = 25
          ProjectionExpression      = "GUID,SORT"
          KeyConditionExpression    = "TEAM_ID = :TEAM_ID"
          ExpressionAttributeValues = { ":TEAM_ID.$" = "$.team_id" }
        }
      }
      GetItems = {
        Type     = "Task"
        Resource = aws_lambda_function.dynamodb_query.arn
        Next     = "DeleteItems"
      }
      DeleteItems = {
        Type       = "Map"
        Next       = "NextPage?"
        ItemsPath  = "$.Items"
        ResultPath = "$.Items"
        Iterator = {
          StartAt = "DeleteItem"
          States = {
            DeleteItem = {
              Type     = "Task"
              Resource = "arn:aws:states:::dynamodb:deleteItem"
              End      = true
              Parameters = {
                TableName = aws_dynamodb_table.brutalismbot.name
                Key = {
                  GUID = { "S.$" = "$.GUID" }
                  SORT = { "S.$" = "$.SORT" }
                }
              }
            }
          }
        }
      }
      "NextPage?" = {
        Type    = "Choice"
        Default = "Finish"
        Choices = [
          {
            Next      = "NextPage"
            Variable  = "$.LastEvaluatedKey"
            IsPresent = true
          }
        ]
      }
      NextPage = {
        Type = "Pass"
        Next = "GetItems"
        Parameters = {
          TableName                 = aws_dynamodb_table.brutalismbot.name
          IndexName                 = "SlackTeam"
          Limit                     = 25
          ProjectionExpression      = "GUID,SORT"
          KeyConditionExpression    = "TEAM_ID = :TEAM_ID"
          ExpressionAttributeValues = { ":TEAM_ID.$" = "$.team_id" }
          "ExclusiveStartKey.$"     = "$.LastEvaluatedKey"
        }
      }
      Finish = { Type = "Succeed" }
    }
  })
}

# STATE MACHINES :: TWITTER

resource "aws_sfn_state_machine" "twitter_post" {
  name     = "brutalismbot-twitter-post"
  role_arn = aws_iam_role.states.arn

  definition = jsonencode({
    StartAt = "Post"
    States = {
      Post = {
        Type     = "Task"
        Resource = aws_lambda_function.twitter_post.arn
        End      = true
      }
    }
  })
}
