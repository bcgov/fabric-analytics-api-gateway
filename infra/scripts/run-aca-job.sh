#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
run-aca-job.sh

Starts a manual Azure Container Apps Job execution and waits for completion.
Terraform is expected to gate repeated runs by changing the execution fingerprint
only when the bootstrap token or other relevant inputs change.

Required arguments:
  --job-name <name>
  --resource-group <rg>

Optional arguments:
  --container-name <name>   Default: bootstrap
  --workspace-id <id>       Log Analytics customer/workspace ID for failure log queries
  --timeout <dur>           Default: 10m
  --interval <dur>          Default: 10s

Required environment variables:
  KONG_KEY_VAULT_NAME
  KONG_KEY_VAULT_SECRET_PREFIX
  KONG_RUNTIME_GROUP_NAME
  SDX_BOOTSTRAP_TOKEN
  SDX_CLIENT_CA_URL

Optional environment variables:
  KONG_ROUTE_HOST
  SDX_SERVER_IP_SAN
EOF
}

duration_to_seconds() {
  local value="$1"

  if echo "$value" | grep -Eq '^[0-9]+$'; then
    echo "$value"
    return 0
  fi

  if ! echo "$value" | grep -Eq '^[0-9]+[smhd]$'; then
    echo "Unsupported duration '$value'. Use e.g. 15s, 10m, 1h (or a raw number of seconds)." >&2
    return 1
  fi

  local num unit
  num="$(echo "$value" | sed -E 's/^([0-9]+)[smhd]$/\1/')"
  unit="$(echo "$value" | sed -E 's/^[0-9]+([smhd])$/\1/')"

  case "$unit" in
    s) echo "$num" ;;
    m) echo $((num * 60)) ;;
    h) echo $((num * 3600)) ;;
    d) echo $((num * 86400)) ;;
  esac
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
}

require_env() {
  local var_name="$1"

  if [[ -z "${!var_name:-}" ]]; then
    echo "Required environment variable is not set: $var_name" >&2
    usage
    exit 2
  fi
}

query_logs() {
  local workspace_id="$1"
  local execution_name="$2"

  if [[ -z "$workspace_id" ]]; then
    return 0
  fi

  az monitor log-analytics query \
    --workspace "$workspace_id" \
    --analytics-query "ContainerAppConsoleLogs_CL | where ContainerGroupName_s startswith '$execution_name' | order by _timestamp_d asc | project Log_s" \
    --output table || true
}

main() {
  local container_name="bootstrap"
  local interval="10s"
  local job_name=""
  local resource_group=""
  local timeout="10m"
  local workspace_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --container-name)
        container_name="${2:-}"
        shift 2
        ;;
      --interval)
        interval="${2:-}"
        shift 2
        ;;
      --job-name)
        job_name="${2:-}"
        shift 2
        ;;
      --resource-group)
        resource_group="${2:-}"
        shift 2
        ;;
      --timeout)
        timeout="${2:-}"
        shift 2
        ;;
      --workspace-id)
        workspace_id="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 2
        ;;
    esac
  done

  require_command az
  require_env KONG_KEY_VAULT_NAME
  require_env KONG_KEY_VAULT_SECRET_PREFIX
  require_env KONG_RUNTIME_GROUP_NAME
  require_env SDX_BOOTSTRAP_TOKEN
  require_env SDX_CLIENT_CA_URL

  if [[ -z "$job_name" || -z "$resource_group" ]]; then
    echo "Both --job-name and --resource-group are required." >&2
    usage
    exit 2
  fi

  local interval_seconds timeout_seconds
  interval_seconds="$(duration_to_seconds "$interval")"
  timeout_seconds="$(duration_to_seconds "$timeout")"

  local -a start_args=(
    --name "$job_name"
    --resource-group "$resource_group"
    --container-name "$container_name"
    --env-vars
    "KONG_KEY_VAULT_NAME=$KONG_KEY_VAULT_NAME"
    "KONG_KEY_VAULT_SECRET_PREFIX=$KONG_KEY_VAULT_SECRET_PREFIX"
    "KONG_RUNTIME_GROUP_NAME=$KONG_RUNTIME_GROUP_NAME"
    "SDX_BOOTSTRAP_TOKEN=$SDX_BOOTSTRAP_TOKEN"
    "SDX_CLIENT_CA_URL=$SDX_CLIENT_CA_URL"
  )

  if [[ -n "${KONG_ROUTE_HOST:-}" ]]; then
    start_args+=("KONG_ROUTE_HOST=$KONG_ROUTE_HOST")
  fi

  if [[ -n "${SDX_SERVER_IP_SAN:-}" ]]; then
    start_args+=("SDX_SERVER_IP_SAN=$SDX_SERVER_IP_SAN")
  fi

  local execution_name
  execution_name="$(az containerapp job start "${start_args[@]}" --query name --output tsv)"
  if [[ -z "$execution_name" ]]; then
    echo "ACA job start did not return an execution name for job '$job_name'." >&2
    exit 1
  fi

  echo "Started ACA job execution '$execution_name' for job '$job_name'." >&2

  local status=""
  SECONDS=0
  while true; do
    status="$(az containerapp job execution list \
      --name "$job_name" \
      --resource-group "$resource_group" \
      --query "[?name=='$execution_name'].properties.status | [0]" \
      --output tsv)"

    case "$status" in
      Succeeded)
        echo "ACA job execution '$execution_name' succeeded." >&2
        exit 0
        ;;
      Failed|Canceled)
        echo "ACA job execution '$execution_name' finished with status '$status'." >&2
        query_logs "$workspace_id" "$execution_name"
        exit 1
        ;;
      *)
        if [[ "$SECONDS" -ge "$timeout_seconds" ]]; then
          echo "Timed out waiting for ACA job execution '$execution_name' after $timeout." >&2
          query_logs "$workspace_id" "$execution_name"
          exit 1
        fi

        echo "ACA job execution '$execution_name' status: ${status:-Pending}" >&2
        sleep "$interval_seconds"
        ;;
    esac
  done
}

main "$@"
