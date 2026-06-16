#!/usr/bin/env bash
# deploy-scaled.sh — internal stack engine for infra-fabric-gateway
#
# Called by deploy-terraform.sh. Orchestrates stacks in dependency order:
#
#   Phase 1 (serial):   shared  — App GW, APIM instance, WAF, Log Analytics
#   Phase 2 (serial):   tenant  — All tenant APIM API wiring (reads shared state)
#
# Params layout (per environment, under params/<env>/):
#   common.tfvars               — passed to BOTH stacks (app_env, app_name)
#   shared.tfvars               — passed to the shared stack only
#   tenants/<name>/tenant.tfvars — passed to the tenant stack only (per tenant)
#
# Provider auth and the state backend coordinates are NOT in tfvars; they are
# supplied via TF_VAR_* / -backend-config so committed values cannot override CI.
#
# Usage: deploy-scaled.sh <plan|apply|destroy> <env> [extra terraform flags]
#
set -euo pipefail

COMMAND="${1:?Usage: deploy-scaled.sh <plan|apply|destroy> <env> [flags]}"
ENVIRONMENT="${2:?Usage: deploy-scaled.sh <plan|apply|destroy> <env> [flags]}"
shift 2
EXTRA_FLAGS=("$@")

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARAMS_DIR="${REPO_ROOT}/params/${ENVIRONMENT}"
STACKS_DIR="${REPO_ROOT}/stacks"

# Validate environment
case "${ENVIRONMENT}" in
  dev|test|prod) ;;
  *) echo "ERROR: environment must be dev, test, or prod" >&2; exit 1 ;;
esac

# The tenant stack's terraform_remote_state block reads the backend coordinates
# from var.backend_*. Feed them the same values used for -backend-config below,
# via TF_VAR_* so they are never committed. Terraform silently ignores TF_VAR_*
# for variables a stack does not declare, so exporting these is safe for the
# shared stack (which does not declare them).
export TF_VAR_backend_resource_group="${BACKEND_RESOURCE_GROUP:?BACKEND_RESOURCE_GROUP must be set}"
export TF_VAR_backend_storage_account="${BACKEND_STORAGE_ACCOUNT:?BACKEND_STORAGE_ACCOUNT must be set}"
export TF_VAR_backend_container_name="${BACKEND_CONTAINER_NAME:-tfstate}"

# Collect tenant tfvars files
TENANT_VAR_FILES=()
if [[ -d "${PARAMS_DIR}/tenants" ]]; then
  while IFS= read -r -d '' f; do
    TENANT_VAR_FILES+=("$f")
  done < <(find "${PARAMS_DIR}/tenants" -name "tenant.tfvars" -print0 | sort -z)
fi

# Build the -var-file arguments for a stack.
# Both stacks get common.tfvars; the shared stack additionally gets shared.tfvars,
# and the tenant stack additionally gets each tenants/<name>/tenant.tfvars.
# $1: stack name ("shared" or "tenant")
var_file_args() {
  local stack="$1"
  local args=()
  args+=("-var-file=${PARAMS_DIR}/common.tfvars")
  case "${stack}" in
    shared)
      args+=("-var-file=${PARAMS_DIR}/shared.tfvars")
      ;;
    tenant)
      for f in "${TENANT_VAR_FILES[@]+"${TENANT_VAR_FILES[@]}"}"; do
        args+=("-var-file=${f}")
      done
      ;;
  esac
  printf '%s\n' "${args[@]}"
}

run_stack() {
  local stack="$1"
  local stack_dir="${STACKS_DIR}/${stack}"
  local state_key="fabric-gateway/${ENVIRONMENT}/${stack}.tfstate"
  local tf_data_dir="${REPO_ROOT}/.terraform-data/${stack}"

  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Stack: ${stack}  (${COMMAND})"
  echo "════════════════════════════════════════════════════════════"

  mkdir -p "${tf_data_dir}"

  # Read var-file args into array
  mapfile -t var_files < <(var_file_args "${stack}")

  TF_DATA_DIR="${tf_data_dir}" terraform -chdir="${stack_dir}" init \
    -backend-config="resource_group_name=${BACKEND_RESOURCE_GROUP:?}" \
    -backend-config="storage_account_name=${BACKEND_STORAGE_ACCOUNT:?}" \
    -backend-config="container_name=${BACKEND_CONTAINER_NAME:-tfstate}" \
    -backend-config="key=${state_key}" \
    -input=false \
    -reconfigure

  case "${COMMAND}" in
    plan)
      TF_DATA_DIR="${tf_data_dir}" terraform -chdir="${stack_dir}" plan \
        "${var_files[@]}" "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}"
      ;;
    apply)
      TF_DATA_DIR="${tf_data_dir}" terraform -chdir="${stack_dir}" apply \
        "${var_files[@]}" "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}"
      ;;
    destroy)
      TF_DATA_DIR="${tf_data_dir}" terraform -chdir="${stack_dir}" destroy \
        "${var_files[@]}" "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Execution order
# ---------------------------------------------------------------------------
if [[ "${COMMAND}" == "destroy" ]]; then
  # Reverse: tenant first, shared last
  run_stack "tenant"
  run_stack "shared"
else
  # Forward: shared first, tenant second
  run_stack "shared"
  run_stack "tenant"
fi

echo ""
echo "✓ All stacks completed successfully."
