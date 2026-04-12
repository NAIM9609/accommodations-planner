# Production GitHub Setup Checklist

This file tells you exactly what to configure in GitHub for successful production deployment.

## 1. Required GitHub Environment

- Environment name: `prod`
- Recommended protection:
  - Required reviewer(s): enabled
  - Prevent self-review: enabled

Create it in:
- GitHub repository -> `Settings` -> `Environments` -> `New environment` -> `prod`

## 2. Required GitHub Secrets (Environment: prod)

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

## 3. Required GitHub Variable (Environment: prod)

No additional GitHub variable is required.

## 4. Required AWS Prerequisites

Before first prod deploy, ensure:
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
4. Store it as environment secret `AMPLIFY_GITHUB_TOKEN` in `prod`.

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
Environment: prod
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

## 8. How Frontend Deployment Works

- CI workflow (`ci.yml`) only lints/tests/builds.
- Frontend deployment is handled by AWS Amplify branch integration configured by Terraform.
- Current configuration points Amplify to branch `master`.

What this means:
- Frontend is not deployed by `ci.yml` itself.
- Frontend updates are deployed by Amplify when commits land on the configured branch.

## 9. Final Pre-Deploy Checks

- [ ] `prod` environment exists in GitHub.
- [ ] `AWS_ACCESS_KEY_ID` set in Actions secrets.
- [ ] `AWS_SECRET_ACCESS_KEY` set in Actions secrets.
- [ ] `AMPLIFY_GITHUB_TOKEN` set in Actions secrets.
- [ ] `DEPLOY_AWS_REGION` set as a GitHub Actions secret.
- [ ] Branch used for production is `master` (or update Terraform/workflows if different).
- [ ] Run workflow: `Deploy Prod` and confirm with `deploy-prod`.

## 10. Future Custom Domain (When You Are Ready)

The default Amplify domain remains active now. To switch later, set these Terraform variables in `infrastructure/prod.tfvars` and apply:

```hcl
amplify_custom_domain_enabled = true
amplify_custom_domain_name    = "example.com"
amplify_custom_domain_prefix  = "" # use "www" for www.example.com
```

Then run your production deploy workflow. Amplify will provide DNS records to validate/attach the domain.
