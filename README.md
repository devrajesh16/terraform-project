# Terraform AWS Cloud Foundation

Production-ready AWS infrastructure automation using Terraform modules.
Targets DevOps Engineers with 3-8 years of experience.

---

## Repository Layout

```
terraform-cloud-foundation/
│
├── backend/                     # Remote state bootstrap (run once)
│   ├── main.tf                  # S3 bucket + DynamoDB lock table + KMS
│   ├── variables.tf
│   └── outputs.tf
│
├── environments/
│   ├── dev/                     # Development — SPOT nodes, single NAT, public API
│   ├── stage/                   # Staging — mirrors prod topology, smaller instances
│   └── prod/                    # Production — full HA, private API, Multi-AZ
│       ├── versions.tf          # Terraform version + backend config
│       ├── main.tf              # Module orchestration
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
│
├── modules/
│   ├── vpc/                     # VPC, subnets, IGW, NAT GW, route tables
│   ├── kms/                     # Customer-managed KMS keys (EKS, RDS, S3)
│   ├── iam/                     # EKS cluster role, node role, IRSA roles
│   ├── security-groups/         # ALB, EKS, RDS, Redis security groups
│   ├── eks/                     # EKS cluster + OIDC provider + CW log group
│   ├── node-group/              # Managed node groups with encrypted EBS + IMDSv2
│   ├── ecr/                     # ECR repos with scan-on-push + lifecycle policy
│   ├── rds/                     # RDS PostgreSQL with Multi-AZ + Enhanced Monitoring
│   ├── elasticache/             # Redis with TLS + encryption + Multi-AZ
│   ├── alb/                     # ALB with HTTPS redirect + access logs + WAF
│   ├── route53/                 # DNS records + ACM certificate (DNS validation)
│   ├── s3/                      # S3 buckets (ALB logs, assets) with KMS
│   └── cloudwatch/              # Alarms (CPU/memory/DB/ALB) + dashboard + SNS
│
├── helm-chart/                  # Application Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── hpa.yaml             # HorizontalPodAutoscaler
│       └── pdb.yaml             # PodDisruptionBudget
│
├── jenkins/
│   └── Jenkinsfile              # Terraform CI/CD pipeline
│
├── scripts/
│   ├── ecr-push.sh              # Docker build + ECR push helper
│   └── helm-deploy.sh           # Helm upgrade/install helper
│
└── docs/
    ├── ARCHITECTURE.md          # Diagrams and network design
    ├── COMMANDS.md              # All commands you need
    └── INTERVIEW_QUESTIONS.md   # Q&A for 3-8 YOE DevOps interviews
```

---

## CI/CD Flow

```
Developer
   │  git push feature/xyz
   ▼
GitHub
   │  PR → develop (dev apply)
   │  PR → main    (prod apply after approval)
   ▼
Jenkins Pipeline
   ├─ terraform fmt --check
   ├─ terraform validate
   ├─ terraform init
   ├─ terraform plan  ──► archived as build artifact
   ├─ Manual Approval (stage + prod only)
   └─ terraform apply
         │
         ▼
   AWS Infrastructure
         │
         ▼
   Application CI (separate repo)
         │
         ├─ docker build
         ├─ docker push → ECR
         └─ helm upgrade --install → EKS
```

---

## Quick Start

### Step 1 — Bootstrap remote state (once per AWS account)

```bash
cd backend/
terraform init
terraform apply -var="aws_account_id=$(aws sts get-caller-identity --query Account --output text)"
```

### Step 2 — Deploy an environment

```bash
cd environments/dev/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 3 — Push your first Docker image

```bash
./scripts/ecr-push.sh backend-service v1.0.0 us-east-1 $(aws sts get-caller-identity --query Account --output text)
```

### Step 4 — Deploy application to Kubernetes

```bash
# Update kubeconfig (shown in terraform output)
aws eks update-kubeconfig --region us-east-1 --name mycompany-dev-eks

# Deploy with Helm
helm upgrade --install myapp ./helm-chart \
  --namespace development \
  --create-namespace \
  --set image.tag=v1.0.0 \
  --wait --atomic
```

---

## Environment Comparison

| Feature               | dev              | stage            | prod              |
|-----------------------|------------------|------------------|-------------------|
| EKS API endpoint      | Public           | Private          | Private           |
| NAT Gateways          | 1 (single AZ)   | 3 (per AZ)      | 3 (per AZ)       |
| Node capacity type    | SPOT             | ON_DEMAND        | ON_DEMAND         |
| RDS Multi-AZ          | No               | Yes              | Yes               |
| Deletion protection   | No               | No               | Yes               |
| Flow Logs             | No               | Yes              | Yes               |
| Log retention (EKS)   | 7 days           | 30 days          | 90 days           |

---

## Production Best Practices Implemented

- **Remote state** — S3 + DynamoDB locking + KMS encryption
- **State isolation** — Each environment has its own state key
- **Secrets** — `sensitive = true`, injected via env vars, never in git
- **IMDSv2 required** — Prevents SSRF credential theft from pods
- **IRSA** — Pod-level IAM roles (not node-level)
- **Private EKS API** — Control plane not reachable from internet in prod
- **EBS encryption** — All node volumes encrypted with CMK
- **Multi-AZ** — VPC, NAT GW, EKS nodes, RDS, Redis all span AZs
- **Lifecycle rules** — ECR purges old images; S3 expires old logs
- **PodDisruptionBudget** — Maintains availability during node drains
- **HPA** — Auto-scales pods on CPU + memory
- **Cluster Autoscaler** — Auto-scales node groups
- **CloudWatch alarms** — Alerts on CPU, memory, DB, ALB errors
- **WAF** — OWASP protection on the ALB
- **VPC Flow Logs** — Full network audit trail

---

## Further Reading

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Diagrams and network design
- [docs/COMMANDS.md](docs/COMMANDS.md) — Every command you need
- [docs/INTERVIEW_QUESTIONS.md](docs/INTERVIEW_QUESTIONS.md) — Q&A study guide
