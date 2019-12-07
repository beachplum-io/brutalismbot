variable lag_time {
  description = "Post age lag time."
  default     = "9000"
}

variable lambda_role {
  description = "Lambda IAM Role name."
}

variable lambda_s3_bucket {
  description = "Lambda function S3 bucket."
}

variable lambda_s3_key {
  description = "Lambda function S3 key."
}

variable posts_s3_bucket {
  description = "Cached posts S3 bucket."
}

variable posts_s3_prefix {
  description = "Cached posts S3 prefix."
}

variable tags {
  description = "Resource tags."
  type        = map
  default     = {}
}
