#!/usr/bin/env bash
# Runs inside the 'deploy' docker-compose service.
# Builds the Lambda, then idempotently deploys every AWS resource to LocalStack.
# Writes the final API URL to frontend/.env.local so `npm run dev` works immediately.
set -euo pipefail

ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localstack:4566}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
TABLE_NAME="accommodations-planner-dev-reservations"
FUNCTION_PREFIX="accommodations-planner-dev"
LAMBDA_ROLE_NAME="lambda-local-role"
LAMBDA_ROLE_ARN="arn:aws:iam::000000000000:role/${LAMBDA_ROLE_NAME}"
# Fixed API Gateway ID via LocalStack's _custom_id_ tag — keeps the URL stable
# across restarts: http://localhost:4566/restapis/aplocal/dev/_user_request_/...
API_CUSTOM_ID="aplocal"
STAGE="dev"

aws_local() {
  aws --endpoint-url "$ENDPOINT" --region "$REGION" "$@"
}

# ── 1. Build Lambda ────────────────────────────────────────────────────────────
echo ">>> [deploy-local] Building Lambda (TypeScript → JS)..."
cd /app/backend
npm ci --quiet
npm run build

echo ">>> [deploy-local] Packaging Lambda zip..."
# Copy production dependencies alongside the compiled code, then zip everything.
# The handler paths (handlers/health.js etc.) must sit at the zip root.
cp -r node_modules dist/
cd dist
zip -qr /tmp/lambda.zip .
cd /app/backend

# ── 2. DynamoDB ────────────────────────────────────────────────────────────────
echo ">>> [deploy-local] Creating DynamoDB table..."
aws_local dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST 2>/dev/null || echo "Table already exists, skipping."

# ── 3. IAM role ────────────────────────────────────────────────────────────────
echo ">>> [deploy-local] Creating Lambda IAM role..."
aws_local iam create-role \
  --role-name "$LAMBDA_ROLE_NAME" \
  --assume-role-policy-document \
    '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  2>/dev/null || echo "Role already exists, skipping."

# ── 4. Lambda functions ────────────────────────────────────────────────────────
echo ">>> [deploy-local] Deploying Lambda functions..."

deploy_lambda() {
  local name="$1" handler="$2" env_vars="$3"
  aws_local lambda create-function \
    --function-name "$name" \
    --runtime nodejs20.x \
    --role "$LAMBDA_ROLE_ARN" \
    --handler "$handler" \
    --zip-file fileb:///tmp/lambda.zip \
    --environment "Variables={${env_vars}}" \
    --timeout 10 \
    --memory-size 128 2>/dev/null || \
  aws_local lambda update-function-code \
    --function-name "$name" \
    --zip-file fileb:///tmp/lambda.zip
}

deploy_lambda \
  "${FUNCTION_PREFIX}-health" \
  "handlers/health.handler" \
  "AWS_REGION=${REGION},ENVIRONMENT=${STAGE}"

deploy_lambda \
  "${FUNCTION_PREFIX}-reservations" \
  "handlers/reservations.handler" \
  "AWS_REGION=${REGION},ENVIRONMENT=${STAGE},DYNAMODB_TABLE_NAME=${TABLE_NAME},DYNAMODB_ENDPOINT=${ENDPOINT}"

# ── 5. API Gateway ─────────────────────────────────────────────────────────────
echo ">>> [deploy-local] Setting up API Gateway..."

# Create REST API with a fixed custom ID so the URL is predictable.
API_ID=$(aws_local apigateway create-rest-api \
  --name "accommodations-planner-local" \
  --tags "_custom_id_=${API_CUSTOM_ID}" \
  --query 'id' --output text 2>/dev/null) || true

# If the API already exists, look it up by name.
if [ -z "${API_ID:-}" ] || [ "$API_ID" = "None" ]; then
  API_ID=$(aws_local apigateway get-rest-apis \
    --query "items[?name=='accommodations-planner-local'].id" --output text)
fi

ROOT_ID=$(aws_local apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query "items[?path=='/'].id" --output text)

# Returns the ID of an existing child resource, creating it if absent.
get_or_create_resource() {
  local api_id="$1" parent_id="$2" path_part="$3"
  local existing
  existing=$(aws_local apigateway get-resources \
    --rest-api-id "$api_id" \
    --query "items[?pathPart=='${path_part}' && parentId=='${parent_id}'].id" \
    --output text)
  if [ -n "$existing" ] && [ "$existing" != "None" ]; then
    echo "$existing"
  else
    aws_local apigateway create-resource \
      --rest-api-id "$api_id" \
      --parent-id "$parent_id" \
      --path-part "$path_part" \
      --query 'id' --output text
  fi
}

# Adds a method + AWS_PROXY Lambda integration to a resource (idempotent).
add_method() {
  local api_id="$1" resource_id="$2" http_method="$3" lambda_name="$4"
  local lambda_arn
  lambda_arn=$(aws_local lambda get-function \
    --function-name "$lambda_name" \
    --query 'Configuration.FunctionArn' --output text)

  aws_local apigateway put-method \
    --rest-api-id "$api_id" \
    --resource-id "$resource_id" \
    --http-method "$http_method" \
    --authorization-type NONE 2>/dev/null || true

  aws_local apigateway put-integration \
    --rest-api-id "$api_id" \
    --resource-id "$resource_id" \
    --http-method "$http_method" \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${lambda_arn}/invocations" \
    2>/dev/null || true
}

# Adds an OPTIONS mock integration with CORS headers so browser preflight
# requests (triggered by POST/DELETE with Content-Type: application/json) succeed.
add_cors_options() {
  local api_id="$1" resource_id="$2" methods="$3"
  local params_file
  params_file=$(mktemp /tmp/cors-params-XXXX.json)
  cat > "$params_file" << EOF
{
  "method.response.header.Access-Control-Allow-Headers": "'Content-Type'",
  "method.response.header.Access-Control-Allow-Methods": "'${methods}'",
  "method.response.header.Access-Control-Allow-Origin": "'*'"
}
EOF

  aws_local apigateway put-method \
    --rest-api-id "$api_id" --resource-id "$resource_id" \
    --http-method OPTIONS --authorization-type NONE 2>/dev/null || true

  aws_local apigateway put-integration \
    --rest-api-id "$api_id" --resource-id "$resource_id" \
    --http-method OPTIONS --type MOCK \
    --request-templates '{"application/json":"{\"statusCode\":200}"}' 2>/dev/null || true

  aws_local apigateway put-method-response \
    --rest-api-id "$api_id" --resource-id "$resource_id" \
    --http-method OPTIONS --status-code 200 \
    --response-parameters \
      '{"method.response.header.Access-Control-Allow-Headers":false,"method.response.header.Access-Control-Allow-Methods":false,"method.response.header.Access-Control-Allow-Origin":false}' \
    2>/dev/null || true

  aws_local apigateway put-integration-response \
    --rest-api-id "$api_id" --resource-id "$resource_id" \
    --http-method OPTIONS --status-code 200 \
    --response-parameters "file://${params_file}" 2>/dev/null || true

  rm -f "$params_file"
}

# /health
HEALTH_ID=$(get_or_create_resource "$API_ID" "$ROOT_ID" "health")
add_method "$API_ID" "$HEALTH_ID" "GET" "${FUNCTION_PREFIX}-health"

# /reservations
RESERVATIONS_ID=$(get_or_create_resource "$API_ID" "$ROOT_ID" "reservations")
add_method "$API_ID" "$RESERVATIONS_ID" "GET"  "${FUNCTION_PREFIX}-reservations"
add_method "$API_ID" "$RESERVATIONS_ID" "POST" "${FUNCTION_PREFIX}-reservations"
add_cors_options "$API_ID" "$RESERVATIONS_ID" "GET,POST,OPTIONS"

# /reservations/{id}
RESERVATION_ID_RES=$(get_or_create_resource "$API_ID" "$RESERVATIONS_ID" "{id}")
add_method "$API_ID" "$RESERVATION_ID_RES" "GET"    "${FUNCTION_PREFIX}-reservations"
add_method "$API_ID" "$RESERVATION_ID_RES" "DELETE" "${FUNCTION_PREFIX}-reservations"
add_cors_options "$API_ID" "$RESERVATION_ID_RES" "GET,DELETE,OPTIONS"

echo ">>> [deploy-local] Deploying API Gateway stage '${STAGE}'..."
aws_local apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE" 2>/dev/null || true

# ── 6. Write frontend env ──────────────────────────────────────────────────────
# Use localhost:4566 (not the internal localstack hostname) so the browser
# and Next.js dev server can reach the API from the host machine.
API_URL="http://localhost:4566/restapis/${API_ID}/${STAGE}/_user_request_"

echo ">>> [deploy-local] Writing API URL to frontend/.env.local..."
cat > /app/frontend/.env.local << EOF
# Written by scripts/deploy-local.sh — do not edit by hand.
NEXT_PUBLIC_API_BASE_URL=${API_URL}
NEXT_PUBLIC_STAGE=${STAGE}
EOF

echo ""
echo "✅ Local stack is ready!"
echo "   API Gateway : ${API_URL}"
echo "   DynamoDB    : ${ENDPOINT} (table: ${TABLE_NAME})"
echo ""
echo "   Start the frontend: cd frontend && npm run dev"
echo ""
