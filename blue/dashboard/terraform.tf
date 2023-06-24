#################
#   VARIABLES   #
#################

variable "env" { type = string }

##############
#   LOCALS   #
##############

locals {
  env  = var.env
  app  = basename(path.module)
  tags = { "brutalismbot:app" = local.app }

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
    reddit     = ["pop", "pop-backlog"]
    shared     = []
    slack      = ["create-posts", "install", "send-post", "uninstall"]
    slack-beta = ["app-home", "delete-message", "disable", "enable", "reject", "screen", "states-errors"]
    twitter    = ["send-post"]
  }
}

############
#   DATA   #
############

data "aws_lambda_function" "functions" {
  for_each = toset(concat([
    for app, names in local.functions :
    [for name in names : "brutalismbot-${local.env}-${app}-${name}"]
  ]...))
  function_name = each.key
}

data "aws_sfn_state_machine" "state_machines" {
  for_each = toset(concat([
    for app, names in local.state_machines :
    [for name in names : "brutalismbot-${local.env}-${app}-${name}"]
  ]...))
  name = each.key
}

############################
#   CLOUDWATCH DASHBOARD   #
############################

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "brutalismbot-${local.env}"
  dashboard_body = jsonencode(yamldecode(templatefile("${path.module}/dashboard.yml", {
    duration = jsonencode([
      for function in keys(data.aws_lambda_function.functions) :
      ["AWS/Lambda", "Duration", "FunctionName", function]
    ])

    lambda_errors = jsonencode([
      for function in keys(data.aws_lambda_function.functions) :
      ["AWS/Lambda", "Errors", "FunctionName", function]
    ])

    state_machine_errors = jsonencode([
      for name, state_machine in data.aws_sfn_state_machine.state_machines :
      ["AWS/States", "ExecutionsFailed", "StateMachineArn", state_machine.arn, { label = state_machine.name }]
    ])
  })))
}
