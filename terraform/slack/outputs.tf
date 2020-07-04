output list {
  description = "Slack list module"
  value       = aws_lambda_function.list
}

output push {
  description = "Slack push module"
  value       = aws_lambda_function.push
}
