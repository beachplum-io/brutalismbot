variable "description" { type = string }
variable "identifier" { type = string }
variable "is_enabled" { type = bool }
variable "schedule_expression" { type = string }
variable "state_machine_arn" { type = string }

variable "input" {
  type    = any
  default = {}
}
