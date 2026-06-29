# AWS Production Architecture

## Traffic Flow

```
                         INTERNET
                            │
                    ┌───────▼────────┐
                    │  Route 53 DNS  │
                    │  (app.example) │
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │   ALB (public) │  ← HTTPS:443 / HTTP:80→redirect
                    │  WAF attached  │
                    └───────┬────────┘
                            │
              ┌─────────────▼──────────────┐
              │         PUBLIC SUBNETS      │
              │   us-east-1a  us-east-1b   │
              │   NAT GW      NAT GW        │
              └─────────────┬──────────────┘
                            │
              ┌─────────────▼──────────────┐
              │        PRIVATE SUBNETS      │
              │                             │
              │  ┌──────────────────────┐  │
              │  │   EKS Worker Nodes   │  │
              │  │  ┌────────────────┐  │  │
              │  │  │ AWS LB Cntrlr  │  │  │
              │  │  │ (Ingress ctrl) │  │  │
              │  │  └───────┬────────┘  │  │
              │  │          │           │  │
              │  │  ┌───────▼────────┐  │  │
              │  │  │  App Service   │  │  │
              │  │  └───────┬────────┘  │  │
              │  │          │           │  │
              │  │  ┌───────▼────────┐  │  │
              │  │  │   App Pods     │  │  │
              │  └──┴────────────────┴──┘  │
              │                             │
              │  ┌──────────┐ ┌─────────┐  │
              │  │   RDS    │ │  Redis  │  │
              │  │Postgres  │ │ Cluster │  │
              │  │ Multi-AZ │ │ Multi-AZ│  │
              │  └──────────┘ └─────────┘  │
              └─────────────────────────────┘
```

## Network CIDR Design

| Environment | VPC CIDR     | Public Subnets          | Private Subnets           |
|-------------|--------------|-------------------------|---------------------------|
| prod        | 10.0.0.0/16  | 10.0.1-3.0/24           | 10.0.11-13.0/24           |
| stage       | 10.2.0.0/16  | 10.2.1-3.0/24           | 10.2.11-13.0/24           |
| dev         | 10.1.0.0/16  | 10.1.1-2.0/24           | 10.1.11-12.0/24           |

## Security Layers

1. **WAF** — Blocks common web attacks (OWASP Top 10) before traffic hits ALB
2. **Security Groups** — Stateful firewall at instance/ENI level
3. **Network ACL** — Stateless subnet-level firewall (additional defense layer)
4. **IMDSv2** — Prevents SSRF attacks from stealing node credentials
5. **KMS encryption** — All data at rest encrypted with customer-managed keys
6. **VPC Flow Logs** — Network traffic metadata for audit and forensics
7. **IAM least-privilege** — Every service has only the permissions it needs

## Module Dependency Graph

```
kms ──────────────────────────────────────────────────────┐
                                                          │
vpc ──────────────────┐                                  │
                      │                                   │
security-groups ──────┤                                  │
                      │                                   │
iam ──────────────────┤                                  │
                      │                                   │
s3 ───────────────────┼──────────────────────────────────┤
                      ▼                                   ▼
            eks ──► node-group      rds   elasticache   alb
                      │                                   │
                      └─────────────────────────────────►─┘
                                                          │
                                             cloudwatch   route53
```
