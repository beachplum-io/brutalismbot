variable lambda_layer_arn {
  description = "Lambda layer ARN."
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

variable posts_s3_bucket {
  description = "Posts S3 bucket."
}

variable posts_s3_prefix {
  description = "Posts S3 prefix."
}

variable slack_s3_bucket {
  description = "Slack S3 bucket."
}

variable slack_s3_prefix {
  description = "Slack S3 prefix."
}

variable twitter_access_token {
  description = "Twitter API access token."
}

variable twitter_access_token_secret {
  description = "Twitter API access token secret."
}

variable twitter_consumer_key {
  description = "Twitter API Consumer Key."
}

variable twitter_consumer_secret {
  description = "Twitter API Consumer Secret."
}

variable tags {
  description = "Resource tags."
  type        = map
  default     = {}
}
