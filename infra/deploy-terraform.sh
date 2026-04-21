#!/usr/bin/env bash

set -euo pipefail

COMMAND="${1:-plan}"
shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKEND_CONTAINER_NAME="${BACKEND_CONTAINER_NAME:-tfstate}"
BACKEND_STATE_KEY="${BACKEND_STATE_KEY:-fabric-analytics-api-gateway/terraform.tfstate}"

backend_args=()
if [[ -n "${BACKEND_RESOURCE_GROUP:-}" && -n "${BACKEND_STORAGE_ACCOUNT:-}" ]]; then
  backend_args+=("-backend-config=resource_group_name=${BACKEND_RESOURCE_GROUP}")
  backend_args+=("-backend-config=storage_account_name=${BACKEND_STORAGE_ACCOUNT}")
  backend_args+=("-backend-config=container_name=${BACKEND_CONTAINER_NAME}")
  backend_args+=("-backend-config=key=${BACKEND_STATE_KEY}")
fi

terraform_init() {
  if [[ ${#backend_args[@]} -gt 0 ]]; then
    terraform init "${backend_args[@]}" "$@"
  else
    terraform init -backend=false "$@"
  fi
}

usage() {
  cat <<'EOF'
Usage: ./deploy-terraform.sh <command> [terraform args]

Commands:
  fmt       Run terraform fmt recursively
  init      Initialize Terraform, using remote backend when backend env vars exist
  validate  Initialize Terraform and run terraform validate
  plan      Initialize Terraform, validate, then run terraform plan
  apply     Initialize Terraform, validate, then run terraform apply
  destroy   Initialize Terraform, validate, then run terraform destroy
EOF
}

case "$COMMAND" in
  fmt)
    terraform fmt -recursive
    ;;
  init)
    terraform_init "$@"
    ;;
  validate)
    terraform_init
    terraform validate "$@"
    ;;
  plan)
    terraform_init
    terraform validate
    terraform plan -input=false "$@"
    ;;
  apply)
    terraform_init
    terraform validate
    if [[ "${CI:-false}" == "true" ]]; then
      terraform apply -input=false -auto-approve "$@"
    else
      terraform apply -input=false "$@"
    fi
    ;;
  destroy)
    terraform_init
    terraform validate
    if [[ "${CI:-false}" == "true" ]]; then
      terraform destroy -input=false -auto-approve "$@"
    else
      terraform destroy -input=false "$@"
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac