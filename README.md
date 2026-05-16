# Serene Stay

A hotel booking landing page built with **Next.js 16**, deployed on **AWS** using **Terraform** (IaC).
Live demo running on ECS Fargate behind an Application Load Balancer.

**Live URL:** `http://serene-stay-demo-alb-952740670.us-east-1.elb.amazonaws.com`

---

## What the App Does

| Page | URL | Description |
|---|---|---|
| Home | `/` | Landing page — booking form, featured rooms (Deluxe Suite, Garden Room, Executive Corner), perks |
| About | `/about` | About Serene Stay — Sri Lanka destinations (Galle, Colombo, Matara) |
| Dashboard | `/dashboard` | Guest dashboard — reservation stats placeholder |

| API Route | Method | Description |
|---|---|---|
| `/api/health` | GET | Health check — used by ALB target group and ECS container health check |
| `/api/upload` | POST | Accepts `multipart/form-data`, uploads file to S3, returns public URL |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Next.js 16.2.4 (App Router, `output: standalone`) |
| Language | TypeScript 5 |
| Styling | Tailwind CSS 4 |
| File Storage | AWS S3 via `@aws-sdk/client-s3` v3 |
| Container | Docker (multi-stage, node:20-alpine, non-root user) |
| Infrastructure | Terraform >= 1.6 (AWS provider ~> 5.0) |
| CI/CD | GitHub Actions |
| Runtime | Node.js 20 on ECS Fargate |

---

## AWS Architecture

```
                         ┌─────────────────────────────────────────────────────────────┐
                         │                  AWS  us-east-1                              │
                         │                                                               │
  Browser ──HTTP:80────► │  Application Load Balancer (internet-facing)                 │
                         │  serene-stay-demo-alb-952740670.us-east-1.elb.amazonaws.com  │
                         │  Subnets: us-east-1a (10.0.0.0/24)                           │
                         │           us-east-1b (10.0.1.0/24)                           │
                         │       │                                                       │
                         │       │ HTTP forward to port 3000                             │
                         │       │ Health check: GET /api/health → 200                  │
                         │       ▼                                                       │
                         │  ┌─────────────────────────────────────────────────────────┐ │
                         │  │  Private Subnets                                         │ │
                         │  │  us-east-1a: 10.0.2.0/24                                │ │
                         │  │  us-east-1b: 10.0.3.0/24                                │ │
                         │  │                                                           │ │
                         │  │  ECS Fargate Task (256 CPU / 512 MB)                     │ │
                         │  │  Image: ECR → nextjs-app:latest                          │ │
                         │  │  Port: 3000                                               │ │
                         │  │  User: nextjs (non-root, uid 1001)                       │ │
                         │  │       │                        │                          │ │
                         │  │       │ TCP:5432               │ HTTPS PutObject          │ │
                         │  │       ▼                        ▼                          │ │
                         │  │  RDS PostgreSQL 16.3      S3 Bucket                      │ │
                         │  │  db.t3.micro               serene-stay-uploads-demo       │ │
                         │  │  20 GB gp3                 AES-256 encrypted              │ │
                         │  │  Single-AZ                 Versioning enabled             │ │
                         │  │  DB Subnets:                                              │ │
                         │  │  us-east-1a: 10.0.4.0/24                                │ │
                         │  │  us-east-1b: 10.0.5.0/24                                │ │
                         │  └─────────────────────────────────────────────────────────┘ │
                         │       │                                                       │
                         │       │ Outbound via NAT Gateway                             │
                         │       │ (nat-0ce19c4d1e9929a78, EIP: 3.230.101.125)         │
                         │       ▼                                                       │
                         │  Internet Gateway ──► AWS APIs (ECR, S3, Secrets Manager)    │
                         │                                                               │
                         │  Secrets Manager ◄── ECS reads at task startup               │
                         │  secret: serene-stay-demo/app-secrets                        │
                         │                                                               │
                         │  ECR Repository                                               │
                         │  987454179025.dkr.ecr.us-east-1.amazonaws.com/               │
                         │  serene-stay-demo/nextjs-app                                  │
                         │                                                               │
                         │  CloudWatch ──► 4 Alarms ──► SNS ──► Email                  │
                         │  Dashboard: serene-stay-demo-dashboard                       │
                         └─────────────────────────────────────────────────────────────┘
```

---

## AWS Resources (Deployed)

### VPC & Networking

| Resource | ID / Value | Purpose |
|---|---|---|
| VPC | `vpc-0dd7fd7b8911e0981` | Isolated network, CIDR `10.0.0.0/16` |
| Public Subnet (1a) | `10.0.0.0/24` us-east-1a | ALB, NAT Gateway |
| Public Subnet (1b) | `10.0.1.0/24` us-east-1b | ALB (multi-AZ requirement) |
| Private Subnet (1a) | `10.0.2.0/24` us-east-1a | ECS Fargate tasks |
| Private Subnet (1b) | `10.0.3.0/24` us-east-1b | ECS Fargate tasks |
| DB Subnet (1a) | `10.0.4.0/24` us-east-1a | RDS (isolated, no internet route) |
| DB Subnet (1b) | `10.0.5.0/24` us-east-1b | RDS subnet group requirement |
| Internet Gateway | `igw-08d769ebbee20776a` | Public subnet internet access |
| NAT Gateway | `nat-0ce19c4d1e9929a78` | Private subnet outbound (ECR pull, S3, Secrets Manager) |
| Elastic IP | `3.230.101.125` | Static IP for NAT Gateway |
| VPC Flow Logs | CloudWatch `/aws/vpc/serene-stay-demo/flow-logs` | All traffic logged, 30-day retention |

**Route tables:**
- Public → `0.0.0.0/0` via Internet Gateway
- Private → `0.0.0.0/0` via NAT Gateway
- Database → local only (no internet route)

### Security Groups

| Security Group | Inbound | Outbound | Attached To |
|---|---|---|---|
| `serene-stay-demo-alb-sg` | TCP :80 from `0.0.0.0/0` | All | ALB |
| `serene-stay-demo-ecs-sg` | TCP :3000 from ALB SG only | All | ECS tasks |
| `serene-stay-demo-db-sg` | TCP :5432 from ECS SG only | All | RDS |

### Application Load Balancer

| Property | Value |
|---|---|
| Name | `serene-stay-demo-alb` |
| DNS | `serene-stay-demo-alb-952740670.us-east-1.elb.amazonaws.com` |
| Scheme | internet-facing |
| Type | Application (Layer 7) |
| Listener | HTTP :80 → forward to target group |
| Target Group | IP type, port 3000, health check `GET /api/health` → 200 |
| Health Check | Interval 30s, threshold 2 healthy / 3 unhealthy |
| Availability Zones | us-east-1a, us-east-1b |

### ECS Fargate

| Property | Value |
|---|---|
| Cluster | `serene-stay-demo-cluster` |
| Service | `serene-stay-demo-service` |
| Task Definition | `serene-stay-demo-task:1` |
| Launch Type | FARGATE |
| CPU | 256 units (0.25 vCPU) |
| Memory | 512 MiB |
| Desired Count | 1 |
| Image | `987454179025.dkr.ecr.us-east-1.amazonaws.com/serene-stay-demo/nextjs-app:latest` |
| Container Port | 3000 |
| Container User | `nextjs` (uid 1001, non-root) |
| Network | Private subnets, no public IP |
| Deployment | Rolling, circuit breaker with auto-rollback |
| Logs | CloudWatch `/ecs/serene-stay-demo`, 7-day retention |
| Secrets | Injected from Secrets Manager at startup (no secrets in image) |

**IAM Roles:**
- **Execution Role** (`serene-stay-demo-ecs-execution-role`) — pulls image from ECR, reads secrets from Secrets Manager
- **Task Role** (`serene-stay-demo-ecs-task-role`) — S3 PutObject/GetObject on uploads bucket only

### ECR

| Property | Value |
|---|---|
| Repository | `serene-stay-demo/nextjs-app` |
| URI | `987454179025.dkr.ecr.us-east-1.amazonaws.com/serene-stay-demo/nextjs-app` |
| Scan on Push | Enabled (CVE scanning) |
| Encryption | AES-256 |
| Lifecycle Policy | Keep last 10 tagged images, delete untagged after 1 day |

### RDS PostgreSQL

| Property | Value |
|---|---|
| Identifier | `serene-stay-demo-postgres` |
| Endpoint | `serene-stay-demo-postgres.cupqukwaksd5.us-east-1.rds.amazonaws.com:5432` |
| Engine | PostgreSQL 16.3 |
| Instance Class | `db.t3.micro` (2 vCPU, 1 GiB RAM) |
| Storage | 20 GB gp3, auto-scales to 50 GB |
| Encryption | Enabled (AES-256) |
| Multi-AZ | No (single-AZ, demo cost saving) |
| Publicly Accessible | No (private subnet only) |
| Backup Retention | 3 days, window 03:00–04:00 UTC |
| Maintenance Window | Monday 04:00–05:00 UTC |
| Deletion Protection | Disabled (easy teardown) |
| Logs | PostgreSQL logs exported to CloudWatch |

### S3

| Property | Value |
|---|---|
| Bucket | `serene-stay-uploads-demo` |
| Region | us-east-1 |
| Encryption | AES-256 (SSE-S3) |
| Versioning | Enabled |
| Public Access | Fully blocked |
| Lifecycle | Old versions → STANDARD_IA after 30 days, expire after 90 days |
| Access Logging | Logged to `serene-stay-uploads-demo-access-logs` bucket |
| CORS | Allows all origins (demo) |
| Used By | `/api/upload` route — stores uploaded files, returns public URL |

### Secrets Manager

| Property | Value |
|---|---|
| Secret Name | `serene-stay-demo/app-secrets` |
| ARN | `arn:aws:secretsmanager:us-east-1:987454179025:secret:serene-stay-demo/app-secrets-6ZCOYB` |
| Recovery Window | 7 days |
| Contents | `DATABASE_URL`, `AWS_REGION`, `AWS_S3_BUCKET`, `NEXT_PUBLIC_API_URL`, `NODE_ENV` |
| How Used | ECS execution role reads individual JSON keys at task startup — injected as env vars |

### CloudWatch Monitoring

**Alarms (all currently OK):**

| Alarm | Metric | Threshold | Action |
|---|---|---|---|
| `serene-stay-demo-unhealthy-hosts` | `UnHealthyHostCount` | > 0 | SNS email |
| `serene-stay-demo-5xx-errors` | `HTTPCode_ELB_5XX_Count` | > 5 / min | SNS email |
| `serene-stay-demo-ecs-cpu-high` | ECS `CPUUtilization` | > 85% for 10 min | SNS email |
| `serene-stay-demo-rds-cpu-high` | RDS `CPUUtilization` | > 80% for 15 min | SNS email |

**Dashboard:** `serene-stay-demo-dashboard` — ECS CPU, ALB requests/errors, RDS CPU, ALB response time (p99)

**Log Groups:**
- `/ecs/serene-stay-demo` — container stdout/stderr (7-day retention)
- `/aws/vpc/serene-stay-demo/flow-logs` — VPC network traffic (30-day retention)

---

## Cost Analysis (us-east-1, On-Demand)

### Per-Resource Breakdown

| Resource | Config | Unit Price | Monthly (24/7) |
|---|---|---|---|
| ECS Fargate | 0.25 vCPU × $0.04048/hr | $0.0101/hr | **$7.34** |
| ECS Fargate | 0.5 GB × $0.004445/hr | $0.0022/hr | **$1.62** |
| RDS PostgreSQL | db.t3.micro single-AZ | $0.018/hr | **$13.14** |
| RDS Storage | 20 GB gp3 | $0.115/GB/mo | **$2.30** |
| ALB | Base charge | $0.008/hr | **$5.84** |
| ALB | LCU (minimal traffic) | ~$0.008/LCU/hr | **~$1.00** |
| NAT Gateway | Hourly charge | $0.045/hr | **$32.85** |
| NAT Gateway | Data processing (minimal) | $0.045/GB | **~$0.50** |
| S3 Storage | < 1 GB | $0.023/GB/mo | **~$0.02** |
| S3 Requests | PUT/GET (minimal) | $0.005/1000 | **~$0.10** |
| ECR Storage | ~200 MB image | $0.10/GB/mo | **~$0.02** |
| Secrets Manager | 1 secret | $0.40/secret/mo | **$0.40** |
| CloudWatch Logs | ~1 GB/mo | $0.50/GB | **~$0.50** |
| CloudWatch Alarms | 4 alarms | $0.10/alarm/mo | **$0.40** |
| Elastic IP | In use (no charge) | $0.00 | **$0.00** |

### Summary

| Scenario | Cost |
|---|---|
| **Per hour** | ~$0.09 |
| **Per day** | ~$2.16 |
| **3-day demo** | **~$6.50** |
| **1 week** | **~$15.10** |
| **1 month (24/7)** | **~$66/month** |

### Cost Breakdown by Category

```
NAT Gateway    ████████████████████████  $33.35  (50%)
RDS            ███████████              $15.44  (23%)
ALB            ████                      $6.84  (10%)
ECS Fargate    ████                      $8.96  (14%)
Other          █                         $1.44   (3%)
```

### Why NAT Gateway is the Biggest Cost

ECS tasks run in **private subnets** (security best practice — no public IPs). To pull Docker images from ECR, read secrets from Secrets Manager, and write to S3, they need outbound internet access. The NAT Gateway provides this at $0.045/hr regardless of traffic.

**Alternative for cost reduction:** Add VPC Interface Endpoints for ECR, S3, and Secrets Manager (~$7.50/mo each) to eliminate NAT Gateway data charges — but for a short demo the NAT Gateway is simpler.

### Teardown Savings

When the demo is done, `terraform destroy` removes everything. No resources continue to accrue charges.

---

## Project Structure

```
demo-app/
├── src/
│   ├── app/
│   │   ├── page.tsx                  # Home — landing page
│   │   ├── about/page.tsx            # About page
│   │   ├── dashboard/page.tsx        # Dashboard placeholder
│   │   ├── layout.tsx                # Root layout (Geist font, metadata)
│   │   ├── globals.css               # Tailwind base styles
│   │   └── api/
│   │       ├── health/route.ts       # GET /api/health → {status, timestamp}
│   │       └── upload/route.ts       # POST /api/upload → S3 upload → URL
│   └── lib/
│       └── s3.ts                     # S3Client (IAM role in prod, keys in dev)
├── terraform/
│   ├── main.tf                       # Root — wires all 8 modules
│   ├── variables.tf                  # Input variables with defaults
│   ├── outputs.tf                    # app_url, ecr_url, deploy commands
│   ├── terraform.tfvars              # Demo environment values
│   ├── bootstrap/
│   │   └── main.tf                   # One-time: S3 state bucket + DynamoDB lock
│   └── modules/
│       ├── networking/               # VPC, 6 subnets, IGW, NAT, route tables, flow logs
│       ├── security/                 # 3 security groups (ALB, ECS, RDS)
│       ├── storage/                  # S3 uploads bucket + access logs bucket
│       ├── database/                 # RDS PostgreSQL 16 instance
│       ├── secrets/                  # Secrets Manager secret + version
│       ├── ecr/                      # ECR repository + lifecycle policy
│       ├── ecs/                      # Cluster, task def, service, ALB, IAM roles
│       └── monitoring/               # CloudWatch alarms, SNS topic, dashboard
├── .github/workflows/
│   ├── ci.yml                        # PR → lint + build
│   └── deploy.yml                    # Push to main → ECR push → ECS deploy
├── Dockerfile                        # 3-stage: deps → builder → runner (node:20-alpine)
├── .dockerignore
└── README.md
```

---

## Local Development

### Prerequisites
- Node.js 20+
- AWS CLI configured with your credentials

### Setup

```bash
npm install
```

Create `.env.local`:
```env
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
AWS_S3_BUCKET=your-bucket-name
NEXT_PUBLIC_API_URL=http://localhost:3000
```

```bash
npm run dev
# Open http://localhost:3000
```

> In production, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are **not used** — the ECS task IAM role grants S3 access automatically via the instance metadata service.

---

## Deployment

### Prerequisites
- Terraform >= 1.6.0
- Docker Desktop
- AWS CLI connected (`aws sts get-caller-identity` should return your account)

### Step 1 — Bootstrap state backend (once only)

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

Creates `serene-stay-tfstate` S3 bucket and `serene-stay-tfstate-lock` DynamoDB table.

### Step 2 — Deploy all infrastructure

```bash
cd terraform
terraform init
terraform plan    # 66 resources to create
terraform apply   # ~10 minutes (RDS is slowest)
```

### Step 3 — Authenticate Docker to ECR

```powershell
# PowerShell
$token = (aws ecr get-login-password --region us-east-1)
docker login --username AWS --password $token 987454179025.dkr.ecr.us-east-1.amazonaws.com
```

### Step 4 — Build and push image

```bash
docker build -t 987454179025.dkr.ecr.us-east-1.amazonaws.com/serene-stay-demo/nextjs-app:latest .
docker push 987454179025.dkr.ecr.us-east-1.amazonaws.com/serene-stay-demo/nextjs-app:latest
```

### Step 5 — Deploy to ECS

```bash
aws ecs update-service \
  --cluster serene-stay-demo-cluster \
  --service serene-stay-demo-service \
  --force-new-deployment \
  --region us-east-1
```

### Step 6 — Verify

```bash
# Check task is running
aws ecs describe-services \
  --cluster serene-stay-demo-cluster \
  --services serene-stay-demo-service \
  --region us-east-1 \
  --query "services[0].{Running:runningCount,Status:deployments[0].rolloutState}"

# Hit health check
curl http://serene-stay-demo-alb-952740670.us-east-1.elb.amazonaws.com/api/health
```

### Teardown

```bash
cd terraform
terraform destroy   # removes all 66 resources, ~5 minutes
```

---

## CI/CD (GitHub Actions)

| Workflow | Trigger | Steps |
|---|---|---|
| `ci.yml` | Pull request → `main` | `npm ci` → `npm run lint` → `npm run build` |
| `deploy.yml` | Push → `main` | ECR login → `docker build` → `docker push` → ECS update-service |

**Required GitHub Secrets:**

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user with ECR push + ECS deploy permissions |
| `AWS_SECRET_ACCESS_KEY` | Corresponding secret key |

---

## Environment Variables

| Variable | Local (`.env.local`) | Production (Secrets Manager) | Description |
|---|---|---|---|
| `AWS_REGION` | `us-east-1` | `us-east-1` | AWS region for S3 client |
| `AWS_S3_BUCKET` | `nextjs-app-uploads` | `serene-stay-uploads-demo` | S3 bucket for file uploads |
| `AWS_ACCESS_KEY_ID` | Your key | **Not used** (IAM role) | S3 auth in local dev only |
| `AWS_SECRET_ACCESS_KEY` | Your secret | **Not used** (IAM role) | S3 auth in local dev only |
| `NEXT_PUBLIC_API_URL` | `http://localhost:3000` | ALB URL | Base URL for client-side API calls |
| `NODE_ENV` | `development` | `production` | Next.js environment |
| `DATABASE_URL` | Local postgres | RDS endpoint | PostgreSQL connection (future use) |

---

## Well-Architected Framework

| Pillar | Decisions Made |
|---|---|
| **Security** | No static AWS keys in containers — ECS task IAM role for S3. All secrets in Secrets Manager. RDS in isolated DB subnets. Security groups enforce least-privilege (ALB→ECS on :3000, ECS→RDS on :5432). VPC Flow Logs enabled. ECR scan-on-push. Non-root container user. |
| **Reliability** | ALB health checks on `/api/health`. ECS deployment circuit breaker with auto-rollback. RDS automated backups (3-day retention). Multi-AZ ALB (us-east-1a + 1b). |
| **Operational Excellence** | All infrastructure in Terraform (66 resources, 8 modules). GitHub Actions CI/CD. CloudWatch dashboard + 4 alarms. Structured log groups with retention policies. |
| **Performance Efficiency** | ECS Fargate — serverless containers, no EC2 to manage. Smallest viable task size (256 CPU / 512 MB). RDS gp3 storage with auto-scaling. |
| **Cost Optimization** | Single-AZ RDS (saves ~$13/mo vs Multi-AZ). 1 Fargate task. No WAF, no CloudFront. `skip_final_snapshot = true` for easy teardown. ECR lifecycle policy prevents image accumulation. |
| **Sustainability** | Managed services (Fargate, RDS) — no idle EC2. Scale to zero possible by setting `desired_count = 0`. |
