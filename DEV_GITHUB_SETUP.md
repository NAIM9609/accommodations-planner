# Development GitHub Setup Checklist

This file tells you exactly what to configure in GitHub for successful development deployment.

## 1. Required GitHub Environment

- Environment name: `dev`
- Recommended protection:
  - No manual approval required (typically)
  - Keep default protections lightweight for faster iteration

Create it in:
- GitHub repository -> `Settings` -> `Environments` -> `New environment` -> `dev`

## 2. Required GitHub Secrets (Environment: dev)

Set these under:
- GitHub repository -> `Settings` -> `Secrets and variables` -> `Actions` -> `Secrets`

| Secret name | Required | Value to fill |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Yes | `<AWS_ACCESS_KEY_ID>` |
| `AWS_SECRET_ACCESS_KEY` | Yes | `<AWS_SECRET_ACCESS_KEY>` |
| `AMPLIFY_GITHUB_TOKEN` | Yes | `<GITHUB_PAT_FOR_AMPLIFY>` |
| `DEPLOY_AWS_REGION` | Yes | `us-east-1` (or your target region) |

Notes:
- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are used by GitHub Actions to authenticate to AWS.
- `AMPLIFY_GITHUB_TOKEN` is passed to Terraform and used by Amplify GitHub integration.

## 3. Required GitHub Variable (Environment: dev)

No additional GitHub variable is required.

## 4. Required AWS Prerequisites

Before first dev deploy, ensure:
- The IAM user/credentials behind `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` exist.
- The IAM user has permissions for Terraform-managed resources (Lambda, API Gateway, DynamoDB, Amplify, IAM pass role, logs, S3 state access).

## 5. How To Obtain Each Value Quickly

Use this section to fetch every required value in a few minutes.

### A. Get `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`

Option 1 (recommended): create a dedicated CI user credentials in IAM.

```bash
aws iam create-user --user-name accommodations-planner-ci
aws iam create-access-key --user-name accommodations-planner-ci
```

Copy and store both values in GitHub secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Option 2: reuse existing IAM user credentials that already have required permissions.

### B. Get `AMPLIFY_GITHUB_TOKEN`

Create a GitHub personal access token (PAT):

1. Go to GitHub -> Settings -> Developer settings -> Personal access tokens.
2. Create either:
   - Fine-grained token (preferred): grant repository access to this repo and required read access so Amplify can pull source/build.
   - Classic token: `repo` scope.
3. Copy token once (GitHub only shows it at creation time).
4. Store it as environment secret `AMPLIFY_GITHUB_TOKEN` in `dev`.

Quick validation (optional):

```bash
curl -H "Authorization: Bearer <GITHUB_PAT_FOR_AMPLIFY>" https://api.github.com/user
```

If valid, response includes your GitHub login JSON.

### C. Get `DEPLOY_AWS_REGION`

Use the region where your stack is deployed (default in this repo is `us-east-1`).

Confirm from Terraform variable files:

```bash
cd infrastructure
grep -n "aws_region" local.tfvars || true
```

Or confirm from current AWS CLI profile:

```bash
aws configure get region
```

Set that value into GitHub Actions secret `DEPLOY_AWS_REGION`.

### D. Verify Values Before Saving

Checklist:

- `AWS_ACCESS_KEY_ID` is present and active.
- `AWS_SECRET_ACCESS_KEY` is present and matches the access key.
- `AMPLIFY_GITHUB_TOKEN` is non-empty and not expired/revoked.
- `DEPLOY_AWS_REGION` matches deployed resources and Terraform target region.

## 6. Fill-This-Now Template

Copy this section and replace placeholders:

```text
Environment: dev
AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID>
AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY>
AMPLIFY_GITHUB_TOKEN=<GITHUB_PAT_FOR_AMPLIFY>
DEPLOY_AWS_REGION=us-east-1
```

## 7. CLI Commands (Optional)

Use GitHub CLI to set values quickly:

```bash
gh secret set AWS_ACCESS_KEY_ID --body "<AWS_ACCESS_KEY_ID>"
gh secret set AWS_SECRET_ACCESS_KEY --body "<AWS_SECRET_ACCESS_KEY>"
gh secret set AMPLIFY_GITHUB_TOKEN --body "<GITHUB_PAT_FOR_AMPLIFY>"
gh secret set DEPLOY_AWS_REGION --body "us-east-1"
```

## 8. How Dev Deployment Works

- Dev deployment is automatic on push to branch `master`.
- Workflow chain is:
  - CI checks run (`ci.yml`).
  - Dev deploy runs (`deploy-dev.yml`) and applies Terraform + backend deployment.
- Amplify frontend updates come from Amplify Git branch integration configured by Terraform.

What this means:
- You do not manually trigger dev deployment in normal flow.
- Frontend updates appear when commits land on the configured Amplify branch (`master`).

## 9. Final Pre-Deploy Checks

- [ ] `dev` environment exists in GitHub.
- [ ] `AWS_ACCESS_KEY_ID` set in Actions secrets.
- [ ] `AWS_SECRET_ACCESS_KEY` set in Actions secrets.
- [ ] `AMPLIFY_GITHUB_TOKEN` set in Actions secrets.
- [ ] `DEPLOY_AWS_REGION` set as a GitHub Actions secret.
- [ ] Dev deploy workflow is enabled and branch is `master`.
- [ ] Push a small commit to `master` and confirm Actions + Amplify build start.
