output "node_group_id" {
  value = aws_eks_node_group.this.id
}

output "node_group_arn" {
  value = aws_eks_node_group.this.arn
}

output "node_group_status" {
  value = aws_eks_node_group.this.status
}

output "autoscaling_group_names" {
  description = "Names of the Auto Scaling Groups created by the node group"
  value       = [for r in aws_eks_node_group.this.resources : r.autoscaling_groups[*].name][0]
}
