variable lambda_role {
  description = "Lambda IAM Role name."
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

variable tags {
  description = "Resource tags."
  type        = map
  default     = {}
}

variable topic {
  description = "SNS topic name."
}
