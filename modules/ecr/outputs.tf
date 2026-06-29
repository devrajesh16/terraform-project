output "repository_urls" {
  description = "Map of repository name -> full ECR URL"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of repository name -> ARN"
  value       = { for k, v in aws_ecr_repository.this : k => v.arn }
}

output "registry_id" {
  description = "AWS account ID where the registry lives"
  value       = values(aws_ecr_repository.this)[0].registry_id
}
