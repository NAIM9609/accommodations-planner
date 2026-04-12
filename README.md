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
| AWS SAM CLI | latest (optional, for local Lambda invoke) |

---

## 🐳 Local Development with LocalStack

LocalStack emulates AWS services (DynamoDB, API Gateway, Lambda) on your machine — no real AWS account needed for local testing.

### 1. Start LocalStack

```bash
docker compose up -d
# LocalStack health: http://localhost:4566/_localstack/health
```

The init script (`scripts/localstack-init.sh`) automatically creates the DynamoDB table on startup.

### 2. Run the backend (Lambda) locally

```bash
cd backend
npm install
cp .env.example .env.local   # already has DYNAMODB_ENDPOINT=http://localhost:4566
export $(grep -v '^#' .env.local | xargs)
sam local start-api           # API available at http://localhost:3001
```

> Unit tests never need LocalStack — DynamoDB is fully mocked by Jest: `npm test`

### 3. Run the frontend

`frontend/.env.development` is committed with localhost defaults and is loaded **automatically** by `npm run dev`. No manual setup needed.

```bash
cd frontend
npm install
npm run dev   # http://localhost:3000  →  API at http://localhost:3001 (SAM local)
```

To override the API URL (e.g. point to a real deployed API), create `frontend/.env.local` (gitignored):

```bash
echo "NEXT_PUBLIC_API_BASE_URL=https://abc123.execute-api.us-east-1.amazonaws.com/dev" \
  > frontend/.env.local
```

### LocalStack services used

| Service | Local port | Purpose |
|---------|-----------|---------|
| DynamoDB | `localhost:4566` | Reservations table |
| API Gateway | `localhost:4566` | REST API emulation |
| Lambda | `localhost:4566` | Function emulation |

---

## 🚀 Local Development

### Frontend

`frontend/.env.development` is committed with LocalStack localhost defaults — no setup required:

```bash
cd frontend
npm install
npm run dev   # http://localhost:3000
```

To use a different API URL, create `frontend/.env.local` (gitignored, takes precedence):

```bash
echo "NEXT_PUBLIC_API_BASE_URL=https://abc123.execute-api.us-east-1.amazonaws.com/dev" \
  > frontend/.env.local
```

### Backend (tests only — Lambda runs on AWS)

Unit tests mock DynamoDB entirely, so no real AWS credentials or env vars are needed:

```bash
cd backend
npm install
npm test        # all tests run in-process with mocked DynamoDB
npm run build   # compiles TypeScript → dist/
```

For **manual local integration testing** against a real DynamoDB table:

```bash
# Copy the example and fill in your values
cp backend/.env.example backend/.env.local

# Load vars and invoke a handler locally via AWS SAM CLI
#   https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/using-sam-cli-local-invoke.html
export $(grep -v '^#' backend/.env.local | xargs)
sam local invoke HealthFunction

# Or simply run tests with real env vars set:
AWS_REGION=us-east-1 \
  DYNAMODB_TABLE_NAME=accommodations-planner-dev-reservations \
  npm --prefix backend test
```

> **Never commit `backend/.env.local`** — it is already listed in `.gitignore`.

---

## 🌐 Environment Variables

### Frontend env files

| File | Committed | Loaded in | Purpose |
|------|-----------|-----------|---------|
| `frontend/.env.development` | ✅ | `next dev` | Localhost defaults (LocalStack / SAM local) |
| `frontend/.env.local` | ❌ gitignored | always | Personal overrides (takes precedence) |
| `frontend/.env.example` | ✅ | manual | Template — documents available variables |

| Variable | Description | Local default |
|----------|-------------|---------------|
| `NEXT_PUBLIC_API_BASE_URL` | API base URL | `http://localhost:3001` (SAM local) |
| `NEXT_PUBLIC_STAGE` | Deployment stage | `local` |

### Backend (Lambda environment variables — set by Terraform, no defaults)

| Variable | Description | Required |
|----------|-------------|---------|
| `DYNAMODB_TABLE_NAME` | DynamoDB table name | ✅ |
| `ENVIRONMENT` | `dev` or `prod` | ✅ |
| `AWS_REGION` | AWS region (auto-set by Lambda runtime) | ✅ (runtime) |
| `DYNAMODB_ENDPOINT` | Override DynamoDB endpoint (LocalStack only) | local only |

> `DYNAMODB_ENDPOINT` is **never** set in production. The Lambda SDK uses the standard AWS endpoint when this var is absent.

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
gh variable set AWS_REGION --env dev --body "us-east-1"
gh variable set AWS_REGION --env prod --body "us-east-1"
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
3. Requires approval from a `prod` environment reviewer
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