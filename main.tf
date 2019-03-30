provider archive {
  version = "~> 1.2"
}

provider aws {
  access_key = "${var.aws_access_key_id}"
  profile    = "${var.aws_profile}"
  region     = "${var.aws_region}"
  secret_key = "${var.aws_secret_access_key}"
  version    = "~> 2.4"
}

locals {
  tags {
    App     = "brutalismbot"
    Release = "${var.release}"
    Repo    = "${var.repo}"
  }
}

data archive_file package {
  output_path = "${path.module}/dist/package.zip"
  source_dir  = "${path.module}/lib"
  type        = "zip"
}

data aws_kms_key key {
  key_id = "alias/brutalismbot"
}

data aws_iam_policy_document s3 {
  statement {
    actions   = ["s3:*"]
    resources = [
      "${aws_s3_bucket.brutalismbot.arn}",
      "${aws_s3_bucket.brutalismbot.arn}/*",
    ]
  }
}

resource aws_cloudwatch_dashboard dash {
  dashboard_name = "Brutalismbot"
  dashboard_body = "${file("${path.module}/dashboard.json")}"
}

resource aws_cloudwatch_event_rule cache {
  description         = "Cache posts from /r/brutalism to S3"
  name                = "${aws_lambda_function.cache.function_name}"
  schedule_expression = "rate(1 hour)"
}

resource aws_cloudwatch_event_target cache {
  rule  = "${aws_cloudwatch_event_rule.cache.name}"
  arn   = "${aws_lambda_function.cache.arn}"
}

resource aws_cloudwatch_log_group install {
  name              = "/aws/lambda/${aws_lambda_function.install.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

resource aws_cloudwatch_log_group cache {
  name              = "/aws/lambda/${aws_lambda_function.cache.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

resource aws_cloudwatch_log_group mirror {
  name              = "/aws/lambda/${aws_lambda_function.mirror.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

resource aws_cloudwatch_log_group uninstall {
  name              = "/aws/lambda/${aws_lambda_function.uninstall.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

/*
resource aws_kms_key brutalismbot {
  description = "Brutalismbot Slack App"
  tags        = "${local.tags}"
}

resource aws_kms_alias brutalismbot {
  name          = "alias/brutalismbot"
  target_key_id = "${aws_kms_key.brutalismbot.key_id}"
}
*/

resource aws_iam_role_policy s3_access {
  name   = "s3"
  policy = "${data.aws_iam_policy_document.s3.json}"
  role   = "${module.slackbot.role_name}"
}

resource aws_lambda_function install {
  description      = "Install OAuth credentials"
  filename         = "${data.archive_file.package.output_path}"
  function_name    = "brutalismbot-install"
  handler          = "handlers.install"
  role             = "${module.slackbot.role_arn}"
  runtime          = "ruby2.5"
  source_code_hash = "${filebase64sha256("${data.archive_file.package.output_path}")}"
  tags             = "${local.tags}"

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_function cache {
  description      = "Cache posts from /r/brutalism"
  filename         = "${data.archive_file.package.output_path}"
  function_name    = "brutalismbot-cache"
  handler          = "handlers.cache"
  role             = "${module.slackbot.role_arn}"
  runtime          = "ruby2.5"
  source_code_hash = "${filebase64sha256("${data.archive_file.package.output_path}")}"
  tags             = "${local.tags}"
  timeout          = 15

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_function mirror {
  description      = "Mirror posts from /r/brutalism"
  filename         = "${data.archive_file.package.output_path}"
  function_name    = "brutalismbot-mirror"
  handler          = "handlers.mirror"
  role             = "${module.slackbot.role_arn}"
  runtime          = "ruby2.5"
  source_code_hash = "${filebase64sha256("${data.archive_file.package.output_path}")}"
  tags             = "${local.tags}"
  timeout          = 30

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_function uninstall {
  description      = "Uninstall brutalismbot from workspace"
  filename         = "${data.archive_file.package.output_path}"
  function_name    = "brutalismbot-uninstall"
  handler          = "handlers.uninstall"
  role             = "${module.slackbot.role_arn}"
  runtime          = "ruby2.5"
  source_code_hash = "${filebase64sha256("${data.archive_file.package.output_path}")}"
  tags             = "${local.tags}"

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_permission install {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.install.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${module.slackbot.oauth_topic_arn}"
}

resource aws_lambda_permission cache {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.cache.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.cache.arn}"
}

resource aws_lambda_permission mirror {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.mirror.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.brutalismbot.arn}"
}

resource aws_lambda_permission uninstall {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.uninstall.arn}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.uninstall.arn}"
}

resource aws_s3_bucket brutalismbot {
  acl           = "private"
  bucket        = "brutalismbot"
  force_destroy = false

  /*server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${data.aws_kms_key.key.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }*/
}

resource aws_s3_bucket_notification mirror {
  bucket = "${aws_s3_bucket.brutalismbot.id}"

  lambda_function {
    id                  = "mirror"
    lambda_function_arn = "${aws_lambda_function.mirror.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "posts/v1/"
    filter_suffix       = ".json"
  }
}

resource aws_sns_topic uninstall {
  name = "brutalismbot_event_app_uninstalled"
}

resource aws_sns_topic_subscription install {
  endpoint  = "${aws_lambda_function.install.arn}"
  protocol  = "lambda"
  topic_arn = "${module.slackbot.oauth_topic_arn}"
}

resource aws_sns_topic_subscription uninstall {
  endpoint  = "${aws_lambda_function.uninstall.arn}"
  protocol  = "lambda"
  topic_arn = "${aws_sns_topic.uninstall.arn}"
}

module slackbot {
  source               = "amancevice/slackbot/aws"
  version              = "13.2.1"
  api_description      = "Brutalismbot REST API"
  api_name             = "brutalismbot"
  api_stage_name       = "v1"
  api_stage_tags       = "${local.tags}"
  base_url             = "/brutalismbot"
  kms_key_id           = "${data.aws_kms_key.key.key_id}"
  lambda_function_name = "brutalismbot-api"
  lambda_tags          = "${local.tags}"
  log_group_tags       = "${local.tags}"
  role_name            = "brutalismbot"
  role_tags            = "${local.tags}"
  secret_name          = "brutalismbot"
  sns_topic_prefix     = "brutalismbot_"
}
