# =============================================================================
# DEV ENVIRONMENT — Cost-optimised, single NAT, smaller instances
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

module "kms" {
  source      = "../../modules/kms"
  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  cluster_name         = local.cluster_name
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]
  # Single NAT GW in dev saves ~$33/month per additional NAT
  enable_nat_gateway   = true
  enable_flow_logs     = false
  tags                 = local.common_tags
}

module "security_groups" {
  source      = "../../modules/security-groups"
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  tags        = local.common_tags
}

module "iam" {
  source            = "../../modules/iam"
  name_prefix       = local.name_prefix
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  tags              = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name              = local.cluster_name
  kubernetes_version        = "1.30"
  cluster_role_arn          = module.iam.eks_cluster_role_arn
  private_subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids         = module.vpc.public_subnet_ids
  cluster_security_group_id = module.security_groups.eks_cluster_sg_id
  kms_key_arn               = module.kms.eks_kms_key_arn
  # Dev: expose API publicly so developers can kubectl without a VPN
  endpoint_public_access    = true
  public_access_cidrs       = var.developer_cidrs
  log_retention_days        = 7
  tags                      = local.common_tags
}

module "application_node_group" {
  source = "../../modules/node-group"

  cluster_name    = module.eks.cluster_name
  node_group_name = "dev-ng"
  node_role_arn   = module.iam.eks_node_role_arn
  subnet_ids      = module.vpc.private_subnet_ids
  kms_key_arn     = module.kms.eks_kms_key_arn

  # SPOT instances reduce dev compute cost by ~70%
  instance_types = ["m5.large", "m5a.large", "m4.large"]
  capacity_type  = "SPOT"
  desired_size   = 2
  min_size       = 1
  max_size       = 4

  labels = { "role" = "dev" }
  taints = []

  tags = local.common_tags
}

module "ecr" {
  source        = "../../modules/ecr"
  name_prefix   = var.project_name
  repositories  = ["backend-service", "frontend-service"]
  kms_key_arn   = module.kms.s3_kms_key_arn
  node_role_arn = module.iam.eks_node_role_arn
  tags          = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  name_prefix       = local.name_prefix
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security_groups.rds_sg_id
  kms_key_arn       = module.kms.rds_kms_key_arn

  db_name     = "devdb"
  db_username = var.db_username
  db_password = var.db_password

  instance_class        = "db.t3.medium"
  allocated_storage     = 20
  max_allocated_storage = 50
  multi_az              = false    # No Multi-AZ in dev
  deletion_protection   = false
  skip_final_snapshot   = true     # Destroy without snapshot in dev

  tags = local.common_tags
}
