locals {
  common_tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Component  = "terraform-foundation"
    Repository = var.github_repository
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = local.common_tags
  }
}
