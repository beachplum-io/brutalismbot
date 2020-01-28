locals {
  retention_in_days = var.retention_in_days

  description           = var.description
  environment_variables = var.environment_variables[*]
  function_name         = var.function_name
  handler               = var.handler
  layers                = var.layers
  memory_size           = var.memory_size
  role                  = var.role
  runtime               = var.runtime
  s3_bucket             = var.s3_bucket
  s3_key                = var.s3_key
  tags                  = var.tags
  timeout               = var.timeout
}

resource aws_cloudwatch_log_group logs {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = local.retention_in_days
  tags              = local.tags
}

resource aws_lambda_function lambda {
  description   = local.description
  function_name = local.function_name
  handler       = local.handler
  layers        = local.layers
  memory_size   = local.memory_size
  role          = local.role
  runtime       = local.runtime
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  tags          = local.tags
  timeout       = local.timeout

  dynamic environment {
    for_each = local.environment_variables

    content {
      variables = environment.value
    }
  }
}
