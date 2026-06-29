variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  description = "ID of the VPC where the security groups will be created"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
