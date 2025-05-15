// RDS Database (PostgreSQL)

resource "aws_db_subnet_group" "n8n_rds" {
  name       = "${var.prefix}-n8n-rds-subnet-group"
  subnet_ids = module.vpc.private_subnets // Uses private subnets from vpc.tf
  tags = {
    Name = "${var.prefix}-n8n-rds-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.prefix}-rds-sg"
  description = "Allow PostgreSQL access from ECS tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.n8n.id] // Reference to n8n task SG in ecs.tf
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-rds-sg"
  }
}

resource "aws_db_instance" "n8n_postgres" {
  identifier             = "${var.prefix}-n8n-postgres-db"
  engine                 = "postgres"
  engine_version         = "15" // Specify a recent, supported PostgreSQL version
  instance_class         = "db.t3.micro" // Or a user-defined variable
  allocated_storage      = 20            // Or a user-defined variable (GB)
  storage_type           = "gp2"
  username               = "n8nadmin" // Master username
  password               = aws_secretsmanager_secret_version.db_master_password.secret_string
  db_subnet_group_name   = aws_db_subnet_group.n8n_rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = "default.postgres15"

  db_name = "n8n" // Initial database name

  multi_az               = true // Recommended for production
  backup_retention_period = 7    // Days, recommended for production
  skip_final_snapshot    = false // Recommended to set to true for ephemeral/dev, false for prod

  publicly_accessible = false

  tags = {
    Name = "${var.prefix}-n8n-postgres-db"
  }

  # Make sure to check for the latest supported engine versions and parameter groups.
  # `apply_immediately` can be useful during development but use with caution in prod.
} 