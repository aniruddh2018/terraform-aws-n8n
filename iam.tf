resource "aws_iam_role" "taskrole" {
  name = "${var.prefix}-taskrole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  inline_policy {
    name = "${var.prefix}-task-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ],
          Resource = [
            "arn:aws:logs:*:*:*"
          ]
        },
        {
          Effect = "Allow",
          Action = [
            "elasticfilesystem:ClientMount",
            "elasticfilesystem:ClientWrite",
            "elasticfilesystem:ClientRootAccess",
            "elasticfilesystem:DescribeMountTargets"
          ],
          Resource = aws_efs_file_system.main.arn,
          Condition = {
            StringEquals = {
              "elasticfilesystem:AccessPointArn" = aws_efs_access_point.access.arn
            }
          }
        },
        {
          Effect = "Allow",
          Action = [
            "secretsmanager:GetSecretValue"
          ],
          Resource = [
            aws_secretsmanager_secret.n8n_encryption_key.arn,
            aws_secretsmanager_secret.db_master_password.arn
          ]
        }
      ]
    })
  }
}

resource "aws_iam_role" "executionrole" {
  name = "${var.prefix}-executionrole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}