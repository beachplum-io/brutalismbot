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

module "send-post" {
  source = "./send-post"
  env    = local.env
  app    = local.app
  tags   = local.tags
}
