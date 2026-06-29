variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "mycompany"
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "developer_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. Restrict to your IP for security."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_name" {
  type    = string
  default = "devdb"
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
