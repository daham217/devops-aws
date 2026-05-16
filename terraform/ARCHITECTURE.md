# Serene Stay — AWS Architecture (Intern Demo)

## Architecture Diagram

```
                    ┌──────────────────────────────────────────────────┐
                    │                  AWS Cloud (us-east-1)            │
                    │                                                    │
  Browser ─HTTP──► │  ALB  (public subnets: us-east-1a, us-east-1b)   │
                    │   │                                                │
                    │   │  port 80 → port 3000                          │
                    │   ▼                                                │
                    │  ┌──────────────────────────────────────────────┐ │
                    │  │  Private Subnet                               │ │
                    │  │                                               │ │
                    │  │  ECS Fargate Task (256 CPU / 512 MB)         │ │
                    │  │  Next.js container  :3000                    │ │
                    │  │       │                    │                  │ │
                    │  │       │ SQL               S3 PutObject        │ │
                    │  │       ▼                    ▼                  │ │
                    │  │  RDS PostgreSQL 16    S3 Bucket               │ │
                    │  │  (private subnet)     (uploads)               │ │
                    │  └──────────────────────────────────────────────┘ │
                    │                                                    │
                    │  Secrets Manager  ← ECS reads at startup          │
                    │  ECR              ← Docker images stored here      │
                    │  CloudWatch       → Alarms → SNS → Email          │
                    └──────────────────────────────────────────────────┘
```

## What's included (and why)

| Resource | Why it's here |
|---|---|
| VPC + subnets | Network isolation — public for ALB, private for ECS + RDS |
| Security Groups | Least-privilege: ALB→ECS on :3000, ECS→RDS on :5432 only |
| ALB | Load balancer + health checks, single entry point |
| ECS Fargate | Serverless containers — no EC2 to manage |
| RDS PostgreSQL 16 | Managed database, encrypted, automated backups |
| S3 | File uploads (images), versioned, encrypted |
| ECR | Docker image registry with scan-on-push |
| Secrets Manager | All env vars stored securely — no static keys in containers |
| CloudWatch | Logs, alarms, dashboard |
| NAT Gateway | Lets ECS tasks in private subnets reach ECR/S3/Secrets Manager |

## What's intentionally excluded (demo simplifications)

| Excluded | Reason |
|---|---|
| Route53 / custom domain | Not needed — access via ALB DNS |
| ACM certificate / HTTPS | No domain, so no cert |
| CloudFront CDN | Adds cost, not needed for demo |
| WAF | Adds ~$5/mo base + per-rule cost |
| Multi-AZ RDS | Doubles DB cost — single-AZ is fine for demo |
| Auto-scaling | 1 task is enough for intern demo |
| Deletion protection | Easy teardown when demo is done |

---

## Cost Estimate (us-east-1, running 24/7)

| Resource | Config | $/hour | $/month |
|---|---|---|---|
| ECS Fargate | 0.25 vCPU × $0.04048 + 0.5 GB × $0.004445 | $0.0124 | ~$9 |
| RDS PostgreSQL | db.t3.micro single-AZ | $0.018 | ~$13 |
| ALB | Base charge | $0.008 | ~$6 |
| NAT Gateway | 1× $0.045/hr | $0.045 | ~$33 |
| S3 | 20 GB storage + requests | — | ~$1 |
| ECR | Storage + data transfer | — | ~$1 |
| Secrets Manager | 1 secret | — | ~$0.40 |
| CloudWatch | Logs + alarms | — | ~$2 |
| **Total** | | | **~$65/month** |

> **NAT Gateway is the biggest cost** at ~$33/mo. It's needed because ECS tasks
> run in private subnets and need to reach ECR, S3, and Secrets Manager.
> For a very short demo you could use VPC endpoints instead to eliminate it,
> but NAT is simpler to set up.

### If you only run it for a few days:
- 3 days = ~$6.50 total
- 1 week = ~$15 total

---

## Module Structure

```
terraform/
├── main.tf                 # Wires all modules together
├── variables.tf            # Input variables
├── outputs.tf              # Outputs (app URL, deploy commands)
├── terraform.tfvars        # Values for this demo
├── bootstrap/
│   └── main.tf             # Run once: creates S3 state bucket + DynamoDB lock
└── modules/
    ├── networking/         # VPC, subnets, IGW, NAT Gateway, route tables
    ├── security/           # Security groups (ALB, ECS, RDS)
    ├── storage/            # S3 uploads bucket
    ├── database/           # RDS PostgreSQL 16
    ├── secrets/            # Secrets Manager
    ├── ecr/                # ECR repository
    ├── ecs/                # ECS cluster, task, service, ALB
    └── monitoring/         # CloudWatch alarms, SNS, dashboard
```

---

## Deployment Steps

### Prerequisites
- AWS CLI configured (`aws configure` or access key already set)
- Terraform >= 1.6.0 installed
- Docker installed

### Step 1 — Bootstrap Terraform backend (once only)
```bash
cd terraform/bootstrap
terraform init
terraform apply
```

### Step 2 — Deploy infrastructure
```bash
cd terraform
terraform init
terraform plan    # Review what will be created
terraform apply   # Takes ~10 minutes (RDS is the slowest)
```

After apply, note the outputs:
- `app_url` — the ALB URL to open in browser
- `ecr_repository_url` — where to push your Docker image
- `deploy_commands` — copy-paste commands for the full deploy

### Step 3 — Build and push Docker image
```bash
# Authenticate to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ecr_repository_url>

# Build and push
docker build -t <ecr_repository_url>:latest .
docker push <ecr_repository_url>:latest
```

### Step 4 — Run Prisma migrations
```bash
# Get subnet and security group IDs from terraform output
SUBNET_ID=$(terraform output -raw private_subnet_id_0)
SG_ID=$(terraform output -raw ecs_security_group_id)

aws ecs run-task \
  --cluster serene-stay-demo-cluster \
  --task-definition serene-stay-demo-task \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SG_ID],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"nextjs-app","command":["npx","prisma","migrate","deploy"]}]}'
```

### Step 5 — Force ECS to pull the new image
```bash
aws ecs update-service \
  --cluster serene-stay-demo-cluster \
  --service serene-stay-demo-service \
  --force-new-deployment \
  --region us-east-1
```

### Step 6 — Open the app
```
http://<alb_dns_name>
```
(Takes ~2 minutes for the task to start and pass health checks)

---

## Teardown (when demo is done)
```bash
cd terraform
terraform destroy   # Destroys everything — ~5 minutes
```
> RDS has `skip_final_snapshot = true` so it deletes cleanly.

---

## GitHub Actions CI/CD

Push to `main` → automatically builds image, pushes to ECR, deploys to ECS.

Required GitHub secrets:
| Secret | Value |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | IAM role ARN (OIDC) — or use access key for demo |
| `CLOUDFRONT_DISTRIBUTION_ID` | Not needed for demo (remove from workflow) |
| `PRIVATE_SUBNET_IDS` | From `terraform output` |
| `ECS_SECURITY_GROUP_ID` | From `terraform output` |
