# =============================================================================
# S3 MODULE — Application buckets (ALB logs, assets, backups)
# =============================================================================

resource "aws_s3_bucket" "this" {
  for_each = var.buckets
  bucket   = each.value.name

  tags = merge(var.tags, { Name = each.value.name, Purpose = each.value.purpose })
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = { for k, v in var.buckets : k => v if v.versioning }
  bucket   = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = { for k, v in var.buckets : k => v if v.lifecycle_days > 0 }
  bucket   = aws_s3_bucket.this[each.key].id

  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    expiration {
      days = each.value.lifecycle_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Grant ALB access to write access logs
resource "aws_s3_bucket_policy" "alb_logs" {
  for_each = { for k, v in var.buckets : k => v if v.purpose == "alb-logs" }
  bucket   = aws_s3_bucket.this[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.elb_account_id}:root" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.this[each.key].arn}/alb/*"
      }
    ]
  })
}
