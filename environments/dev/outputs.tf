output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT Gateways — add to external firewall allowlists if needed"
  value       = module.vpc.nat_gateway_public_ips
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "ecr_repository_urls" {
  description = "ECR repo URLs — use these in your app CI to push images"
  value       = module.ecr.repository_urls
}

output "rds_endpoint" {
  description = "RDS connection endpoint (host:port)"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "rds_db_name" {
  value = module.rds.db_name
}

output "kubeconfig_command" {
  description = "Run this after apply to connect kubectl to the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
