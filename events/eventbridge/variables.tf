variable "description" { type = string }
variable "event_bus_name" { type = string }
variable "identifier" { type = string }
variable "input_path" { default = "$.detail" }
variable "is_enabled" { type = bool }
variable "pattern" { type = any }
variable "state_machine_arn" { type = string }
