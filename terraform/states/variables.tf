variable lambda_layers {
  description = "Lambda layer ARNs."
}

variable lag_time {
  description = "Post age lag time."
  default     = "9000"
}

variable lambda_role_arn {
  description = "Lambda IAM Role ARN."
}

variable lambda_s3_bucket {
  description = "Lambda function S3 bucket."
}

variable lambda_s3_key {
  description = "Lambda function S3 key."
}

variable pull_lambda_arn {
  description = "Pull lambda ARN."
}

variable slack_list_lambda_arn {
  description = "Slack list Lambda ARN."
}

variable slack_push_lambda_arn {
  description = "Slack push Lambda ARN."
}

variable tags {
  description = "Resource tags."
  type        = map
  default     = {}
}

variable twitter_push_lambda_arn {
  description = "Twitter push Lambda ARN."
}
