# Terraform AWS Cloud Foundation — Complete Training Guide

**Prepared by:** Srikanth  
**Level:** Beginner to Intermediate DevOps / Cloud Engineers  
**Goal:** Understand, deploy, and destroy a production-grade AWS infrastructure using Terraform and Jenkins CI/CD from scratch.

---

## Table of Contents

1. [What Are We Building?](#1-what-are-we-building)
2. [Tools and Concepts You Must Know First](#2-tools-and-concepts-you-must-know-first)
3. [Repository Structure Explained](#3-repository-structure-explained)
4. [Module-by-Module Breakdown](#4-module-by-module-breakdown)
5. [The Jenkins CI/CD Pipeline Explained](#5-the-jenkins-cicd-pipeline-explained)
6. [How Remote State Works](#6-how-remote-state-works)
7. [Step-by-Step: Run the Pipeline from Zero](#7-step-by-step-run-the-pipeline-from-zero)
8. [What Gets Created in AWS](#8-what-gets-created-in-aws)
9. [Common Errors and Fixes](#9-common-errors-and-fixes)
10. [How to Destroy Everything](#10-how-to-destroy-everything)
11. [Cost Awareness](#11-cost-awareness)
12. [Key Takeaways for Interviews](#12-key-takeaways-for-interviews)

---

## 1. What Are We Building?

This project provisions a **complete production-grade AWS infrastructure** using Terraform. It is the **platform layer** — the foundation on which containerised applications run.

### The Big Picture

```
Developer pushes code
        │
        ▼
   GitHub Repository
        │
        ▼
   Jenkins Pipeline  ──────────────────────────────────────────────►  AWS
   (runs inside Docker                                               ┌─────────────────────────────┐
    terraform:1.6.6)                                                │  VPC  (10.1.0.0/16)         │
        │                                                           │                             │
        │  Stages:                                                  │  Public Subnets             │
        │  1. Checkout                                              │    NAT Gateway x2           │
        │  2. Bootstrap S3 backend                                  │    (Elastic IPs)            │
        │  3. Format check                                          │                             │
        │  4. Validate                                              │  Private Subnets            │
        │  5. Init                                                  │    EKS Worker Nodes         │
        │  6. Plan                                                  │    RDS PostgreSQL           │
        │  7. Manual approval                                       │                             │
        │  8. Apply / Destroy                                       │  EKS Control Plane          │
        │                                                           │  ECR Repositories           │
        ▼                                                           │  IAM Roles                  │
   S3 Remote State                                                  │  KMS Keys                   │
   DynamoDB Lock                                                    │  CloudWatch                 │
   KMS Encryption                                                   └─────────────────────────────┘
```

### Three Environments

| Environment | Purpose | Key Difference |
|-------------|---------|----------------|
| `dev` | POC / learning | Cheapest — db.t3.micro, public EKS API, no Redis |
| `stage` | Pre-production testing | Mirrors prod at smaller scale |
| `prod` | Live traffic | Full HA, private EKS API, Multi-AZ everything |

> **In this training we work with `dev` only.**

---

## 2. Tools and Concepts You Must Know First

### Tools to Install

| Tool | Version | Why Needed |
|------|---------|-----------|
| Terraform | >= 1.6.0 | Infrastructure as Code engine |
| AWS CLI | v2 | Interact with AWS from terminal |
| kubectl | any | Connect to Kubernetes cluster |
| Git | any | Version control |
| Docker | any | Jenkins runs Terraform in a container |

### Concepts to Understand

**Infrastructure as Code (IaC)**
> Instead of clicking in the AWS Console, you write code that describes what you want. Terraform reads that code and creates/changes/deletes AWS resources automatically.

**Terraform State**
> Terraform keeps a file called `terraform.tfstate` that records every resource it has created. This file is the "memory" of your infrastructure. We store it in S3 so the whole team shares the same view.

**Modules**
> Reusable Terraform building blocks. Like functions in programming — write once, call multiple times. Each folder under `modules/` is one module.

**Remote Backend**
> Storing the Terraform state file in S3 (not on your laptop) so multiple people and Jenkins can all work from the same state.

**CI/CD Pipeline**
> An automated sequence of steps that runs every time code is pushed. Jenkins runs our pipeline: it checks formatting, validates code, shows a plan, then applies the infrastructure.

**Kubernetes (EKS)**
> AWS's managed Kubernetes service. Think of it as a cluster of servers that automatically runs and manages Docker containers.

---

## 3. Repository Structure Explained

```
terraform-cloud-foundation/
│
├── backend/                  ← Run ONCE to create S3 + DynamoDB + KMS
│   ├── main.tf               ← Creates the 3 resources for remote state
│   ├── variables.tf          ← aws_account_id variable
│   └── outputs.tf            ← Prints bucket name, table name, KMS ARN
│
├── environments/
│   ├── dev/                  ← Everything you need to deploy dev
│   │   ├── versions.tf       ← Terraform version + S3 backend address
│   │   ├── main.tf           ← Calls all modules with dev-specific values
│   │   ├── variables.tf      ← Input variables (project name, region, etc.)
│   │   └── outputs.tf        ← Prints cluster name, RDS endpoint, etc.
│   ├── stage/                ← Same structure, different values
│   └── prod/                 ← Same structure, production-scale values
│
├── modules/                  ← Reusable building blocks
│   ├── vpc/                  ← Network foundation
│   ├── kms/                  ← Encryption keys
│   ├── iam/                  ← Roles and permissions
│   ├── security-groups/      ← Firewall rules
│   ├── eks/                  ← Kubernetes cluster
│   ├── node-group/           ← Worker nodes for EKS
│   ├── ecr/                  ← Docker image registry
│   ├── rds/                  ← PostgreSQL database
│   ├── elasticache/          ← Redis cache
│   ├── alb/                  ← Load balancer
│   ├── route53/              ← DNS
│   ├── s3/                   ← Object storage
│   └── cloudwatch/           ← Monitoring and alerts
│
├── jenkins/
│   └── Jenkinsfile           ← The CI/CD pipeline definition
│
└── docs/                     ← All documentation lives here
```

### How the Pieces Connect

```
environments/dev/main.tf
        │
        │  calls module "vpc"   ──────────►  modules/vpc/main.tf
        │  calls module "kms"   ──────────►  modules/kms/main.tf
        │  calls module "iam"   ──────────►  modules/iam/main.tf
        │  calls module "eks"   ──────────►  modules/eks/main.tf
        │  calls module "rds"   ──────────►  modules/rds/main.tf
        │  ...etc
```

Think of `environments/dev/main.tf` as the **conductor** and each module as a **musician** playing its part.

---

## 4. Module-by-Module Breakdown

### 4.1 backend/ — Remote State Bootstrap

**What it creates:**
- `aws_s3_bucket` — stores `terraform.tfstate`
- `aws_dynamodb_table` — prevents two people applying at the same time (state locking)
- `aws_kms_key` — encrypts the state file at rest

**Why this runs first:**
Before any environment can store its state remotely, the S3 bucket must exist. This is the classic chicken-and-egg problem. The bootstrap runs with **local state** to create the remote state infrastructure. After this, all environments use S3.

```
First run:  terraform apply  →  creates S3 + DynamoDB + KMS  →  saves state locally
All others: terraform apply  →  state already in S3  →  no changes
```

---

### 4.2 modules/vpc — Network Foundation

**What it creates:**
- VPC with CIDR `10.1.0.0/16`
- 2 Public subnets (one per AZ) — where NAT Gateways and ALB live
- 2 Private subnets (one per AZ) — where EKS nodes and RDS live
- Internet Gateway — allows public subnets to reach the internet
- 2 NAT Gateways — allows private subnets to reach the internet (for outbound only)
- Route tables — rules for where network traffic goes

**Key concept — Public vs Private subnets:**
```
Internet
   │
   ▼
Internet Gateway  ←── attached to VPC
   │
   ▼
Public Subnet  (10.1.1.0/24, 10.1.2.0/24)
   │  Resources here have public IPs
   │  NAT Gateways live here
   │
   ▼
NAT Gateway  ←── private resources use this for outbound internet
   │
   ▼
Private Subnet  (10.1.11.0/24, 10.1.12.0/24)
   │  Resources here have NO public IPs
   │  EKS nodes, RDS live here — unreachable from internet
```

**Why private subnets matter for security:**
EKS worker nodes and RDS should never be directly accessible from the internet. They need the internet for outbound calls (downloading updates, calling AWS APIs) but incoming traffic must only come from within the VPC or the load balancer.

---

### 4.3 modules/kms — Encryption Keys

**What it creates:**
- KMS key for EKS secrets encryption
- KMS key for RDS disk encryption
- KMS key for S3 and ECR encryption

**Why KMS?**
AWS manages encryption automatically, but with KMS Customer Managed Keys (CMKs) you control who can decrypt the data. If you delete the key, the data becomes permanently inaccessible — even AWS cannot read it.

---

### 4.4 modules/iam — Roles and Permissions

**What it creates:**
- `eks-cluster-role` — the EKS control plane uses this to manage AWS resources
- `eks-node-role` — worker nodes use this to pull images from ECR, write logs to CloudWatch
- `cluster-autoscaler-role` — IRSA role for the cluster autoscaler pod
- `alb-controller-role` — IRSA role for the AWS Load Balancer Controller pod

**Key concept — IRSA (IAM Roles for Service Accounts):**
```
Old way (bad):  Give ALL nodes on the EC2 instance the same IAM role
                → Every pod on those nodes gets the same permissions

New way (IRSA): Each Kubernetes ServiceAccount maps to its own IAM role
                → Pod A gets only the permissions it needs
                → Pod B gets only its permissions
                → Zero cross-contamination
```

IRSA works via the OIDC provider that the EKS module creates. When a pod assumes a role, AWS verifies the request against the OIDC endpoint of the EKS cluster.

---

### 4.5 modules/security-groups — Firewall Rules

**What it creates:**
Five security groups — one for each tier of the application:

```
Internet
   │  443/80
   ▼
ALB Security Group
   │  30000–32767 (NodePort)
   ▼
EKS Nodes Security Group  ←── also allows: self (node-to-node), control plane
   │  5432
   ▼
RDS Security Group
   │  6379
   ▼
Redis Security Group
```

**Rule:** Each security group only allows traffic from the security group directly above it. RDS cannot be reached from the internet or the ALB — only from EKS nodes. This is called **least privilege networking**.

---

### 4.6 modules/eks — Kubernetes Cluster

**What it creates:**
- `aws_eks_cluster` — the Kubernetes control plane (managed by AWS)
- `aws_iam_openid_connect_provider` — OIDC provider for IRSA
- `aws_cloudwatch_log_group` — stores control plane logs

**Important settings in dev:**
- `endpoint_public_access = true` — you can reach the API server from your laptop
- In prod this is `false` — API server only reachable from within the VPC

**EKS architecture:**
```
┌─────────────────────────────────────────┐
│         EKS Control Plane (AWS managed) │
│  kube-apiserver, etcd, scheduler,       │
│  controller-manager                     │
│  You do NOT manage these servers        │
└─────────────┬───────────────────────────┘
              │  (secure channel)
              ▼
┌─────────────────────────────────────────┐
│         Worker Nodes (EC2 instances)    │
│  Managed by you via node groups         │
│  Runs: kubelet, kube-proxy, containerd  │
│  Runs: your application pods            │
└─────────────────────────────────────────┘
```

---

### 4.7 modules/node-group — Worker Nodes

**What it creates:**
- `aws_eks_node_group` — managed group of EC2 instances joined to EKS
- `aws_launch_template` — defines EC2 configuration (encrypted EBS, IMDSv2)

**Key settings in dev:**
```hcl
instance_types = ["t3.small"]   # Cheapest viable EKS worker
capacity_type  = "ON_DEMAND"    # Predictable, never interrupted
desired_size   = 1
min_size       = 1
max_size       = 3              # Cluster autoscaler can scale up to 3
```

**IMDSv2 — why it matters:**
```
Old (IMDSv1): Any process on the node can call http://169.254.169.254
              and steal the node's IAM credentials. A malicious pod
              could use this to attack your AWS account.

New (IMDSv2): Requires a session token first. Hops are limited to 2.
              A pod cannot reach the metadata service — only the node itself.
```

---

### 4.8 modules/ecr — Docker Image Registry

**What it creates:**
- One ECR repository per service (e.g., `mycompany/backend-service`)
- Lifecycle policy — keeps last 30 tagged images, deletes untagged after 1 day
- Repository policy — only the EKS node role can pull images

**How it fits in the workflow:**
```
Developer  →  docker build  →  docker push to ECR  →  EKS pulls from ECR
```
This repo only creates the registry. Image pushing happens in the application CI pipeline.

---

### 4.9 modules/rds — PostgreSQL Database

**What it creates:**
- `aws_db_subnet_group` — tells RDS which private subnets to use
- `aws_db_parameter_group` — custom PostgreSQL settings (connection logging, slow query logging)
- `aws_db_instance` — the actual PostgreSQL database

**Dev-specific settings:**
```hcl
instance_class        = "db.t3.micro"  # Free tier eligible
backup_retention_days = 0              # No backups (free tier restriction)
multi_az              = false          # Single AZ (saves cost)
deletion_protection   = false          # Can be destroyed by terraform destroy
skip_final_snapshot   = true           # No snapshot on destroy
```

**Engine version — dynamic resolution:**
Instead of hardcoding a PostgreSQL version (which AWS deprecates over time), the module uses a data source to automatically pick the current AWS default version:
```hcl
data "aws_rds_engine_version" "postgres" {
  engine       = "postgres"
  default_only = true
}
```

---

### 4.10 modules/cloudwatch — Monitoring

**What it creates:**
- CloudWatch Alarms — alerts when CPU, memory, error rates breach thresholds
- SNS Topic — sends email notifications when alarms fire
- CloudWatch Dashboard — single-pane view of EKS, RDS, and ALB metrics

---

## 5. The Jenkins CI/CD Pipeline Explained

The `jenkins/Jenkinsfile` defines the entire pipeline as code. Every stage runs inside a Docker container with Terraform pre-installed — nothing is installed on the Jenkins server itself.

### Pipeline Flow

```
┌─────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  Checkout   │───►│Bootstrap Backend │───►│  Format Check    │───►│    Validate      │
│             │    │(creates S3+      │    │(terraform fmt    │    │(terraform        │
│git pull +   │    │ DynamoDB+KMS if  │    │ -check)          │    │ validate)        │
│tf version   │    │ not exist)       │    │                  │    │                  │
└─────────────┘    └──────────────────┘    └──────────────────┘    └────────┬─────────┘
                                                                            │
┌─────────────┐    ┌──────────────────┐    ┌──────────────────┐            │
│   Apply /   │◄───│Manual Approval   │◄───│   Terraform Plan │◄───────────┘
│   Destroy   │    │(stage/prod/      │    │(-out=tfplan,     │
│             │    │ destroy only)    │    │ archived)        │
└─────────────┘    └──────────────────┘    └──────────────────┘
```

### Stage-by-Stage Explanation

**Stage 1: Checkout**
```groovy
checkout scm          // pulls latest code from GitHub
sh 'terraform version' // confirms the correct Terraform version
```

**Stage 2: Bootstrap Backend**
This is the most intelligent stage. It:
1. Checks if the S3 bucket already exists in Terraform state
2. If state is empty (first run or state was lost), imports existing AWS resources
3. Runs `terraform apply` — which is a no-op if everything already exists
4. Saves the state file to a persistent location in the Jenkins workspace

```bash
# The idempotency check
if ! terraform state list | grep -q "aws_s3_bucket.terraform_state"; then
    # Import each existing resource
    terraform import ... aws_s3_bucket.terraform_state mycompany-terraform-state-169588426347
    # ... import others
fi
terraform apply -auto-approve -var="aws_account_id=169588426347"
```

**Stage 3: Terraform Format Check**
```bash
terraform fmt -check -recursive -diff ../../
```
Fails the pipeline if any `.tf` file is not properly formatted. Enforces consistent code style across the team.

**Stage 4: Terraform Validate**
```bash
terraform init -backend=false   # initialise without connecting to S3
terraform validate               # checks syntax and references are valid
```
Catches errors like wrong variable names, missing required fields — without making any AWS API calls.

**Stage 5: Terraform Init**
```bash
terraform init -input=false -reconfigure
```
Downloads providers, connects to the S3 remote backend, reads existing state.

**Stage 6: Terraform Plan**
```bash
terraform plan -out=tfplan
terraform show -no-color tfplan > tfplan.txt
```
Shows exactly what will change in AWS. The `tfplan` file is archived as a Jenkins build artifact — providing an audit trail of who approved what change.

**Stage 7: Manual Approval**
Only runs for `stage`, `prod`, or any `DESTROY` operation:
```groovy
input(
    message: "Approve Terraform APPLY on prod?",
    ok: "Approve APPLY"
)
```
A human must click approve in the Jenkins UI before the pipeline proceeds.

**Stage 8: Apply / Destroy**
```bash
terraform apply -input=false -auto-approve tfplan
```
Executes exactly the plan that was reviewed and approved — no surprises.

### Key Pipeline Design Decisions

| Decision | Reason |
|----------|--------|
| Docker agent (not installed on Jenkins) | No version conflicts, reproducible builds |
| `disableConcurrentBuilds()` | Prevents two people applying to the same environment simultaneously |
| Plan archived as artifact | Audit trail — who approved what, when |
| `cleanWs()` with `.terraform-backend-state` exclusion | Clean workspace but preserve bootstrap state |
| `TF_IN_AUTOMATION=true` | Disables Terraform's interactive prompts |

---

## 6. How Remote State Works

This is one of the most important concepts to understand.

### Without Remote State (bad)
```
Person A runs terraform apply on their laptop
    → state saved to ~/project/terraform.tfstate

Person B runs terraform apply on their laptop
    → state saved to ~/project/terraform.tfstate (different file!)
    → Person B doesn't know about resources Person A created
    → CONFLICT — duplicate resources, broken infrastructure
```

### With Remote State (correct)
```
Person A runs terraform apply
    → Acquires lock in DynamoDB: "I am applying, nobody else can"
    → Downloads latest state from S3
    → Applies changes
    → Uploads updated state to S3
    → Releases DynamoDB lock

Person B tries to run terraform apply at the same time
    → Tries to acquire DynamoDB lock
    → Lock is held by Person A → Person B's apply FAILS with "state locked"
    → Person B must wait for Person A to finish
```

### Our Remote State Setup

```
S3 Bucket: mycompany-terraform-state-169588426347
    ├── dev/terraform.tfstate       ← dev environment state
    ├── stage/terraform.tfstate     ← stage environment state
    └── prod/terraform.tfstate      ← prod environment state

DynamoDB Table: mycompany-terraform-state-lock
    └── LockID entries created/deleted per terraform operation

KMS Key: alias/mycompany-terraform-state
    └── Encrypts everything in the S3 bucket at rest
```

---

## 7. Step-by-Step: Run the Pipeline from Zero

### Prerequisites Checklist

Before starting, confirm:

- [ ] AWS account created and you have an IAM user with programmatic access
- [ ] Jenkins installed and running (with Docker available)
- [ ] GitHub repository forked/cloned at `git@github.com:srikanth78933/terraform-cloud-foundation.git`
- [ ] Jenkins has access to the GitHub repo (SSH key or token configured)

### Step 1: Configure Jenkins Credentials

Go to **Jenkins → Manage Jenkins → Credentials → System → Global → Add Credential**

Add three credentials:

| Credential ID | Type | Value |
|---------------|------|-------|
| `AWS_ACCESS_KEY_ID` | Secret text | Your IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | Secret text | Your IAM user secret key |
| `TF_VAR_db_password` | Secret text | A password ≥ 8 chars (e.g. `DevPass123!`) — no `@ / " ' \` characters |

### Step 2: Create the Jenkins Pipeline Job

1. Click **New Item**
2. Name it `Terraform`
3. Select **Pipeline**
4. Under **Pipeline → Definition** select: `Pipeline script from SCM`
5. Set SCM to `Git`
6. Repository URL: `git@github.com:srikanth78933/terraform-cloud-foundation.git`
7. Credentials: select your GitHub credential
8. Branch: `*/main`
9. Script Path: `jenkins/Jenkinsfile`
10. Click **Save**

### Step 3: Run the Pipeline

1. Click **Build with Parameters**
2. Select:
   - `ENVIRONMENT`: `dev`
   - `DESTROY`: unchecked (false)
3. Click **Build**

### Step 4: Watch the Stages

The pipeline will progress through each stage. **Expected timings:**

| Stage | Expected Duration |
|-------|------------------|
| Checkout | < 30 seconds |
| Bootstrap Backend | 2–3 min (first run), < 30s after |
| Format Check | < 30 seconds |
| Validate | 1–2 min (downloads providers) |
| Init | < 30 seconds |
| Plan | 1–2 minutes |
| Apply | **15–20 minutes** (EKS takes longest) |

### Step 5: Verify the Output

After a successful apply, click **Post-Apply Outputs** stage and look for:

```
eks_cluster_name       = "mycompany-dev-eks"
eks_cluster_endpoint   = (sensitive)
kubeconfig_command     = "aws eks update-kubeconfig --region us-east-1 --name mycompany-dev-eks"
vpc_id                 = "vpc-xxxxxxxxxxxxxxxxx"
private_subnet_ids     = ["subnet-xxx", "subnet-yyy"]
rds_endpoint           = (sensitive)
ecr_repository_urls    = { backend-service = "...", frontend-service = "..." }
```

### Step 6: Connect to the EKS Cluster (optional)

Run these commands locally (requires AWS CLI + kubectl):

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name mycompany-dev-eks

# Verify nodes are ready
kubectl get nodes

# Verify system pods are running
kubectl get pods -A
```

Expected output:
```
NAME                STATUS   ROLES    AGE   VERSION
ip-10-1-11-xxx...   Ready    <none>   5m    v1.30.x
```

---

## 8. What Gets Created in AWS

After a successful `dev` apply, these resources exist in your AWS account:

### Networking (VPC Module)
| Resource | Name / ID | Details |
|----------|-----------|---------|
| VPC | mycompany-dev-vpc | 10.1.0.0/16 |
| Public Subnet x2 | mycompany-dev-public-us-east-1a/b | 10.1.1.0/24, 10.1.2.0/24 |
| Private Subnet x2 | mycompany-dev-private-us-east-1a/b | 10.1.11.0/24, 10.1.12.0/24 |
| Internet Gateway | mycompany-dev-igw | Attached to VPC |
| NAT Gateway x2 | mycompany-dev-nat-gw-* | One per AZ, in public subnets |
| Elastic IP x2 | mycompany-dev-nat-eip-* | Static IPs for NAT Gateways |
| Route Tables | public + private-1a + private-1b | Correct routes configured |

### Security (KMS + Security Groups)
| Resource | Name | Purpose |
|----------|------|---------|
| KMS Key | mycompany-dev-eks | Encrypts EKS secrets |
| KMS Key | mycompany-dev-rds | Encrypts RDS disk |
| KMS Key | mycompany-dev-s3 | Encrypts S3 and ECR |
| Security Group | mycompany-dev-alb-sg | 80/443 from internet |
| Security Group | mycompany-dev-eks-cluster-sg | Control plane communication |
| Security Group | mycompany-dev-eks-nodes-sg | Node traffic rules |
| Security Group | mycompany-dev-rds-sg | 5432 from EKS nodes only |

### Compute (EKS + Node Group)
| Resource | Name | Details |
|----------|------|---------|
| EKS Cluster | mycompany-dev-eks | Kubernetes 1.30, public endpoint |
| OIDC Provider | oidc.eks.us-east-1... | Enables IRSA |
| Node Group | dev-ng | t3.small, 1 node, ON_DEMAND |
| Launch Template | mycompany-dev-eks-dev-ng-lt | IMDSv2, encrypted EBS |
| IAM Role | mycompany-dev-eks-cluster-role | EKS control plane |
| IAM Role | mycompany-dev-eks-node-role | Worker nodes |
| IAM Role | mycompany-dev-cluster-autoscaler-role | IRSA |
| IAM Role | mycompany-dev-alb-controller-role | IRSA |

### Data Layer (RDS + ECR)
| Resource | Name | Details |
|----------|------|---------|
| RDS Instance | mycompany-dev-postgres | PostgreSQL, db.t3.micro, single-AZ |
| DB Subnet Group | mycompany-dev-db-subnet-group | Private subnets |
| DB Parameter Group | mycompany-dev-postgres-params | Logging enabled |
| ECR Repository | mycompany/backend-service | Scan on push, lifecycle policy |
| ECR Repository | mycompany/frontend-service | Scan on push, lifecycle policy |

### Observability (CloudWatch)
| Resource | Name | Details |
|----------|------|---------|
| Log Group | /aws/eks/mycompany-dev-eks/cluster | 7-day retention |
| CloudWatch Dashboard | mycompany-dev-infrastructure | EKS + RDS metrics |

### Remote State (Backend)
| Resource | Name | Details |
|----------|------|---------|
| S3 Bucket | mycompany-terraform-state-169588426347 | Versioned, KMS encrypted |
| DynamoDB Table | mycompany-terraform-state-lock | State locking |
| KMS Key | alias/mycompany-terraform-state | State file encryption |

---

## 9. Common Errors and Fixes

These are real errors encountered when running this pipeline:

### Error 1: Terraform Format Check fails

```
Error: main.tf
--- old/main.tf
+++ new/main.tf
```

**Cause:** `.tf` files have inconsistent spacing or alignment.

**Fix:** Run `terraform fmt -recursive` locally before committing:
```bash
terraform fmt -recursive
git add -A && git commit -m "style: fix terraform formatting"
```

---

### Error 2: S3 Bucket does not exist

```
Error: Failed to get existing workspaces: S3 bucket "mycompany-terraform-state-169588426347" does not exist
```

**Cause:** Backend was never bootstrapped.

**Fix:** The Bootstrap Backend stage handles this automatically. If it fails, check AWS credentials are correctly set in Jenkins.

---

### Error 3: Security group description invalid character

```
Error: "ingress.3.description" doesn't comply with restrictions
```

**Cause:** Em dash `—` in description. AWS only allows ASCII: `[0-9A-Za-z_ .:/()#,@\[\]+=&;{}!$*-]`

**Fix:** Replace em dashes with regular hyphens `-` in security group descriptions.

---

### Error 4: RDS Free Tier backup restriction

```
Error: FreeTierRestrictionError: The specified backup retention period exceeds the maximum
```

**Cause:** AWS Free Tier does not allow automated backups.

**Fix:** Set `backup_retention_days = 0` in the dev environment RDS module call.

---

### Error 5: RDS version not found

```
Error: InvalidParameterCombination: Cannot find version 15.4 for postgres
```

**Cause:** AWS deprecates old PostgreSQL minor versions.

**Fix:** The module now uses `data "aws_rds_engine_version"` with `default_only = true` to always resolve a valid current version automatically.

---

### Error 6: RDS parameter invalid value

```
Error: Invalid parameter value: 1 for: log_connections
allowed values are: receipt, authentication, authorization, setup_durations, all
```

**Cause:** PostgreSQL 17 changed `log_connections` from boolean to enum.

**Fix:** Set `value = "all"` instead of `"1"` for the `log_connections` parameter group entry.

---

### Error 7: RDS password too short

```
Error: The parameter MasterUserPassword is not a valid password because it is shorter than 8 characters
```

**Cause:** `TF_VAR_db_password` Jenkins credential is less than 8 characters.

**Fix:** Update the credential in Jenkins to a password ≥ 8 characters. Avoid `@ / " ' \` characters.

---

### Error 8: Manual Approval hangs / does not respond

**Cause:** `submitterParameter` in the Jenkins `input` step can cause UI hangs.

**Fix:** The Jenkinsfile was simplified to remove `submitterParameter`. Approve by going to the Jenkins build URL and clicking the Approve button.

---

## 10. How to Destroy Everything

### Via Jenkins Pipeline

1. Click **Build with Parameters**
2. Select `ENVIRONMENT`: `dev`
3. Check `DESTROY`: ✓ (true)
4. Click **Build**
5. Pipeline will plan the destroy and pause for **Manual Approval**
6. Review the plan (62 resources will be destroyed)
7. Click **Approve DESTROY** in the Jenkins UI
8. Wait ~10–15 minutes for all resources to be deleted

### Verify Nothing Was Left Behind

Run these AWS CLI commands after destroy:

```bash
# No EKS clusters
aws eks list-clusters

# No RDS instances
aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier'

# No NAT Gateways (these cost $0.045/hr if left running)
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[*].NatGatewayId'

# No leftover VPCs
aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=false" \
  --query 'Vpcs[*].VpcId'
```

> **Note:** The S3 bucket, DynamoDB table, and KMS key (backend resources) are NOT destroyed by the environment destroy. They are protected by `lifecycle { prevent_destroy = true }`. Delete them manually from the AWS Console if you want to clean up completely.

---

## 11. Cost Awareness

### While the Dev Environment is Running

| Resource | Hourly Cost | Monthly Estimate |
|----------|------------|------------------|
| EKS Control Plane | $0.10/hr | $72 |
| NAT Gateway x2 | $0.045/hr each | $65 |
| EC2 t3.small x1 | $0.021/hr | $15 |
| RDS db.t3.micro | Free tier (12 months) | $0 |
| KMS Keys x3 | $1/key/month | $3 |
| ECR + S3 + CloudWatch | negligible | ~$0 |
| **Total** | **~$0.22/hr** | **~$155/mo** |

### For a 3-Hour POC Session

**~$0.66 total**

**Rule:** Always run `terraform destroy` immediately after you finish experimenting. The EKS control plane alone costs $0.10/hr whether you use it or not.

---

## 12. Key Takeaways for Interviews

These are the concepts you must be able to explain clearly:

**Q: What is Terraform state and why do we store it in S3?**
> State is Terraform's record of what resources it has created. Storing it in S3 means the entire team and Jenkins all work from the same source of truth. DynamoDB prevents concurrent applies from corrupting the state.

**Q: What is the difference between a Terraform module and a root module?**
> A module is a reusable block of Terraform code (like a function). The root module is the environment directory (`environments/dev`) that calls the modules and wires them together with environment-specific values.

**Q: Why do EKS worker nodes go in private subnets?**
> Worker nodes should never be directly reachable from the internet. Inbound traffic comes from the ALB via security group rules. Outbound traffic (pulling container images, calling AWS APIs) goes via the NAT Gateway. This follows the principle of least exposure.

**Q: What is IRSA and why is it better than node IAM roles?**
> IRSA (IAM Roles for Service Accounts) lets each Kubernetes pod assume its own IAM role via the OIDC provider. With node-level IAM roles, every pod on a node gets the same permissions — a compromised pod could access AWS as if it were any other pod on that node. IRSA limits the blast radius to the specific pod.

**Q: What does `terraform plan -out=tfplan` do and why is it important in CI/CD?**
> It saves the execution plan to a binary file. In CI/CD, you plan first, get human approval, then apply exactly that plan. This prevents the plan from changing between the review and the apply (which could happen if someone else changed infrastructure between the two steps).

**Q: How does state locking work?**
> When `terraform apply` starts, it writes a lock entry to DynamoDB with a unique ID. If another apply starts at the same time, it tries to write the same entry and gets a conditional write failure — meaning it sees the lock and waits or fails. When the first apply finishes, it deletes the DynamoDB entry, releasing the lock.

**Q: Why is IMDSv2 important in EKS?**
> Without IMDSv2, any pod on a node can call the EC2 metadata service at `169.254.169.254` and retrieve the node's IAM credentials — a well-known attack called SSRF credential theft. IMDSv2 requires a session token with `hop_limit=2`, which prevents pods (which are one extra hop away) from reaching the metadata service.

---

## How to Convert This Document to PDF

**Option 1: VS Code + Markdown PDF extension**
1. Install the `Markdown PDF` extension in VS Code
2. Open this file
3. Right-click → `Markdown PDF: Export (pdf)`

**Option 2: Browser**
1. Open this file in a Markdown viewer (e.g., GitHub, Typora)
2. Print → Save as PDF

**Option 3: Pandoc (command line)**
```bash
pandoc TRAINING_GUIDE.md -o TRAINING_GUIDE.pdf \
  --pdf-engine=wkhtmltopdf \
  --margin-top=20mm --margin-bottom=20mm \
  --margin-left=20mm --margin-right=20mm
```

---

*End of Training Guide*
