variable "buckets" {
  description = "Map of bucket configurations"
  type = map(object({
    name           = string
    purpose        = string
    versioning     = bool
    lifecycle_days = number
  }))
}

variable "kms_key_arn" {
  type = string
}

variable "elb_account_id" {
  description = "AWS account ID of the ELB service in your region (for ALB access log bucket policy)"
  type        = string
  # us-east-1 value — change per region: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
  default = "127311923021"
}

variable "tags" {
  type    = map(string)
  default = {}
}
