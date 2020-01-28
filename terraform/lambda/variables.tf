variable description {
  description = "Lambda function description."
}

variable environment_variables {
  description = "Lambda function environment variables."
  type        = map(string)
  default     = null
}

variable function_name {
  description = "Lambda function name."
}

variable handler {
  description = "Lambda function handler."
}

variable layers {
  description = "Lambda function layer ARNs."
  type        = list
}

variable memory_size {
  description = "Lambda function memory size."
  default     = 128
}

variable retention_in_days {
  description = "CloudWatch log group retention in days."
  default     = 30
}

variable role {
  description = "Lambda function role ARN."
}

variable runtime {
  description = "Lambda function runtime."
  default     = "ruby2.5"
}

variable s3_bucket {
  description = "Lambda function package S3 bucket."
}

variable s3_key {
  description = "Lambda function package S3 key."
}

variable tags {
  description = "Lambda function tags."
  type        = map
  default     = {}
}

variable timeout {
  description = "Lambda function timeout."
  default     = 3
}
