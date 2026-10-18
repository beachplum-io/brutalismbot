#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  backend "s3" {
    bucket = "beachplum-terraform"
    key    = "beachplum-io/brutalismbot/screen/terraform.tfstate"
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
  name   = "brutalismbot-screen"
  region = "us-west-2"

  tags = {
    "brutalismbot:app" = "screen"
    "git:repo"         = "beachplum-io/brutalismbot"
  }
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

# resource "aws_iam_role_policy" "states" {
#   name = aws_iam_role.states.name
#   role = aws_iam_role.states.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#     ]
#   })
# }

resource "aws_sfn_state_machine" "states" {
  definition = jsonencode(yamldecode(file("${path.module}/states.asl.yaml")))
  name       = local.name
  role_arn   = aws_iam_role.states.arn
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
