provider aws {
  access_key = "${var.aws_access_key_id}"
  profile    = "${var.aws_profile}"
  region     = "${var.aws_region}"
  secret_key = "${var.aws_secret_access_key}"
  version    = "~> 2.5"
}

locals {
  tags {
    App     = "brutalismbot"
    Name    = "brutalismbot.com"
    Repo    = "${var.repo}"
    Release = "${var.release}"
  }
}

module secrets {
  source                   = "amancevice/slackbot-secrets/aws"
  version                  = "1.1.0"
  kms_key_alias            = "alias/brutalismbot"
  kms_key_tags             = "${local.tags}"
  secret_name              = "brutalismbot"
  secret_tags              = "${local.tags}"
  slack_client_id          = "${var.slack_client_id}"
  slack_client_secret      = "${var.slack_client_secret}"
  slack_oauth_error_uri    = "${var.slack_oauth_error_uri}"
  slack_oauth_redirect_uri = "${var.slack_oauth_redirect_uri}"
  slack_oauth_success_uri  = "${var.slack_oauth_success_uri}"
  slack_signing_secret     = "${var.slack_signing_secret}"
  slack_signing_version    = "${var.slack_signing_version}"
  slack_token              = "${var.slack_token}"
}
