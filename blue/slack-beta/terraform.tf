###############
#   MODULES   #
###############

module "api" { source = "./api" }
module "app-home" { source = "./app-home" }
module "delete-message" { source = "./delete-message" }
module "disable" { source = "./disable" }
module "enable" { source = "./enable" }
module "reject" { source = "./reject" }
module "screen" { source = "./screen" }
module "states-errors" { source = "./states-errors" }
module "states-retry" { source = "./states-retry" }
