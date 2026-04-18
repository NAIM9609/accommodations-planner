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

import_if_missing aws_iam_role.github_actions "${PREFIX}-github-actions"
import_if_missing aws_iam_role_policy.github_actions "${PREFIX}-github-actions:${PREFIX}-github-actions-policy"
import_if_missing module.dynamodb.aws_dynamodb_table.reservations "${PREFIX}-reservations"
import_if_missing module.lambda.aws_iam_role.lambda "${PREFIX}-lambda-role"
import_if_missing module.lambda.aws_iam_role_policy.lambda_dynamodb "${PREFIX}-lambda-role:${PREFIX}-lambda-dynamodb"
import_if_missing module.lambda.aws_iam_role_policy_attachment.lambda_basic "${PREFIX}-lambda-role/arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
import_if_missing 'module.lambda.aws_cloudwatch_log_group.lambda["health"]' "/aws/lambda/${PREFIX}-health"
import_if_missing 'module.lambda.aws_cloudwatch_log_group.lambda["reservations"]' "/aws/lambda/${PREFIX}-reservations"
import_if_missing module.lambda.aws_lambda_function.health "${PREFIX}-health"
import_if_missing module.lambda.aws_lambda_function.reservations "${PREFIX}-reservations"

LAYER_ARN="$(aws lambda list-layer-versions \
  --region "$REGION" \
  --layer-name "${PREFIX}-deps" \
  --query 'LayerVersions[0].LayerVersionArn' \
  --output text 2>/dev/null || true)"
if [ -n "${LAYER_ARN:-}" ] && [ "$LAYER_ARN" != "None" ]; then
  import_if_missing module.lambda.aws_lambda_layer_version.deps "$LAYER_ARN"
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

MANIFEST_FILE="/tmp/drift-manifest.json"
printf '{\n  "already_in_state": %s,\n  "newly_imported": %s\n}\n' \
  "$AIS_JSON" "$NI_JSON" > "$MANIFEST_FILE"

echo "Drift manifest written to ${MANIFEST_FILE}:"
cat "$MANIFEST_FILE"
