variable "project_name" { type = string }
variable "environment"  { type = string }
variable "db_name"      { type = string }
variable "s3_bucket"    { type = string }
variable "aws_region"   { type = string }
variable "app_url"      { type = string }

variable "db_endpoint" {
  type      = string
  sensitive = true
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}
