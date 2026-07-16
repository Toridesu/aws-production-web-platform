variable "aws_account_id" {
  description = "AWS account ID that Terraform is allowed to manage."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "Primary AWS Region for this project."
  type        = string
  default     = "ap-northeast-1"

  validation {
    condition     = var.aws_region == "ap-northeast-1"
    error_message = "Phase 4 must run in ap-northeast-1."
  }
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the Terraform plan role."
  type        = string
  default     = "Toridesu/aws-production-web-platform"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must use the owner/repository format."
  }
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "aws-production-web-platform"
}
