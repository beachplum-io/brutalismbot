terraform {
  required_version = "~> 1.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.38"
    }
  }
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
  name                = "brutalismbot-v2-every-15m"
  schedule_expression = "rate(15 minutes)"
}

resource "aws_cloudwatch_event_target" "reddit_dequeue" {
  arn      = aws_sfn_state_machine.reddit_dequeue.id
  input    = jsonencode({})
  role_arn = aws_iam_role.events.arn
  rule     = aws_cloudwatch_event_rule.reddit_dequeue.name
}

# EVENTBRIDGE :: REDDIT METRICS

resource "aws_cloudwatch_event_rule" "reddit_metrics" {
  description    = "Publish Reddit metrics"
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  is_enabled     = true
  name           = "reddit-metrics"

  event_pattern = jsonencode({
    source      = ["reddit"]
    detail-type = ["metrics"]
  })
}

resource "aws_cloudwatch_event_target" "reddit_metrics" {
  arn            = aws_lambda_function.reddit_metrics.arn
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  input_path     = "$.detail"
  rule           = aws_cloudwatch_event_rule.reddit_metrics.name
}

# EVENTBRIDGE :: REDDIT POST

resource "aws_cloudwatch_event_rule" "reddit_post" {
  description    = "Handle new posts for Reddit"
  event_bus_name = aws_cloudwatch_event_bus.brutalismbot.name
  is_enabled     = true
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
      aws_sfn_state_machine.slack_post.arn,
      aws_sfn_state_machine.twitter_post.arn,
    ]
  }
}

resource "aws_iam_role" "events" {
  assume_role_policy = data.aws_iam_policy_document.trust_events.json
  name               = "brutalismbot-v2-events"
}

resource "aws_iam_role_policy" "events" {
  name   = "access"
  policy = data.aws_iam_policy_document.access_events.json
  role   = aws_iam_role.events.name
}

# IAM :: LAMBDA

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
    sid       = "StatesSendTask"
    actions   = ["states:SendTask*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda" {
  assume_role_policy = data.aws_iam_policy_document.trust_lambda.json
  name               = "brutalismbot-v2-lambda"
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
      aws_lambda_function.reddit_dequeue.arn,
    ]
  }
}

resource "aws_iam_role" "states" {
  assume_role_policy = data.aws_iam_policy_document.trust_states.json
  name               = "brutalismbot-v2-states"
}

resource "aws_iam_role_policy" "states" {
  name   = "access"
  policy = data.aws_iam_policy_document.access_states.json
  role   = aws_iam_role.states.name
}

# LAMBDA FUNCTIONS

data "archive_file" "package" {
  output_path = "${path.module}/package.zip"
  source_dir  = "${path.module}/lib"
  type        = "zip"
}

# LAMBDA FUNCTIONS :: REDDIT DEQUEUE

resource "aws_lambda_function" "reddit_dequeue" {
  description      = "Dequeue next post from /r/brutalism"
  filename         = data.archive_file.package.output_path
  function_name    = "brutalismbot-v2-reddit-dequeue"
  handler          = "reddit.dequeue"
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
  function_name    = "brutalismbot-v2-reddit-metrics"
  handler          = "reddit.metrics"
  role             = aws_iam_role.lambda.arn
  runtime          = "ruby2.7"
  source_code_hash = data.archive_file.package.output_base64sha256
}

resource "aws_lambda_permission" "reddit_metrics" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reddit_metrics.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.reddit_metrics.arn
}

resource "aws_cloudwatch_log_group" "reddit_metrics" {
  name              = "/aws/lambda/${aws_lambda_function.reddit_metrics.function_name}"
  retention_in_days = 14
}

# STATE MACHINES

resource "aws_sfn_state_machine" "reddit_dequeue" {
  name     = "brutalismbot-v2-reddit-dequeue"
  role_arn = aws_iam_role.states.arn

  definition = jsonencode({
    StartAt = "GetStartTime"
    States = {
      GetStartTime = {
        Type           = "Task"
        Resource       = "arn:aws:states:::dynamodb:getItem"
        Next           = "DequeueNext"
        ResultSelector = { "MinCreatedUTC.$" = "$.Item.CREATED_UTC.S" }
        Parameters = {
          TableName            = aws_dynamodb_table.brutalismbot.name
          ProjectionExpression = "CREATED_UTC"
          Key = {
            GUID = { S = "STATS/MAX" }
            SORT = { S = "REDDIT/POST" }
          }
        }
      }
      DequeueNext = {
        Type     = "Task"
        Resource = aws_lambda_function.reddit_dequeue.arn
        Next     = "GetEvents"
        Catch = [
          {
            ErrorEquals = ["Function<IndexError>"]
            Next        = "EmptyQueue"
          }
        ]
      }
      EmptyQueue = {
        Type = "Succeed"
      }
      GetEvents = {
        Type           = "Parallel"
        Next           = "PublishEvents"
        ResultSelector = { "Entries.$" : "$" }
        Branches = [
          {
            StartAt = "QueueSize"
            States = {
              QueueSize = {
                Type = "Pass"
                End  = true
                Parameters = {
                  EventBusName = aws_cloudwatch_event_bus.brutalismbot.name
                  Source       = "reddit"
                  DetailType   = "metrics"
                  Detail = {
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
          },
          {
            StartAt = "NextPost"
            States = {
              NextPost = {
                Type = "Pass"
                End  = true
                Parameters = {
                  EventBusName = aws_cloudwatch_event_bus.brutalismbot.name
                  Source       = "reddit"
                  DetailType   = "post"
                  Detail = {
                    "AWS_STEP_FUNCTIONS_STARTED_BY_EXECUTION_ID.$" = "$$.Execution.Id"
                    "RedditPost.$"                                 = "$.NextPost"
                  }
                }
              }
            }
          }
        ]
      }
      PublishEvents = {
        Type       = "Task"
        End        = true
        Resource   = "arn:aws:states:::events:putEvents"
        Parameters = { "Entries.$" : "$.Entries" }
      }
    }
  })
}

resource "aws_sfn_state_machine" "reddit_post" {
  name     = "brutalismbot-v2-reddit-post"
  role_arn = aws_iam_role.states.arn

  definition = jsonencode({
    StartAt = "GetItems"
    States = {
      GetItems = {
        Type = "Parallel"
        Next = "NewMaxCreatedUTC"
        ResultSelector = {
          "Item.$"          = "$[0]"
          "MaxCreatedUTC.$" = "$[1]"
        }
        Branches = [
          {
            StartAt = "GetItem"
            States = {
              GetItem = {
                Type      = "Pass"
                End       = true
                InputPath = "$.RedditPost"
                Parameters = {
                  SORT        = { "S" = "REDDIT/POST" }
                  GUID        = { "S.$" = "$.Name" }
                  CREATED_UTC = { "S.$" = "$.CreatedUTC" }
                  JSON        = { "S.$" = "$.JSON" }
                  MEDIA       = { "L.$" = "$.Media" }
                  NAME        = { "S.$" = "$.Name" }
                  PERMALINK   = { "S.$" = "$.Permalink" }
                  TITLE       = { "S.$" = "$.Title" }
                  TTL         = { "N.$" = "States.JsonToString($.TTL)" }
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
      NewMaxCreatedUTC = {
        Type    = "Choice"
        Default = "InsertItemOnly"
        Choices = [
          {
            Next               = "InsertItemWithNewMax"
            Variable           = "$.MaxCreatedUTC"
            StringLessThanPath = "$.Item.CREATED_UTC.S"
          }
        ]
      }
      InsertItemOnly = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:putItem"
        End      = true
        Parameters = {
          TableName = aws_dynamodb_table.brutalismbot.name
          "Item.$"  = "$.Item"
        }
      },
      InsertItemWithNewMax = {
        Type = "Parallel"
        End  = true
        Branches = [
          {
            StartAt = "InsertItem"
            States = {
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
          },
          {
            StartAt = "UpdateMaxCreatedUTC"
            States = {
              UpdateMaxCreatedUTC = {
                Type     = "Task"
                Resource = "arn:aws:states:::dynamodb:updateItem"
                End      = true
                Parameters = {
                  TableName                 = aws_dynamodb_table.brutalismbot.name
                  UpdateExpression          = "SET CREATED_UTC = :X"
                  ExpressionAttributeValues = { ":X.$" = "$.Item.CREATED_UTC" }
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
    }
  })
}

resource "aws_sfn_state_machine" "slack_post" {
  name     = "brutalismbot-v2-slack-post"
  role_arn = aws_iam_role.states.arn

  definition = jsonencode({
    StartAt = "Placeholder"
    States = {
      Placeholder = {
        Type = "Pass"
        End  = true
      }
    }
  })
}

resource "aws_sfn_state_machine" "twitter_post" {
  name     = "brutalismbot-v2-twitter-post"
  role_arn = aws_iam_role.states.arn

  definition = jsonencode({
    StartAt = "Placeholder"
    States = {
      Placeholder = {
        Type = "Pass"
        End  = true
      }
    }
  })
}

# OUTPUTS

output "event_bus" { value = aws_cloudwatch_event_bus.brutalismbot }
