###############################################################################
# outputs.tf — Key values after terraform apply
###############################################################################

output "app_url" {
  description = "Application URL — open this in your browser"
  value       = "http://${module.ecs.alb_dns_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.ecs.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL — push your Docker image here"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (private — only accessible from ECS)"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 bucket name for file uploads"
  value       = module.storage.bucket_name
}

output "private_subnet_id_0" {
  description = "First private subnet ID (for running one-off ECS tasks)"
  value       = module.networking.private_subnet_id_0
}

output "ecs_security_group_id" {
  description = "ECS security group ID (for running one-off ECS tasks)"
  value       = module.security.ecs_security_group_id
}

output "deploy_commands" {
  description = "Step-by-step commands to build and deploy"
  value       = <<-EOT

    ── Step 1: Authenticate Docker to ECR ──────────────────────────────────
    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${module.ecr.repository_url}

    ── Step 2: Build and push image ────────────────────────────────────────
    docker build -t ${module.ecr.repository_url}:latest .
    docker push ${module.ecr.repository_url}:latest

    ── Step 3: Run Prisma migrations (one-off ECS task) ────────────────────
    # (see ARCHITECTURE.md for the full command)

    ── Step 4: Force new ECS deployment ────────────────────────────────────
    aws ecs update-service \
      --cluster ${module.ecs.cluster_name} \
      --service ${module.ecs.service_name} \
      --force-new-deployment \
      --region ${var.aws_region}

    ── App will be live at ─────────────────────────────────────────────────
    http://${module.ecs.alb_dns_name}

  EOT
}
