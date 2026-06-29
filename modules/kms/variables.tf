variable "name_prefix" {
  description = "Prefix for KMS key aliases"
  type        = string
}

variable "deletion_window_in_days" {
  description = "Days before a deleted KMS key is permanently removed (7–30). Use 7 for dev/POC so keys are purged quickly after destroy."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
