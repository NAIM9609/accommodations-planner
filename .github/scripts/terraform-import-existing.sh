#!/usr/bin/env bash
# terraform-import-existing.sh
#
# Usage (run from the infrastructure/ directory):
#   bash ../.github/scripts/terraform-import-existing.sh <prefix> <aws_region> [lock_timeout]
#
# Imports pre-existing AWS resources into Terraform state so that a subsequent
# `terraform apply` treats them as already-managed rather than trying to
# create them from scratch.
#
# Behaviour:
#   - Any resource address already tracked in state is silently skipped.
#   - If a DynamoDB state lock is detected (stale lock from a previous aborted
#     run), the lock UUID is extracted and force-unlocked, then the import is
#     retried automatically.
#   - Resources not found in AWS (e.g. first-time bootstrap) are also skipped.

set -uo pipefail

PREFIX="${1:?Usage: $0 <prefix> <aws_region> [lock_timeout]}"
AWS_REGION="${2:?Usage: $0 <prefix> <aws_region> [lock_timeout]}"
LOCK_TIMEOUT="${3:-45s}"

# ── Helpers ───────────────────────────────────────────────────────────────────

# Extract the first UUID-shaped token from a string.
_extract_uuid() {
  printf '%s' "$1" \
    | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
    | head -1
}

# Given error output that contains a "Lock Info" block, extract the lock ID
# and run `terraform force-unlock -force` to release the stale lock.
release_stale_lock() {
  local output="$1"
  local lock_id
  lock_id="$(_extract_uuid "${output}")"

  if [ -z "${lock_id}" ]; then
    echo "  [lock] No lock ID found in error output — cannot auto-unlock." >&2
    return 1
  fi

  echo "  [lock] Stale lock detected (ID: ${lock_id}). Attempting force-unlock..."
  if terraform force-unlock -force "${lock_id}" 2>&1; then
    echo "  [lock] Force-unlock succeeded."
    return 0
  fi

  echo "  [lock] Force-unlock failed." >&2
  return 1
}

# Return 0 if the given Terraform resource address is already tracked in state.
# Uses -lock=false because this is a read-only probe and we do not want to
# block on any existing (possibly stale) write lock.
resource_in_state() {
  terraform state list -lock=false 2>/dev/null | grep -qxF "$1"
}

# ── Core import function ──────────────────────────────────────────────────────

# import_resource <terraform_address> <aws_resource_id>
#
# Checks state first and skips when the address is already tracked.
# On a lock-acquisition error, attempts to force-unlock then retries once.
# On a "resource does not exist in AWS" error, skips gracefully.
import_resource() {
  local address="$1"
  local resource_id="$2"

  echo ""
  echo "── ${address}"

  if resource_in_state "${address}"; then
    echo "  Already in state — skipping."
    return 0
  fi

  echo "  Importing <= ${resource_id}"

  local output exit_code
  output="$(terraform import \
    -lock-timeout="${LOCK_TIMEOUT}" \
    "${address}" "${resource_id}" 2>&1)" \
    && exit_code=0 || exit_code=$?

  if [ "${exit_code}" -eq 0 ]; then
    printf '%s\n' "${output}"
    echo "  Import successful."
    return 0
  fi

  printf '%s\n' "${output}"

  # ── Stale lock: force-unlock then retry ──────────────────────────────────
  if printf '%s' "${output}" | grep -q "Error acquiring the state lock"; then
    if release_stale_lock "${output}"; then
      echo "  Retrying import after force-unlock..."
      terraform import \
        -lock-timeout="${LOCK_TIMEOUT}" \
        "${address}" "${resource_id}"
      return $?
    fi
    echo "Error: Unable to release state lock. Aborting import of ${address}." >&2
    return 1
  fi

  # ── Resource absent in AWS or already managed elsewhere — skip ────────────
  if printf '%s' "${output}" | grep -qiE \
    "Cannot import non-existent remote object|Resource already managed by Terraform|does not exist|NoSuchEntity|NotFoundException|ResourceNotFoundException"; then
    echo "  Resource not found in AWS or not importable — skipping."
    return 0
  fi

  return "${exit_code}"
}

# ── Optional helpers: discover AWS-generated resource IDs via AWS CLI ─────────

# Import a Lambda function by name (name is deterministic; ARN is not needed).
import_lambda_function() {
  local func="$1"
  local name="${PREFIX}-${func}"
  local address="module.lambda.aws_lambda_function.${func}"

  echo ""
  echo "── ${address}"

  if resource_in_state "${address}"; then
    echo "  Already in state — skipping."
    return 0
  fi

  if ! aws lambda get-function \
    --function-name "${name}" \
    --region "${AWS_REGION}" \
    --output text \
    --query 'Configuration.FunctionName' \
    &>/dev/null 2>&1; then
    echo "  Lambda function '${name}' not found in AWS — skipping."
    return 0
  fi

  import_resource "${address}" "${name}"
}

# Import the Amplify app and its main branch (IDs are AWS-generated).
import_amplify_app() {
  local app_name="${PREFIX}-frontend"
  local app_id

  app_id="$(aws amplify list-apps \
    --region "${AWS_REGION}" \
    --query "apps[?name=='${app_name}'].appId | [0]" \
    --output text 2>/dev/null || true)"

  echo ""
  echo "── module.amplify.aws_amplify_app.frontend"

  if [ -z "${app_id}" ] || [ "${app_id}" = "None" ]; then
    echo "  Amplify app '${app_name}' not found in AWS — skipping."
    return 0
  fi

  import_resource "module.amplify.aws_amplify_app.frontend" "${app_id}"

  local branch="${AMPLIFY_BRANCH:-master}"
  import_resource "module.amplify.aws_amplify_branch.main" "${app_id}/${branch}"
}

# Import the API Gateway HTTP API and its stage (IDs are AWS-generated).
import_api_gateway() {
  local api_name="${PREFIX}-api"
  local api_id

  api_id="$(aws apigatewayv2 get-apis \
    --region "${AWS_REGION}" \
    --query "Items[?Name=='${api_name}'].ApiId | [0]" \
    --output text 2>/dev/null || true)"

  echo ""
  echo "── module.api_gateway.aws_apigatewayv2_api.api"

  if [ -z "${api_id}" ] || [ "${api_id}" = "None" ]; then
    echo "  API Gateway '${api_name}' not found in AWS — skipping."
    return 0
  fi

  import_resource "module.api_gateway.aws_apigatewayv2_api.api" "${api_id}"

  # Derive environment from prefix (last dash-separated segment: dev or prod).
  local env="${PREFIX##*-}"
  import_resource "module.api_gateway.aws_apigatewayv2_stage.api" "${api_id}/${env}"
}

# ── Import list ───────────────────────────────────────────────────────────────

echo "=== Importing existing resources for prefix: ${PREFIX} (region: ${AWS_REGION}) ==="

# 1. IAM: GitHub Actions OIDC role and its inline policy (root module)
import_resource "aws_iam_role.github_actions" \
  "${PREFIX}-github-actions"

import_resource "aws_iam_role_policy.github_actions" \
  "${PREFIX}-github-actions:${PREFIX}-github-actions-policy"

# 2. DynamoDB reservations table
import_resource "module.dynamodb.aws_dynamodb_table.reservations" \
  "${PREFIX}-reservations"

# 3. Lambda execution role and its inline DynamoDB policy
import_resource "module.lambda.aws_iam_role.lambda" \
  "${PREFIX}-lambda-role"

import_resource "module.lambda.aws_iam_role_policy.lambda_dynamodb" \
  "${PREFIX}-lambda-role:${PREFIX}-lambda-dynamodb"

# 4. CloudWatch log groups for Lambda (names are deterministic)
import_resource 'module.lambda.aws_cloudwatch_log_group.lambda["health"]' \
  "/aws/lambda/${PREFIX}-health"

import_resource 'module.lambda.aws_cloudwatch_log_group.lambda["reservations"]' \
  "/aws/lambda/${PREFIX}-reservations"

# 5. Lambda functions (discovered via AWS CLI)
import_lambda_function "health"
import_lambda_function "reservations"

# 6. Amplify app and branch (IDs discovered via AWS CLI)
import_amplify_app

# 7. API Gateway HTTP API and stage (IDs discovered via AWS CLI)
import_api_gateway

echo ""
echo "=== Import complete. ==="
