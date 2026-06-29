variable "cluster_name" {
  type = string
}

variable "node_group_name" {
  description = "e.g. system-ng or application-ng"
  type        = string
}

variable "node_role_arn" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnet IDs where nodes will be launched"
  type        = list(string)
}

variable "ami_type" {
  type    = string
  default = "AL2_x86_64"
}

variable "capacity_type" {
  description = "ON_DEMAND (stable) or SPOT (cost-saving, can be interrupted)"
  type        = string
  default     = "ON_DEMAND"
}

variable "instance_types" {
  type    = list(string)
  default = ["m5.large"]
}

variable "disk_size" {
  description = "EBS volume size in GB for each node"
  type        = number
  default     = 50
}

variable "desired_size" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 5
}

variable "labels" {
  description = "Kubernetes labels applied to nodes"
  type        = map(string)
  default     = {}
}

variable "taints" {
  description = "Kubernetes taints applied to nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for EBS volume encryption"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
