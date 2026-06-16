#!/usr/bin/env bash
# deploy-terraform.sh — deploy script for fabric-analytics-api-gateway
#
# Usage:
#   ./scripts/deploy-terraform.sh plan    <env>                               # Preview all stacks
#   ./scripts/deploy-terraform.sh apply   <env> [--auto-approve]              # Apply shared → tenant
#   ./scripts/deploy-terraform.sh destroy <env> [--auto-approve]              # Destroy tenant → shared
#   ./scripts/deploy-terraform.sh import  <env> <stack> <tf-addr> <azure-id>  # Import one resource
#
# Required env vars:
#   BACKEND_RESOURCE_GROUP  — resource group holding Terraform state storage
#   BACKEND_STORAGE_ACCOUNT — storage account name for Terraform state
#   BACKEND_CONTAINER_NAME  — blob container name (default: tfstate)
#
# Optional env vars for DNS zone wait (between shared apply and tenant apply):
#   DNS_ZONE_RG       — resource group containing the DNS zone or private endpoint
#   DNS_ZONE_NAME     — DNS zone name  (e.g. privatelink.azure-api.net)
#   DNS_ZONE_TYPE     — private | public (default: private)
#   DNS_ZONE_ID       — resource ID of the DNS zone (alternative to RG+name)
#   DNS_PE_NAME       — private endpoint name; waits for zone groups instead of zone existence
#   DNS_WAIT_TIMEOUT  — polling timeout (default: 10m)  — accepts raw seconds or 15s/10m/1h
#   DNS_WAIT_INTERVAL — polling interval (default: 10s) — same format
#   DNS_SUBSCRIPTION  — subscription ID passed to az commands (optional)
#
# Stack ordering:
#   Apply/plan  — shared first, tenant second (tenant reads shared remote state)
#   Destroy     — tenant first, shared last   (reverse dependency)
#
# Auto-import on apply:
#   When terraform apply fails with an "already exists" error, the script
#   extracts the resource address and Azure resource ID from the error output,
#   imports the resource into state, and retries the apply automatically
#   (up to 3 times per stack).
#
set -euo pipefail

COMMAND="${1:?Usage: deploy-terraform.sh <plan|apply|destroy|import> <env> [...]}"
ENVIRONMENT="${2:?Usage: deploy-terraform.sh <plan|apply|destroy|import> <env> [...]}"
shift 2
EXTRA_FLAGS=("$@")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PARAMS_DIR="${REPO_ROOT}/params/${ENVIRONMENT}"
STACKS_DIR="${REPO_ROOT}/stacks"

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
case "${ENVIRONMENT}" in
  dev|test|prod) ;;
  *) echo "ERROR: environment must be dev, test, or prod" >&2; exit 1 ;;
esac

case "${COMMAND}" in
  plan|apply|destroy|import) ;;
  *) echo "ERROR: command must be plan, apply, destroy, or import" >&2; exit 1 ;;
esac

# ---------------------------------------------------------------------------
# CI non-interactive mode
# When CI=true, inject -auto-approve so apply/destroy never hang on the
# interactive confirmation prompt. plan and import take no such flag (Terraform
# would error), so they are skipped. A caller-supplied -auto-approve is kept
# as-is — we only add it when not already present.
# ---------------------------------------------------------------------------
if [[ "${CI:-}" == "true" ]]; then
  case "${COMMAND}" in
    apply|destroy)
      auto_approve_set=0
      for flag in "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}"; do
        if [[ "${flag}" == "-auto-approve" || "${flag}" == "--auto-approve" ]]; then
          auto_approve_set=1
          break
        fi
      done
      if [[ "${auto_approve_set}" -eq 0 ]]; then
        EXTRA_FLAGS+=("-auto-approve")
        echo "CI=true — running ${COMMAND} with -auto-approve."
      fi
      ;;
  esac
fi

: "${BACKEND_RESOURCE_GROUP:?BACKEND_RESOURCE_GROUP must be set}"
: "${BACKEND_STORAGE_ACCOUNT:?BACKEND_STORAGE_ACCOUNT must be set}"
export BACKEND_CONTAINER_NAME="${BACKEND_CONTAINER_NAME:-tfstate}"
export BACKEND_RESOURCE_GROUP BACKEND_STORAGE_ACCOUNT

# TF_VAR_backend_* — consumed by the tenant stack's terraform_remote_state block
# so it can read shared outputs. Terraform silently ignores TF_VAR_* for variables
# a stack does not declare, so exporting these is also safe for the shared stack.
export TF_VAR_backend_resource_group="${BACKEND_RESOURCE_GROUP}"
export TF_VAR_backend_storage_account="${BACKEND_STORAGE_ACCOUNT}"
export TF_VAR_backend_container_name="${BACKEND_CONTAINER_NAME}"

# ---------------------------------------------------------------------------
# Collect tenant tfvars files
# ---------------------------------------------------------------------------
TENANT_VAR_FILES=()
if [[ -d "${PARAMS_DIR}/tenants" ]]; then
  while IFS= read -r -d '' f; do
    TENANT_VAR_FILES+=("$f")
  done < <(find "${PARAMS_DIR}/tenants" -name "tenant.tfvars" -print0 | sort -z)
fi

# ---------------------------------------------------------------------------
# Remote tenant configs (optional) — keep Fabric endpoint URLs out of the repo
# AND out of GitHub secrets. When TENANT_CONFIG_CONTAINER is set, tenant tfvars
# live as blobs in the state storage account (public data plane — no private
# endpoint needed, unlike Key Vault). Every <env>/*.tfvars blob is downloaded
# and fed to the tenant stack as -var-file, alongside any local
# tenants/**/tenant.tfvars. Unset → no-op (fully backward compatible).
# ---------------------------------------------------------------------------
REMOTE_TENANT_VAR_FILES=()
REMOTE_TENANT_DIR=""

cleanup_remote_tenant_configs() {
  [[ -n "${REMOTE_TENANT_DIR}" && -d "${REMOTE_TENANT_DIR}" ]] && rm -rf "${REMOTE_TENANT_DIR}"
}
trap cleanup_remote_tenant_configs EXIT

fetch_remote_tenant_configs() {
  local container="${TENANT_CONFIG_CONTAINER:-}"
  [[ -z "${container}" ]] && return 0

  if ! command -v az >/dev/null 2>&1; then
    echo "  ⚠ TENANT_CONFIG_CONTAINER set but az CLI not found — skipping remote tenant configs." >&2
    return 0
  fi

  echo "  Fetching remote tenant configs: ${BACKEND_STORAGE_ACCOUNT}/${container}/${ENVIRONMENT}/*.tfvars"
  REMOTE_TENANT_DIR="$(mktemp -d)"

  # Prefer AAD (Storage Blob Data Reader); fall back to the account key — the
  # same credential the azurerm state backend already uses for this account.
  local -a auth=(--auth-mode login)
  if ! az storage blob list --account-name "${BACKEND_STORAGE_ACCOUNT}" \
        --container-name "${container}" --prefix "${ENVIRONMENT}/" \
        --auth-mode login --only-show-errors -o none >/dev/null 2>&1; then
    local key
    key="$(az storage account keys list --account-name "${BACKEND_STORAGE_ACCOUNT}" \
           --resource-group "${BACKEND_RESOURCE_GROUP}" \
           --query '[0].value' -o tsv 2>/dev/null || true)"
    [[ -n "${key}" ]] && auth=(--account-key "${key}")
  fi

  if ! az storage blob download-batch \
        --account-name "${BACKEND_STORAGE_ACCOUNT}" \
        --source "${container}" \
        --pattern "${ENVIRONMENT}/*.tfvars" \
        --destination "${REMOTE_TENANT_DIR}" \
        "${auth[@]}" --only-show-errors >/dev/null 2>&1; then
    echo "  ⚠ No remote tenant configs downloaded for env '${ENVIRONMENT}' (container/blobs may not exist yet)." >&2
    return 0
  fi

  while IFS= read -r -d '' f; do
    REMOTE_TENANT_VAR_FILES+=("$f")
    echo "    + remote tenant config: $(basename "$f")"
  done < <(find "${REMOTE_TENANT_DIR}" -name '*.tfvars' -print0 | sort -z)
}

# ---------------------------------------------------------------------------
# has_tenant_configs
# True when at least one tenant config (local tenant.tfvars or downloaded blob)
# is present. Used to SKIP the tenant stack on plan/apply when no config is
# available — otherwise Terraform would see tenants = {} and DESTROY every
# existing tenant resource. This guards against a CI run that lacks the config
# (e.g. blob not uploaded yet) silently wiping live tenants. Removing a tenant
# is still possible via `destroy`, or by applying with the remaining tenants.
# ---------------------------------------------------------------------------
has_tenant_configs() {
  local n=$(( ${#TENANT_VAR_FILES[@]} + ${#REMOTE_TENANT_VAR_FILES[@]} ))
  [[ "${n}" -gt 0 ]]
}

# ---------------------------------------------------------------------------
# var_file_args <stack>
# Build the -var-file flag list for a stack:
#   Both stacks  → common.tfvars
#   shared only  → shared.tfvars
#   tenant only  → each tenants/**/tenant.tfvars
# ---------------------------------------------------------------------------
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
      for f in "${REMOTE_TENANT_VAR_FILES[@]+"${REMOTE_TENANT_VAR_FILES[@]}"}"; do
        args+=("-var-file=${f}")
      done
      ;;
  esac
  printf '%s\n' "${args[@]}"
}

# ---------------------------------------------------------------------------
# init_stack <stack>
# Always re-init so the backend key is current. TF_DATA_DIR is set per-stack
# so shared and tenant plugin caches never collide.
# ---------------------------------------------------------------------------
init_stack() {
  local stack="$1"
  local state_key="fabric-gateway/${ENVIRONMENT}/${stack}.tfstate"
  local tf_data_dir="${REPO_ROOT}/.terraform-data/${stack}"

  mkdir -p "${tf_data_dir}"
  TF_DATA_DIR="${tf_data_dir}" terraform -chdir="${STACKS_DIR}/${stack}" init \
    -backend-config="resource_group_name=${BACKEND_RESOURCE_GROUP}" \
    -backend-config="storage_account_name=${BACKEND_STORAGE_ACCOUNT}" \
    -backend-config="container_name=${BACKEND_CONTAINER_NAME}" \
    -backend-config="key=${state_key}" \
    -input=false \
    -reconfigure
}

# ---------------------------------------------------------------------------
# run_stack <stack>
# Init then run the current COMMAND (plan/destroy) against one stack.
# For apply, use apply_stack instead (adds auto-import retry).
# ---------------------------------------------------------------------------
run_stack() {
  local stack="$1"
  local tf_data_dir="${REPO_ROOT}/.terraform-data/${stack}"

  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Stack: ${stack}  (${COMMAND})"
  echo "════════════════════════════════════════════════════════════"

  init_stack "${stack}"

  mapfile -t var_files < <(var_file_args "${stack}")

  case "${COMMAND}" in
    plan)
      TF_DATA_DIR="${tf_data_dir}" terraform -chdir="${STACKS_DIR}/${stack}" plan \
        "${var_files[@]}" "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}"
      ;;
    destroy)
      TF_DATA_DIR="${tf_data_dir}" terraform -chdir="${STACKS_DIR}/${stack}" destroy \
        "${var_files[@]}" "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# extract_import_target <file|->>
# Parse Terraform apply output for "already exists" errors and extract the
# resource address and Azure resource ID.
#
# Output (tab-separated):  <tf-address>\t<azure-resource-id>
# Returns 0 when a pair is found, 1 when none found.
#
# Handles: multiple errors (uses last), escaped quotes, pipe-separated IDs
# (Diagnostic Settings), and bare /subscriptions/ paths.
# ---------------------------------------------------------------------------
extract_import_target() {
  local input="$1"
  local content

  if [[ "${input}" == "-" ]]; then
    content="$(cat)"
  elif [[ -f "${input}" ]]; then
    content="$(cat "${input}")"
  else
    echo "extract_import_target: file not found: ${input}" >&2
    return 1
  fi

  if ! echo "${content}" | grep -q "already exists"; then
    return 1
  fi

  local awk_script result
  awk_script="$(mktemp 2>/dev/null || true)"
  if [[ -z "${awk_script}" ]]; then
    return 1
  fi

  cat >"${awk_script}" <<'AWK'
function trim(s) {
    sub(/^[[:space:]]+/, "", s)
    sub(/[[:space:]]+$/, "", s)
    return s
}

function extract_addr(line,    s) {
    if (match(line, /with[[:space:]]+[^,]+,/)) {
        s = substr(line, RSTART, RLENGTH)
        sub(/^with[[:space:]]+/, "", s)
        sub(/,$/, "", s)
        return s
    }
    return ""
}

function extract_id(line,    s) {
    # Prefer a quoted (or escaped-quoted) /subscriptions/... pattern
    if (match(line, /\\?"\/subscriptions\/[^\\\"]+\\?"/)) {
        s = substr(line, RSTART, RLENGTH)
        sub(/^\\?"/, "", s)
        sub(/\\?"$/, "", s)
        sub(/\\$/, "", s)
        return s
    }
    if (match(line, /\/subscriptions\//)) {
        s = substr(line, RSTART)
        sub(/["[:space:]].*$/, "", s)
        sub(/\\$/, "", s)
        return s
    }
    return ""
}

BEGIN { pending_id = ""; last_addr = ""; last_id = ""; in_error = 0 }

{
    gsub(/\r/, "", $0)
    line = $0

    if (line ~ /already exists/) { in_error = 1 }

    if (in_error) {
        id = extract_id(line)
        if (id != "") { pending_id = id }
    }

    addr = extract_addr(line)
    if (addr != "" && pending_id != "") {
        last_addr = trim(addr)
        last_id   = trim(pending_id)
        pending_id = ""
        in_error   = 0
    }
}

END {
    if (last_addr != "" && last_id != "") {
        printf "%s\t%s\n", last_addr, last_id
        exit 0
    }
    exit 1
}
AWK

  result="$(printf '%s\n' "${content}" | awk -f "${awk_script}" 2>/dev/null)" || true
  rm -f "${awk_script}" >/dev/null 2>&1 || true

  if [[ -n "${result}" ]]; then
    printf '%s\n' "${result}"
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# apply_stack <stack>
# Run terraform apply. On "already exists" failure, extract the import target,
# import the resource into state, and retry — up to MAX_IMPORT_RETRIES times.
# ---------------------------------------------------------------------------
apply_stack() {
  local stack="$1"
  local tf_data_dir="${REPO_ROOT}/.terraform-data/${stack}"
  local max_retries=3

  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Stack: ${stack}  (apply)"
  echo "════════════════════════════════════════════════════════════"

  init_stack "${stack}"

  mapfile -t var_files < <(var_file_args "${stack}")

  for ((retry = 0; retry < max_retries; retry++)); do
    if [[ "${retry}" -gt 0 ]]; then
      echo ""
      echo "  Retrying apply (attempt $((retry + 1))/${max_retries})..."
    fi

    local apply_log
    apply_log="$(mktemp)"

    # Capture combined stdout+stderr to both terminal and the log file
    if TF_DATA_DIR="${tf_data_dir}" terraform -chdir="${STACKS_DIR}/${stack}" apply \
        "${var_files[@]}" "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}" 2>&1 \
        | tee "${apply_log}"; then
      rm -f "${apply_log}"
      return 0
    fi

    local import_pair address azure_id
    if import_pair="$(extract_import_target "${apply_log}")"; then
      address="$(echo "${import_pair}" | cut -f1)"
      azure_id="$(echo "${import_pair}" | cut -f2)"
      rm -f "${apply_log}"

      echo ""
      echo "  Detected existing resource — importing before retry:"
      echo "    Address  : ${address}"
      echo "    Azure ID : ${azure_id}"

      TF_DATA_DIR="${tf_data_dir}" terraform -chdir="${STACKS_DIR}/${stack}" import \
        "${var_files[@]}" "${address}" "${azure_id}"
    else
      rm -f "${apply_log}"
      echo "  Apply failed — no importable 'already exists' error detected." >&2
      return 1
    fi
  done

  echo "ERROR: Apply failed after ${max_retries} import retries." >&2
  return 1
}

# ---------------------------------------------------------------------------
# duration_to_seconds <value>
# Convert a human duration (15s / 10m / 1h / 1d) or raw integer to seconds.
# ---------------------------------------------------------------------------
duration_to_seconds() {
  local value="$1"

  if echo "${value}" | grep -Eq '^[0-9]+$'; then
    echo "${value}"
    return 0
  fi

  if ! echo "${value}" | grep -Eq '^[0-9]+[smhd]$'; then
    echo "Unsupported duration '${value}'. Use e.g. 15s, 10m, 1h, or a raw number of seconds." >&2
    return 1
  fi

  local num unit
  num="$(echo "${value}" | sed -E 's/^([0-9]+)[smhd]$/\1/')"
  unit="$(echo "${value}" | sed -E 's/^[0-9]+([smhd])$/\1/')"

  case "${unit}" in
    s) echo "${num}" ;;
    m) echo $((num * 60)) ;;
    h) echo $((num * 3600)) ;;
    d) echo $((num * 86400)) ;;
  esac
}

# ---------------------------------------------------------------------------
# check_zone_exists <zone_id> <zone_type> <resource_group> <zone_name> <subscription>
# Return 0 when the DNS zone exists in Azure, non-zero otherwise.
# ---------------------------------------------------------------------------
check_zone_exists() {
  local zone_id="$1" zone_type="$2" resource_group="$3" zone_name="$4" subscription="$5"
  local -a sub_args=()
  [[ -n "${subscription}" ]] && sub_args+=(--subscription "${subscription}")

  if [[ -n "${zone_id}" ]]; then
    az resource show --ids "${zone_id}" "${sub_args[@]}" --only-show-errors -o none >/dev/null 2>&1
    return $?
  fi

  case "${zone_type}" in
    private)
      az network private-dns zone show \
        --resource-group "${resource_group}" --name "${zone_name}" \
        "${sub_args[@]}" --only-show-errors -o none >/dev/null 2>&1
      ;;
    public)
      az network dns zone show \
        --resource-group "${resource_group}" --name "${zone_name}" \
        "${sub_args[@]}" --only-show-errors -o none >/dev/null 2>&1
      ;;
    *)
      echo "Invalid DNS_ZONE_TYPE '${zone_type}' (expected private|public)." >&2
      return 2
      ;;
  esac
}

# ---------------------------------------------------------------------------
# check_pe_zone_group_exists <resource_group> <private_endpoint_name> <subscription>
# Return 0 when at least one DNS zone group is attached to the private endpoint.
# ---------------------------------------------------------------------------
check_pe_zone_group_exists() {
  local resource_group="$1" private_endpoint_name="$2" subscription="$3"
  local -a sub_args=()
  [[ -n "${subscription}" ]] && sub_args+=(--subscription "${subscription}")

  local count
  count="$(az network private-endpoint dns-zone-group list \
    --resource-group "${resource_group}" \
    --endpoint-name "${private_endpoint_name}" \
    "${sub_args[@]}" \
    --query "length(@)" --only-show-errors -o tsv 2>/dev/null || echo 0)"

  [[ "${count}" =~ ^[0-9]+$ ]] && [[ "${count}" -gt 0 ]]
}

# ---------------------------------------------------------------------------
# wait_for_dns_zone
# Called between shared apply and tenant apply. Polls for an Azure DNS zone
# (private or public) or a private endpoint DNS zone group until it exists or
# the timeout elapses. Controlled entirely by env vars; silently skipped when
# none of DNS_ZONE_RG / DNS_ZONE_NAME / DNS_ZONE_ID / DNS_PE_NAME are set.
#
# Required env vars (one form must be set to activate the wait):
#   DNS_ZONE_RG + DNS_ZONE_NAME           — poll for a named DNS zone
#   DNS_ZONE_ID                           — poll for a DNS zone by resource ID
#   DNS_ZONE_RG + DNS_PE_NAME             — poll for PE DNS zone group attachment
#
# Optional env vars:
#   DNS_ZONE_TYPE        — private (default) | public
#   DNS_WAIT_TIMEOUT     — default 10m
#   DNS_WAIT_INTERVAL    — default 10s
#   DNS_SUBSCRIPTION     — passed to az commands
# ---------------------------------------------------------------------------
wait_for_dns_zone() {
  local zone_rg="${DNS_ZONE_RG:-}"
  local zone_name="${DNS_ZONE_NAME:-}"
  local zone_type="${DNS_ZONE_TYPE:-private}"
  local zone_id="${DNS_ZONE_ID:-}"
  local pe_name="${DNS_PE_NAME:-}"
  local subscription="${DNS_SUBSCRIPTION:-}"
  local timeout="${DNS_WAIT_TIMEOUT:-10m}"
  local interval="${DNS_WAIT_INTERVAL:-10s}"

  # Skip when no DNS wait parameters are configured
  if [[ -z "${zone_rg}" && -z "${zone_id}" ]]; then
    return 0
  fi

  if ! command -v az >/dev/null 2>&1; then
    echo "  ⚠ Azure CLI (az) not found — skipping DNS zone wait." >&2
    return 0
  fi

  # Validate arguments
  if [[ -n "${pe_name}" && -z "${zone_rg}" ]]; then
    echo "ERROR: DNS_PE_NAME requires DNS_ZONE_RG to be set." >&2
    return 1
  fi
  if [[ -z "${zone_id}" && -z "${pe_name}" && -z "${zone_name}" ]]; then
    echo "ERROR: Set DNS_ZONE_NAME (with DNS_ZONE_RG), DNS_ZONE_ID, or DNS_PE_NAME (with DNS_ZONE_RG)." >&2
    return 1
  fi

  local timeout_secs interval_secs
  timeout_secs="$(duration_to_seconds "${timeout}")"
  interval_secs="$(duration_to_seconds "${interval}")"

  echo ""
  if [[ -n "${pe_name}" ]]; then
    echo "  Waiting for PE DNS zone group (rg='${zone_rg}', endpoint='${pe_name}') timeout=${timeout}..." >&2
  elif [[ -n "${zone_id}" ]]; then
    echo "  Waiting for DNS zone (id='${zone_id}') timeout=${timeout}..." >&2
  else
    echo "  Waiting for DNS zone (type=${zone_type}, rg='${zone_rg}', name='${zone_name}') timeout=${timeout}..." >&2
  fi

  SECONDS=0
  while true; do
    if [[ -n "${pe_name}" ]]; then
      if check_pe_zone_group_exists "${zone_rg}" "${pe_name}" "${subscription}"; then
        echo "  ✓ PE DNS zone group found." >&2
        return 0
      fi
    else
      if check_zone_exists "${zone_id}" "${zone_type}" "${zone_rg}" "${zone_name}" "${subscription}"; then
        echo "  ✓ DNS zone found." >&2
        return 0
      fi
    fi

    if [[ "${SECONDS}" -ge "${timeout_secs}" ]]; then
      echo "  ⚠ Timed out after ${timeout} — continuing anyway." >&2
      return 0
    fi

    echo "  [${SECONDS}s / ${timeout_secs}s elapsed] not yet found — retrying in ${interval}..." >&2
    sleep "${interval_secs}"
  done
}

# ---------------------------------------------------------------------------
# plan_tenant_graceful
# Like run_stack "tenant" but exits 0 when the tenant plan fails because the
# shared stack has not been applied yet (remote state empty → outputs missing
# → "unsupported attribute" or failed lifecycle precondition).
# Only use this during 'plan'; apply/destroy must fail loudly on real errors.
# ---------------------------------------------------------------------------
plan_tenant_graceful() {
  local tf_data_dir="${REPO_ROOT}/.terraform-data/tenant"
  local plan_log
  plan_log="$(mktemp)"

  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Stack: tenant  (plan)"
  echo "════════════════════════════════════════════════════════════"

  init_stack "tenant"
  mapfile -t var_files < <(var_file_args "tenant")

  if TF_DATA_DIR="${tf_data_dir}" terraform -chdir="${STACKS_DIR}/tenant" plan \
      "${var_files[@]}" "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}" 2>&1 \
      | tee "${plan_log}"; then
    rm -f "${plan_log}"
    return 0
  fi

  # When the shared stack hasn't been applied yet its remote state blob is
  # empty, so every output reference (outputs.apim_id etc.) fails as
  # "unsupported attribute".  The lifecycle precondition on the APIM product
  # resource also fires.  Treat these as "not yet applied" rather than a real
  # error so that PR plans don't break on a fresh environment.
  if grep -qiE \
      "unsupported attribute|does not have an attribute|precondition|No state was found" \
      "${plan_log}" 2>/dev/null; then
    rm -f "${plan_log}"
    echo ""
    echo "  ⚠ Tenant stack plan skipped — shared stack has not been applied yet."
    echo "    Run 'apply' first to deploy the shared stack, then re-plan."
    return 0
  fi

  rm -f "${plan_log}"
  return 1
}

# ---------------------------------------------------------------------------
# import_resource <stack> <tf-address> <azure-id>
# Import a single Azure resource into the named stack's Terraform state.
# ---------------------------------------------------------------------------
import_resource() {
  local stack="$1" address="$2" azure_id="$3"
  local tf_data_dir="${REPO_ROOT}/.terraform-data/${stack}"

  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Import → stack: ${stack}"
  echo "  Address  : ${address}"
  echo "  Azure ID : ${azure_id}"
  echo "════════════════════════════════════════════════════════════"

  init_stack "${stack}"

  mapfile -t var_files < <(var_file_args "${stack}")

  TF_DATA_DIR="${tf_data_dir}" terraform -chdir="${STACKS_DIR}/${stack}" import \
    "${var_files[@]}" "${address}" "${azure_id}"
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
echo "Fabric Gateway — ${COMMAND} — environment: ${ENVIRONMENT}"
echo "State: ${BACKEND_STORAGE_ACCOUNT}/${BACKEND_CONTAINER_NAME}"

# Pull any remote tenant configs (no-op unless TENANT_CONFIG_CONTAINER is set).
fetch_remote_tenant_configs

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------
case "${COMMAND}" in
  plan)
    run_stack "shared"
    if has_tenant_configs; then
      plan_tenant_graceful
    else
      echo ""
      echo "  (No tenant configs present — skipping tenant plan. Add a local"
      echo "   tenant.tfvars or set TENANT_CONFIG_CONTAINER with uploaded blobs.)"
    fi
    ;;

  apply)
    apply_stack "shared"
    wait_for_dns_zone
    if has_tenant_configs; then
      apply_stack "tenant"
    else
      echo ""
      echo "⚠ No tenant configs found — SKIPPING the tenant stack so this apply"
      echo "  cannot destroy existing tenant resources. To manage tenants, supply"
      echo "  a local params/${ENVIRONMENT}/tenants/**/tenant.tfvars or set"
      echo "  TENANT_CONFIG_CONTAINER and upload <env>/*.tfvars blobs."
    fi
    ;;

  destroy)
    # Reverse order — tenant must be torn down before shared so that
    # terraform_remote_state references in the tenant stack resolve cleanly.
    run_stack "tenant"
    run_stack "shared"
    ;;

  import)
    # deploy-terraform.sh import <env> <stack> <tf-address> <azure-resource-id>
    IMPORT_STACK="${EXTRA_FLAGS[0]:?import requires: <stack> <tf-address> <azure-resource-id>}"
    IMPORT_ADDRESS="${EXTRA_FLAGS[1]:?import requires: <stack> <tf-address> <azure-resource-id>}"
    IMPORT_ID="${EXTRA_FLAGS[2]:?import requires: <stack> <tf-address> <azure-resource-id>}"
    case "${IMPORT_STACK}" in
      shared|tenant) ;;
      *) echo "ERROR: import stack must be 'shared' or 'tenant'" >&2; exit 1 ;;
    esac
    import_resource "${IMPORT_STACK}" "${IMPORT_ADDRESS}" "${IMPORT_ID}"
    ;;
esac

echo ""
echo "✓ Done."
