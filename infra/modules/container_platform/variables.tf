variable "name_prefix" {
  description = "Prefix used for container platform resource names."
  type        = string

  validation {
    condition     = trimspace(var.name_prefix) != ""
    error_message = "name_prefix must not be empty."
  }
}

variable "ecr_force_delete" {
  description = "Whether ECR may delete a repository that still contains images. Use true only for disposable dev environments."
  type        = bool
  default     = false
}

variable "ecr_keep_last_images" {
  description = "Number of tagged images retained by the ECR lifecycle policy."
  type        = number
  default     = 10

  validation {
    condition     = var.ecr_keep_last_images >= 1 && floor(var.ecr_keep_last_images) == var.ecr_keep_last_images
    error_message = "ecr_keep_last_images must be a positive whole number."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Log Group retention in days."
  type        = number
  default     = 7

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653,
    ], var.log_retention_days)
    error_message = "log_retention_days must be a CloudWatch Logs supported retention period."
  }
}

variable "enable_container_insights" {
  description = "Whether ECS Container Insights is enabled. Keep disabled for low-cost Phase 5 validation."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "ID of the VPC where the ALB and Security Groups are created."
  type        = string
  default     = null

  validation {
    condition     = var.vpc_id == null || trimspace(var.vpc_id) != ""
    error_message = "vpc_id must not be empty when provided."
  }
}

variable "public_subnet_ids" {
  description = "Exactly two public subnet IDs used by the internet-facing ALB."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.public_subnet_ids) == 0 || length(var.public_subnet_ids) == 2
    error_message = "public_subnet_ids must contain exactly two subnet IDs when provided."
  }
}

variable "application_subnet_ids" {
  description = "Exactly two private application subnet IDs used by ECS tasks."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.application_subnet_ids) == 0 || length(var.application_subnet_ids) == 2
    error_message = "application_subnet_ids must contain exactly two subnet IDs when provided."
  }
}

variable "allowed_ingress_cidrs" {
  description = "Temporary validation source IPv4 CIDRs allowed to reach the HTTP ALB listener."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_ingress_cidrs : can(cidrhost(cidr, 0)) && endswith(trimspace(cidr), "/32")
    ])
    error_message = "allowed_ingress_cidrs must contain valid IPv4 /32 CIDRs."
  }
}

variable "target_port" {
  description = "Port exposed by the Go API container."
  type        = number
  default     = 8080

  validation {
    condition     = var.target_port >= 1 && var.target_port <= 65535 && floor(var.target_port) == var.target_port
    error_message = "target_port must be a whole number between 1 and 65535."
  }
}

variable "health_check_path" {
  description = "ALB target health check and explicitly forwarded health path."
  type        = string
  default     = "/health/live"

  validation {
    condition     = startswith(var.health_check_path, "/") && !strcontains(var.health_check_path, "?")
    error_message = "health_check_path must be a URL path without a query string."
  }
}

variable "alb_deletion_protection" {
  description = "Whether deletion protection is enabled for the ALB."
  type        = bool
  default     = false
}

variable "image_tag" {
  description = "Immutable ECR image tag used by the ECS task definition."
  type        = string
  default     = "bootstrap"

  validation {
    condition = (
      var.image_tag == "bootstrap"
      || can(regex("^[0-9a-f]{7,64}$", var.image_tag))
    )
    error_message = "image_tag must be bootstrap or a hexadecimal commit SHA."
  }
}

variable "ecs_desired_count" {
  description = "Number of ECS tasks requested for the service."
  type        = number
  default     = 1

  validation {
    condition     = var.ecs_desired_count >= 0 && floor(var.ecs_desired_count) == var.ecs_desired_count
    error_message = "ecs_desired_count must be a non-negative whole number."
  }
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "task_cpu must be a supported Fargate CPU value."
  }
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512

  validation {
    condition     = var.task_memory >= 512 && floor(var.task_memory) == var.task_memory
    error_message = "task_memory must be a whole number of at least 512 MiB."
  }
}

variable "health_check_grace_period_seconds" {
  description = "Time for a new ECS task to start before service health checks affect deployment."
  type        = number
  default     = 60

  validation {
    condition     = var.health_check_grace_period_seconds >= 0 && floor(var.health_check_grace_period_seconds) == var.health_check_grace_period_seconds
    error_message = "health_check_grace_period_seconds must be a non-negative whole number."
  }
}

variable "tags" {
  description = "Common tags applied to container platform resources."
  type        = map(string)
  default     = {}
}
