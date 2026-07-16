output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "terraform_plan_role_arn" {
  description = "ARN of the IAM role used by the Terraform Plan workflow."
  value       = aws_iam_role.terraform_plan.arn
}
