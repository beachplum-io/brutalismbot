#################
#   VARIABLES   #
#################

variable "env" { type = string }

##############
#   LOCALS   #
##############

locals {
  env     = var.env
  app     = basename(path.module)
  tags    = { "brutalismbot:app" = local.app }
  user_id = "UH9M57X6Z"
}

###############
#   MODULES   #
###############

module "api" {
  source = "./api"
  app    = local.app
  env    = local.env
  tags   = local.tags
}


module "app-home" {
  source = "./app-home"
  app    = local.app
  env    = local.env
  tags   = local.tags
}

module "delete-message" {
  source = "./delete-message"
  app    = local.app
  env    = local.env
  tags   = local.tags
}

module "disable" {
  source = "./disable"
  app    = local.app
  env    = local.env
  tags   = local.tags
}

module "enable" {
  source = "./enable"
  app    = local.app
  env    = local.env
  tags   = local.tags
}

module "reject" {
  source = "./reject"
  app    = local.app
  env    = local.env
  tags   = local.tags
}

module "screen" {
  source     = "./screen"
  app        = local.app
  env        = local.env
  tags       = local.tags
  channel_id = local.user_id
}

module "states-errors" {
  source     = "./states-errors"
  app        = local.app
  env        = local.env
  tags       = local.tags
  channel_id = local.user_id
}
