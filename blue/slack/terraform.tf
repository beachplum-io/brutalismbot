###############
#   MODULES   #
###############

module "api" { source = "./api" }
module "create-posts" { source = "./create-posts" }
module "install" { source = "./install" }
module "uninstall" { source = "./uninstall" }
module "send-post" { source = "./send-post" }
