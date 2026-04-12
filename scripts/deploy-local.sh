#!/usr/bin/env bash
# Runs inside the 'deploy' docker-compose service OR locally.
# Builds the Lambda, then idempotently deploys every AWS resource to LocalStack.
# Writes the final API URL to frontend/.env.local so `npm run dev` works immediately.
set -eu
set -o pipefail 2>/dev/null || true

ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:14566}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
TABLE_NAME="accommodations-planner-dev-reservations"
FUNCTION_PREFIX="accommodations-planner-dev"
LAMBDA_ROLE_NAME="lambda-local-role"
LAMBDA_ROLE_ARN="arn:aws:iam::000000000000:role/${LAMBDA_ROLE_NAME}"
# Fixed API Gateway ID via LocalStack's _custom_id_ tag (keeps the URL stable
# across restarts). The frontend proxies requests through /api/... routes which
# forward to this backend URL.
API_CUSTOM_ID="aplocal"
STAGE="dev"

# Resolve paths - works both locally and in Docker
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)/backend"
FRONTEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)/frontend"
TEMP_DIR="${TMPDIR:-/tmp}"
test -d "$TEMP_DIR" || TEMP_DIR=/tmp
LAMBDA_ZIP="${TEMP_DIR}/lambda-$$.zip"

aws_local() {
  aws --endpoint-url "$ENDPOINT" --region "$REGION" "$@"
}

# 1. Build Lambda (TypeScript to JS)
echo ">>> [deploy-local] Building Lambda (TypeScript -> JS)..."
cd "$BACKEND_DIR"
if [ -f package-lock.json ]; then
  rm -rf node_modules
  npm ci --quiet || npm ci
else
  npm install --quiet || npm install
fi
npm run build

echo ">>> [deploy-local] Packaging Lambda zip..."
# Stage compiled output + production-only deps into a temp dir, then zip.
# Avoids bundling devDependencies (jest, ts-jest, typescript...) which can
# add hundreds of MB for no benefit.
STAGE_DIR="${TEMP_DIR}/lambda-stage-$$"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
# Clean leftovers from older packaging logic (dist/node_modules)
rm -rf dist/node_modules
# Compiled JS must sit at the zip root (handlers/health.js etc.)
cp -r dist/. "$STAGE_DIR/"
# Install only production dependencies into the staging directory.
cp package.json "$STAGE_DIR/"
cp package-lock.json "$STAGE_DIR/"
( cd "$STAGE_DIR" && npm ci --omit=dev --quiet )
rm -f "$STAGE_DIR/package.json" "$STAGE_DIR/package-lock.json"
( cd "$STAGE_DIR" && zip -qr "$LAMBDA_ZIP" . )
rm -rf "$STAGE_DIR"
cd "$BACKEND_DIR"

# 2. DynamoDB table
echo ">>> [deploy-local] Creating DynamoDB table..."
aws_local dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST 2>/dev/null || echo "Table already exists, skipping."

# 3. IAM role
echo ">>> [deploy-local] Creating Lambda IAM role..."
aws_local iam create-role \
  --role-name "$LAMBDA_ROLE_NAME" \
  --assume-role-policy-document \
    '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  2>/dev/null || echo "Role already exists, skipping."

# 4. Lambda functions
echo ">>> [deploy-local] Deploying Lambda functions..."

deploy_lambda() {
  local name="$1" handler="$2" env_vars="$3"
  aws_local lambda create-function \
    --function-name "$name" \
    --runtime nodejs20.x \
    --role "$LAMBDA_ROLE_ARN" \
    --handler "$handler" \
    --zip-file "fileb://$LAMBDA_ZIP" \
    --environment "Variables={${env_vars}}" \
    --timeout 10 \
    --memory-size 128 2>/dev/null || \
  aws_local lambda update-function-code \
    --function-name "$name" \
    --zip-file "fileb://$LAMBDA_ZIP"
}

deploy_lambda \
  "${FUNCTION_PREFIX}-health" \
  "handlers/health.handler" \
  "AWS_REGION=${REGION},ENVIRONMENT=${STAGE}"

deploy_lambda \
  "${FUNCTION_PREFIX}-reservations" \
  "handlers/reservations.handler" \
  "AWS_REGION=${REGION},ENVIRONMENT=${STAGE},DYNAMODB_TABLE_NAME=${TABLE_NAME},DYNAMODB_ENDPOINT=${ENDPOINT}"

# 5. API Gateway
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
  params_file="${TEMP_DIR}/cors-params-$$-${resource_id}.json"
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

# 6. Write frontend env
# Use localhost:14566 (not the internal localstack hostname) so the browser
# and Next.js dev server can reach the API from the host machine.
# The frontend proxies via /api/... routes to this backend URL.
API_URL="http://localhost:14566/restapis/${API_ID}/${STAGE}/_user_request_"

echo ">>> [deploy-local] Writing Backend API URL to frontend/.env.local..."
cat > "$FRONTEND_DIR/.env.local" << EOF
# Written by scripts/deploy-local.sh -- do not edit by hand.
BACKEND_API_URL=${API_URL}
NEXT_PUBLIC_STAGE=${STAGE}
EOF

echo ""
echo "Check Local Stack is ready!"
echo "   API Gateway (backend) : ${API_URL}"
echo "   Frontend API proxy    : http://localhost:3000/api"
echo "   DynamoDB              : ${ENDPOINT} (table: ${TABLE_NAME})"
echo ""
echo "   Start the frontend: cd frontend && npm run dev"
