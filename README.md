# 🏡 Accommodations Planner — Haddar Etna Luxury B&B

A production-ready monorepo for a Bed & Breakfast accommodations planner built with:
- **Frontend**: Next.js 15 (TypeScript, hosted on AWS Amplify)
- **Backend**: AWS Lambda (Node.js 20, TypeScript) + API Gateway REST API
- **Database**: DynamoDB (on-demand billing)
- **IaC**: AWS CloudFormation (root + nested stacks)
- **CI/CD**: GitHub Actions reusable deployment workflows

---

## 📁 Repository Structure

```
accommodations-planner/
├── frontend/          # Next.js 15 app (Haddar Etna Luxury B&B UI)
├── backend/           # Lambda handlers (TypeScript)
├── infrastructure/    # CloudFormation templates, params, cleanup scripts
└── .github/workflows/ # CI, deploy-dev, deploy-prod pipelines
```

---

## 🔧 Prerequisites

| Tool | Version |
|------|---------|
| Node.js | 20.x |
| npm | 10.x (bundled with Node 20) |
| AWS CLI | v2 |
| GitHub CLI | latest |
| AWS Account | with IAM permissions |
| Docker | 24.x+ (for LocalStack) |
| Python | 3.x (for `cfn-lint`) |

---

## ✅ CloudFormation Checks Before Commit

Validate templates locally before pushing infrastructure changes:

```bash
cd infrastructure
pip install cfn-lint
cfn-lint root-stack.yaml
cfn-lint nested/*.yaml
aws cloudformation validate-template --template-body file://root-stack.yaml
for template in nested/*.yaml; do
  aws cloudformation validate-template --template-body "file://${template}"
done
```

The same linting is enforced in CI by [infra-validate.yml](.github/workflows/infra-validate.yml).

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

### Infrastructure local testing (optional)

For local integration tests, use `docker compose up` and let the bundled deploy
service provision LocalStack resources from scripts. CloudFormation deployment
is used in GitHub Actions for dev/prod environments.

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

### Backend (Lambda environment variables — set by CloudFormation, no defaults)

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

## ☁️ GitHub Actions AWS Credentials Setup

Before the first deploy, configure repository secrets used by deployment workflows.

### 1. Configure GitHub secrets

```bash
# Set GitHub Actions secrets (repository-level) — required, no fallback
gh secret set AWS_ACCESS_KEY_ID --body "<AWS_ACCESS_KEY_ID>"
gh secret set AWS_SECRET_ACCESS_KEY --body "<AWS_SECRET_ACCESS_KEY>"
gh secret set AMPLIFY_GITHUB_TOKEN --body "<your-token>"

# Set deploy region secret (repo-level) — required, no fallback
gh secret set DEPLOY_AWS_REGION --body "us-east-1"
```

### 2. Create GitHub Environments

```bash
# Create environments (prod requires manual approval)
gh api repos/:owner/:repo/environments/dev --method PUT
gh api repos/:owner/:repo/environments/prod --method PUT \
  -f wait_timer=0 \
  -F reviewers='[{"type":"User","id":<YOUR_USER_ID>}]'
```

### 3. First deployment

Use `Deploy Dev Infra` from GitHub Actions to create/update stacks in the `dev`
environment.

---

## 🔄 Deploying

### Dev

Automatic deploy:
1. Push to `master` with infrastructure changes
2. `.github/workflows/deploy-dev-infra.yml` runs
3. The workflow calls `.github/workflows/deploy-infra.yml` for the `dev` environment

Manual deploy:
1. Go to Actions and run `Deploy Dev Infra`
2. Use checkboxes to select services to deploy:
  - `deploy_dynamodb`
  - `deploy_lambda`
  - `deploy_api_gateway`
  - `deploy_amplify`
  - `deploy_iam`
  - `deploy_cognito`
3. Optional cleanup controls:
  - `cleanup_orphaned_resources`
  - `remove_orphaned_dynamodb` (only relevant when DynamoDB deploy is disabled)

### Prod (manual `workflow_dispatch`)

1. Go to Actions and run `Deploy Prod Infra`
2. Type `deploy-prod` in the confirmation box
3. Use checkboxes to select services to deploy:
  - `deploy_dynamodb`
  - `deploy_lambda`
  - `deploy_api_gateway`
  - `deploy_amplify`
  - `deploy_iam`
  - `deploy_cognito`
4. Optional cleanup controls:
  - `cleanup_orphaned_resources`
  - `remove_orphaned_dynamodb` (only relevant when DynamoDB deploy is disabled)
5. Workflow calls `.github/workflows/deploy-infra.yml` for the `prod` environment

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

Amplify App → GitHub repo master branch → Next.js SSG build
```
