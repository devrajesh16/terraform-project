# Interview Questions — DevOps / Terraform / AWS / EKS

---

## Terraform

**Q1. What is Terraform state and why is it critical?**
State is Terraform's source of truth — a JSON snapshot mapping your config to real AWS resources.
Without it, Terraform cannot know what already exists, so it would try to create duplicates or
leave orphaned resources. In production you store it remotely in S3 so the whole team shares
the same view. DynamoDB locking prevents two people from running `apply` simultaneously, which
would corrupt the state.

**Q2. What is the difference between `terraform plan` and `terraform apply`?**
`plan` is a dry-run — it shows what changes Terraform would make, but makes no real changes.
`apply` executes those changes against AWS. In CI/CD you always run plan first, save the plan
file (`-out tfplan`), get human approval, then apply exactly that plan.

**Q3. What is a Terraform module and when would you create one?**
A module is a reusable, self-contained Terraform package (a directory of `.tf` files).
You create one when the same infrastructure pattern appears in multiple places — e.g., every
environment needs a VPC, so you write the VPC module once and call it three times with different
variables. Modules enforce consistency and reduce copy-paste drift.

**Q4. How does Terraform handle secrets (e.g., database passwords)?**
Mark the variable `sensitive = true` so Terraform redacts it from plan output.
In practice you never hard-code passwords in `.tfvars`:
- Inject via environment variables (`TF_VAR_db_password`)
- Retrieve from AWS Secrets Manager using the `aws_secretsmanager_secret_version` data source
- Use HashiCorp Vault provider for centralised secrets management

**Q5. Explain `terraform state rm` and when you'd use it.**
It removes a resource from Terraform's state WITHOUT deleting it from AWS. Use it when:
- You need to import the resource into a different state (rename or move)
- A resource was created outside Terraform and you want Terraform to stop managing it
- You're refactoring module paths (followed by `terraform import`)

---

## AWS VPC & Networking

**Q6. What is the difference between a Security Group and a Network ACL?**
Security Groups are stateful (if you allow inbound traffic, the response is automatically allowed)
and operate at the ENI level. NACLs are stateless (you must explicitly allow both inbound and
outbound for each flow) and operate at the subnet level. They provide defence-in-depth when used together.

**Q7. Why do you need a NAT Gateway in private subnets?**
Private subnets have no Internet Gateway route, so instances cannot directly reach the internet.
NAT Gateway provides outbound-only internet access (e.g., downloading OS patches, calling external
APIs) while keeping instances completely unreachable from the internet.

**Q8. What are the EKS-specific subnet tags and why are they needed?**
- `kubernetes.io/role/elb = 1` on public subnets — tells the AWS Load Balancer Controller
  where to place internet-facing ALBs
- `kubernetes.io/role/internal-elb = 1` on private subnets — for internal load balancers
- `kubernetes.io/cluster/<cluster-name> = shared` — lets EKS autodiscover subnets

---

## EKS

**Q9. What is IRSA and why is it better than attaching IAM roles to nodes?**
IRSA (IAM Roles for Service Accounts) lets individual Kubernetes pods assume their own IAM
role via OIDC federation, rather than sharing the node's broad IAM role.
Benefit: a compromised pod can only do what its specific role allows, not everything the node can.
This is least-privilege at the pod level.

**Q10. What is IMDSv2 and why is it required on EKS nodes?**
IMDSv2 (Instance Metadata Service v2) adds a session token requirement to the metadata endpoint.
Without it, an SSRF vulnerability in a pod could steal the node's AWS credentials by calling
`http://169.254.169.254/latest/meta-data/iam/security-credentials/`. IMDSv2 prevents this because
the token requires an HTTP PUT (which SSRF can't do cross-domain).

**Q11. What is a Pod Disruption Budget (PDB)?**
A PDB guarantees that at least N replicas of a pod remain running during voluntary disruptions
(node drains, cluster upgrades). Without a PDB, a node drain could kill all replicas simultaneously.

**Q12. Explain the EKS Cluster Autoscaler.**
The Cluster Autoscaler watches for pods in `Pending` state (not schedulable due to insufficient
resources) and automatically increases the node group's desired count. When nodes have been
underutilised for 10 minutes it removes them. It requires tags on Auto Scaling Groups so it
knows which groups it can control.

---

## CI/CD

**Q13. What does `TF_IN_AUTOMATION=true` do?**
It tells Terraform it's running in a non-interactive environment. This suppresses suggestions
like "run `terraform apply`" at the end of `plan` output, producing cleaner CI logs.

**Q14. Why do you archive the Terraform plan file as a build artifact?**
For audit compliance: you need to prove that the code that was approved was the exact code
that was applied. The approved plan file is deterministic — `terraform apply tfplan` applies
exactly what was planned.

---

## Helm

**Q15. What is the difference between `helm install` and `helm upgrade --install`?**
`helm install` fails if the release already exists. `helm upgrade --install` is idempotent —
it installs if the release doesn't exist, upgrades it if it does. This is the CI/CD-safe form.

**Q16. What does `--atomic` do in helm upgrade?**
If the upgrade fails (e.g., pods don't become ready within the timeout), `--atomic` automatically
rolls back to the previous release. Without it, a failed upgrade leaves the cluster in a partial
state. Use `--wait` with `--atomic` to ensure readiness probes are checked before declaring success.
