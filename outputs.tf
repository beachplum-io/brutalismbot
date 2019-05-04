output lambda_s3_url {
  description = "Lambda function package S3 URL."
  value       = "s3://${aws_s3_bucket.brutalismbot.bucket}/${local.lambda_s3_key}"
}
