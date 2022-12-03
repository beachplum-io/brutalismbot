#################
#   VARIABLES   #
#################

variable "name" {}
variable "policy" {}

variable "variables" {
  type    = map(any)
  default = {}
}
