variable lambda_environment {
  description = "Lambda function ENV variables"
  type        = map(string)
  default     = {}
}

variable lambda_filename {
  description = "Lambda function filename"
}

variable lambda_layers {
  description = "Lambda layer ARNs"
}

variable lambda_role_arn {
  description = "Lambda IAM Role ARN"
}

variable lambda_runtime {
  description = "Lambda runtime"
  default     = "ruby2.7"
}

variable lambda_source_code_hash {
  description = "Lambda function source code hash"
}

variable reddit_pull_lambda_arn {
  description = "Reddit pull lambda ARN"
}

variable slack_list_lambda_arn {
  description = "Slack list Lambda ARN"
}

variable slack_push_lambda_arn {
  description = "Slack push Lambda ARN"
}

variable tags {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable twitter_push_lambda_arn {
  description = "Twitter push Lambda ARN"
}
