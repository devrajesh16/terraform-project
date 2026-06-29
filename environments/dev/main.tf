# =============================================================================
# DEV ENVIRONMENT — Minimal footprint for POC (apply → validate → destroy)
# =============================================================================
# Estimated cost while running:
#   EKS control plane : ~$0.10/hr  ($72/mo) — unavoidable for EKS
#   NAT Gateway       : ~$0.045/hr ($33/mo)
#   EC2 nodes (SPOT)  : ~$0.007/hr ($5/mo)  — t3.small x1
#   RDS db.t3.micro   : free tier (750 hrs/mo for first 12 months)
#   KMS keys          : $1/key/mo  ($3/mo)
#   ECR, S3, CW       : effectively $0 at POC scale
# ─────────────────────────────────────────────────────────────────────────────
# Destroy is safe:  deletion_protection=false, skip_final_snapshot=true,
#                   force_delete=true on ECR
# =============================================================================

locals {
  env          = "dev"
  name_prefix  = "${var.project_name}-${local.env}"
  cluster_name = "${var.project_name}-${local.env}-eks"

  common_tags = {
    Environment = local.env
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# KMS  ($1/key/month × 3 keys = $3/month)
# ---------------------------------------------------------------------------
module "kms" {
  source                  = "../../modules/kms"
  name_prefix             = local.name_prefix
  deletion_window_in_days = 7   # Minimum allowed — keys purge quickly after destroy
  tags                    = local.common_tags
}

# ---------------------------------------------------------------------------
# VPC  — 2 AZs, single NAT Gateway to minimise cost
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  cluster_name         = local.cluster_name
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]
  enable_nat_gateway   = true
  enable_flow_logs     = false
  tags                 = local.common_tags
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
# EKS Cluster  (public endpoint — no VPN needed for POC validation)
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
  endpoint_public_access    = true
  public_access_cidrs       = var.developer_cidrs
  log_retention_days        = 7
  tags                      = local.common_tags
}

# ---------------------------------------------------------------------------
# Node Group  — t3.small SPOT, 1 node minimum (cheapest viable EKS worker)
# ---------------------------------------------------------------------------
module "node_group" {
  source = "../../modules/node-group"

  cluster_name    = module.eks.cluster_name
  node_group_name = "dev-ng"
  node_role_arn   = module.iam.eks_node_role_arn
  subnet_ids      = module.vpc.private_subnet_ids
  kms_key_arn     = module.kms.eks_kms_key_arn

  instance_types = ["t3.small"]
  capacity_type  = "ON_DEMAND"
  desired_size   = 1
  min_size       = 1
  max_size       = 3

  labels = { "role" = "dev" }
  taints = []

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# ECR  — force_delete=true so terraform destroy succeeds even if images exist
# ---------------------------------------------------------------------------
module "ecr" {
  source        = "../../modules/ecr"
  name_prefix   = var.project_name
  repositories  = ["backend-service", "frontend-service"]
  kms_key_arn   = module.kms.s3_kms_key_arn
  node_role_arn = module.iam.eks_node_role_arn
  force_delete  = true
  tags          = local.common_tags
}

# ---------------------------------------------------------------------------
# RDS PostgreSQL  — db.t3.micro is AWS Free Tier eligible (first 12 months)
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

  instance_class        = "db.t3.micro"   # Free tier eligible
  allocated_storage     = 20              # 20 GB — free tier limit
  max_allocated_storage = 20              # Disable autoscaling for POC
  multi_az              = false           # No standby in dev
  deletion_protection   = false           # Must be false for destroy to work
  skip_final_snapshot   = true            # No snapshot on destroy

  tags = local.common_tags
}
