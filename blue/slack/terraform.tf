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

module "api" {
  source = "./api"
  env    = local.env
  app    = local.app
  tags   = local.tags
}

module "create-posts" {
  source = "./create-posts"
  env    = local.env
  app    = local.app
  tags   = local.tags
}

module "install" {
  source = "./install"
  env    = local.env
  app    = local.app
  tags   = local.tags
}

module "uninstall" {
  source = "./uninstall"
  env    = local.env
  app    = local.app
  tags   = local.tags
}

module "send-post" {
  source = "./send-post"
  env    = local.env
  app    = local.app
  tags   = local.tags
}
