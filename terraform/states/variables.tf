variable lambda_layers {
  description = "Lambda layer ARNs"
}

variable lag_time {
  description = "Post age lag time"
  default     = "9000"
}

variable lambda_role_arn {
  description = "Lambda IAM Role ARN"
}

variable lambda_s3_bucket {
  description = "Lambda function S3 bucket"
}

variable lambda_s3_key {
  description = "Lambda function S3 key"
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
