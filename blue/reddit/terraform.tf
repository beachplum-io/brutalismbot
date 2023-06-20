#################
#   VARIABLES   #
#################

variable "env" { type = string }

##############
#   LOCALS   #
##############

locals {
  env  = var.env
  app  = basename(path.module)
  tags = { "brutalismbot:app" = local.app }
}

###############
#   MODULES   #
###############

module "pop" {
  source = "./pop"
  env    = local.env
  app    = local.app
  tags   = local.tags
}
