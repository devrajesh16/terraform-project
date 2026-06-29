# =============================================================================
# RDS MODULE — Production PostgreSQL database
# =============================================================================
# Production features:
#   - Multi-AZ deployment for automatic failover
#   - KMS encryption at rest
#   - Automated backups with 7-day retention
#   - Enhanced monitoring via CloudWatch
#   - Performance Insights enabled
#   - Deletion protection enabled
# =============================================================================

# ---------------------------------------------------------------------------
# Resolve engine version — use var.engine_version if set, otherwise fall back
# to the AWS-default PostgreSQL version so this never breaks on minor version
# deprecations.
# ---------------------------------------------------------------------------
data "aws_rds_engine_version" "postgres" {
  engine       = "postgres"
  version      = var.engine_version != "" ? var.engine_version : null
  default_only = var.engine_version == ""
}

locals {
  pg_version = data.aws_rds_engine_version.postgres.version
  pg_major   = split(".", local.pg_version)[0]
}

# ---------------------------------------------------------------------------
# DB Subnet Group — ensures RDS is placed in private subnets
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name        = "${var.name_prefix}-db-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "Private subnet group for ${var.name_prefix} RDS"

  tags = merge(var.tags, { Name = "${var.name_prefix}-db-subnet-group" })
}

# ---------------------------------------------------------------------------
# DB Parameter Group
# ---------------------------------------------------------------------------
resource "aws_db_parameter_group" "main" {
  name        = "${var.name_prefix}-postgres-params"
  family      = "postgres${local.pg_major}"
  description = "Custom parameter group for ${var.name_prefix}"

  parameter {
    # PostgreSQL 17+ uses an enum; "all" is equivalent to the old boolean true
    name  = "log_connections"
    value = "all"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries taking longer than 1 second
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# RDS Instance
# ---------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-postgres"

  engine                = "postgres"
  engine_version        = local.pg_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  # High Availability
  multi_az = var.multi_az

  # Backups
  backup_retention_period  = var.backup_retention_days
  backup_window            = "03:00-04:00"
  maintenance_window       = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot    = true
  delete_automated_backups = false

  # Monitoring
  monitoring_interval                   = 60 # Enhanced monitoring every 60 seconds
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn
  performance_insights_retention_period = 7

  # Logging to CloudWatch
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Upgrades
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false

  # Protection
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-final-snapshot"

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres" })
}

# ---------------------------------------------------------------------------
# IAM role for RDS Enhanced Monitoring
# ---------------------------------------------------------------------------
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
