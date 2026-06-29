variable "name_prefix" {
  description = "Prefix for KMS key aliases"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
