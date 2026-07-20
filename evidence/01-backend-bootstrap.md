# Step: Remote State Backend Bootstrap

## Command: aws sts get-caller-identity

{
    "UserId": "AIDAUHBDLPD7E3SPTKGSE",
    "Account": "289984444670",
    "Arn": "arn:aws:iam::289984444670:user/terraform-user"
}

## Command: terraform apply (in backend/)

Apply completed successfully — 8 resources created.

Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:

dynamodb_table_name = "terraform-project-terraform-state-lock"
s3_bucket_arn = "arn:aws:s3:::terraform-project-terraform-state-289984444670"
s3_bucket_name = "terraform-project-terraform-state-289984444670"
