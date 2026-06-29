variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Public subnets where the ALB will be placed"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group allowing port 80 and 443 from Internet"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS termination"
  type        = string
}

variable "access_log_bucket" {
  description = "S3 bucket name for ALB access logs"
  type        = string
}

variable "enable_deletion_protection" {
  type    = bool
  default = true
}

variable "waf_web_acl_arn" {
  description = "ARN of a WAFv2 Web ACL to associate. Leave empty to skip."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
