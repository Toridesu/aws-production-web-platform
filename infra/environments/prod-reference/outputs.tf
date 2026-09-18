output "vpc_id" {
  description = "ID of the production reference VPC."
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the production reference Application Load Balancer."
  value       = module.container_platform.alb_dns_name
}

output "ecr_repository_url" {
  description = "URL of the production reference API ECR repository."
  value       = module.container_platform.ecr_repository_url
}

output "ecs_service_name" {
  description = "Name of the production reference API ECS service."
  value       = module.container_platform.ecs_service_name
}

output "alarm_names" {
  description = "Names of the production reference Phase 5 CloudWatch alarms."
  value       = module.container_platform.alarm_names
}
