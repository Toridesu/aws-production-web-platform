output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state."
  value       = aws_s3_bucket.terraform_state.id
}

output "bootstrap_state_key" {
  description = "S3 object key used by the bootstrap root module."
  value       = "bootstrap/terraform.tfstate"
}
