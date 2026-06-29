variable "name_prefix" {
  description = "Prefix / namespace for repository names (e.g. mycompany)"
  type        = string
}

variable "repositories" {
  description = "List of repository short names to create"
  type        = list(string)
  default     = ["backend-service", "frontend-service"]
}

variable "image_tag_mutability" {
  description = "MUTABLE or IMMUTABLE. Immutable tags prevent overwriting released images."
  type        = string
  default     = "IMMUTABLE"
}

variable "force_delete" {
  description = "Delete the repository even if it contains images. Set true for dev/POC so terraform destroy works cleanly."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for image encryption"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN of the EKS node group — granted pull access"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
