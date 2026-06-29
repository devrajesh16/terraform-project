# =============================================================================
# ECR MODULE — Container image registries
# =============================================================================
# Creates one ECR repository per service listed in var.repositories.
# Each repo gets:
#   - Image scanning on push (detects CVEs automatically)
#   - A lifecycle policy that keeps only the last 30 tagged images
#   - KMS encryption
# =============================================================================

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name                 = "${var.name_prefix}/${each.value}"
  image_tag_mutability = var.image_tag_mutability
  # force_delete allows terraform destroy to succeed even if images exist in the repo
  force_delete = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}/${each.value}"
  })
}

# ---------------------------------------------------------------------------
# Lifecycle Policy — keep latest 30 images, delete untagged after 1 day
# ---------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = toset(var.repositories)
  repository = aws_ecr_repository.this[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only last 30 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release", "prod", "stage"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Repository Policy — allow the EKS node role to pull images
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

resource "aws_ecr_repository_policy" "this" {
  for_each   = toset(var.repositories)
  repository = aws_ecr_repository.this[each.value].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSNodePull"
        Effect = "Allow"
        Principal = {
          AWS = var.node_role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
