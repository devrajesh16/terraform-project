# =============================================================================
# PRODUCTION ENVIRONMENT
# =============================================================================
# Orchestrates all modules to create the full production AWS infrastructure.
# =============================================================================

locals {
  env          = "prod"
  name_prefix  = "${var.project_name}-${local.env}"
  cluster_name = "${var.project_name}-${local.env}-eks"

  common_tags = {
    Environment = local.env
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# KMS Keys
# ---------------------------------------------------------------------------
module "kms" {
  source      = "../../modules/kms"
  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = true
  enable_flow_logs     = true
  tags                 = local.common_tags
}

# ---------------------------------------------------------------------------
# S3 Buckets (ALB logs, application assets)
# ---------------------------------------------------------------------------
module "s3" {
  source      = "../../modules/s3"
  kms_key_arn = module.kms.s3_kms_key_arn
  tags        = local.common_tags

  buckets = {
    alb_logs = {
      name           = "${local.name_prefix}-alb-logs"
      purpose        = "alb-logs"
      versioning     = false
      lifecycle_days = 90
    }
    app_assets = {
      name           = "${local.name_prefix}-app-assets"
      purpose        = "app-assets"
      versioning     = true
      lifecycle_days = 0
    }
  }
}

# ---------------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------------
module "security_groups" {
  source      = "../../modules/security-groups"
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# IAM Roles
# ---------------------------------------------------------------------------
module "iam" {
  source            = "../../modules/iam"
  name_prefix       = local.name_prefix
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  tags              = local.common_tags
}

# ---------------------------------------------------------------------------
# Route 53 + ACM Certificate
# ---------------------------------------------------------------------------
module "route53" {
  source          = "../../modules/route53"
  domain_name     = var.domain_name
  subdomain_names = ["app", "api"]
  alb_dns_name    = module.alb.alb_dns_name
  alb_zone_id     = module.alb.alb_zone_id
  tags            = local.common_tags
}

# ---------------------------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------------------------
module "alb" {
  source      = "../../modules/alb"
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id

  public_subnet_ids          = module.vpc.public_subnet_ids
  security_group_id          = module.security_groups.alb_sg_id
  acm_certificate_arn        = module.route53.certificate_arn
  access_log_bucket          = module.s3.bucket_ids["alb_logs"]
  enable_deletion_protection = true
  tags                       = local.common_tags
}

# ---------------------------------------------------------------------------
# EKS Cluster
# ---------------------------------------------------------------------------
module "eks" {
  source = "../../modules/eks"

  cluster_name              = local.cluster_name
  kubernetes_version        = var.kubernetes_version
  cluster_role_arn          = module.iam.eks_cluster_role_arn
  private_subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids         = module.vpc.public_subnet_ids
  cluster_security_group_id = module.security_groups.eks_cluster_sg_id
  kms_key_arn               = module.kms.eks_kms_key_arn
  endpoint_public_access    = false # prod: API server is private-only
  log_retention_days        = 90
  tags                      = local.common_tags
}

# ---------------------------------------------------------------------------
# EKS Node Groups
# ---------------------------------------------------------------------------
module "system_node_group" {
  source = "../../modules/node-group"

  cluster_name    = module.eks.cluster_name
  node_group_name = "system-ng"
  node_role_arn   = module.iam.eks_node_role_arn
  subnet_ids      = module.vpc.private_subnet_ids
  kms_key_arn     = module.kms.eks_kms_key_arn

  instance_types = ["m5.large"]
  capacity_type  = "ON_DEMAND"
  desired_size   = 2
  min_size       = 2
  max_size       = 4

  labels = { "role" = "system" }
  taints = [{
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }]

  tags = local.common_tags
}

module "application_node_group" {
  source = "../../modules/node-group"

  cluster_name    = module.eks.cluster_name
  node_group_name = "application-ng"
  node_role_arn   = module.iam.eks_node_role_arn
  subnet_ids      = module.vpc.private_subnet_ids
  kms_key_arn     = module.kms.eks_kms_key_arn

  instance_types = ["m5.xlarge"]
  capacity_type  = "ON_DEMAND"
  desired_size   = 3
  min_size       = 2
  max_size       = 10

  labels = { "role" = "application" }
  taints = []

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# ECR Repositories
# ---------------------------------------------------------------------------
module "ecr" {
  source        = "../../modules/ecr"
  name_prefix   = var.project_name
  repositories  = ["backend-service", "frontend-service", "worker-service"]
  kms_key_arn   = module.kms.s3_kms_key_arn
  node_role_arn = module.iam.eks_node_role_arn
  tags          = local.common_tags
}

# ---------------------------------------------------------------------------
# RDS PostgreSQL
# ---------------------------------------------------------------------------
module "rds" {
  source = "../../modules/rds"

  name_prefix       = local.name_prefix
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security_groups.rds_sg_id
  kms_key_arn       = module.kms.rds_kms_key_arn

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  instance_class        = "db.r6g.large"
  allocated_storage     = 100
  max_allocated_storage = 500
  multi_az              = true
  deletion_protection   = true
  skip_final_snapshot   = false

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# ElastiCache Redis
# ---------------------------------------------------------------------------
module "redis" {
  source = "../../modules/elasticache"

  name_prefix       = local.name_prefix
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security_groups.redis_sg_id
  kms_key_arn       = module.kms.rds_kms_key_arn

  node_type       = "cache.r6g.large"
  num_cache_nodes = 2

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# CloudWatch Monitoring
# ---------------------------------------------------------------------------
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  name_prefix    = local.name_prefix
  cluster_name   = module.eks.cluster_name
  db_instance_id = module.rds.db_instance_id
  alb_arn_suffix = module.alb.alb_arn
  kms_key_arn    = module.kms.s3_kms_key_arn
  alert_emails   = var.alert_emails

  tags = local.common_tags
}
