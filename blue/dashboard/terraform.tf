##############
#   LOCALS   #
##############

locals {
  region = data.aws_region.current.name

  tags = { "brutalismbot:app" = basename(path.module) }

  functions = {
    bluesky    = ["send-post"]
    reddit     = ["pop"]
    shared     = ["http"]
    slack      = ["api", "create-posts"]
    slack-beta = ["api", "app-home", "screen"]
    twitter    = ["send-post"]
  }

  state_machines = {
    bluesky    = ["send-post"]
    reddit     = ["pop"]
    shared     = []
    slack      = ["create-posts", "install", "send-post", "uninstall"]
    slack-beta = ["app-home", "delete-message", "disable", "enable", "reject", "screen", "states-errors"]
    twitter    = ["send-post"]
  }
}

############
#   DATA   #
############

data "aws_region" "current" {}

data "aws_lambda_function" "functions" {
  for_each = toset(concat([
    for app, names in local.functions :
    [for name in names : "${terraform.workspace}-${app}-${name}"]
  ]...))
  function_name = each.key
}

data "aws_sfn_state_machine" "state_machines" {
  for_each = toset(concat([
    for app, names in local.state_machines :
    [for name in names : "${terraform.workspace}-${app}-${name}"]
  ]...))
  name = each.key
}

############################
#   CLOUDWATCH DASHBOARD   #
############################

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = terraform.workspace
  dashboard_body = jsonencode(yamldecode(templatefile("${path.module}/dashboard.yml", {
    duration = jsonencode([
      for function in keys(data.aws_lambda_function.functions) :
      ["AWS/Lambda", "Duration", "FunctionName", function, { region : local.region }]
    ])

    lambda_errors = jsonencode([
      for function in keys(data.aws_lambda_function.functions) :
      ["AWS/Lambda", "Errors", "FunctionName", function, { region : local.region }]
    ])

    state_machine_errors = jsonencode([
      for name, state_machine in data.aws_sfn_state_machine.state_machines :
      ["AWS/States", "ExecutionsFailed", "StateMachineArn", state_machine.arn, { label = state_machine.name }]
    ])
  })))
}
