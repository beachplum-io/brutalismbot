variable lambda_layers {
  description = "Lambda layer ARNs."
  type        = list
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

variable slack_s3_bucket {
  description = "Slack S3 bucket."
}

variable slack_s3_prefix {
  description = "Slack S3 prefix."
}

variable slack_sns_topic_arn {
  description = "Slack SNS topic ARN."
}

variable tags {
  description = "Resource tags."
  type        = map
  default     = {}
}
