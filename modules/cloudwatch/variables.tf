variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  description = "EKS cluster name for Container Insights metrics"
  type        = string
}

variable "db_instance_id" {
  description = "RDS DB instance identifier"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (used in CloudWatch dimensions)"
  type        = string
}

variable "sns_topic_arn" {
  description = "Existing SNS topic ARN. Leave empty to create a new one."
  type        = string
  default     = ""
}

variable "alert_emails" {
  description = "Email addresses to receive alarm notifications"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key for SNS topic encryption"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
