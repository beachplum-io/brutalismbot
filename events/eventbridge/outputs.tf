output "role" { value = aws_iam_role.role }
output "rule" { value = aws_cloudwatch_event_rule.rule }
output "target" { value = aws_cloudwatch_event_target.target }
