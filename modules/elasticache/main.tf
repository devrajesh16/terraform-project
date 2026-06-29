# =============================================================================
# ELASTICACHE MODULE — Redis cluster
# =============================================================================

resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.name_prefix}-redis-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "Private subnet group for ${var.name_prefix} Redis"

  tags = var.tags
}

resource "aws_elasticache_parameter_group" "main" {
  name   = "${var.name_prefix}-redis-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = var.tags
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "Redis replication group for ${var.name_prefix}"

  node_type            = var.node_type
  port                 = 6379
  num_cache_clusters   = var.num_cache_nodes

  parameter_group_name = aws_elasticache_parameter_group.main.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [var.security_group_id]

  # TLS in-transit encryption
  transit_encryption_enabled = true
  # Encryption at rest
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn

  # Automatic failover (requires num_cache_clusters >= 2)
  automatic_failover_enabled = var.num_cache_nodes > 1 ? true : false
  multi_az_enabled           = var.num_cache_nodes > 1 ? true : false

  # Maintenance & backup
  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "03:00-04:00"
  snapshot_retention_limit = var.snapshot_retention_days

  engine_version = var.engine_version

  apply_immediately = false

  tags = merge(var.tags, { Name = "${var.name_prefix}-redis" })
}
