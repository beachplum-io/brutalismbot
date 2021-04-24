output "dlqs" {
  description = "SQS dead letter queues"
  value = {
    slack   = aws_sqs_queue.slack_dlq
    twitter = aws_sqs_queue.twitter_dlq
  }
}

output "state_machines" {
  description = "State machines"
  value = {
    main    = aws_sfn_state_machine.main
    slack   = aws_sfn_state_machine.slack
    twitter = aws_sfn_state_machine.twitter
  }
}
