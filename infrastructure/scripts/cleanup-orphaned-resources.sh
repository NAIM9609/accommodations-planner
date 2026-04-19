#!/usr/bin/env bash
# cleanup-orphaned-resources.sh
# Deletes orphaned AWS resources left behind by failed CloudFormation deployments.
#
# Required env vars:
#   PREFIX      — resource name prefix (e.g. accommodations-planner-dev)
#   STACK_NAME  — CloudFormation stack name
#
# Optional env vars:
#   REMOVE_ORPHANED_DYNAMODB — set to "true" to also delete the DynamoDB table (DATA LOSS)
#   CLEANUP_DYNAMO            — legacy alias for backward compatibility

set -euo pipefail

: "${PREFIX:?PREFIX is required}"
: "${STACK_NAME:?STACK_NAME is required}"
REMOVE_ORPHANED_DYNAMODB="${REMOVE_ORPHANED_DYNAMODB:-${CLEANUP_DYNAMO:-false}}"

DELETED=0
SKIPPED=0
NOT_FOUND=0

# ── Helpers ──────────────────────────────────────────────────────────────────

log()  { echo "[cleanup] $*"; }
warn() { echo "::warning::$*"; }

delete_iam_role() {
  local role_name="$1"
  if ! aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    log "IAM role $role_name — not found"
    (( NOT_FOUND++ )) || true
    return
  fi
  log "Deleting IAM role: $role_name"
  # Delete inline policies
  local policies
  policies="$(aws iam list-role-policies --role-name "$role_name" \
    --query 'PolicyNames[]' --output text 2>/dev/null || true)"
  for p in $policies; do
    aws iam delete-role-policy --role-name "$role_name" --policy-name "$p"
  done
  # Detach managed policies
  local arns
  arns="$(aws iam list-attached-role-policies --role-name "$role_name" \
    --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || true)"
  for a in $arns; do
    aws iam detach-role-policy --role-name "$role_name" --policy-arn "$a"
  done
  aws iam delete-role --role-name "$role_name"
  log "  deleted."
  (( DELETED++ )) || true
}

delete_lambda_function() {
  local fn_name="$1"
  if ! aws lambda get-function --function-name "$fn_name" >/dev/null 2>&1; then
    log "Lambda function $fn_name — not found"
    (( NOT_FOUND++ )) || true
    return
  fi
  log "Deleting Lambda function: $fn_name"
  aws lambda delete-function --function-name "$fn_name"
  log "  deleted."
  (( DELETED++ )) || true
}

delete_lambda_layer() {
  local layer_name="$1"
  local versions
  versions="$(aws lambda list-layer-versions --layer-name "$layer_name" \
    --query 'LayerVersions[].Version' --output text 2>/dev/null || true)"
  if [ -z "$versions" ]; then
    log "Lambda layer $layer_name — not found"
    (( NOT_FOUND++ )) || true
    return
  fi
  log "Deleting Lambda layer: $layer_name"
  for v in $versions; do
    aws lambda delete-layer-version --layer-name "$layer_name" --version-number "$v"
  done
  log "  deleted all versions."
  (( DELETED++ )) || true
}

delete_log_group() {
  local lg_name="$1"
  if ! aws logs describe-log-groups --log-group-name-prefix "$lg_name" \
      --query "logGroups[?logGroupName=='$lg_name'].logGroupName" \
      --output text 2>/dev/null | grep -q .; then
    log "Log group $lg_name — not found"
    (( NOT_FOUND++ )) || true
    return
  fi
  log "Deleting log group: $lg_name"
  aws logs delete-log-group --log-group-name "$lg_name"
  log "  deleted."
  (( DELETED++ )) || true
}

delete_api_gateway() {
  local api_name="$1"
  local api_id
  api_id="$(aws apigatewayv2 get-apis \
    --query "Items[?Name=='${api_name}'].ApiId | [0]" \
    --output text 2>/dev/null || true)"
  if [ -z "$api_id" ] || [ "$api_id" = "None" ]; then
    log "API Gateway $api_name — not found"
    (( NOT_FOUND++ )) || true
    return
  fi
  log "Deleting API Gateway: $api_name ($api_id)"
  aws apigatewayv2 delete-api --api-id "$api_id"
  log "  deleted."
  (( DELETED++ )) || true
}

delete_amplify_app() {
  local app_name="$1"
  local app_id
  app_id="$(aws amplify list-apps \
    --query "apps[?name=='${app_name}'].appId | [0]" \
    --output text 2>/dev/null || true)"
  if [ -z "$app_id" ] || [ "$app_id" = "None" ]; then
    log "Amplify app $app_name — not found"
    (( NOT_FOUND++ )) || true
    return
  fi
  log "Deleting Amplify app: $app_name ($app_id)"
  aws amplify delete-app --app-id "$app_id"
  log "  deleted."
  (( DELETED++ )) || true
}

delete_dynamodb_table() {
  local table_name="$1"
  if ! aws dynamodb describe-table --table-name "$table_name" >/dev/null 2>&1; then
    log "DynamoDB table $table_name — not found"
    (( NOT_FOUND++ )) || true
    return
  fi
  if [ "$REMOVE_ORPHANED_DYNAMODB" != "true" ]; then
    warn "DynamoDB table '$table_name' exists as an orphan but was SKIPPED (data loss risk)."
    warn "Re-run with remove_orphaned_dynamodb=true to delete it."
    (( SKIPPED++ )) || true
    return
  fi
  warn "Deleting DynamoDB table: $table_name (remove_orphaned_dynamodb=true)"
  aws dynamodb delete-table --table-name "$table_name"
  aws dynamodb wait table-not-exists --table-name "$table_name"
  log "  deleted."
  (( DELETED++ )) || true
}

# ── Main ─────────────────────────────────────────────────────────────────────

log "Checking for orphaned resources with prefix: $PREFIX"

# If the stack exists and is healthy, skip cleanup entirely
STACK_STATUS="$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "DOES_NOT_EXIST")"

case "$STACK_STATUS" in
  CREATE_COMPLETE|UPDATE_COMPLETE|UPDATE_ROLLBACK_COMPLETE)
    log "Stack '$STACK_NAME' is healthy ($STACK_STATUS). Skipping orphan cleanup."
    exit 0
    ;;
  DOES_NOT_EXIST|ROLLBACK_COMPLETE|DELETE_COMPLETE)
    log "Stack is $STACK_STATUS — scanning for orphaned resources."
    ;;
  *)
    log "Stack is in state $STACK_STATUS — scanning for orphaned resources."
    ;;
esac

# Clean up each resource type
delete_iam_role        "${PREFIX}-github-actions"
delete_iam_role        "${PREFIX}-lambda-role"
delete_lambda_function "${PREFIX}-health"
delete_lambda_function "${PREFIX}-reservations"
delete_lambda_layer    "${PREFIX}-deps"
delete_log_group       "/aws/lambda/${PREFIX}-health"
delete_log_group       "/aws/lambda/${PREFIX}-reservations"
delete_api_gateway     "${PREFIX}-api"
delete_amplify_app     "${PREFIX}-frontend"
delete_dynamodb_table  "${PREFIX}-reservations"

log "Done. Deleted: $DELETED | Skipped: $SKIPPED | Not found: $NOT_FOUND"
