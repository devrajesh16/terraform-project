variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "mycompany"
}

variable "developer_cidrs" {
  description = "CIDR blocks allowed to reach the EKS public API server in dev"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_username" {
  type      = string
  sensitive = true
  default   = "devuser"
}

variable "db_password" {
  type      = string
  sensitive = true
}
