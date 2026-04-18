# WARNING: This file MUST ONLY be used with LocalStack for local/CI testing.
# DO NOT copy into infrastructure/ for real AWS deployments — fake credentials
# and disabled validation will cause authentication failures and expose no real
# infrastructure, but the misconfigured provider could mask serious errors.
#
# LocalStack provider override – injected by CI; NOT for real AWS deployments.
#
# This file overrides infrastructure/provider.tf to redirect all AWS API calls
# to a local LocalStack container.  It is stored in .github/scripts/ so it
# stays in version control, but it is only copied into the infrastructure/
# working directory during the infra-localstack-test workflow.
#
# The CI workflow copies it as:
#   cp .github/scripts/localstack-providers-override.tf \
#      infrastructure/localstack_override.tf
#
# Any file whose name ends in _override.tf is treated as an override by
# Terraform (same as *_override.tf / override.tf special naming rules).

provider "aws" {
  access_key = "test"
  secret_key = "test"
  region     = "us-east-1"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    apigateway = "http://localhost:14566"
    dynamodb   = "http://localhost:14566"
    iam        = "http://localhost:14566"
    lambda     = "http://localhost:14566"
    s3         = "http://localhost:14566"
    sts        = "http://localhost:14566"
  }
}
