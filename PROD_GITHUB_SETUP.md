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
- GitHub repository -> `Settings` -> `Environments` -> `prod` -> `Environment secrets`

| Secret name | Required | Value to fill |
|---|---|---|
| `AWS_ROLE_ARN` | Yes | `arn:aws:iam::<AWS_ACCOUNT_ID>:role/<PROD_GITHUB_ACTIONS_ROLE_NAME>` |
| `AMPLIFY_GITHUB_TOKEN` | Yes | `<GITHUB_PAT_FOR_AMPLIFY>` |

Notes:
- `AWS_ROLE_ARN` is used by GitHub Actions OIDC auth for Terraform and backend deploy.
- `AMPLIFY_GITHUB_TOKEN` is passed to Terraform and used by Amplify GitHub integration.

## 3. Required GitHub Variable (Environment: prod)

Set this under:
- GitHub repository -> `Settings` -> `Environments` -> `prod` -> `Environment variables`

| Variable name | Required | Value to fill |
|---|---|---|
| `AWS_REGION` | Yes | `us-east-1` (or your target region) |

## 4. Required AWS Prerequisites

Before first prod deploy, ensure:
- GitHub OIDC provider exists in AWS account.
- IAM role in `AWS_ROLE_ARN` trusts GitHub Actions for this repository/workflows.
- IAM role has permissions for Terraform-managed resources (Lambda, API Gateway, DynamoDB, Amplify, IAM pass role, logs, S3 state access).

## 5. How To Obtain Each Value Quickly

Use this section to fetch every required value in a few minutes.

### A. Get `AWS_ROLE_ARN`

Option 1 (recommended): from Terraform output (inside `infrastructure`)

```bash
cd infrastructure
terraform output -raw github_actions_role_arn
```

If output exists, copy it directly into GitHub secret `AWS_ROLE_ARN` for environment `prod`.

Option 2: find role in AWS CLI by name pattern

```bash
aws iam list-roles --query "Roles[?contains(RoleName, 'github-actions')].Arn" --output text
```

Then pick the production role ARN (for example one containing `accommodations-planner-prod`).

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

### C. Get `AWS_REGION`

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

Set that value into GitHub environment variable `AWS_REGION` for `prod`.

### D. Verify Values Before Saving

Checklist:

- `AWS_ROLE_ARN` starts with `arn:aws:iam::` and contains a role name.
- `AMPLIFY_GITHUB_TOKEN` is non-empty and not expired/revoked.
- `AWS_REGION` matches deployed resources and Terraform target region.

## 6. Fill-This-Now Template

Copy this section and replace placeholders:

```text
Environment: prod
AWS_ROLE_ARN=arn:aws:iam::<AWS_ACCOUNT_ID>:role/<PROD_GITHUB_ACTIONS_ROLE_NAME>
AMPLIFY_GITHUB_TOKEN=<GITHUB_PAT_FOR_AMPLIFY>
AWS_REGION=us-east-1
```

## 7. CLI Commands (Optional)

Use GitHub CLI to set values quickly:

```bash
gh secret set AWS_ROLE_ARN --env prod --body "arn:aws:iam::<AWS_ACCOUNT_ID>:role/<PROD_GITHUB_ACTIONS_ROLE_NAME>"
gh secret set AMPLIFY_GITHUB_TOKEN --env prod --body "<GITHUB_PAT_FOR_AMPLIFY>"
gh variable set AWS_REGION --env prod --body "us-east-1"
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
- [ ] `AWS_ROLE_ARN` set in `prod` environment secrets.
- [ ] `AMPLIFY_GITHUB_TOKEN` set in `prod` environment secrets.
- [ ] `AWS_REGION` set in `prod` environment variables.
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
