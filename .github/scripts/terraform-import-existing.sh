#!/usr/bin/env bash
set -euo pipefail

PREFIX="${1:?prefix is required}"
REGION="${2:?region is required}"
LOCK_TIMEOUT="${3:-5m}"

run_with_lock_recovery() {
  local cmd=("$@")
  local tf_log
  tf_log="$(mktemp)"

  if "${cmd[@]}" 2> >(tee "$tf_log" >&2); then
    rm -f "$tf_log"
    return 0
  fi

  if ! grep -q "Error acquiring the state lock" "$tf_log"; then
    rm -f "$tf_log"
    return 1
  fi

  local lock_id
  lock_id="$(sed -n 's/^  ID:[[:space:]]*//p' "$tf_log" | head -n1 || true)"
  if [ -z "${lock_id:-}" ]; then
    echo "State lock detected but lock ID was not found in Terraform output."
    rm -f "$tf_log"
    return 1
  fi

  echo "State lock detected. Attempting force-unlock for lock ID: $lock_id"
  terraform force-unlock -force "$lock_id"
  echo "Retrying Terraform command after force-unlock..."
  "${cmd[@]}"
  rm -f "$tf_log"
}

import_if_missing() {
  local addr="$1"
  local id="$2"
  if terraform state show "$addr" > /dev/null 2>&1; then
    echo "Already in state: $addr"
    return 0
  fi
  echo "Importing $addr <= $id"
  run_with_lock_recovery terraform import -lock-timeout="$LOCK_TIMEOUT" "$addr" "$id"
}

import_if_missing aws_iam_role.github_actions "${PREFIX}-github-actions" || true
import_if_missing aws_iam_role_policy.github_actions "${PREFIX}-github-actions:${PREFIX}-github-actions-policy" || true
import_if_missing module.dynamodb.aws_dynamodb_table.reservations "${PREFIX}-reservations" || true
import_if_missing module.lambda.aws_iam_role.lambda "${PREFIX}-lambda-role" || true
import_if_missing module.lambda.aws_iam_role_policy.lambda_dynamodb "${PREFIX}-lambda-role:${PREFIX}-lambda-dynamodb" || true
import_if_missing module.lambda.aws_iam_role_policy_attachment.lambda_basic "${PREFIX}-lambda-role/arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" || true
import_if_missing 'module.lambda.aws_cloudwatch_log_group.lambda["health"]' "/aws/lambda/${PREFIX}-health" || true
import_if_missing 'module.lambda.aws_cloudwatch_log_group.lambda["reservations"]' "/aws/lambda/${PREFIX}-reservations" || true
import_if_missing module.lambda.aws_lambda_function.health "${PREFIX}-health" || true
import_if_missing module.lambda.aws_lambda_function.reservations "${PREFIX}-reservations" || true

LAYER_ARN="$(aws lambda list-layer-versions \
  --region "$REGION" \
  --layer-name "${PREFIX}-deps" \
  --query 'LayerVersions[0].LayerVersionArn' \
  --output text 2>/dev/null || true)"
if [ -n "${LAYER_ARN:-}" ] && [ "$LAYER_ARN" != "None" ]; then
  import_if_missing module.lambda.aws_lambda_layer_version.deps "$LAYER_ARN" || true
fi
