#!/usr/bin/env bash
# Post-apply smoke tests for a LocalStack Terraform deployment.
# Asserts that every Terraform-managed resource was actually created
# in the LocalStack container.
#
# Usage:
#   LOCALSTACK_ENDPOINT=http://localhost:14566 \
#   AWS_DEFAULT_REGION=us-east-1 \
#   bash .github/scripts/localstack-post-apply-smoke.sh accommodations-planner-dev
#
# Exit code 0 = all checks passed; non-zero = at least one check failed.

set -euo pipefail

PREFIX="${1:-accommodations-planner-dev}"
ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:14566}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

PASS=0
FAIL=0

aws_local() {
  aws --endpoint-url "$ENDPOINT" --region "$REGION" "$@"
}

check_pass() {
  echo "[PASS] $1"
  PASS=$((PASS + 1))
}

check_fail() {
  echo "[FAIL] $1"
  FAIL=$((FAIL + 1))
}

# ---------------------------------------------------------------------------
# DynamoDB reservations table
# ---------------------------------------------------------------------------
echo "--- DynamoDB ---"
TABLE_STATUS=$(aws_local dynamodb describe-table \
  --table-name "${PREFIX}-reservations" \
  --query 'Table.TableStatus' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TABLE_STATUS" = "ACTIVE" ]; then
  check_pass "DynamoDB table ${PREFIX}-reservations is ACTIVE"
else
  check_fail "DynamoDB table ${PREFIX}-reservations not found or status=${TABLE_STATUS}"
fi

# ---------------------------------------------------------------------------
# Lambda: health function
# ---------------------------------------------------------------------------
echo "--- Lambda ---"
HEALTH_FN=$(aws_local lambda get-function \
  --function-name "${PREFIX}-health" \
  --query 'Configuration.FunctionName' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$HEALTH_FN" = "${PREFIX}-health" ]; then
  check_pass "Lambda function ${PREFIX}-health exists"
else
  check_fail "Lambda function ${PREFIX}-health not found"
fi

# Lambda: reservations function
RES_FN=$(aws_local lambda get-function \
  --function-name "${PREFIX}-reservations" \
  --query 'Configuration.FunctionName' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$RES_FN" = "${PREFIX}-reservations" ]; then
  check_pass "Lambda function ${PREFIX}-reservations exists"
else
  check_fail "Lambda function ${PREFIX}-reservations not found"
fi

# ---------------------------------------------------------------------------
# IAM Lambda execution role
# ---------------------------------------------------------------------------
echo "--- IAM ---"
ROLE_NAME=$(aws_local iam get-role \
  --role-name "${PREFIX}-lambda-role" \
  --query 'Role.RoleName' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$ROLE_NAME" = "${PREFIX}-lambda-role" ]; then
  check_pass "IAM role ${PREFIX}-lambda-role exists"
else
  check_fail "IAM role ${PREFIX}-lambda-role not found"
fi

# ---------------------------------------------------------------------------
# NOTE: API Gateway v2 (HTTP API) is intentionally excluded from this smoke
# test because LocalStack Community Edition does not support the apigatewayv2
# service. The api_gateway Terraform module is validated separately via
# `terraform validate` and tflint in the infra-validate.yml workflow.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Smoke test results: ${PASS} passed, ${FAIL} failed."
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
