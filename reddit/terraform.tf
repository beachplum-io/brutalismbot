#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  backend "s3" {
    bucket = "beachplum-terraform"
    key    = "beachplum-io/brutalismbot/reddit/terraform.tfstate"
    region = "us-west-2"
  }
}

###########
#   AWS   #
###########

provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

##############
#   LOCALS   #
##############

locals {
  name   = "brutalismbot-reddit"
  region = "us-west-2"

  tags = {
    "brutalismbot:app" = "reddit"
    "git:repo"         = "beachplum-io/brutalismbot"
  }
}

############
#   DATA   #
############

data "aws_lambda_function" "s3_download" {
  function_name = "brutalismbot-functions-s3-download"
}

data "aws_sqs_queue" "screen" {
  name = "brutalismbot-screen"
}

###########
#   SQS   #
###########

resource "aws_sqs_queue" "queue" {
  # message_retention_seconds = 1209600 # 14 days (max)
  name = local.name

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "dlq" {
  # message_retention_seconds = 1209600 # 14 days (max)
  name = "${local.name}-dlq"
}

######################
#   STEP FUNCTIONS   #
######################

resource "aws_iam_role" "states" {
  name = "${local.name}-states"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeRole"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "states" {
  name = aws_iam_role.states.name
  role = aws_iam_role.states.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3Access"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::brutalismbot/reddit/*"
      },
      {
        Sid      = "InvokeFunction"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = data.aws_lambda_function.s3_download.arn
      },
      {
        Sid      = "Enqueue"
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = data.aws_sqs_queue.screen.arn
      }
    ]
  })
}

resource "aws_sfn_state_machine" "states" {
  name     = local.name
  role_arn = aws_iam_role.states.arn

  definition = jsonencode(yamldecode(templatefile("${path.module}/states.asl.yaml", {
    queue_url = data.aws_sqs_queue.screen.url
  })))
}

#############
#   PIPES   #
#############

resource "aws_iam_role" "pipes" {
  name = "${local.name}-pipes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeRole"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "pipes.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "pipes" {
  for_each = {
    sqs = {
      Version = "2012-10-17"
      Statement = [{
        Sid      = "StartExection"
        Effect   = "Allow"
        Resource = aws_sqs_queue.queue.arn
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ReceiveMessage",
        ]
      }]
    }
    states = {
      Version = "2012-10-17"
      Statement = [{
        Sid      = "StartExection"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.states.arn
      }]
    }
  }

  name   = each.key
  policy = jsonencode(each.value)
  role   = aws_iam_role.pipes.id
}

resource "aws_pipes_pipe" "pipes" {
  name     = local.name
  role_arn = aws_iam_role.pipes.arn
  source   = aws_sqs_queue.queue.arn
  target   = aws_sfn_state_machine.states.arn

  target_parameters {
    step_function_state_machine_parameters {
      invocation_type = "FIRE_AND_FORGET"
    }
  }

  depends_on = [aws_iam_role_policy.pipes]
}
