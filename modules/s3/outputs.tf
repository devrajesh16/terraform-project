output "bucket_ids" {
  description = "Map of bucket key -> bucket name"
  value       = { for k, v in aws_s3_bucket.this : k => v.id }
}

output "bucket_arns" {
  description = "Map of bucket key -> ARN"
  value       = { for k, v in aws_s3_bucket.this : k => v.arn }
}
