resource "random_string" "n8n_encryption_key" {
  length  = 64
  special = false # n8n might have issues with special characters in this key, keeping it alphanumeric
}

resource "aws_secretsmanager_secret" "n8n_encryption_key" {
  name        = "${var.prefix}/n8n/encryption_key"
  description = "n8n encryption key"
}

resource "aws_secretsmanager_secret_version" "n8n_encryption_key" {
  secret_id     = aws_secretsmanager_secret.n8n_encryption_key.id
  secret_string = random_string.n8n_encryption_key.result
}

resource "random_password" "db_master_password" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()"
}

resource "aws_secretsmanager_secret" "db_master_password" {
  name        = "${var.prefix}/rds/master_password"
  description = "RDS master user password"
}

resource "aws_secretsmanager_secret_version" "db_master_password" {
  secret_id     = aws_secretsmanager_secret.db_master_password.id
  secret_string = random_password.db_master_password.result
} 