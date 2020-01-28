output lambda {
  description = "Lambda."
  value       = aws_lambda_function.lambda
}

output log_group {
  description = "Lambda CloudWatch log group."
  value       = aws_cloudwatch_log_group.logs
}
