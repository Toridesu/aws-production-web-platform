variable "name_prefix" {
  description = "Prefix used for network resource names."
  type        = string

  validation {
    condition     = trimspace(var.name_prefix) != ""
    error_message = "name_prefix must not be empty."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Exactly two Availability Zones used by the environment."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct Availability Zones."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets, in AZ order."
  type        = list(string)

  validation {
    condition = (
      length(var.public_subnet_cidrs) == 2
      && alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))])
    )
    error_message = "public_subnet_cidrs must contain two valid IPv4 CIDR blocks."
  }
}

variable "application_subnet_cidrs" {
  description = "CIDR blocks for the two private application subnets, in AZ order."
  type        = list(string)

  validation {
    condition = (
      length(var.application_subnet_cidrs) == 2
      && alltrue([for cidr in var.application_subnet_cidrs : can(cidrhost(cidr, 0))])
    )
    error_message = "application_subnet_cidrs must contain two valid IPv4 CIDR blocks."
  }
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for the two private database subnets, in AZ order."
  type        = list(string)

  validation {
    condition = (
      length(var.database_subnet_cidrs) == 2
      && alltrue([for cidr in var.database_subnet_cidrs : can(cidrhost(cidr, 0))])
    )
    error_message = "database_subnet_cidrs must contain two valid IPv4 CIDR blocks."
  }
}

variable "nat_gateway_count" {
  description = "Number of NAT Gateways. Use one for dev or one per AZ for prod-reference."
  type        = number

  validation {
    condition     = contains([1, 2], var.nat_gateway_count)
    error_message = "nat_gateway_count must be 1 or 2."
  }
}

variable "tags" {
  description = "Common tags applied to network resources."
  type        = map(string)
  default     = {}
}
