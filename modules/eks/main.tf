# =============================================================================
# EKS MODULE — Production-ready Kubernetes cluster
# =============================================================================
# Features:
#   - Kubernetes 1.30 (latest stable)
#   - Private API endpoint (no public API exposure in prod)
#   - KMS encryption for Kubernetes secrets
#   - CloudWatch control-plane logging
#   - OIDC provider for IRSA (IAM Roles for Service Accounts)
# =============================================================================

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    security_group_ids      = [var.cluster_security_group_id]
    endpoint_private_access = true
    # Set to false in prod so the API server is not reachable from the Internet
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  # Encrypt Kubernetes secrets at rest using a customer-managed KMS key
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.kms_key_arn
    }
  }

  # Enable all control-plane log types for auditability
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # Cluster must not be deleted while node groups exist
  depends_on = [var.cluster_role_policy_attachment_ids]

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}

# ---------------------------------------------------------------------------
# OIDC Provider — enables IRSA (pod-level IAM roles via service accounts)
# ---------------------------------------------------------------------------
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-oidc-provider"
  })
}

# ---------------------------------------------------------------------------
# CloudWatch Log Group for EKS control plane logs
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
