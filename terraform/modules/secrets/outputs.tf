output "secret_arn" {
  value     = aws_secretsmanager_secret.app.arn
  sensitive = true
}

output "secret_name" {
  value = aws_secretsmanager_secret.app.name
}
