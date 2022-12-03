###############
#   OUTPUTS   #
###############

output "role" { value = aws_iam_role.role }
output "state_machine" { value = aws_sfn_state_machine.state_machine }
