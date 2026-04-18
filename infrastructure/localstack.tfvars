# Variable values for LocalStack Terraform testing.
# Used exclusively when running terraform plan/apply against a local
# LocalStack container. Never use for real AWS deployments.
#
# Usage in CI (see .github/workflows/infra-localstack-test.yml):
#   terraform plan  -var-file=localstack.tfvars -target=module.dynamodb \
#                   -target=module.lambda \
#                   -out=localstack.tfplan
#   terraform apply localstack.tfplan
#
# Amplify is not available in LocalStack Community Edition.
# module.api_gateway uses aws_apigatewayv2_* (HTTP API v2) which is also
# not available in LocalStack Community Edition.  Both modules are excluded
# via -target flags above.  The api_gateway module is tested separately by
# `terraform test` with mock_provider in infrastructure/tests/api_gateway.tftest.hcl.
# amplify_github_token is still required by the root variable declaration;
# the value below is a harmless placeholder used only for validation.

aws_region           = "us-east-1"
environment          = "dev"
amplify_github_token = "localstack-fake-token"
