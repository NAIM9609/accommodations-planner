#!/usr/bin/env bash
set -euo pipefail

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing required command: $name"
    exit 1
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="${REPO_ROOT}/infrastructure"
TF_DATA_DIR_TMP="${REPO_ROOT}/.tmp/tf-data-precommit-$$"

cleanup() {
  rm -rf "${TF_DATA_DIR_TMP}"
}
trap cleanup EXIT

require_command bash
require_command terraform
require_command tflint

echo "[terraform-check] Checking shell script syntax..."
bash -n "${REPO_ROOT}/scripts/deploy-local.sh"
bash -n "${REPO_ROOT}/.github/scripts/localstack-post-apply-smoke.sh"

cd "${INFRA_DIR}"
mkdir -p "${TF_DATA_DIR_TMP}"
export TF_DATA_DIR="${TF_DATA_DIR_TMP}"

echo "[terraform-check] terraform fmt -check -recursive"
terraform fmt -check -recursive

echo "[terraform-check] terraform init -backend=false -reconfigure -input=false"
terraform init -backend=false -reconfigure -input=false

echo "[terraform-check] tflint --init"
tflint --init

echo "[terraform-check] tflint --recursive"
tflint --recursive

echo "[terraform-check] terraform validate"
TF_VAR_aws_region="us-east-1" \
TF_VAR_environment="dev" \
TF_VAR_amplify_github_token="placeholder" \
terraform validate

echo "[terraform-check] terraform test"
terraform test

echo "[terraform-check] All Terraform pre-commit checks passed."
