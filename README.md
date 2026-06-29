# Terraform AWS Cloud Foundation

Production-ready AWS infrastructure provisioning using Terraform modules.
This repository provisions the AWS platform only — application deployment lives in a separate repo.

---

## Repository Layout

```
terraform-cloud-foundation/
│
├── backend/                     # Remote state bootstrap (run once per AWS account)
│   ├── main.tf                  # S3 bucket + DynamoDB lock table + KMS key
│   ├── variables.tf
│   └── outputs.tf
│
├── environments/
│   ├── dev/                     # Development — cost-optimised, SPOT nodes, single NAT
│   │   ├── versions.tf          # Terraform version constraint + S3 backend config
│   │   ├── main.tf              # Module calls
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── stage/                   # Staging — mirrors prod topology at reduced scale
│   └── prod/                    # Production — full HA, private EKS API, Multi-AZ
│       └── terraform.tfvars.example
│
├── modules/
│   ├── vpc/                     # VPC, public/private subnets, IGW, NAT GW, route tables, flow logs
│   ├── kms/                     # Customer-managed KMS keys for EKS, RDS, and S3
│   ├── iam/                     # EKS cluster role, node role, IRSA roles (ALB controller, autoscaler)
│   ├── security-groups/         # ALB, EKS control plane, EKS nodes, RDS, Redis security groups
│   ├── eks/                     # EKS cluster, OIDC provider, KMS secret encryption, CW logging
│   ├── node-group/              # Managed node groups — IMDSv2, encrypted EBS, launch template
│   ├── ecr/                     # ECR repositories — scan on push, lifecycle policy, repo policy
│   ├── rds/                     # RDS PostgreSQL — Multi-AZ, Enhanced Monitoring, encrypted
│   ├── elasticache/             # Redis — TLS, KMS, Multi-AZ automatic failover
│   ├── alb/                     # Application Load Balancer — HTTPS, WAF, access logs
│   ├── route53/                 # DNS A records + ACM certificate (DNS validation)
│   ├── s3/                      # Encrypted S3 buckets (ALB logs, assets)
│   └── cloudwatch/              # Alarms (CPU/memory/DB/ALB), SNS topic, dashboard
│
├── jenkins/
│   └── Jenkinsfile              # Terraform CI/CD pipeline (fmt → validate → plan → approve → apply)
│
└── docs/
    ├── ARCHITECTURE.md          # Network diagrams, CIDR table, security layer breakdown
    ├── COMMANDS.md              # All Terraform and AWS CLI commands
    └── INTERVIEW_QUESTIONS.md   # Q&A covering Terraform, VPC, EKS, IAM (3–8 YOE level)
```

---

## What This Repo Provisions

```
AWS Account
│
├── Remote State
│   ├── S3 Bucket (versioned, KMS-encrypted, access-logged)
│   └── DynamoDB Table (state locking)
│
├── KMS Customer-Managed Keys
│   ├── EKS secrets encryption key
│   ├── RDS storage encryption key
│   └── S3 encryption key
│
├── VPC  (per environment)
│   ├── Public subnets  (ALB, NAT Gateways)
│   └── Private subnets (EKS nodes, RDS, Redis)
│
├── EKS Cluster
│   ├── system-ng   node group  (ON_DEMAND, runs cluster add-ons)
│   └── application-ng node group  (runs workloads)
│
├── Data Layer
│   ├── RDS PostgreSQL  (Multi-AZ, encrypted, automated backups)
│   └── ElastiCache Redis  (TLS, encrypted, Multi-AZ failover)
│
├── Networking
│   ├── Application Load Balancer  (HTTPS, WAF, access logs)
│   └── Route 53 records + ACM certificate
│
├── ECR Repositories  (registry only — image pushes happen in app CI)
│
└── Observability
    ├── CloudWatch alarms  (EKS CPU/memory, RDS CPU/connections/storage, ALB 5xx/latency)
    ├── CloudWatch dashboard
    └── SNS alerts topic
```

---

## Environment Comparison

| Feature                | dev               | stage             | prod              |
|------------------------|-------------------|-------------------|-------------------|
| EKS API endpoint       | Public            | Private           | Private           |
| NAT Gateways           | 2 (one per AZ)    | 3 (one per AZ)    | 3 (one per AZ)    |
| Node capacity type     | ON_DEMAND         | ON_DEMAND         | ON_DEMAND         |
| Node instance type     | t3.small (x1)     | m5.large          | m5.large + m5.xlarge |
| RDS instance           | db.t3.micro       | db.t3.large       | db.r6g.large      |
| RDS Multi-AZ           | No                | Yes               | Yes               |
| RDS automated backups  | No (free tier)    | Yes               | Yes               |
| Redis nodes            | None              | 2                 | 2                 |
| Deletion protection    | No                | No                | Yes               |
| VPC Flow Logs          | No                | Yes               | Yes               |
| EKS log retention      | 7 days            | 30 days           | 90 days           |

---

## Quick Start

### Step 1 — Bootstrap remote state (once per AWS account)

> **Via Jenkins (recommended):** The pipeline's **Bootstrap Backend** stage handles this automatically on the first run — no manual steps needed.

> **Manually (local runs only):**
```bash
cd backend/
terraform init
terraform apply -var="aws_account_id=$(aws sts get-caller-identity --query Account --output text)"
```

The S3 backend bucket name (`mycompany-terraform-state-<ACCOUNT_ID>`) is already pre-configured in each environment's `versions.tf` — no manual editing required after the bucket is created.

### Step 2 — Deploy an environment

```bash
cd environments/dev/

# Fill in secrets (never commit this file)
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 3 — Verify EKS cluster

```bash
# Command is printed in terraform output as `kubeconfig_command`
aws eks update-kubeconfig --region us-east-1 --name mycompany-dev-eks
kubectl get nodes
kubectl get pods -A
```

---

## Jenkins CI/CD Pipeline

The `jenkins/Jenkinsfile` runs these stages against the selected environment:

```
Checkout → Bootstrap Backend → fmt check → validate → init → plan → [approval] → apply
```

| Stage | What it does |
|-------|-------------|
| Checkout | Pulls code, confirms Terraform version |
| Bootstrap Backend | Creates S3 + DynamoDB + KMS for remote state (no-op after first run) |
| Terraform Format Check | `terraform fmt -check` — fails fast on whitespace issues |
| Terraform Validate | `terraform validate` with local backend — no AWS calls |
| Terraform Init | Connects to S3 remote backend |
| Terraform Plan | Generates `tfplan` artifact, archived for audit |
| Manual Approval | Blocks on human approval for stage, prod, and any destroy |
| Terraform Apply / Destroy | Executes the approved plan |
| Post-Apply Outputs | Archives `terraform-outputs.json` |

- **dev apply**: auto-proceeds (no approval gate)
- **stage / prod apply**: requires manual approval
- **any destroy**: requires manual approval regardless of environment

### Required Jenkins credentials

| Credential ID            | Type        | Purpose                                        |
|--------------------------|-------------|------------------------------------------------|
| `AWS_ACCESS_KEY_ID`      | Secret text | AWS authentication                             |
| `AWS_SECRET_ACCESS_KEY`  | Secret text | AWS authentication                             |
| `TF_VAR_db_password`     | Secret text | RDS master password (min 8 chars, no `@/\"'\`) |

---

## Security Highlights

| Control | Implementation |
|---------|---------------|
| Encryption at rest | KMS CMKs on EKS secrets, RDS, ElastiCache, S3, EBS volumes |
| Encryption in transit | TLS on ALB, ElastiCache; HTTPS-only listener with redirect |
| No public nodes | EKS worker nodes in private subnets only |
| IMDSv2 required | Prevents SSRF credential theft from pods |
| IRSA | Pod-level IAM roles — not node-level broad permissions |
| Private EKS API (prod) | Control plane unreachable from internet |
| State locking | DynamoDB prevents concurrent `terraform apply` runs |
| Secrets never in git | `sensitive = true`, injected via env vars or Secrets Manager |

---

## Further Reading

- [docs/POC_WORKFLOW.md](docs/POC_WORKFLOW.md) — **Start here for POC** — apply → validate every resource → destroy
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Diagrams and design decisions
- [docs/COMMANDS.md](docs/COMMANDS.md) — Terraform and AWS CLI command reference
- [docs/INTERVIEW_QUESTIONS.md](docs/INTERVIEW_QUESTIONS.md) — Study guide for 3–8 YOE DevOps roles
