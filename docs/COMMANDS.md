# Commands Reference

## 1. Bootstrap Remote State (Run Once)

```bash
cd backend/
terraform init
terraform apply -var="aws_account_id=<YOUR_ACCOUNT_ID>"
```

## 2. Deploy an Environment

```bash
# From repo root
cd environments/prod/

# Copy and fill in secrets
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# Initialise — downloads providers, connects to S3 backend
terraform init

# Preview changes — ALWAYS do this before apply
terraform plan -out=tfplan

# Read the plan output carefully, then apply
terraform apply tfplan
```

## 3. Common Terraform Commands

```bash
# Format all .tf files in place
terraform fmt -recursive

# Validate configuration without connecting to AWS
terraform validate

# Show current state
terraform show

# List resources in state
terraform state list

# Import an existing resource (e.g. a manually-created S3 bucket)
terraform import module.s3.aws_s3_bucket.this["alb_logs"] my-existing-bucket

# Remove a resource from state without destroying it
terraform state rm module.s3.aws_s3_bucket.this["alb_logs"]

# Destroy a single resource
terraform destroy -target=module.redis

# Refresh state from real AWS resources
terraform refresh

# Unlock a stuck state
terraform force-unlock <LOCK_ID>
```

## 4. Connect kubectl to EKS

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name mycompany-prod-eks

# Verify
kubectl get nodes
kubectl get pods -A
```

## 5. ECR Image Push

```bash
# Authenticate
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS \
    --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

# Build & push
docker build -t mycompany/backend-service:v1.2.3 .
docker tag mycompany/backend-service:v1.2.3 \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/mycompany/backend-service:v1.2.3
docker push \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/mycompany/backend-service:v1.2.3

# Or use the helper script:
./scripts/ecr-push.sh backend-service v1.2.3 us-east-1 123456789012
```

## 6. Helm Deployment

```bash
# Install / upgrade application
helm upgrade --install myapp ./helm-chart \
  --namespace production \
  --create-namespace \
  --set image.repository=123456789012.dkr.ecr.us-east-1.amazonaws.com/mycompany/backend-service \
  --set image.tag=v1.2.3 \
  --wait --atomic

# List releases
helm list -A

# Show release history
helm history myapp -n production

# Rollback to previous version
helm rollback myapp 1 -n production

# Uninstall
helm uninstall myapp -n production
```

## 7. Debugging

```bash
# Check EKS cluster status
aws eks describe-cluster --name mycompany-prod-eks

# Check node group status
aws eks describe-nodegroup \
  --cluster-name mycompany-prod-eks \
  --nodegroup-name application-ng

# Pod logs
kubectl logs -f deployment/myapp-myapp -n production

# Exec into a pod
kubectl exec -it deployment/myapp-myapp -n production -- /bin/sh

# Check ingress
kubectl describe ingress -n production

# Check ALB events
kubectl get events -n production --sort-by='.lastTimestamp'
```
