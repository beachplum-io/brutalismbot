output kms_key_alias {
  description = "KMS key alias."
  value       = "${module.secrets.kms_key_alias}"
}

output kms_key_arn {
  description = "KMS key ARN."
  value       = "${module.secrets.kms_key_arn}"
}

output kms_key_id {
  description = "KMS key ID."
  value       = "${module.secrets.kms_key_id}"
}

output secret_arn {
  description = "Slackbot SecretsManager secret ARN."
  value       = "${module.secrets.secret_arn}"
}

output secret_name {
  description = "Slackbot SecretsManager secret name."
  value       = "${module.secrets.secret_name}"
}
