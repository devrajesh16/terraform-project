variable "name_prefix" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID restricting access to the RDS instance"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for storage encryption"
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL full version (e.g. 15.4)"
  type        = string
  default     = "15.4"
}

variable "engine_version_major" {
  description = "Major PostgreSQL version for parameter group family (e.g. 15)"
  type        = string
  default     = "15"
}

variable "instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Initial storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum auto-scaled storage in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "multi_az" {
  description = "Deploy standby replica in a different AZ for automatic failover"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  description = "Prevent accidental deletion. Disable only to destroy the environment."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy. Set true only in dev."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
