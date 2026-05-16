variable "project_name"          { type = string }
variable "environment"           { type = string }
variable "aws_region"            { type = string }
variable "vpc_id"                { type = string }
variable "private_subnet_ids"    { type = list(string) }
variable "public_subnet_ids"     { type = list(string) }
variable "ecs_security_group_id" { type = string }
variable "alb_security_group_id" { type = string }
variable "ecr_repository_url"    { type = string }
variable "s3_bucket_arn"         { type = string }
variable "container_cpu"         { type = number }
variable "container_memory"      { type = number }
variable "desired_count"         { type = number }

variable "secret_arn" {
  type      = string
  sensitive = true
}
