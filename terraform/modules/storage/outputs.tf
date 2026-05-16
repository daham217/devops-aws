output "bucket_name"            { value = aws_s3_bucket.uploads.bucket }
output "bucket_id"              { value = aws_s3_bucket.uploads.id }
output "bucket_arn"             { value = aws_s3_bucket.uploads.arn }
output "bucket_regional_domain" { value = aws_s3_bucket.uploads.bucket_regional_domain_name }
