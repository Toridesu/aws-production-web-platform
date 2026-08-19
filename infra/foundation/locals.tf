locals {
  common_tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Component  = "terraform-foundation"
    Repository = var.github_repository
  }

  state_bucket_name = "${var.project_name}-tfstate-${var.aws_account_id}-${var.aws_region}"
  state_bucket_arn  = "arn:aws:s3:::${local.state_bucket_name}"

  environment_state_keys = [
    "environments/dev/terraform.tfstate",
    "environments/prod-reference/terraform.tfstate",
  ]
  environment_lock_keys = [
    for key in local.environment_state_keys : "${key}.tflock"
  ]

  github_plan_role_name = "${var.project_name}-github-plan"
}
