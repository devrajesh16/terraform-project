# =============================================================================
# EKS NODE GROUP MODULE
# =============================================================================
# Creates managed node groups.  Two groups are expected per environment:
#   - system-ng   : runs cluster add-ons (CoreDNS, kube-proxy, ALB controller)
#   - application-ng : runs application workloads
# =============================================================================

resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  ami_type       = var.ami_type      # AL2_x86_64 | AL2_ARM_64 | BOTTLEROCKET_x86_64
  capacity_type  = var.capacity_type # ON_DEMAND | SPOT
  instance_types = var.instance_types
  disk_size      = var.disk_size

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    # Replace at most 1 node at a time during updates
    max_unavailable = 1
  }

  # Labels applied to every node in the group — used for pod scheduling
  labels = merge(var.labels, {
    "node-group" = var.node_group_name
  })

  dynamic "taint" {
    for_each = var.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Remote access is intentionally disabled — use SSM Session Manager instead
  # remote_access { ... }

  lifecycle {
    # Autoscaler changes desired_size; ignore to avoid drift
    ignore_changes = [scaling_config[0].desired_size]
  }

  tags = merge(var.tags, {
    Name                                            = "${var.cluster_name}-${var.node_group_name}"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  })
}

# ---------------------------------------------------------------------------
# Launch Template for custom user-data and EBS encryption
# ---------------------------------------------------------------------------
resource "aws_launch_template" "this" {
  name_prefix = "${var.cluster_name}-${var.node_group_name}-lt-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.disk_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    # IMDSv2 required — prevents SSRF-based metadata theft from pods
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.cluster_name}-${var.node_group_name}"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}
