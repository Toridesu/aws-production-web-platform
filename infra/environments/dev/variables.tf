variable "aws_account_id" {
  description = "AWS account ID that Terraform is allowed to manage."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "AWS Region for this environment."
  type        = string
  default     = "ap-northeast-1"

  validation {
    condition     = var.aws_region == "ap-northeast-1"
    error_message = "This project must run in ap-northeast-1."
  }
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "aws-production-web-platform"
}

variable "github_repository" {
  description = "GitHub repository associated with this environment."
  type        = string
  default     = "Toridesu/aws-production-web-platform"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "The dev root must use environment=dev."
  }
}

variable "availability_zones" {
  description = "The two explicitly selected Availability Zones for this environment."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct Availability Zones."
  }
}

variable "allowed_ingress_cidrs" {
  description = "Temporary /32 source CIDRs allowed to reach the Phase 5 HTTP health endpoint."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_ingress_cidrs : can(cidrhost(cidr, 0)) && endswith(trimspace(cidr), "/32")
    ])
    error_message = "allowed_ingress_cidrs must contain valid IPv4 /32 CIDRs."
  }
}

variable "image_tag" {
  description = "Immutable ECR image tag for the API task definition."
  type        = string
  default     = "bootstrap"

  validation {
    condition     = var.image_tag == "bootstrap" || can(regex("^[0-9a-f]{7,64}$", var.image_tag))
    error_message = "image_tag must be bootstrap or a hexadecimal commit SHA."
  }
}

variable "ecs_desired_count" {
  description = "Desired API task count. Set to 0 for the first dev apply before pushing an image."
  type        = number
  default     = 1

  validation {
    condition     = var.ecs_desired_count >= 0 && floor(var.ecs_desired_count) == var.ecs_desired_count
    error_message = "ecs_desired_count must be a non-negative whole number."
  }
}
