output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the dev Application Load Balancer."
  value       = module.container_platform.alb_dns_name
}

output "ecr_repository_url" {
  description = "URL of the dev API ECR repository."
  value       = module.container_platform.ecr_repository_url
}

output "ecs_service_name" {
  description = "Name of the dev API ECS service."
  value       = module.container_platform.ecs_service_name
}

output "alarm_names" {
  description = "Names of the dev Phase 5 CloudWatch alarms."
  value       = module.container_platform.alarm_names
}
