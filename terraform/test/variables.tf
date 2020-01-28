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

variable tags {
  description = "Resource tags."
  type        = map
  default     = {}
}
