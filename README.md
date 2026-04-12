# 🏡 Accommodations Planner — Maple Grove B&B

A production-ready monorepo for a Bed & Breakfast accommodations planner built with:
- **Frontend**: Next.js 15 (TypeScript, hosted on AWS Amplify)
- **Backend**: AWS Lambda (Node.js 20, TypeScript) + API Gateway REST API
- **Database**: DynamoDB (on-demand billing)
- **IaC**: Terraform 1.7+ (modular)
- **CI/CD**: GitHub Actions with AWS OIDC (no long-lived credentials)

---

## 📁 Repository Structure

```
accommodations-planner/
├── frontend/          # Next.js 15 app (Maple Grove B&B UI)
├── backend/           # Lambda handlers (TypeScript)
├── infrastructure/    # Terraform modules (DynamoDB, Lambda, API GW, Amplify)
└── .github/workflows/ # CI, deploy-dev, deploy-prod pipelines
```

---

## 🔧 Prerequisites

| Tool | Version |
|------|---------|
| Node.js | 20.x |
| npm | 10.x (bundled with Node 20) |
| Terraform | >= 1.7 |
| AWS CLI | v2 |
| GitHub CLI | latest |
| AWS Account | with IAM permissions |
| Docker | 24.x+ (for LocalStack) |

---

## 🐳 Local Development with LocalStack

`docker compose up` starts **everything**: LocalStack emulates AWS (DynamoDB,
API Gateway, Lambda), and the bundled `deploy` service builds the TypeScript
Lambda, deploys all resources, and writes the API URL to `frontend/.env.local`.
No SAM CLI. No manual `aws` commands. No real AWS account needed.

### 1. Start the full local stack

```bash
docker compose up
# Wait for: "Check Local Stack is ready!"
# LocalStack health: http://localhost:14566/_localstack/health
```

The `deploy` service (see `scripts/deploy-local.sh`) runs once and:
1. Builds the TypeScript Lambda (`npm run build`)
2. Creates the DynamoDB table
3. Creates the Lambda functions in LocalStack
4. Creates the API Gateway with all routes (including CORS preflight support)
5. Writes the API URL to `frontend/.env.local`

### 2. Run the frontend

```bash
cd frontend
npm install
npm run dev   # http://localhost:3000  →  API at LocalStack (port 14566)
```

`frontend/.env.development` is committed with the LocalStack URL as the stable
default. `frontend/.env.local` (written by the deploy service) takes precedence
and always contains the exact URL for the current LocalStack instance.

> Start the frontend **after** docker compose reports the stack is ready.
> If you started it first, restart `npm run dev` to pick up the new `.env.local`.

To override the API URL (e.g. point to a real deployed API), create
`frontend/.env.local` manually:

```bash
echo "NEXT_PUBLIC_API_BASE_URL=https://abc123.execute-api.us-east-1.amazonaws.com/dev" \
  > frontend/.env.local
```

### LocalStack services used

| Service | Port | Purpose |
|---------|------|---------|
| DynamoDB | `localhost:14566` | Reservations table |
| API Gateway | `localhost:14566` | HTTP API (routes requests to Lambda) |
| Lambda | `localhost:14566` | Function execution |

### Terraform local testing (optional)

Use [`tflocal`](https://github.com/localstack/terraform-local) to run Terraform
against LocalStack — no provider changes needed, it handles endpoint overrides:

```bash
pip install terraform-local
cd infrastructure
tflocal init
# Test core modules only (Amplify not available in LocalStack Community):
tflocal apply -var-file=local.tfvars \
  -target=module.dynamodb \
  -target=module.lambda \
  -target=module.api_gateway
```

---

## 🚀 Local Development

### Frontend

```bash
cd frontend
npm install
npm run dev   # http://localhost:3000
```

To use a different API URL, create `frontend/.env.local` (gitignored, takes precedence):

```bash
echo "BACKEND_API_URL=https://abc123.execute-api.us-east-1.amazonaws.com/dev" \
  > frontend/.env.local
```

### Backend (tests only — Lambda runs in LocalStack or AWS)

Unit tests mock DynamoDB entirely, so no real AWS credentials or env vars are needed:

```bash
cd backend
npm install
npm test        # all tests run in-process with mocked DynamoDB
npm run build   # compiles TypeScript → dist/
```

For **manual local integration testing** against LocalStack (after `docker compose up`):

```bash
# Export env vars and invoke the handler manually via awslocal
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
awslocal lambda invoke \
  --function-name accommodations-planner-dev-health \
  --payload '{}' /tmp/response.json && cat /tmp/response.json
```

> **Never commit `backend/.env.local`** — it is already listed in `.gitignore`.

---

## 🌐 Environment Variables

### Frontend env files

| File | Committed | Loaded in | Purpose |
|------|-----------|-----------|---------|
| `frontend/.env.development` | ✅ | `next dev` | Localhost defaults (LocalStack) |
| `frontend/.env.local` | ❌ gitignored | always | Written by deploy service; personal overrides (takes precedence) |
| `frontend/.env.example` | ✅ | manual | Template — documents available variables |

| Variable | Description | Local default |
|----------|-------------|---------------|
| `BACKEND_API_URL` | Backend API endpoint (proxied via Next.js `/api` routes) | `http://localhost:14566/restapis/aplocal/dev/_user_request_` (LocalStack REST fallback) |
| `NEXT_PUBLIC_STAGE` | Deployment stage | `dev` |

### Backend (Lambda environment variables — set by Terraform, no defaults)

| Variable | Description | Required |
|----------|-------------|---------|
| `DYNAMODB_TABLE_NAME` | DynamoDB table name | ✅ |
| `ENVIRONMENT` | `dev` or `prod` | ✅ |
| `AWS_REGION` | AWS region (auto-set by Lambda runtime) | ✅ (runtime) |
| `DYNAMODB_ENDPOINT` | Override DynamoDB endpoint (LocalStack only) | local only |

> `DYNAMODB_ENDPOINT` is **never** set in production. The Lambda SDK uses the standard AWS endpoint when this var is absent.

---

## 🔌 API Architecture

The frontend uses **Next.js API routes** to proxy requests to the backend, avoiding direct exposure of LocalStack's complex URL format (`_user_request_`).

```
Frontend Client
    ↓
Next.js API Routes (`/api/...`)  ← Handles all client requests
    ↓
Backend API Gateway  ← Proxied via BACKEND_API_URL env var
    ↓
Lambda Functions
```

**Benefits:**
- **Simpler client code**: Frontend always calls `/api/health`, `/api/reservations`, etc.
- **Easier environment management**: Only the server knows the actual backend URL
- **Production-ready**: Same pattern works for both LocalStack (dev) and AWS (prod)
- **No client exposure**: Backend endpoint details stay on the server

**How it works:**
1. Frontend component calls `fetch('/api/reservations')` (via `getApiBaseUrl()`)
2. Next.js API route `/pages/api/reservations.ts` receives the request
3. Route reads `BACKEND_API_URL` environment variable (set by deploy service)
4. Route forwards request to actual backend (LocalStack or AWS)
5. Response is sent back to client

---

## ☁️ GitHub Actions OIDC Setup

Before first deploy, set up AWS OIDC trust so GitHub Actions can assume an IAM role without long-lived credentials:

### 1. Bootstrap Terraform state (one-time)

```bash
# Create S3 bucket for TF state
aws s3api create-bucket \
  --bucket accommodations-planner-tf-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket accommodations-planner-tf-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket accommodations-planner-tf-state \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name accommodations-planner-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. First Terraform apply (creates OIDC provider + IAM role)

```bash
cd infrastructure
terraform init
terraform apply -var="environment=dev"
```

This creates `aws_iam_openid_connect_provider.github` and `aws_iam_role.github_actions`.

### 3. Configure GitHub secrets/vars

```bash
# Get the IAM role ARN from Terraform output
ROLE_ARN=$(terraform output -raw github_actions_role_arn)

# Set GitHub secrets (per environment) — required, no fallback
gh secret set AWS_ROLE_ARN --env dev --body "$ROLE_ARN"
gh secret set AWS_ROLE_ARN --env prod --body "$ROLE_ARN"
gh secret set AMPLIFY_GITHUB_TOKEN --env dev --body "<your-token>"
gh secret set AMPLIFY_GITHUB_TOKEN --env prod --body "<your-token>"

# Set region variable — required, no fallback
gh variable set DEPLOY_AWS_REGION --env dev --body "us-east-1"
gh variable set DEPLOY_AWS_REGION --env prod --body "us-east-1"
```

### 4. Create GitHub Environments

```bash
# Create environments (prod requires manual approval)
gh api repos/:owner/:repo/environments/dev --method PUT
gh api repos/:owner/:repo/environments/prod --method PUT \
  -f wait_timer=0 \
  -F reviewers='[{"type":"User","id":<YOUR_USER_ID>}]'
```

---

## 🔄 Deploying

### Dev (automatic on push to `main`)

Every push to `main` triggers:
1. `ci.yml` — lint, test, build (backend + frontend)
2. `deploy-dev.yml` — Terraform apply + Lambda update for `dev` environment

### Prod (manual `workflow_dispatch`)

1. Go to **Actions → Deploy Prod → Run workflow**
2. Type `deploy-prod` in the confirmation box
3. Workflow runs Docker/LocalStack smoke tests first (`/health`, create/list reservations)
4. Terraform + backend prod deploy runs only if those local Docker smoke tests pass
5. Requires approval from a `prod` environment reviewer
4. Runs Terraform apply + Lambda update for `prod` environment

---

## 🏗️ Infrastructure Overview

```
API Gateway (REST)
  └── GET  /health             → health Lambda
  └── GET  /reservations       → reservations Lambda
  └── POST /reservations       → reservations Lambda
  └── GET  /reservations/{id}  → reservations Lambda
  └── DELETE /reservations/{id}→ reservations Lambda

DynamoDB Table: accommodations-planner-{env}-reservations
  └── PK: id (String)

Lambda Functions:
  └── accommodations-planner-{env}-health       (128MB, 10s timeout)
  └── accommodations-planner-{env}-reservations (128MB, 10s timeout)

Amplify App → GitHub repo main branch → Next.js SSG build
```

---

## 🔒 Enabling Remote Terraform State

Uncomment the `backend` block in `infrastructure/backend.tf` after bootstrapping the S3 bucket:

```hcl
terraform {
  backend "s3" {
    bucket         = "accommodations-planner-tf-state"
    key            = "accommodations-planner/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "accommodations-planner-tf-lock"
    encrypt        = true
  }
}
```

Then run `terraform init -migrate-state`.