variable lambda_arns {
  description = "Lambda ARNs"

  type = object({
    reddit_pull  = string
    slack_list   = string
    slack_push   = string
    twitter_push = string
  })
}

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

variable tags {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
