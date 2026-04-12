# Values for running `tflocal` against LocalStack (local Terraform testing).
#
# Usage:
#   pip install terraform-local        # installs the tflocal wrapper
#   cd infrastructure
#   tflocal init
#   # Test only the core infra modules (Amplify is not supported locally):
#   tflocal apply -var-file=local.tfvars \
#     -target=module.dynamodb \
#     -target=module.lambda \
#     -target=module.api_gateway
#
# tflocal automatically overrides all AWS provider endpoints to point at
# LocalStack (http://localhost:4566) — no provider changes needed.

aws_region           = "us-east-1"
environment          = "dev"
# Amplify is not available in LocalStack Community; use -target to skip it.
# The value below is a placeholder so terraform doesn't error on the variable.
amplify_github_token = "dummy-not-used-locally"
