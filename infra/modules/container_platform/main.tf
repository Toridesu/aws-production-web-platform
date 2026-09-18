data "aws_region" "current" {}

locals {
  base_tags = merge(var.tags, {
    Component = "container-platform"
  })

  ecr_repository_arn = aws_ecr_repository.api.arn
  log_group_arn      = aws_cloudwatch_log_group.api.arn
}

resource "aws_ecr_repository" "api" {
  name                 = "${var.name_prefix}-api"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-api"
  })
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after one image remains."
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the configured number of recent images."
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_keep_last_images
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-cluster"
  })
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.name_prefix}/api"
  retention_in_days = var.log_retention_days

  tags = merge(local.base_tags, {
    Name = "/ecs/${var.name_prefix}/api"
  })
}

resource "aws_iam_role" "task_execution" {
  name = "${var.name_prefix}-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-task-execution"
  })
}

resource "aws_iam_role_policy" "task_execution" {
  name = "${var.name_prefix}-task-execution"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EcrAuthorization"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
        ]
        Resource = "*"
      },
      {
        Sid    = "EcrPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = local.ecr_repository_arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${local.log_group_arn}:*"
      },
    ]
  })
}

resource "aws_iam_role" "api_task" {
  name = "${var.name_prefix}-api-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-api-task"
  })
}

resource "aws_security_group" "alb" {
  count = var.vpc_id == null ? 0 : 1

  name                   = "${var.name_prefix}-alb"
  description            = "ALB security group for the ${var.name_prefix} environment."
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
  egress                 = []

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-alb"
  })
}

resource "aws_security_group" "ecs" {
  count = var.vpc_id == null ? 0 : 1

  name                   = "${var.name_prefix}-ecs"
  description            = "ECS task security group for the ${var.name_prefix} environment."
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
  egress                 = []

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-ecs"
  })
}

resource "aws_security_group" "rds" {
  count = var.vpc_id == null ? 0 : 1

  name                   = "${var.name_prefix}-rds"
  description            = "Future RDS security group for the ${var.name_prefix} environment."
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
  egress                 = []

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-rds"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = var.vpc_id == null ? toset([]) : var.allowed_ingress_cidrs

  security_group_id = aws_security_group.alb[0].id
  cidr_ipv4         = each.value
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  description       = "Temporary Phase 5 validation access from an approved /32."
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  count = var.vpc_id == null ? 0 : 1

  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = aws_security_group.ecs[0].id
  from_port                    = var.target_port
  ip_protocol                  = "tcp"
  to_port                      = var.target_port
  description                  = "ALB may reach the API container port."
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  count = var.vpc_id == null ? 0 : 1

  security_group_id            = aws_security_group.ecs[0].id
  referenced_security_group_id = aws_security_group.alb[0].id
  from_port                    = var.target_port
  ip_protocol                  = "tcp"
  to_port                      = var.target_port
  description                  = "Only the ALB may reach the API container port."
}

resource "aws_vpc_security_group_egress_rule" "ecs_https" {
  count = var.vpc_id == null ? 0 : 1

  security_group_id = aws_security_group.ecs[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  description       = "ECS tasks need HTTPS for ECR and CloudWatch Logs through NAT."
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  count = var.vpc_id == null ? 0 : 1

  security_group_id            = aws_security_group.ecs[0].id
  referenced_security_group_id = aws_security_group.rds[0].id
  from_port                    = 5432
  ip_protocol                  = "tcp"
  to_port                      = 5432
  description                  = "Future API database access."
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  count = var.vpc_id == null ? 0 : 1

  security_group_id            = aws_security_group.rds[0].id
  referenced_security_group_id = aws_security_group.ecs[0].id
  from_port                    = 5432
  ip_protocol                  = "tcp"
  to_port                      = 5432
  description                  = "Only ECS tasks may reach the future RDS port."
}

resource "aws_lb" "api" {
  count = var.vpc_id == null ? 0 : 1

  name                       = substr(replace("${var.name_prefix}-alb", "_", "-"), 0, 32)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb[0].id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = var.alb_deletion_protection

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "api" {
  count = var.vpc_id == null ? 0 : 1

  name        = substr(replace("${var.name_prefix}-api-tg", "_", "-"), 0, 32)
  port        = var.target_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-api-tg"
  })
}

resource "aws_lb_listener" "http" {
  count = var.vpc_id == null ? 0 : 1

  load_balancer_arn = aws_lb.api[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "access denied"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "health" {
  count = var.vpc_id == null ? 0 : 1

  listener_arn = aws_lb_listener.http[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api[0].arn
  }

  condition {
    path_pattern {
      values = [var.health_check_path]
    }
  }
}

resource "aws_ecs_task_definition" "api" {
  count = var.vpc_id == null ? 0 : 1

  family                   = "${var.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.api_task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${aws_ecr_repository.api.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          name          = "http"
          containerPort = var.target_port
          hostPort      = var.target_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "APP_ADDRESS"
          value = ":${var.target_port}"
        },
        {
          name  = "AUTH_MODE"
          value = "deny-all"
        },
        {
          name  = "LOG_LEVEL"
          value = "info"
        },
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "wget -q -O - http://127.0.0.1:${var.target_port}${var.health_check_path} || exit 1",
        ]
        interval    = 10
        timeout     = 3
        retries     = 3
        startPeriod = 5
      }

      readonlyRootFilesystem = true

      linuxParameters = {
        initProcessEnabled = true
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "api"
        }
      }
    }
  ])

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-api"
  })
}

resource "aws_ecs_service" "api" {
  count = var.vpc_id == null ? 0 : 1

  name                               = "${var.name_prefix}-api"
  cluster                            = aws_ecs_cluster.this.arn
  task_definition                    = aws_ecs_task_definition.api[0].arn
  desired_count                      = var.ecs_desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.application_subnet_ids
    security_groups  = [aws_security_group.ecs[0].id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api[0].arn
    container_name   = "api"
    container_port   = var.target_port
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-api"
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  count = var.vpc_id == null ? 0 : 1

  alarm_name          = "${var.name_prefix}-alb-target-5xx"
  alarm_description   = "ALB target returned one or more 5xx responses."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.api[0].arn_suffix
    TargetGroup  = aws_lb_target_group.api[0].arn_suffix
  }

  tags = local.base_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count = var.vpc_id == null ? 0 : 1

  alarm_name          = "${var.name_prefix}-alb-unhealthy-hosts"
  alarm_description   = "The ALB has one or more unhealthy targets."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.api[0].arn_suffix
    TargetGroup  = aws_lb_target_group.api[0].arn_suffix
  }

  tags = local.base_tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  count = var.vpc_id == null ? 0 : 1

  alarm_name          = "${var.name_prefix}-ecs-cpu-high"
  alarm_description   = "The ECS service CPU utilization is high."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.api[0].name
  }

  tags = local.base_tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  count = var.vpc_id == null ? 0 : 1

  alarm_name          = "${var.name_prefix}-ecs-memory-high"
  alarm_description   = "The ECS service memory utilization is high."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.api[0].name
  }

  tags = local.base_tags
}
