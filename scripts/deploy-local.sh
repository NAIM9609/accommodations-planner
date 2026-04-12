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

USE_HTTP_API=false
if aws_local apigatewayv2 get-apis >/dev/null 2>&1; then
  USE_HTTP_API=true
fi

if [ "$USE_HTTP_API" = true ]; then
  # 5a. HTTP API v2 parity path (available only on supported LocalStack license)
  echo ">>> [deploy-local] Setting up HTTP API Gateway (v2)..."

  API_ID=$(aws_local apigatewayv2 create-api \
    --name "accommodations-planner-local" \
    --protocol-type HTTP \
    --tags "_custom_id_=${API_CUSTOM_ID}" \
    --query 'ApiId' --output text 2>/dev/null) || true

  if [ -z "${API_ID:-}" ] || [ "$API_ID" = "None" ]; then
    API_ID=$(aws_local apigatewayv2 get-apis \
      --query "Items[?Name=='accommodations-planner-local'].ApiId" --output text)
  fi

  create_integration() {
    local api_id="$1" lambda_name="$2"
    local lambda_arn
    lambda_arn=$(aws_local lambda get-function \
      --function-name "$lambda_name" \
      --query 'Configuration.FunctionArn' --output text)

    aws_local apigatewayv2 create-integration \
      --api-id "$api_id" \
      --integration-type AWS_PROXY \
      --integration-method POST \
      --payload-format-version 1.0 \
      --integration-uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${lambda_arn}/invocations" \
      --query 'IntegrationId' --output text
  }

  ensure_route() {
    local api_id="$1" route_key="$2" integration_id="$3"
    local existing
    existing=$(aws_local apigatewayv2 get-routes \
      --api-id "$api_id" \
      --query "Items[?RouteKey=='${route_key}'].RouteId" --output text)

    if [ -n "$existing" ] && [ "$existing" != "None" ]; then
      aws_local apigatewayv2 update-route \
        --api-id "$api_id" \
        --route-id "$existing" \
        --target "integrations/${integration_id}" >/dev/null
    else
      aws_local apigatewayv2 create-route \
        --api-id "$api_id" \
        --route-key "$route_key" \
        --target "integrations/${integration_id}" >/dev/null
    fi
  }

  HEALTH_INTEGRATION_ID=$(create_integration "$API_ID" "${FUNCTION_PREFIX}-health")
  RESERVATIONS_INTEGRATION_ID=$(create_integration "$API_ID" "${FUNCTION_PREFIX}-reservations")

  ensure_route "$API_ID" "GET /health" "$HEALTH_INTEGRATION_ID"
  ensure_route "$API_ID" "GET /reservations" "$RESERVATIONS_INTEGRATION_ID"
  ensure_route "$API_ID" "POST /reservations" "$RESERVATIONS_INTEGRATION_ID"
  ensure_route "$API_ID" "GET /reservations/{id}" "$RESERVATIONS_INTEGRATION_ID"
  ensure_route "$API_ID" "DELETE /reservations/{id}" "$RESERVATIONS_INTEGRATION_ID"

  aws_local apigatewayv2 create-stage \
    --api-id "$API_ID" \
    --stage-name "$STAGE" \
    --auto-deploy \
    --default-route-settings "ThrottlingBurstLimit=4,ThrottlingRateLimit=2" >/dev/null 2>&1 || \
  aws_local apigatewayv2 update-stage \
    --api-id "$API_ID" \
    --stage-name "$STAGE" \
    --auto-deploy \
    --default-route-settings "ThrottlingBurstLimit=4,ThrottlingRateLimit=2" >/dev/null

  API_URL="http://${API_ID}.execute-api.localhost.localstack.cloud:14566/${STAGE}"
else
  # 5b. Fallback for LocalStack editions without API Gateway v2
  echo ">>> [deploy-local] apigatewayv2 unavailable in this LocalStack license; using REST API fallback for localhost."

  API_ID=$(aws_local apigateway create-rest-api \
    --name "accommodations-planner-local" \
    --tags "_custom_id_=${API_CUSTOM_ID}" \
    --query 'id' --output text 2>/dev/null) || true

  if [ -z "${API_ID:-}" ] || [ "$API_ID" = "None" ]; then
    API_ID=$(aws_local apigateway get-rest-apis \
      --query "items[?name=='accommodations-planner-local'].id" --output text)
  fi

  ROOT_ID=$(aws_local apigateway get-resources \
    --rest-api-id "$API_ID" \
    --query "items[?path=='/'].id" --output text)

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

  HEALTH_ID=$(get_or_create_resource "$API_ID" "$ROOT_ID" "health")
  add_method "$API_ID" "$HEALTH_ID" "GET" "${FUNCTION_PREFIX}-health"

  RESERVATIONS_ID=$(get_or_create_resource "$API_ID" "$ROOT_ID" "reservations")
  add_method "$API_ID" "$RESERVATIONS_ID" "GET"  "${FUNCTION_PREFIX}-reservations"
  add_method "$API_ID" "$RESERVATIONS_ID" "POST" "${FUNCTION_PREFIX}-reservations"
  add_cors_options "$API_ID" "$RESERVATIONS_ID" "GET,POST,OPTIONS"

  RESERVATION_ID_RES=$(get_or_create_resource "$API_ID" "$RESERVATIONS_ID" "{id}")
  add_method "$API_ID" "$RESERVATION_ID_RES" "GET"    "${FUNCTION_PREFIX}-reservations"
  add_method "$API_ID" "$RESERVATION_ID_RES" "DELETE" "${FUNCTION_PREFIX}-reservations"
  add_cors_options "$API_ID" "$RESERVATION_ID_RES" "GET,DELETE,OPTIONS"

  aws_local apigateway create-deployment \
    --rest-api-id "$API_ID" \
    --stage-name "$STAGE" >/dev/null 2>&1 || true

  API_URL="http://localhost:14566/restapis/${API_ID}/${STAGE}/_user_request_"
fi

# 6. Write frontend env
# API_URL is set above in either HTTP API mode or REST fallback mode.

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
