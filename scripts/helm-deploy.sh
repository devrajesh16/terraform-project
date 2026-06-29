#!/usr/bin/env bash
# =============================================================================
# Helm Deploy Script
# =============================================================================
# Usage:
#   ./scripts/helm-deploy.sh <environment> <image-tag>
#
# Example:
#   ./scripts/helm-deploy.sh production v1.2.3
# =============================================================================
set -euo pipefail

ENVIRONMENT="${1:?Usage: $0 <environment> <image-tag>}"
IMAGE_TAG="${2:?Usage: $0 <environment> <image-tag>}"
NAMESPACE="${NAMESPACE:-${ENVIRONMENT}}"
RELEASE_NAME="${RELEASE_NAME:-myapp}"
CHART_PATH="${CHART_PATH:-./helm-chart}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="${ACCOUNT_ID:?Set ACCOUNT_ID env var}"
PROJECT_NAME="${PROJECT_NAME:-mycompany}"

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_REPO="${ECR_REGISTRY}/${PROJECT_NAME}/backend-service"

echo "=== Updating kubeconfig ==="
aws eks update-kubeconfig \
  --region "${AWS_REGION}" \
  --name "${PROJECT_NAME}-${ENVIRONMENT}-eks"

echo "=== Creating namespace if needed ==="
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "=== Running Helm upgrade/install ==="
helm upgrade --install "${RELEASE_NAME}" "${CHART_PATH}" \
  --namespace "${NAMESPACE}" \
  --values "${CHART_PATH}/values.yaml" \
  --values "${CHART_PATH}/values-${ENVIRONMENT}.yaml" \
  --set image.repository="${IMAGE_REPO}" \
  --set image.tag="${IMAGE_TAG}" \
  --set global.environment="${ENVIRONMENT}" \
  --wait \
  --timeout 10m \
  --atomic  # rolls back automatically on failure

echo "=== Deployment status ==="
kubectl rollout status deployment/"${RELEASE_NAME}-myapp" -n "${NAMESPACE}"
kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/instance=${RELEASE_NAME}"

echo "=== Deploy complete: ${RELEASE_NAME} @ ${IMAGE_TAG} in ${NAMESPACE} ==="
