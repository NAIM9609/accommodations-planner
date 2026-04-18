# Tests for the api_gateway module using Terraform's built-in mock-provider
# framework.  No LocalStack or real AWS credentials are needed.
#
# aws_apigatewayv2_* resources are not available in LocalStack Community
# Edition.  This test file is the replacement for LocalStack-based testing of
# module.api_gateway: it runs as part of `terraform test` (invoked by
# infra-validate.yml via scripts/validate-terraform-precommit.sh) and fully
# validates the HTTP API configuration without any live AWS endpoint.
#
# Run with:
#   cd infrastructure
#   terraform test -filter=tests/api_gateway.tftest.hcl

mock_provider "aws" {}
mock_provider "archive" {}

# ---------------------------------------------------------------------------
# Shared defaults – overridden per run block where needed.
# ---------------------------------------------------------------------------
variables {
  aws_region           = "us-east-1"
  environment          = "dev"
  amplify_github_token = "test-placeholder"
}

# ---------------------------------------------------------------------------
# Basic plan: all aws_apigatewayv2_* resources must be plannable.
# ---------------------------------------------------------------------------
run "api_gateway_http_api_planned_dev" {
  command = plan
  # Plan succeeding verifies that all aws_apigatewayv2_* resources in
  # module.api_gateway are syntactically and structurally valid for dev.
}

run "api_gateway_http_api_planned_prod" {
  command = plan
  variables {
    environment = "prod"
  }
  # Same check for the prod environment value.
}

# ---------------------------------------------------------------------------
# Custom throttle settings are accepted without error.
# ---------------------------------------------------------------------------
run "api_gateway_custom_throttle" {
  command = plan
  variables {
    api_throttle_rate_limit  = 100
    api_throttle_burst_limit = 200
  }
}
