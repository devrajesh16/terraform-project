output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform remote state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_state_lock.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt state"
  value       = aws_kms_key.terraform_state.arn
}

output "backend_config_snippet" {
  description = "Paste this backend block into each environment's versions.tf"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.bucket}"
        key            = "<environment>/terraform.tfstate"
        region         = "${var.aws_region}"
        encrypt        = true
        kms_key_id     = "${aws_kms_key.terraform_state.arn}"
        dynamodb_table = "${aws_dynamodb_table.terraform_state_lock.name}"
      }
    }
  EOT
}
