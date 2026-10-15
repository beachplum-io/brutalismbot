#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  backend "s3" {
    bucket = "beachplum-terraform"
    key    = "beachplum-io/brutalismbot/functions/terraform.tfstate"
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
  name   = "brutalismbot-functions"
  region = "us-west-2"

  tags = {
    "brutalismbot:app" = "functions"
    "git:repo"         = "beachplum-io/brutalismbot"
  }
}

#################
#   FUNCTIONS   #
#################

data "archive_file" "s3_download" {
  type        = "zip"
  source_file = "${path.module}/s3-download/index.rb"
  output_path = "${path.module}/s3-download/package.zip"
}

resource "aws_iam_role" "s3_download" {
  name = "${local.name}-s3-download"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeRole"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "s3_download" {
  for_each = {
    S3 = {
      Version = "2012-10-17"
      Statement = [{
        Sid      = "S3Write"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::brutalismbot/*"
      }]
    }
  }

  name   = each.key
  policy = jsonencode(each.value)
  role   = aws_iam_role.s3_download.id
}

resource "aws_lambda_function" "s3_download" {
  architectures    = ["arm64"]
  filename         = data.archive_file.s3_download.output_path
  function_name    = "${local.name}-s3-download"
  handler          = "index.download"
  role             = aws_iam_role.s3_download.arn
  runtime          = "ruby4.0"
  source_code_hash = data.archive_file.s3_download.output_base64sha256
}

###############
#   OUTPUTS   #
###############

output "s3_download" { value = aws_lambda_function.s3_download.arn }
