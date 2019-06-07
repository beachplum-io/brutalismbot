terraform {
  backend s3 {
    bucket = "brutalismbot"
    key    = "terraform/brutalismbot.tfstate"
    region = "us-east-1"
  }

  required_version = ">= 0.12.0"
}

provider aws {
  version = "~> 2.7"
}

provider null {
  version = "~> 2.1"
}

locals {
  lambda_s3_key = "terraform/pkg/brutalismbot-${var.release}.zip"

  tags = {
    App     = "core"
    Name    = "brutalismbot"
    Release = var.release
    Repo    = var.repo
  }
}

data aws_iam_role role {
  name = "brutalismbot"
}

data aws_iam_policy_document s3 {
  statement {
    actions = ["s3:*"]

    resources = [
      "${aws_s3_bucket.brutalismbot.arn}",
      "${aws_s3_bucket.brutalismbot.arn}/*",
    ]
  }
}

data aws_sns_topic oauth {
  name = "brutalismbot_oauth"
}

resource aws_cloudwatch_event_rule cache {
  description         = "Cache posts from /r/brutalism to S3"
  name                = aws_lambda_function.cache.function_name
  schedule_expression = "rate(1 hour)"
}

resource aws_cloudwatch_event_target cache {
  rule = aws_cloudwatch_event_rule.cache.name
  arn  = aws_lambda_function.cache.arn
}

resource aws_cloudwatch_log_group install {
  name              = "/aws/lambda/${aws_lambda_function.install.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_cloudwatch_log_group cache {
  name              = "/aws/lambda/${aws_lambda_function.cache.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_cloudwatch_log_group mirror {
  name              = "/aws/lambda/${aws_lambda_function.mirror.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_cloudwatch_log_group uninstall {
  name              = "/aws/lambda/${aws_lambda_function.uninstall.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_iam_role_policy s3_access {
  name   = "s3"
  policy = data.aws_iam_policy_document.s3.json
  role   = data.aws_iam_role.role.id
}

resource aws_lambda_function test {
  description   = "Test Brutalismbot Lambda package"
  function_name = "brutalismbot-test"
  handler       = "lambda.test"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = aws_s3_bucket.brutalismbot.bucket
  s3_key        = null_resource.lambda.triggers.lambda_s3_key
  tags          = local.tags
  timeout       = 3

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.brutalismbot.bucket
    }
  }
}

resource aws_lambda_function install {
  description   = "Install OAuth credentials"
  function_name = "brutalismbot-install"
  handler       = "lambda.install"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = aws_s3_bucket.brutalismbot.bucket
  s3_key        = null_resource.lambda.triggers.lambda_s3_key
  tags          = local.tags
  timeout       = 3

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.brutalismbot.bucket
    }
  }
}

resource aws_lambda_function cache {
  description   = "Cache posts from /r/brutalism"
  function_name = "brutalismbot-cache"
  handler       = "lambda.cache"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = aws_s3_bucket.brutalismbot.bucket
  s3_key        = null_resource.lambda.triggers.lambda_s3_key
  tags          = local.tags
  timeout       = 30

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.brutalismbot.bucket
    }
  }
}

resource aws_lambda_function mirror {
  description   = "Mirror posts from /r/brutalism"
  function_name = "brutalismbot-mirror"
  handler       = "lambda.mirror"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = aws_s3_bucket.brutalismbot.bucket
  s3_key        = null_resource.lambda.triggers.lambda_s3_key
  tags          = local.tags
  timeout       = 30

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.brutalismbot.bucket
    }
  }
}

resource aws_lambda_function uninstall {
  description   = "Uninstall brutalismbot from workspace"
  function_name = "brutalismbot-uninstall"
  handler       = "lambda.uninstall"
  role          = data.aws_iam_role.role.arn
  runtime       = "ruby2.5"
  s3_bucket     = aws_s3_bucket.brutalismbot.bucket
  s3_key        = null_resource.lambda.triggers.lambda_s3_key
  tags          = local.tags
  timeout       = 3

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.brutalismbot.bucket
    }
  }
}

resource aws_lambda_permission install {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.install.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = data.aws_sns_topic.oauth.arn
}

resource aws_lambda_permission cache {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cache.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cache.arn
}

resource aws_lambda_permission mirror {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mirror.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.brutalismbot.arn
}

resource aws_lambda_permission uninstall {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.uninstall.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.uninstall.arn
}

resource aws_s3_bucket brutalismbot {
  acl           = "private"
  bucket        = "brutalismbot"
  force_destroy = false
}

resource aws_s3_bucket_notification mirror {
  bucket = aws_s3_bucket.brutalismbot.id

  lambda_function {
    id                  = "mirror"
    lambda_function_arn = aws_lambda_function.mirror.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "posts/v1/"
    filter_suffix       = ".json"
  }
}

resource aws_sns_topic uninstall {
  name = "brutalismbot_event_app_uninstalled"
}

resource aws_sns_topic_subscription install {
  endpoint  = aws_lambda_function.install.arn
  protocol  = "lambda"
  topic_arn = data.aws_sns_topic.oauth.arn
}

resource aws_sns_topic_subscription uninstall {
  endpoint  = aws_lambda_function.uninstall.arn
  protocol  = "lambda"
  topic_arn = aws_sns_topic.uninstall.arn
}

resource null_resource lambda {
  triggers = {
    lambda_s3_key = local.lambda_s3_key
  }

  provisioner "local-exec" {
    command = "aws s3 cp lambda.zip s3://${aws_s3_bucket.brutalismbot.bucket}/${local.lambda_s3_key}"
  }
}

variable release {
  description = "Release tag."
}

variable repo {
  description = "Project repository."
  default     = "https://github.com/brutalismbot/brutalismbot"
}

output lambda_s3_url {
  description = "Lambda function package S3 URL."
  value       = "s3://${aws_s3_bucket.brutalismbot.bucket}/${local.lambda_s3_key}"
}
