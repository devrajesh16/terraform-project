variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "cluster_role_arn" {
  description = "ARN of the IAM role for the EKS cluster"
  type        = string
}

variable "cluster_role_policy_attachment_ids" {
  description = "Policy attachment IDs to ensure the role is fully provisioned before cluster creation"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (used for public-facing ALBs)"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "Security group ID for the EKS control plane"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encrypting Kubernetes secrets"
  type        = string
}

variable "endpoint_public_access" {
  description = "Whether to enable public API server endpoint. Disable in production."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public API endpoint (when enabled)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  description = "Days to retain EKS control plane logs in CloudWatch"
  type        = number
  default     = 90
}

variable "tags" {
  type    = map(string)
  default = {}
}
