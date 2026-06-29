variable "aws_region" {
  description = "AWS region where the backend resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "mycompany"
}

variable "aws_account_id" {
  description = "AWS Account ID — used to make the S3 bucket name globally unique"
  type        = string
}
