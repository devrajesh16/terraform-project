# Commands Reference

## 1. Bootstrap Remote State (Run Once)

```bash
cd backend/
terraform init
terraform apply -var="aws_account_id=$(aws sts get-caller-identity --query Account --output text)"
```

## 2. Deploy an Environment

```bash
cd environments/prod/

# Copy and fill in real values — NEVER commit this file
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# Download providers and connect to the S3 backend
terraform init

# Preview all changes before touching AWS
terraform plan -out=tfplan

# Review the plan, then apply
terraform apply tfplan
```

## 3. Common Terraform Commands

```bash
# Format all .tf files in-place
terraform fmt -recursive

# Validate configuration without connecting to AWS
terraform validate

# Show the current state
terraform show

# List all resources tracked in state
terraform state list

# Import an existing AWS resource into state
terraform import module.vpc.aws_vpc.main vpc-0abc123

# Remove a resource from state without destroying it in AWS
terraform state rm module.redis.aws_elasticache_replication_group.main

# Destroy a single module/resource (use with care)
terraform destroy -target=module.redis

# Refresh state to match real AWS resources
terraform refresh

# Unlock a stuck state (get LOCK_ID from the error message)
terraform force-unlock <LOCK_ID>

# Graph module dependencies
terraform graph | dot -Tsvg > graph.svg
```

## 4. Connect kubectl to EKS

```bash
# Command is printed by terraform output as `kubeconfig_command`
aws eks update-kubeconfig \
  --region us-east-1 \
  --name mycompany-prod-eks

# Verify nodes are Ready
kubectl get nodes -o wide

# Verify system pods
kubectl get pods -A
```

## 5. Useful AWS CLI Checks

```bash
# Describe EKS cluster
aws eks describe-cluster --name mycompany-prod-eks

# Check node group status
aws eks describe-nodegroup \
  --cluster-name mycompany-prod-eks \
  --nodegroup-name application-ng

# List ECR repositories
aws ecr describe-repositories --repository-names mycompany/backend-service

# Check RDS instance status
aws rds describe-db-instances --db-instance-identifier mycompany-prod-postgres

# Check ElastiCache replication group
aws elasticache describe-replication-groups \
  --replication-group-id mycompany-prod-redis

# List CloudWatch alarms and their state
aws cloudwatch describe-alarms \
  --alarm-name-prefix mycompany-prod \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table
```

## 6. Debugging

```bash
# Why is Terraform failing?
TF_LOG=DEBUG terraform apply 2>&1 | tee tf-debug.log

# Which resources would be destroyed by a change?
terraform plan -out=tfplan
terraform show -json tfplan | jq '[.resource_changes[] | select(.change.actions[] == "delete")]'

# Check VPC flow logs (after enabling in the vpc module)
aws logs filter-log-events \
  --log-group-name /aws/vpc/mycompany-prod-flow-logs \
  --start-time $(date -d '1 hour ago' +%s000)

# List resources that Terraform manages (sanity check)
terraform state list | grep module.eks
```
