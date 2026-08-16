locals {
  common_tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Component  = "terraform-foundation"
    Repository = var.github_repository
  }

  state_bucket_name = "${var.project_name}-tfstate-${var.aws_account_id}-${var.aws_region}"
  state_bucket_arn  = "arn:aws:s3:::${local.state_bucket_name}"

  foundation_state_arn = "${local.state_bucket_arn}/foundation/terraform.tfstate"
  foundation_lock_arn  = "${local.foundation_state_arn}.tflock"

  github_plan_role_name = "${var.project_name}-github-plan"
}