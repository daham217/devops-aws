###############################################################################
# modules/secrets/main.tf
# AWS Secrets Manager — stores all app secrets
# Well-Architected Security: no static credentials in env vars or code
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.name_prefix}/app-secrets"
  description             = "All application secrets for ${local.name_prefix}"
  recovery_window_in_days = 7

  tags = {
    Name = "${local.name_prefix}-app-secrets"
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    DATABASE_URL          = "postgresql://${var.db_username}:${var.db_password}@${var.db_endpoint}/${var.db_name}"
    AWS_REGION            = var.aws_region
    AWS_S3_BUCKET         = var.s3_bucket
    NEXT_PUBLIC_API_URL   = var.app_url
    NODE_ENV              = "production"
  })
}
