##############
#   LOCALS   #
##############

locals {
  app  = basename(path.module)
  name = "${terraform.workspace}-${local.app}"
  tags = { "brutalismbot:app" = local.app }

  strings = {
    "bluesky/BLUESKY_USERNAME"                = "brutalismbot.com"
    "slack-beta-api/SLACK_CLIENT_ID"          = "588825324710.2005310499636"
    "slack-beta-api/SLACK_OAUTH_ERROR_URI"    = "https://www.brutalismbot.com/slack/error.html"
    "slack-beta-api/SLACK_OAUTH_INSTALL_URI"  = "https://slack.com/oauth/v2/authorize?client_id=588825324710.2005310499636&scope=chat:write+chat:write.public+incoming-webhook+links:read+links:write"
    "slack-beta-api/SLACK_OAUTH_REDIRECT_URI" = "https://api.brutalismbot.com/slack/beta/oauth/v2"
    "slack-beta-api/SLACK_OAUTH_SUCCESS_URI"  = "https://www.brutalismbot.com/slack/success.v2.html?team=%s&id=%s&tab=home"
    "slack-beta-api/SLACK_SIGNING_VERSION"    = "v0"
  }

  secure_strings = {
    "bluesky/BLUESKY_PASSWORD"            = "IGNORED BY TERRAFORM"
    "slack-beta-api/SLACK_SIGNING_SECRET" = "IGNORED BY TERRAFORM"
    "slack-beta-api/SLACK_API_TOKEN"      = "IGNORED BY TERRAFORM"
    "slack-beta-api/SLACK_CLIENT_SECRET"  = "IGNORED BY TERRAFORM"
    "slack-beta-api/SLACK_SIGNING_SECRET" = "IGNORED BY TERRAFORM"
  }
}

###################
#    PARAMETERS   #
###################

resource "aws_ssm_parameter" "strings" {
  for_each = {
    for key, val in local.strings :
    "/${replace(terraform.workspace, "-", "/")}/${key}" => val
  }

  name  = each.key
  value = each.value
  type  = "String"
}

resource "aws_ssm_parameter" "secure_strings" {
  for_each = {
    for key, val in local.secure_strings :
    "/${replace(terraform.workspace, "-", "/")}/${key}" => val
  }

  name  = each.key
  value = each.value
  type  = "SecureString"

  lifecycle {
    ignore_changes = [value]
  }
}
