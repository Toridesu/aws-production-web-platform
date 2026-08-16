output "github_plan_role_arn" {
  description = "ARN of the GitHub Actions Plan role."
  value       = aws_iam_role.github_plan.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}