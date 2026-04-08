# DevOps Challenge - SimpleTimeService

A minimal microservice deployed on AWS ECS Fargate using Terraform. Returns current timestamp and visitor IP address.

## Architecture

```
Internet (HTTP :80 / HTTPS :443)
              │
  ┌───────────▼────────────┐
  │   ALB (Public Subnets) │  ← ap-south-1a, ap-south-1b
  │   HTTP → HTTPS (301)   │  ← when ACM cert provided
  └───────────┬────────────┘
              │
  ┌───────────▼────────────────┐
  │  ECS Fargate (Private)     │  ← Non-root container, 2 tasks across 2 AZs
  │  Security group: ALB only  │
  └───────────┬────────────────┘
              │
  ┌───────────▼────────────┐
  │     NAT Gateway        │  ← Outbound only (image pulls, etc.)
  └────────────────────────┘
```

**Key design decisions:**

| Decision | Reason |
|---|---|
| ECS Fargate | Serverless containers — no EC2 nodes to manage or patch |
| Private subnets for app | App is never directly internet-accessible |
| ALB in public subnets | Single encrypted entry point, forwards to private tasks |
| HTTP → HTTPS redirect | All plaintext traffic rejected at ALB level |
| Single NAT Gateway | Cost tradeoff (~$32/mo vs ~$64/mo for HA). For production, use one NAT per AZ |
| 2 tasks across 2 AZs | High availability — survives single AZ failure |
| Non-root container (UID 1001) | Reduces blast radius if container is compromised |
| Separate task & execution IAM roles | Least-privilege: execution role = ECS agent; task role = app code |
| Container Insights + CloudWatch | Observability from day one |
| Auto-scaling (CPU 70%) | Handles traffic spikes without manual intervention |

## Repository Structure

```
.
├── .github/workflows/deploy.yml   # CI/CD: build image → push → redeploy ECS
├── app/
│   ├── app.py                     # Flask microservice
│   ├── requirements.txt
│   ├── .dockerignore
│   └── Dockerfile                 # Multi-stage build, non-root user (UID 1001)
└── terraform/
    ├── main.tf                    # Root module — calls vpc, alb, ecs modules
    ├── variables.tf               # Input variable definitions
    ├── outputs.tf                 # Outputs: app URL, cluster name, etc.
    ├── terraform.tfvars           # Variable values
    ├── versions.tf                # Provider + Terraform version constraints
    └── modules/
        ├── vpc/                   # VPC, subnets, IGW, NAT Gateway, route tables
        ├── alb/                   # ALB, target group, HTTP/HTTPS listeners, SG
        └── ecs/                   # Cluster, task definition, service, IAM, autoscaling
```

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Terraform | >= 1.5.0 | [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | >= 2.x | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| Docker | >= 24.x | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |

## Part 1: Build & Push Docker Image

```bash
cd app/

# Build image
docker build -t dineshreddy2025/simpletimeservice:latest .

# Test locally
docker run -p 5000:5000 dineshreddy2025/simpletimeservice:latest

# Verify response
curl http://localhost:5000/
# {"ip": "172.17.0.1", "timestamp": "2026-04-07T10:00:00+00:00"}

# Verify health check
curl http://localhost:5000/health
# {"status": "healthy"}

# Push to DockerHub
docker login
docker push dineshreddy2025/simpletimeservice:latest
```

## Part 2: Deploy Infrastructure with Terraform

### 1. Configure AWS Credentials

```bash
aws configure
# AWS Access Key ID:     <your-key>
# AWS Secret Access Key: <your-secret>
# Default region:        ap-south-1
# Default output format: json
```

Or via environment variables:
```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="ap-south-1"
```

### 2. Set Up Remote State Backend (S3 + DynamoDB)

Terraform state is stored remotely in S3 so anyone on the team can run `terraform apply` without conflicting. DynamoDB prevents two people running apply at the same time.

```bash
# From repo root
chmod +x scripts/setup-backend.sh
./scripts/setup-backend.sh
```

The script will:
- Create an S3 bucket named `simpletimeservice-tfstate-<your-account-id>` with versioning + AES-256 encryption + public access blocked
- Create a DynamoDB table `terraform-state-lock` (pay-per-request, no provisioned cost)
- Print the exact backend block to paste into `terraform/versions.tf`

After running, open [terraform/versions.tf](terraform/versions.tf) and replace `BUCKET_NAME` with the bucket name printed by the script:

```hcl
backend "s3" {
  bucket         = "simpletimeservice-tfstate-123456789012"  # ← your account ID
  key            = "devops-challenge/terraform.tfstate"
  region         = "ap-south-1"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

### 3. (Optional) Enable HTTPS

To enable HTTPS with automatic HTTP → HTTPS redirect:

1. Request a certificate in AWS Certificate Manager (ACM):
   ```bash
   aws acm request-certificate \
     --domain-name yourdomain.com \
     --validation-method DNS \
     --region ap-south-1
   ```
2. Complete DNS validation in your domain registrar
3. Copy the certificate ARN and set it in `terraform.tfvars`:
   ```hcl
   acm_certificate_arn = "arn:aws:acm:ap-south-1:123456789012:certificate/xxxx"
   ```

> Without a certificate, the ALB serves HTTP on port 80 only.

### 4. Deploy

```bash
cd terraform/

terraform init
terraform plan
terraform apply
```

### 5. Access the Application

After `terraform apply` completes, the URL is printed:

```
Outputs:
app_url = "http://<alb-dns>.ap-south-1.elb.amazonaws.com"
```

```bash
curl http://<alb-dns>.ap-south-1.elb.amazonaws.com/
# {"ip": "203.0.113.42", "timestamp": "2026-04-07T10:30:00+00:00"}
```

> Wait ~2 minutes after `terraform apply` for ECS tasks to pass health checks.

## CI/CD

On every push to `main` that changes files under `app/`:

1. Docker image is built and pushed to DockerHub (tagged with git SHA + `latest`)
2. ECS service is force-redeployed with the new image

**Required GitHub Secrets:**

| Secret | Value |
|---|---|
| `DOCKERHUB_USERNAME` | `dineshreddy2025` |
| `DOCKERHUB_TOKEN` | DockerHub access token |
| `AWS_ACCESS_KEY_ID` | AWS key with ECS permissions |
| `AWS_SECRET_ACCESS_KEY` | AWS secret |

## Cleanup

Destroy all AWS resources to avoid ongoing costs:

```bash
cd terraform/
terraform destroy
```

## Security Notes

- ECS tasks run as **non-root user (UID 1001)**
- ECS security group accepts traffic **from ALB only** — not the internet
- **Separate IAM roles**: execution role (ECS agent) vs task role (app code)
- HTTP traffic is **redirected to HTTPS** (when ACM cert provided)
- No credentials or secrets committed to this repository
- Multi-stage Docker build — dev dependencies never reach the production image
