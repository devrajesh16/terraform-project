# Interview Questions — Terraform / AWS / EKS Infrastructure

For DevOps Engineers with 3–8 years of experience.

---

## Terraform

**Q1. What is Terraform state and why is it critical?**
State is Terraform's source of truth — a JSON snapshot mapping your HCL config to real AWS
resource IDs. Without it Terraform cannot know what already exists, so it would try to create
duplicates or leave orphaned resources. In production you store it remotely in S3 so the whole
team shares the same view, and DynamoDB locking prevents two `apply` runs from corrupting it
simultaneously.

**Q2. What is the difference between `terraform plan` and `terraform apply`?**
`plan` is a dry-run — it calculates what changes Terraform would make but touches nothing.
`apply` executes those changes. In CI/CD you always plan first, save the plan file (`-out tfplan`),
get human approval, then apply exactly that saved plan. This guarantees the approved plan is the
one that runs — not a new plan generated moments later.

**Q3. What is a Terraform module and when do you create one?**
A module is a reusable, self-contained directory of `.tf` files called with `module {}` blocks.
You create one when the same infrastructure pattern is needed in multiple places — e.g. every
environment needs a VPC, so you write it once and call it three times with different variables.
Modules enforce consistency, reduce copy-paste drift, and make the environment configs readable.

**Q4. How do you handle secrets in Terraform (database passwords, API keys)?**
Never hard-code secrets in `.tf` files or `.tfvars`. Three safe options:
1. Inject as environment variables: `TF_VAR_db_password=xxx terraform apply`
2. Use an `aws_secretsmanager_secret_version` data source to pull the value from Secrets Manager at plan time
3. Use HashiCorp Vault provider for centralised secrets management
Always mark the variable `sensitive = true` so Terraform redacts it from plan output and logs.

**Q5. What does `terraform state rm` do, and when would you use it?**
It removes a resource from Terraform's state file without destroying the real AWS resource.
Use it when: refactoring module paths (then re-import under the new path), handing off a resource
to another state, or when a resource was created outside Terraform and you want Terraform to
stop tracking it.

**Q6. Explain `lifecycle { prevent_destroy = true }`.**
It makes Terraform refuse to destroy that resource even if your config would require it.
Use it on stateful resources that are expensive or impossible to recover — RDS instances,
S3 buckets holding terraform state, KMS keys. The protection only applies to `terraform apply`;
you can override it by removing the lifecycle block and re-planning.

**Q7. What is `depends_on` and when should you use it?**
It creates an explicit dependency edge between resources that Terraform cannot infer from
attribute references alone. For example, an EKS cluster that needs an IAM role to be fully
attached to its policies before creation — if the policy attachment isn't referenced in any
attribute, you add `depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]`.
Overuse is a code smell; prefer using attribute references to create implicit dependencies.

---

## VPC & Networking

**Q8. What is the difference between a Security Group and a Network ACL?**
Security Groups are **stateful** (response traffic is automatically allowed) and operate at the
ENI/instance level. NACLs are **stateless** (you must allow both inbound and outbound for each
flow) and operate at the subnet level. They provide defence-in-depth — an attacker who somehow
bypasses a security group still faces the NACL.

**Q9. Why do private subnets need a NAT Gateway?**
Private subnets have no Internet Gateway route, so instances cannot initiate outbound connections
to the internet. NAT Gateway provides outbound-only internet access (OS patches, pulling images,
calling external APIs) while keeping instances completely unreachable from the internet. Each AZ
gets its own NAT Gateway for HA — if one AZ's NAT fails, nodes in other AZs are unaffected.

**Q10. What are the EKS-specific subnet tags and why are they required?**
- `kubernetes.io/role/elb = 1` on public subnets — tells the AWS Load Balancer Controller where
  to place internet-facing ALBs
- `kubernetes.io/role/internal-elb = 1` on private subnets — for internal load balancers
- `kubernetes.io/cluster/<name> = shared` — allows EKS to autodiscover subnets and manage ENIs

Without these tags, the Load Balancer Controller cannot find the correct subnets and ALB creation
will fail with a confusing error.

**Q11. Why use one NAT Gateway per AZ instead of one shared NAT Gateway?**
A single NAT Gateway is a cross-AZ single point of failure. If that AZ has an outage, all
private subnets lose internet access. With one NAT per AZ, each private route table routes
through its own AZ's NAT, so an AZ failure only isolates that AZ's traffic — the other AZs
continue working. The cost is ~$33/month per extra NAT — acceptable in prod, skippable in dev.

---

## EKS

**Q12. What is IRSA and why is it better than attaching IAM roles to EC2 nodes?**
IRSA (IAM Roles for Service Accounts) lets individual pods assume their own scoped IAM role
via OIDC federation — each pod gets only the permissions its service account is mapped to.
With node-level roles, every pod on that node inherits all the node's permissions. A compromised
pod can only damage what its specific IRSA role allows, not everything the node can do. This
is least-privilege at the pod level.

**Q13. What is IMDSv2 and why must it be enforced on EKS nodes?**
IMDSv2 requires a session token for every metadata API call. Without it, a Server-Side Request
Forgery (SSRF) vulnerability in any pod can steal the node's IAM credentials by calling
`http://169.254.169.254/latest/meta-data/iam/security-credentials/`. IMDSv2 blocks this because
the required HTTP PUT for the token cannot be made cross-domain by a browser or SSRF. We enforce
it in the node group's launch template with `http_tokens = "required"`.

**Q14. What does `endpoint_public_access = false` on an EKS cluster mean?**
The Kubernetes API server is only reachable from within the VPC — not from the internet.
Developers need a bastion host, SSM port-forward, or VPN to run `kubectl` commands.
This is mandatory in production to prevent the API server from being exposed to internet scanners.
In dev we allow public access (restricted to developer CIDRs) to avoid the VPN overhead.

**Q15. What is `ignore_changes = [scaling_config[0].desired_size]` on a node group?**
The Cluster Autoscaler changes the node group's `desired_size` directly in AWS to scale nodes up
and down. If Terraform doesn't ignore this attribute, the next `terraform apply` would reset
desired_size back to the value in your `.tf` file, fighting the autoscaler. This lifecycle ignore
lets the autoscaler own desired_size while Terraform still manages min_size and max_size.

---

## IAM

**Q16. Explain "least privilege" in the context of this infrastructure.**
Each component gets only the IAM permissions it actually needs:
- EKS cluster role: only `AmazonEKSClusterPolicy` and `AmazonEKSVPCResourceController`
- Node role: `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly` — read-only ECR pull, nothing else
- ALB controller IRSA: only the specific `elasticloadbalancing:*` actions it needs to create and manage load balancers
- Cluster Autoscaler IRSA: only `autoscaling:Describe*`, `autoscaling:SetDesiredCapacity`, `autoscaling:TerminateInstanceInAutoScalingGroup`

If any single component is compromised, the blast radius is bounded to what that component can touch.

---

## Remote State & Security

**Q17. Why use DynamoDB for state locking instead of relying on S3 alone?**
S3 does not have a built-in compare-and-swap mechanism. Two concurrent `terraform apply` runs
can both read the state at the same time, both calculate changes, and both write back — corrupting
the state. DynamoDB provides a conditional write (the `LockID` item) that only one process can
hold at a time. The second run gets a lock error and must wait.

**Q18. Why is S3 bucket versioning enabled for the Terraform state bucket?**
Versioning provides a complete history of every state file change. If a `terraform apply`
corrupts the state (rare but possible with interrupted applies), you can roll back to a previous
version of the state file without losing tracked resources. It is the safety net under the DynamoDB lock.
