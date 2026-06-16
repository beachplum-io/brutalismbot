################
#   AWS DATA   #
################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_cloudwatch_event_bus" "bus" {
  name = terraform.workspace
}

data "aws_ssm_parameter" "params" {
  for_each = {
    SLACK_API_TOKEN          = true
    SLACK_CLIENT_ID          = false
    SLACK_CLIENT_SECRET      = true
    SLACK_OAUTH_ERROR_URI    = false
    SLACK_OAUTH_INSTALL_URI  = false
    SLACK_OAUTH_REDIRECT_URI = false
    SLACK_OAUTH_SUCCESS_URI  = false
    SLACK_SIGNING_SECRET     = true
  }

  name            = "/${replace(terraform.workspace, "-", "/")}/${local.app}/${each.key}"
  with_decryption = each.value
}

##############
#   LOCALS   #
##############

locals {
  account = data.aws_caller_identity.current.account_id
  region  = data.aws_region.current.region

  app  = basename(path.module)
  name = "${terraform.workspace}-${local.app}"
  tags = { "brutalismbot:app" = local.app }

  api_token          = data.aws_ssm_parameter.params["SLACK_API_TOKEN"].value
  client_id          = data.aws_ssm_parameter.params["SLACK_CLIENT_ID"].value
  client_secret      = data.aws_ssm_parameter.params["SLACK_CLIENT_SECRET"].value
  oauth_error_uri    = data.aws_ssm_parameter.params["SLACK_OAUTH_ERROR_URI"].value
  oauth_install_uri  = data.aws_ssm_parameter.params["SLACK_OAUTH_INSTALL_URI"].value
  oauth_redirect_uri = data.aws_ssm_parameter.params["SLACK_OAUTH_REDIRECT_URI"].value
  oauth_success_uri  = data.aws_ssm_parameter.params["SLACK_OAUTH_SUCCESS_URI"].value
  signing_secret     = data.aws_ssm_parameter.params["SLACK_SIGNING_SECRET"].value

  api_body = jsonencode(yamldecode(templatefile("${path.module}/openapi.yml", {
    description = "${local.name} REST API"
    region      = local.region
    role_arn    = aws_iam_role.roles["apigateway"].arn
    server_url  = "https://api.brutalismbot.com/slack"
    title       = local.name
  })))

  roles = {
    apigateway = {
      states = {
        Version = "2012-10-17"
        Statement = [{
          Sid    = "StartExecution"
          Effect = "Allow"
          Action = "states:StartSyncExecution"
          Resource = [
            for key, _ in local.state_machines :
            "arn:aws:states:${local.region}:${local.account}:stateMachine:${local.name}-api-${key}"
          ]
        }]
      }
    }

    events = {
      states = {
        Version = "2012-10-17"
        Statement = [{
          Sid      = "StartExecution"
          Effect   = "Allow"
          Resource = "arn:aws:states:${local.region}:${local.account}:stateMachine:${local.name}-*"
          Action = [
            "states:StartExecution",
            "states:StartSyncExecution",
          ]
        }]
      }
    }

    lambda = {
      logs = {
        Version = "2012-10-17"
        Statement = [{
          Sid      = "Logs"
          Effect   = "Allow"
          Action   = "logs:*"
          Resource = "*"
        }]
      }
    }

    states = {
      events = {
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = "events:PutEvents"
          Resource = data.aws_cloudwatch_event_bus.bus.arn
        }]
      }

      lambda = {
        Version = "2012-10-17"
        Statement = [{
          Sid      = "Invoke"
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = "arn:aws:lambda:${local.region}:${local.account}:function:${local.name}-*"
        }]
      }

      logs = {
        Version = "2012-10-17"
        Statement = [{
          Sid      = "Logs"
          Effect   = "Allow"
          Action   = "logs:*"
          Resource = "*"
        }]
      }

      slack-api = {
        Version = "2012-10-17"
        Statement = [
          {
            Sid      = "InvokeHttp"
            Effect   = "Allow"
            Action   = "states:InvokeHTTPEndpoint"
            Resource = "*"
            Condition = {
              StringEquals = { "states:HTTPMethod" = ["GET", "POST"] }
              StringLike   = { "states:HTTPEndpoint" = "https://slack.com/api/*" }
            }
          },
          {
            Sid      = "GetConnection"
            Effect   = "Allow"
            Action   = "events:RetrieveConnectionCredentials"
            Resource = aws_cloudwatch_event_connection.slack.arn
          },
          {
            Sid      = "GetSecret"
            Effect   = "Allow"
            Action   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue"]
            Resource = aws_cloudwatch_event_connection.slack.secret_arn
          }
        ]
      }

      states = {
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Action = [
            "states:DescribeExecution",
            "states:StartExecution",
          ]
          Resource = [
            "arn:aws:states:${local.region}:${local.account}:stateMachine:${local.name}-api-oauth-state",
            "arn:aws:states:${local.region}:${local.account}:execution:${local.name}-api-oauth-state:*",
          ]
        }]
      }
    }
  }

  functions = {
    authorizer = {
      description = "Slack request authorizer"
      memory_size = 1024
      variables = {
        SIGNING_SECRET = local.signing_secret
      }
    }

    oauth = {
      description = "Slack OAuth completion"
      memory_size = 256
      variables = {
        CLIENT_ID     = local.client_id
        CLIENT_SECRET = local.client_secret
      }
    }
  }

  state_machines = {
    callback    = "EXPRESS"
    event       = "EXPRESS"
    install     = "EXPRESS"
    oauth       = "EXPRESS"
    oauth-state = "STANDARD"
  }

  log_groups = merge(
    { apigateway = "/aws/apigateway/${local.name}" },
    { for key, _ in local.functions : "lambda-${key}" => "/aws/lambda/${local.name}-api-${key}" },
    { for key, _ in local.state_machines : "states-${key}" => "/aws/states/${local.name}-api-${key}" },
  )
}

###################
#   EVENTBRIDGE   #
###################

resource "aws_cloudwatch_event_connection" "slack" {
  name               = local.name
  description        = "${local.name} Slack API connection"
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = "authorization"
      value = "Bearer ${local.api_token}"
    }
  }
}

################
#   REST API   #
################

resource "aws_api_gateway_rest_api" "api" {
  body        = local.api_body
  description = "${local.name} REST API"
  name        = local.name
  tags        = local.tags

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(local.api_body)
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  description   = "${local.name} default stage"
  stage_name    = "default"

  variables = {
    for key, state_machine in aws_sfn_state_machine.states :
    "${key}StateMachineArn" => state_machine.arn
    if state_machine.type == "EXPRESS"
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.logs["apigateway"].arn
    format = jsonencode({
      caller            = "$context.identity.caller"
      extendedRequestId = "$context.extendedRequestId"
      httpMethod        = "$context.httpMethod"
      ip                = "$context.identity.sourceIp"
      integrationError  = "$context.integration.error"
      protocol          = "$context.protocol"
      requestId         = "$context.requestId"
      requestTime       = "$context.requestTime"
      resourcePath      = "$context.resourcePath"
      responseLength    = "$context.responseLength"
      status            = "$context.status"
      user              = "$context.identity.user"
    })
  }
}

############
#   LOGS   #
############

resource "aws_cloudwatch_log_group" "logs" {
  for_each = local.log_groups

  name              = each.value
  retention_in_days = 14
}

#################
#   IAM ROLES   #
#################

resource "aws_iam_role" "roles" {
  for_each = local.roles

  name        = "${local.name}-${local.region}-${each.key}"
  description = "${local.name} ${each.key} role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeApiGateway"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "${each.key}.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "policies" {
  for_each = merge(flatten([
    for key, role in aws_iam_role.roles : [
      for name, policy in local.roles[key] : {
        "${key}-${name}" = {
          role   = role.id
          name   = name
          policy = policy
        }
      }
    ]
  ])...)

  name   = each.value.name
  policy = jsonencode(each.value.policy)
  role   = each.value.role
}

########################
#   LAMBDA FUNCTIONS   #
########################

data "archive_file" "packages" {
  for_each = local.functions

  source_dir  = "${path.module}/functions/${each.key}/src"
  output_path = "${path.module}/functions/${each.key}/package.zip"
  type        = "zip"
}

resource "aws_lambda_function" "functions" {
  for_each = local.functions

  architectures    = ["arm64"]
  description      = each.value.description
  filename         = data.archive_file.packages[each.key].output_path
  function_name    = "${local.name}-api-${each.key}"
  handler          = "index.handler"
  memory_size      = each.value.memory_size
  role             = aws_iam_role.roles["lambda"].arn
  runtime          = "python3.14"
  source_code_hash = data.archive_file.packages[each.key].output_base64sha256
  tags             = local.tags
  timeout          = 3

  environment {
    variables = each.value.variables
  }
}

######################
#   STATE MACHINES   #
######################

resource "aws_sfn_state_machine" "states" {
  depends_on = [aws_cloudwatch_log_group.logs]

  for_each = local.state_machines

  name = "${local.name}-api-${each.key}"
  type = each.value

  role_arn = aws_iam_role.roles["states"].arn

  definition = jsonencode(yamldecode(templatefile("${path.module}/state-machines/${each.key}.asl.yml", {
    authorizer_function_arn       = aws_lambda_function.functions["authorizer"].arn
    event_bus_name                = data.aws_cloudwatch_event_bus.bus.name
    oauth_function_arn            = aws_lambda_function.functions["oauth"].arn
    oauth_error_uri               = local.oauth_error_uri
    oauth_install_uri             = local.oauth_install_uri
    oauth_redirect_uri            = local.oauth_redirect_uri
    oauth_redirect_uri_encoded    = urlencode(local.oauth_redirect_uri)
    oauth_success_uri             = local.oauth_success_uri
    oauth_state_state_machine_arn = "arn:aws:states:${local.region}:${local.account}:stateMachine:${local.name}-api-oauth-state"
    source                        = "api.brutalismbot.com/slack/beta"
  })))

  logging_configuration {
    include_execution_data = true
    level                  = "ALL"
    log_destination        = "${aws_cloudwatch_log_group.logs["states-${each.key}"].arn}:*"
  }
}
