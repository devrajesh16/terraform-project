# POC Workflow — Setup → Validate → Destroy

## Prerequisites

```bash
# Install required tools
aws --version          # AWS CLI v2
terraform --version    # >= 1.6.0
kubectl version --client
```

```bash
# Configure AWS credentials
aws configure
# AWS Access Key ID     : <your key>
# AWS Secret Access Key : <your secret>
# Default region name   : us-east-1
# Default output format : json

# Verify identity
aws sts get-caller-identity
```

---

## Step 1 — Bootstrap Remote State (once)

> **Via Jenkins (recommended):** Skip this step entirely — the pipeline's Bootstrap Backend stage creates the S3 bucket, DynamoDB table, and KMS key automatically on the first run. The state file is persisted in the Jenkins workspace across builds so subsequent runs are a no-op.

> **Manually (local runs only):**

```bash
cd backend/

terraform init

terraform apply \
  -var="aws_account_id=$(aws sts get-caller-identity --query Account --output text)"
```

The bucket name `mycompany-terraform-state-169588426347` is already hardcoded in every environment's `versions.tf` — no further editing needed after the bucket is created.

---

## Step 2 — Apply Dev Infrastructure

```bash
cd environments/dev/

# Create your tfvars (git-ignored)
cp terraform.tfvars.example terraform.tfvars

# Edit: set your public IP for developer_cidrs, set db_password
# Find your IP:  curl -s https://checkip.amazonaws.com
notepad terraform.tfvars   # Windows
# or: vim terraform.tfvars

terraform init

terraform plan -out=tfplan

terraform apply tfplan
```

**EKS takes ~12–15 minutes** to become ACTIVE. Node group takes another 3–5 minutes.

---

## Step 3 — Validate All Resources

### 3.1 Connect kubectl

```bash
# Command is printed in terraform output
aws eks update-kubeconfig --region us-east-1 --name mycompany-dev-eks

kubectl get nodes
# Expected: node in Ready state

kubectl get pods -A
# Expected: kube-system pods Running (coredns, kube-proxy, aws-node)
```

### 3.2 VPC

```bash
VPC_ID=$(terraform output -raw vpc_id)

aws ec2 describe-vpcs --vpc-ids $VPC_ID \
  --query 'Vpcs[0].{State:State,CIDR:CidrBlock}'
# Expected: State=available, CIDR=10.1.0.0/16

# Check subnets
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].{AZ:AvailabilityZone,CIDR:CidrBlock,Public:MapPublicIpOnLaunch}' \
  --output table
# Expected: 2 public (MapPublicIpOnLaunch=true), 2 private

# Check NAT Gateway
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --query 'NatGateways[*].{State:State,PublicIP:NatGatewayAddresses[0].PublicIp}'
# Expected: State=available
```

### 3.3 EKS Cluster

```bash
CLUSTER=$(terraform output -raw eks_cluster_name)

aws eks describe-cluster --name $CLUSTER \
  --query 'cluster.{Status:status,Version:version,Endpoint:endpoint}'
# Expected: Status=ACTIVE

aws eks describe-nodegroup \
  --cluster-name $CLUSTER \
  --nodegroup-name dev-ng \
  --query 'nodegroup.{Status:status,DesiredSize:scalingConfig.desiredSize,Instances:instanceTypes}'
# Expected: Status=ACTIVE
```

### 3.4 RDS

```bash
aws rds describe-db-instances \
  --db-instance-identifier mycompany-dev-postgres \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Engine:Engine,Class:DBInstanceClass,MultiAZ:MultiAZ}'
# Expected: Status=available, Engine=postgres, MultiAZ=false
```

### 3.5 ECR

```bash
aws ecr describe-repositories \
  --query 'repositories[*].{Name:repositoryName,URI:repositoryUri}' \
  --output table
# Expected: mycompany/backend-service and mycompany/frontend-service listed
```

### 3.6 IAM Roles

```bash
aws iam get-role --role-name mycompany-dev-eks-cluster-role \
  --query 'Role.{Name:RoleName,Created:CreateDate}'

aws iam get-role --role-name mycompany-dev-eks-node-role \
  --query 'Role.{Name:RoleName,Created:CreateDate}'
# Expected: both roles exist
```

### 3.7 Security Groups

```bash
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId}' \
  --output table
# Expected: alb-sg, eks-cluster-sg, eks-nodes-sg, rds-sg, redis-sg
```

### 3.8 KMS Keys

```bash
aws kms list-aliases \
  --query "Aliases[?contains(AliasName,'mycompany-dev')]"
# Expected: mycompany-dev-eks, mycompany-dev-rds, mycompany-dev-s3
```

### 3.9 Network Connectivity (from within the cluster)

```bash
# Run a quick pod to verify internet egress through NAT and DNS
kubectl run test-pod --image=busybox --restart=Never --rm -it \
  -- sh -c "nslookup google.com && wget -qO- http://ifconfig.me"
# Expected: DNS resolves, wget returns the NAT Gateway public IP
```

---

## Step 4 — Destroy Everything

```bash
cd environments/dev/

terraform destroy
# Type 'yes' when prompted

# This will:
# - Delete EKS node group first, then the cluster
# - Delete RDS (no final snapshot)
# - Delete ECR repos including any images (force_delete=true)
# - Delete KMS keys (7-day pending deletion window)
# - Delete VPC, subnets, NAT Gateway, route tables
# - Delete all IAM roles and policies
# - Delete security groups
```

**Destroy takes ~10–15 minutes.**

### Verify nothing was left behind

```bash
# Check for leftover EKS clusters
aws eks list-clusters

# Check for leftover RDS instances
aws rds describe-db-instances \
  --query 'DBInstances[*].DBInstanceIdentifier'

# Check for leftover NAT Gateways
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[*].{ID:NatGatewayId,State:State}'

# Check for leftover VPCs (excluding the default VPC)
aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=false" \
  --query 'Vpcs[*].{VPC:VpcId,CIDR:CidrBlock}'
```

If any resources show up, they can be removed manually from the AWS Console or with `aws ... delete-*` commands.

---

## Cost While Running

| Resource               | Rate           | Notes                                      |
|------------------------|----------------|--------------------------------------------|
| EKS control plane      | $0.10/hr       | Unavoidable — runs the entire time         |
| NAT Gateway x2         | $0.045/hr each | One per AZ; + $0.045/GB data processed     |
| t3.small ON_DEMAND x1  | ~$0.021/hr     | Single node, capacity_type = ON_DEMAND     |
| RDS db.t3.micro        | Free tier      | 750 hrs/month for first 12 months          |
| KMS (3 keys)           | $1/key/month   | Prorated — negligible for a POC            |
| ECR, CloudWatch, S3    | ~$0            | At POC scale                               |

**A 3-hour POC run costs roughly $0.60–$0.70.**  
Destroy immediately after validation to avoid ongoing charges.
