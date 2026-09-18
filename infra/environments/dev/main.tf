data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

check "account_and_region_guard" {
  assert {
    condition = (
      data.aws_caller_identity.current.account_id == var.aws_account_id
      && data.aws_region.current.region == var.aws_region
    )
    error_message = "The authenticated AWS account or region does not match the configured environment."
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix              = local.name_prefix
  vpc_cidr                 = "10.20.0.0/16"
  availability_zones       = var.availability_zones
  public_subnet_cidrs      = ["10.20.0.0/20", "10.20.16.0/20"]
  application_subnet_cidrs = ["10.20.32.0/20", "10.20.48.0/20"]
  database_subnet_cidrs    = ["10.20.64.0/20", "10.20.80.0/20"]
  nat_gateway_count        = 1
}

module "container_platform" {
  source = "../../modules/container_platform"

  name_prefix                       = local.name_prefix
  vpc_id                            = module.network.vpc_id
  public_subnet_ids                 = module.network.public_subnet_ids
  application_subnet_ids            = module.network.application_subnet_ids
  allowed_ingress_cidrs             = var.allowed_ingress_cidrs
  ecr_force_delete                  = true
  ecr_keep_last_images              = 5
  log_retention_days                = 7
  enable_container_insights         = false
  alb_deletion_protection           = false
  image_tag                         = var.image_tag
  ecs_desired_count                 = var.ecs_desired_count
  task_cpu                          = 256
  task_memory                       = 512
  health_check_grace_period_seconds = 60
}
