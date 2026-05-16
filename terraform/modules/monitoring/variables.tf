variable "project_name"     { type = string }
variable "environment"      { type = string }
variable "aws_region"       { type = string }
variable "ecs_cluster_name" { type = string }
variable "ecs_service_name" { type = string }
variable "alb_arn_suffix"   { type = string }
variable "rds_identifier"   { type = string }
variable "alarm_email"      { type = string }
