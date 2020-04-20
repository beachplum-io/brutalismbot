variable lambda_layers {
  description = "Lambda layer ARNs"
  type        = list
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

variable tags {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable twitter_access_token {
  description = "Twitter API access token"
}

variable twitter_access_token_secret {
  description = "Twitter API access token secret"
}

variable twitter_consumer_key {
  description = "Twitter API Consumer Key"
}

variable twitter_consumer_secret {
  description = "Twitter API Consumer Secret"
}
