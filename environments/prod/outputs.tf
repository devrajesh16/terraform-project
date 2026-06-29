output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "rds_endpoint" {
  value     = module.rds.db_endpoint
  sensitive = true
}

output "redis_primary_endpoint" {
  value     = module.redis.primary_endpoint
  sensitive = true
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "cloudwatch_dashboard_url" {
  value = module.cloudwatch.dashboard_url
}

output "kubeconfig_command" {
  description = "Run this command to update your kubeconfig after apply"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
