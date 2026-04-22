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

require_env() {
  local var_name="$1"

  if [[ -z "${!var_name:-}" ]]; then
    echo "Required environment variable is not set: $var_name" >&2
    exit 1
  fi
}

export_tf_var_if_set() {
  local source_var="$1"
  local target_var="$2"

  if [[ -n "${!source_var:-}" ]]; then
    export "$target_var=${!source_var}"
  fi
}

configure_tf_env() {
  local legacy_bootstrap_toggle="${ENABLE_KONG_KEY_VAULT_BOOTSTRAP:-false}"

  export TF_VAR_deploy_kong_bootstrap_job="${DEPLOY_KONG_BOOTSTRAP_JOB:-$legacy_bootstrap_toggle}"
  export TF_VAR_enable_key_vault="${ENABLE_KEY_VAULT:-$legacy_bootstrap_toggle}"
  export TF_VAR_enable_kong_key_vault_bootstrap="$legacy_bootstrap_toggle"

  export_tf_var_if_set KONG_KEY_VAULT_NAME TF_VAR_kong_key_vault_name
  export_tf_var_if_set KONG_KEY_VAULT_SECRET_PREFIX TF_VAR_kong_key_vault_secret_prefix
  export_tf_var_if_set KONG_ROUTE_HOST TF_VAR_kong_route_host
  export_tf_var_if_set KONG_RUNTIME_GROUP_NAME TF_VAR_kong_runtime_group_name
  export_tf_var_if_set KONG_SDX_CONTROL_URL TF_VAR_kong_sdx_control_url
  export_tf_var_if_set SDX_BOOTSTRAP_TOKEN TF_VAR_sdx_bootstrap_token
  export_tf_var_if_set SDX_CLIENT_CA_URL TF_VAR_sdx_client_ca_url
  export_tf_var_if_set SDX_SERVER_IP_SAN TF_VAR_sdx_server_ip_san
}

append_env_tfvars_file() {
  local -n args_ref=$1
  local tfvars_file="${TFVARS_FILE:-${INPUT_TFVARS_FILE:-}}"

  if [[ -z "$tfvars_file" ]]; then
    return 0
  fi

  if [[ ! -f "$tfvars_file" ]]; then
    echo "tfvars file not found: $tfvars_file" >&2
    exit 1
  fi

  args_ref+=("-var-file=$tfvars_file")
}

has_target_args() {
  local previous_arg=""

  for arg in "$@"; do
    if [[ "$previous_arg" == "-target" ]]; then
      return 0
    fi

    case "$arg" in
      -target|-target=*)
        return 0
        ;;
    esac

    previous_arg="$arg"
  done

  return 1
}

terraform_apply() {
  if [[ "${CI:-false}" == "true" ]]; then
    terraform apply -input=false -auto-approve "$@"
  else
    terraform apply -input=false "$@"
  fi
}

terraform_destroy() {
  if [[ "${CI:-false}" == "true" ]]; then
    terraform destroy -input=false -auto-approve "$@"
  else
    terraform destroy -input=false "$@"
  fi
}

run_bootstrap_apply_if_enabled() {
  if [[ "$COMMAND" != "apply" || "${TF_VAR_deploy_kong_bootstrap_job:-false}" != "true" ]]; then
    return 0
  fi

  if [[ "${TF_VAR_enable_key_vault:-false}" != "true" ]]; then
    echo "deploy_kong_bootstrap_job requires enable_key_vault=true in the current apply." >&2
    exit 1
  fi

  if has_target_args "$@"; then
    echo "Skipping automatic Kong bootstrap pre-apply because custom Terraform target arguments were provided." >&2
    return 0
  fi

  require_env KONG_RUNTIME_GROUP_NAME
  require_env SDX_BOOTSTRAP_TOKEN
  require_env SDX_CLIENT_CA_URL

  local -a bootstrap_args=(
    "-target=module.key_vault[0]"
    "-target=module.container_apps[0].terraform_data.kong_bootstrap_execution[0]"
  )

  terraform_apply "${bootstrap_args[@]}" "$@"
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

Environment helpers:
  ENABLE_KEY_VAULT=true                 Enable the Key Vault module for step-by-step applies
  DEPLOY_KONG_BOOTSTRAP_JOB=true        Automatically run the Kong bootstrap target apply before the full apply
  ENABLE_KONG_KEY_VAULT_BOOTSTRAP=true  Legacy convenience toggle that enables both of the above together
  TFVARS_FILE=<path>                    Append -var-file=<path> when the file exists
EOF
}

configure_tf_env

terraform_args=("$@")
append_env_tfvars_file terraform_args

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
    terraform plan -input=false "${terraform_args[@]}"
    ;;
  apply)
    terraform_init
    terraform validate
    run_bootstrap_apply_if_enabled "${terraform_args[@]}"
    terraform_apply "${terraform_args[@]}"
    ;;
  destroy)
    terraform_init
    terraform validate
    terraform_destroy "${terraform_args[@]}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
