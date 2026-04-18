# Variable values for LocalStack Terraform testing.
# Used exclusively when running terraform plan/apply against a local
# LocalStack container. Never use for real AWS deployments.
#
# Usage in CI (see .github/workflows/infra-localstack-test.yml):
#   terraform plan  -var-file=localstack.tfvars -target=module.dynamodb \
#                   -target=module.lambda -target=module.api_gateway \
#                   -out=localstack.tfplan
#   terraform apply localstack.tfplan
#
# Amplify is not available in LocalStack Community Edition.
# The -target flags above exclude the amplify module from the plan/apply.
# amplify_github_token is still required by the root variable declaration;
# the value below is a harmless placeholder used only for validation.

aws_region             = "us-east-1"
environment            = "dev"
amplify_github_token   = "localstack-fake-token"
allow_dynamodb_destroy = true
