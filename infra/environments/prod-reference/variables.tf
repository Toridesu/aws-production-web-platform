variable "aws_account_id" {
  description = "AWS account ID that Terraform is allowed to manage."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "Primary AWS Region for this environment."
  type        = string
  default     = "ap-northeast-1"

  validation {
    condition     = var.aws_region == "ap-northeast-1"
    error_message = "The prod-reference environment must run in ap-northeast-1."
  }
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "aws-production-web-platform"
}
