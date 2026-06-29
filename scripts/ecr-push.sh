#!/usr/bin/env bash
# =============================================================================
# ECR Image Build & Push Script
# =============================================================================
# Usage:
#   ./scripts/ecr-push.sh <service-name> <image-tag> <aws-region> <account-id>
#
# Example:
#   ./scripts/ecr-push.sh backend-service v1.2.3 us-east-1 123456789012
# =============================================================================
set -euo pipefail

SERVICE_NAME="${1:?Usage: $0 <service-name> <tag> <region> <account-id>}"
IMAGE_TAG="${2:?Usage: $0 <service-name> <tag> <region> <account-id>}"
AWS_REGION="${3:-us-east-1}"
ACCOUNT_ID="${4:?Usage: $0 <service-name> <tag> <region> <account-id>}"
PROJECT_NAME="${PROJECT_NAME:-mycompany}"

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPO="${ECR_REGISTRY}/${PROJECT_NAME}/${SERVICE_NAME}"

echo "=== Authenticating with ECR ==="
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "=== Building Docker image ==="
docker build \
  --tag "${ECR_REPO}:${IMAGE_TAG}" \
  --tag "${ECR_REPO}:latest" \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --build-arg GIT_COMMIT="$(git rev-parse --short HEAD)" \
  --file "services/${SERVICE_NAME}/Dockerfile" \
  "services/${SERVICE_NAME}"

echo "=== Pushing image to ECR ==="
docker push "${ECR_REPO}:${IMAGE_TAG}"
docker push "${ECR_REPO}:latest"

echo "=== Image pushed successfully ==="
echo "Repository : ${ECR_REPO}"
echo "Tag        : ${IMAGE_TAG}"
