#!/usr/bin/env bash
set -euo pipefail

PREFIX="${1:?prefix is required}"
REGION="${2:?region is required}"
LOCK_TIMEOUT="${3:-5m}"
FORCE_UNLOCK_MIN_AGE_SECONDS="${TF_FORCE_UNLOCK_MIN_AGE_SECONDS:-1800}"
LOCK_RETRY_ATTEMPTS="${TF_LOCK_RETRY_ATTEMPTS:-3}"
LOCK_RETRY_DELAY_SECONDS="${TF_LOCK_RETRY_DELAY_SECONDS:-20}"

# Accumulators for the drift manifest written at the end of this script.
ALREADY_IN_STATE=()
NEWLY_IMPORTED=()
NOT_FOUND_IN_AWS=()

aws_value_exists() {
  local value="$1"
  [ -n "$value" ] && [ "$value" != "None" ] && [ "$value" != "null" ]
}

lock_age_seconds() {
  local created_raw="$1"
  local now_epoch
  local created_epoch
  now_epoch="$(date -u +%s)"
  if ! created_epoch="$(date -u -d "$created_raw" +%s 2>/dev/null)"; then
    return 1
  fi
  echo "$(( now_epoch - created_epoch ))"
}

run_with_lock_recovery() {
  local cmd=("$@")
  local attempt
  attempt=1

  while [ "$attempt" -le "$LOCK_RETRY_ATTEMPTS" ]; do
    local tf_log
    local cmd_status
    tf_log="$(mktemp)"

    set +e
    "${cmd[@]}" 2>&1 | tee "$tf_log"
    cmd_status=${PIPESTATUS[0]}
    set -e

    if [ "$cmd_status" -eq 0 ]; then
      rm -f "$tf_log"
      return 0
    fi

    if ! grep -q "Error acquiring the state lock" "$tf_log"; then
      rm -f "$tf_log"
      return 1
    fi

    local lock_id
    local created_raw
    local age_seconds
    # Terraform can render lock info either as plain text:
    #   ID: <uuid>
    # or in boxed output:
    #   │   ID: <uuid>
    lock_id="$(sed -nE 's/^.*ID:[[:space:]]*([0-9a-fA-F-]{36}).*$/\1/p' "$tf_log" | head -n1 || true)"
    created_raw="$(sed -nE 's/^.*Created:[[:space:]]*(.+)$/\1/p' "$tf_log" | head -n1 || true)"

    if [ -z "${lock_id:-}" ]; then
      echo "State lock detected but lock ID was not found in Terraform output."
      echo "Raw Terraform lock output follows:"
      cat "$tf_log"
      rm -f "$tf_log"
      exit 1
    fi

    if [ -n "${created_raw:-}" ] && age_seconds="$(lock_age_seconds "$created_raw")"; then
      echo "Detected Terraform state lock age: ${age_seconds}s (min age for force-unlock: ${FORCE_UNLOCK_MIN_AGE_SECONDS}s)"
      if [ "$age_seconds" -lt "$FORCE_UNLOCK_MIN_AGE_SECONDS" ]; then
        if [ "$attempt" -lt "$LOCK_RETRY_ATTEMPTS" ]; then
          echo "Lock appears recent; waiting ${LOCK_RETRY_DELAY_SECONDS}s before retry ${attempt}/${LOCK_RETRY_ATTEMPTS}."
          rm -f "$tf_log"
          sleep "$LOCK_RETRY_DELAY_SECONDS"
          attempt=$((attempt + 1))
          continue
        fi
        echo "Lock is still recent after ${LOCK_RETRY_ATTEMPTS} attempts. Refusing to force-unlock to avoid interrupting an active run."
        rm -f "$tf_log"
        exit 1
      fi
    else
      if [ "$attempt" -lt "$LOCK_RETRY_ATTEMPTS" ]; then
        echo "Could not parse lock creation time. Retrying ${attempt}/${LOCK_RETRY_ATTEMPTS} before considering force-unlock."
        rm -f "$tf_log"
        sleep "$LOCK_RETRY_DELAY_SECONDS"
        attempt=$((attempt + 1))
        continue
      fi
      echo "Could not parse lock creation time after retries. Refusing force-unlock for safety."
      echo "Raw Terraform lock output follows:"
      cat "$tf_log"
      rm -f "$tf_log"
      exit 1
    fi

    echo "State lock is stale. Attempting force-unlock for lock ID: $lock_id"
    if ! terraform force-unlock -force "$lock_id"; then
      echo "Failed to force-unlock Terraform state for lock ID: $lock_id"
      rm -f "$tf_log"
      exit 1
    fi

    echo "Retrying Terraform command after force-unlock..."
    if ! "${cmd[@]}"; then
      echo "Terraform command still failed after force-unlock retry."
      rm -f "$tf_log"
      exit 1
    fi

    rm -f "$tf_log"
    return 0
  done

  echo "State lock handling exhausted all retry attempts."
  return 1
}

import_if_missing() {
  local addr="$1"
  local id="$2"
  if terraform state show "$addr" > /dev/null 2>&1; then
    echo "Already in state: $addr"
    ALREADY_IN_STATE+=("$addr")
    return 0
  fi
  echo "Importing $addr <= $id"
  run_with_lock_recovery terraform import -lock-timeout="$LOCK_TIMEOUT" "$addr" "$id"
  NEWLY_IMPORTED+=("$addr")
}

if aws iam get-role --role-name "${PREFIX}-github-actions" >/dev/null 2>&1; then
  import_if_missing aws_iam_role.github_actions "${PREFIX}-github-actions"
else
  echo "AWS resource not found, skipping import: aws_iam_role.github_actions"
  NOT_FOUND_IN_AWS+=("aws_iam_role.github_actions")
fi

if aws iam get-role-policy --role-name "${PREFIX}-github-actions" --policy-name "${PREFIX}-github-actions-policy" >/dev/null 2>&1; then
  import_if_missing aws_iam_role_policy.github_actions "${PREFIX}-github-actions:${PREFIX}-github-actions-policy"
else
  echo "AWS resource not found, skipping import: aws_iam_role_policy.github_actions"
  NOT_FOUND_IN_AWS+=("aws_iam_role_policy.github_actions")
fi

if aws dynamodb describe-table --table-name "${PREFIX}-reservations" --region "$REGION" >/dev/null 2>&1; then
  import_if_missing module.dynamodb.aws_dynamodb_table.reservations "${PREFIX}-reservations"
else
  echo "AWS resource not found, skipping import: module.dynamodb.aws_dynamodb_table.reservations"
  NOT_FOUND_IN_AWS+=("module.dynamodb.aws_dynamodb_table.reservations")
fi

if aws iam get-role --role-name "${PREFIX}-lambda-role" >/dev/null 2>&1; then
  import_if_missing module.lambda.aws_iam_role.lambda "${PREFIX}-lambda-role"
else
  echo "AWS resource not found, skipping import: module.lambda.aws_iam_role.lambda"
  NOT_FOUND_IN_AWS+=("module.lambda.aws_iam_role.lambda")
fi

if aws iam get-role-policy --role-name "${PREFIX}-lambda-role" --policy-name "${PREFIX}-lambda-dynamodb" >/dev/null 2>&1; then
  import_if_missing module.lambda.aws_iam_role_policy.lambda_dynamodb "${PREFIX}-lambda-role:${PREFIX}-lambda-dynamodb"
else
  echo "AWS resource not found, skipping import: module.lambda.aws_iam_role_policy.lambda_dynamodb"
  NOT_FOUND_IN_AWS+=("module.lambda.aws_iam_role_policy.lambda_dynamodb")
fi

ATTACHED_BASIC_POLICY="$(aws iam list-attached-role-policies \
  --role-name "${PREFIX}-lambda-role" \
  --query "AttachedPolicies[?PolicyArn=='arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'].PolicyArn | [0]" \
  --output text 2>/dev/null || true)"
if aws_value_exists "$ATTACHED_BASIC_POLICY"; then
  import_if_missing module.lambda.aws_iam_role_policy_attachment.lambda_basic "${PREFIX}-lambda-role/arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
else
  echo "AWS resource not found, skipping import: module.lambda.aws_iam_role_policy_attachment.lambda_basic"
  NOT_FOUND_IN_AWS+=("module.lambda.aws_iam_role_policy_attachment.lambda_basic")
fi

HEALTH_LOG_GROUP="$(aws logs describe-log-groups \
  --region "$REGION" \
  --log-group-name-prefix "/aws/lambda/${PREFIX}-health" \
  --query "logGroups[?logGroupName=='/aws/lambda/${PREFIX}-health'].logGroupName | [0]" \
  --output text 2>/dev/null || true)"
if aws_value_exists "$HEALTH_LOG_GROUP"; then
  import_if_missing 'module.lambda.aws_cloudwatch_log_group.lambda["health"]' "/aws/lambda/${PREFIX}-health"
else
  echo "AWS resource not found, skipping import: module.lambda.aws_cloudwatch_log_group.lambda[\"health\"]"
  NOT_FOUND_IN_AWS+=("module.lambda.aws_cloudwatch_log_group.lambda[\"health\"]")
fi

RESERVATIONS_LOG_GROUP="$(aws logs describe-log-groups \
  --region "$REGION" \
  --log-group-name-prefix "/aws/lambda/${PREFIX}-reservations" \
  --query "logGroups[?logGroupName=='/aws/lambda/${PREFIX}-reservations'].logGroupName | [0]" \
  --output text 2>/dev/null || true)"
if aws_value_exists "$RESERVATIONS_LOG_GROUP"; then
  import_if_missing 'module.lambda.aws_cloudwatch_log_group.lambda["reservations"]' "/aws/lambda/${PREFIX}-reservations"
else
  echo "AWS resource not found, skipping import: module.lambda.aws_cloudwatch_log_group.lambda[\"reservations\"]"
  NOT_FOUND_IN_AWS+=("module.lambda.aws_cloudwatch_log_group.lambda[\"reservations\"]")
fi

if aws lambda get-function --function-name "${PREFIX}-health" --region "$REGION" >/dev/null 2>&1; then
  import_if_missing module.lambda.aws_lambda_function.health "${PREFIX}-health"
else
  echo "AWS resource not found, skipping import: module.lambda.aws_lambda_function.health"
  NOT_FOUND_IN_AWS+=("module.lambda.aws_lambda_function.health")
fi

if aws lambda get-function --function-name "${PREFIX}-reservations" --region "$REGION" >/dev/null 2>&1; then
  import_if_missing module.lambda.aws_lambda_function.reservations "${PREFIX}-reservations"
else
  echo "AWS resource not found, skipping import: module.lambda.aws_lambda_function.reservations"
  NOT_FOUND_IN_AWS+=("module.lambda.aws_lambda_function.reservations")
fi

LAYER_ARN="$(aws lambda list-layer-versions \
  --region "$REGION" \
  --layer-name "${PREFIX}-deps" \
  --query 'LayerVersions[0].LayerVersionArn' \
  --output text 2>/dev/null || true)"
if [ -n "${LAYER_ARN:-}" ] && [ "$LAYER_ARN" != "None" ]; then
  import_if_missing module.lambda.aws_lambda_layer_version.deps "$LAYER_ARN"
else
  echo "AWS resource not found, skipping import: module.lambda.aws_lambda_layer_version.deps"
  NOT_FOUND_IN_AWS+=("module.lambda.aws_lambda_layer_version.deps")
fi

# ---------------------------------------------------------------------------
# Emit drift manifest so the caller can reason about state before apply.
# ---------------------------------------------------------------------------
build_json_array() {
  # Accepts 0 or more arguments; returns a properly-escaped JSON array string.
  # Uses jq -R/-s to handle any characters (quotes, backslashes, etc.) that
  # appear in Terraform resource addresses such as:
  #   module.lambda.aws_cloudwatch_log_group.lambda["health"]
  if [ "$#" -eq 0 ]; then
    printf '[]'
    return
  fi
  printf '%s\n' "$@" | jq -R . | jq -sc .
}

# Expand arrays safely when set -u is active (empty array → zero args to function).
if [ "${#ALREADY_IN_STATE[@]}" -gt 0 ]; then
  AIS_JSON=$(build_json_array "${ALREADY_IN_STATE[@]}")
else
  AIS_JSON="[]"
fi

if [ "${#NEWLY_IMPORTED[@]}" -gt 0 ]; then
  NI_JSON=$(build_json_array "${NEWLY_IMPORTED[@]}")
else
  NI_JSON="[]"
fi

if [ "${#NOT_FOUND_IN_AWS[@]}" -gt 0 ]; then
  NFA_JSON=$(build_json_array "${NOT_FOUND_IN_AWS[@]}")
else
  NFA_JSON="[]"
fi

MANIFEST_FILE="/tmp/drift-manifest.json"
printf '{\n  "already_in_state": %s,\n  "newly_imported": %s,\n  "not_found_in_aws": %s\n}\n' \
  "$AIS_JSON" "$NI_JSON" "$NFA_JSON" > "$MANIFEST_FILE"

echo "Drift manifest written to ${MANIFEST_FILE}:"
cat "$MANIFEST_FILE"
