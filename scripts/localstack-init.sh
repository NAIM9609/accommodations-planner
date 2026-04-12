#!/usr/bin/env bash
# Runs automatically inside LocalStack when it is ready (init hook).
# Creates the DynamoDB table used by the local dev environment.
set -euo pipefail

TABLE_NAME="${DYNAMODB_TABLE_NAME:-accommodations-planner-dev-reservations}"
REGION="${DEFAULT_REGION:-us-east-1}"

echo ">>> [localstack-init] Creating DynamoDB table: $TABLE_NAME"
awslocal dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION" || echo ">>> [localstack-init] Table already exists, skipping."

echo ">>> [localstack-init] Done."
