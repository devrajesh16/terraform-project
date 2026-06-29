variable "domain_name" {
  description = "Root domain name (must already be hosted in Route 53)"
  type        = string
}

variable "subdomain_names" {
  description = "List of subdomains to create A records for (e.g. [\"app\", \"api\"])"
  type        = list(string)
  default     = ["app"]
}

variable "alb_dns_name" {
  description = "DNS name of the ALB"
  type        = string
}

variable "alb_zone_id" {
  description = "Hosted zone ID of the ALB (for alias records)"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
