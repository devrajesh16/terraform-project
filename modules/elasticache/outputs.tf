output "primary_endpoint" {
  description = "Primary endpoint for the Redis replication group"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "reader_endpoint" {
  description = "Reader endpoint (distributes read traffic across replicas)"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "port" {
  value = 6379
}

output "replication_group_id" {
  value = aws_elasticache_replication_group.main.id
}
