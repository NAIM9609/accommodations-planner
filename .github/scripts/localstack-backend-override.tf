# WARNING: This file MUST ONLY be used with LocalStack for local/CI testing.
# DO NOT copy into infrastructure/ for real AWS deployments — a local backend
# has no remote locking and no shared state, so any real deployment would
# immediately diverge and lose state visibility.
#
# LocalStack backend override – injected by CI; NOT for real AWS deployments.
#
# This file overrides the remote S3 backend declared in infrastructure/backend.tf
# so that LocalStack test runs use an ephemeral local state file instead of the
# real S3 bucket (which is unavailable in LocalStack Community Edition without
# extra configuration and credentials).
#
# The CI workflow copies it as:
#   cp .github/scripts/localstack-backend-override.tf \
#      infrastructure/localstack_backend_override.tf
#
# Any file whose name ends in _override.tf is treated as an override by
# Terraform (same as *_override.tf / override.tf special naming rules).
# Terraform merges this backend "local" block on top of the backend "s3" block
# in backend.tf, effectively replacing it for the duration of the test run.

terraform {
  backend "local" {}
}
