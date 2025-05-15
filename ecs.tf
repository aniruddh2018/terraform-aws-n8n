resource "aws_ecs_cluster" "ecs" {
  name = "${var.prefix}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.ecs.name
  capacity_providers = [var.fargate_type]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = var.fargate_type
  }
}

resource "aws_cloudwatch_log_group" "logs" {
  name              = "${var.prefix}-logs"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "taskdef" {
  family             = "${var.prefix}-taskdef"
  task_role_arn      = aws_iam_role.taskrole.arn
  execution_role_arn = aws_iam_role.executionrole.arn
  container_definitions = jsonencode([
    {
      name      = "n8n"
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = 5678
          hostPort      = 5678
          protocol      = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "persistent"
          containerPath = "/home/node/.n8n"
          readOnly      = false
        }
      ]
      environment = [
        {
          name  = "WEBHOOK_URL"
          value = var.url != null ? var.url : "${var.certificate_arn == null ? "http" : "https"}://${aws_lb.main.dns_name}/"
        },
        {
          name  = "N8N_SKIP_WEBHOOK_DEREGISTRATION_SHUTDOWN"
          value = "true"
        },
        {
          name  = "GENERIC_TIMEZONE",
          value = "UTC"
        },
        {
          name  = "DB_TYPE",
          value = "postgresdb"
        },
        {
          name  = "DB_POSTGRESDB_HOST",
          value = aws_db_instance.n8n_postgres.address
        },
        {
          name  = "DB_POSTGRESDB_PORT",
          value = tostring(aws_db_instance.n8n_postgres.port)
        },
        {
          name  = "DB_POSTGRESDB_DATABASE",
          value = aws_db_instance.n8n_postgres.db_name
        },
        {
          name  = "DB_POSTGRESDB_USER",
          value = aws_db_instance.n8n_postgres.username
        }
      ]
      secrets = [
        {
          name      = "N8N_ENCRYPTION_KEY",
          valueFrom = aws_secretsmanager_secret.n8n_encryption_key.arn
        },
        {
          name      = "DB_POSTGRESDB_PASSWORD",
          valueFrom = aws_secretsmanager_secret.db_master_password.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.logs.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "n8n"
        }
      }
    }
  ])
  volume {
    name = "persistent"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.main.id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.access.id
        iam             = "ENABLED"
      }
    }
  }
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
}

resource "aws_security_group" "n8n" {
  name   = "${var.prefix}-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port = 5678
    to_port   = 5678
    protocol  = "tcp"
    security_groups = [
      aws_security_group.alb.id
    ]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    description      = "Allow traffic to RDS PostgreSQL"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    security_groups  = [aws_security_group.rds.id]
  }
}

resource "aws_ecs_service" "service" {
  name            = "${var.prefix}-service"
  cluster         = aws_ecs_cluster.ecs.id
  task_definition = aws_ecs_task_definition.taskdef.arn
  desired_count   = var.desired_count
  capacity_provider_strategy {
    capacity_provider = var.fargate_type
    weight            = 100
    base              = 1
  }
  network_configuration {
    subnets = module.vpc.private_subnets
    security_groups = [
      aws_security_group.n8n.id
    ]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.ip.arn
    container_name   = "n8n"
    container_port   = 5678
  }
}
