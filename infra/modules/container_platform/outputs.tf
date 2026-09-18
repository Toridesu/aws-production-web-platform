output "ecr_repository_name" {
  description = "Name of the API ECR repository."
  value       = aws_ecr_repository.api.name
}

output "ecr_repository_url" {
  description = "URL of the API ECR repository."
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the API ECR repository."
  value       = aws_ecr_repository.api.arn
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster."
  value       = aws_ecs_cluster.this.id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "log_group_name" {
  description = "Name of the API CloudWatch Log Group."
  value       = aws_cloudwatch_log_group.api.name
}

output "task_execution_role_arn" {
  description = "ARN of the ECS Task Execution Role."
  value       = aws_iam_role.task_execution.arn
}

output "api_task_role_arn" {
  description = "ARN of the API Task Role."
  value       = aws_iam_role.api_task.arn
}

output "alb_security_group_id" {
  description = "ID of the ALB Security Group."
  value       = try(aws_security_group.alb[0].id, null)
}

output "ecs_security_group_id" {
  description = "ID of the ECS task Security Group."
  value       = try(aws_security_group.ecs[0].id, null)
}

output "rds_security_group_id" {
  description = "ID of the future RDS Security Group."
  value       = try(aws_security_group.rds[0].id, null)
}

output "alb_arn" {
  description = "ARN of the internet-facing ALB."
  value       = try(aws_lb.api[0].arn, null)
}

output "alb_dns_name" {
  description = "DNS name of the internet-facing ALB."
  value       = try(aws_lb.api[0].dns_name, null)
}

output "target_group_arn" {
  description = "ARN of the API target group."
  value       = try(aws_lb_target_group.api[0].arn, null)
}

output "http_listener_arn" {
  description = "ARN of the HTTP ALB listener."
  value       = try(aws_lb_listener.http[0].arn, null)
}

output "ecs_service_name" {
  description = "Name of the API ECS service."
  value       = try(aws_ecs_service.api[0].name, null)
}

output "task_definition_arn" {
  description = "ARN of the API ECS task definition."
  value       = try(aws_ecs_task_definition.api[0].arn, null)
}

output "alarm_names" {
  description = "Names of the Phase 5 ALB and ECS CloudWatch alarms."
  value = [
    for alarm in [
      try(aws_cloudwatch_metric_alarm.alb_target_5xx[0].alarm_name, null),
      try(aws_cloudwatch_metric_alarm.alb_unhealthy_hosts[0].alarm_name, null),
      try(aws_cloudwatch_metric_alarm.ecs_cpu[0].alarm_name, null),
      try(aws_cloudwatch_metric_alarm.ecs_memory[0].alarm_name, null),
    ] : alarm if alarm != null
  ]
}
