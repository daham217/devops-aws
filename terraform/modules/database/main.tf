###############################################################################
# modules/database/main.tf
# RDS PostgreSQL — Single-AZ, encrypted, automated backups
# Demo: single-AZ to save cost (~$13/mo vs ~$26/mo for Multi-AZ)
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ── DB Subnet Group ───────────────────────────────────────────────────────────
# Needs 2 subnets in different AZs even for single-AZ (AWS requirement)

resource "aws_db_subnet_group" "main" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Subnet group for ${local.name_prefix} RDS"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

# ── DB Parameter Group ────────────────────────────────────────────────────────

resource "aws_db_parameter_group" "main" {
  name        = "${local.name_prefix}-pg16"
  family      = "postgres16"
  description = "Parameter group for ${local.name_prefix}"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Name = "${local.name_prefix}-pg16"
  }
}

# ── RDS PostgreSQL Instance ───────────────────────────────────────────────────

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-postgres"

  # Engine
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = var.db_instance_class
  parameter_group_name = aws_db_parameter_group.main.name

  # Storage
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  # Credentials
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  # Network — private, no public access
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_security_group_id]
  publicly_accessible    = false

  # Single-AZ for demo (saves ~$13/mo vs Multi-AZ)
  multi_az = false

  # Backups
  backup_retention_period  = 3
  backup_window            = "03:00-04:00"
  maintenance_window       = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot    = true
  skip_final_snapshot      = true  # Easy teardown for demo

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled    = false # Saves cost

  # No deletion protection — easy teardown for demo
  deletion_protection = false

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}
