output "bootstrap_state_key" {
  description = "S3 object key used by the bootstrap remote state."
  value       = "bootstrap/terraform.tfstate"
}

output "state_bucket_name" {
  description = "Name of the S3 bucket used for Terraform state."
  value       = local.state_bucket_name
}