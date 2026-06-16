#!/usr/bin/env bash
# deploy-terraform.sh — public entrypoint for infra-fabric-gateway deployments
#
# Usage:
#   ./scripts/deploy-terraform.sh plan   <env>                 # Preview changes
#   ./scripts/deploy-terraform.sh apply  <env> [--auto-approve]
#   ./scripts/deploy-terraform.sh destroy <env> [--auto-approve]
#
# Environment variables (set before running or export in your shell):
#   BACKEND_RESOURCE_GROUP  — resource group holding Terraform state storage
#   BACKEND_STORAGE_ACCOUNT — storage account name for state
#   BACKEND_CONTAINER_NAME  — container name (default: tfstate)
#
# Example (local dev):
#   export BACKEND_RESOURCE_GROUP="your-backend-rg"
#   export BACKEND_STORAGE_ACCOUNT="tfdevaihubtracking"
#   ./scripts/deploy-terraform.sh plan dev
#
set -euo pipefail

COMMAND="${1:?Usage: deploy-terraform.sh <plan|apply|destroy> <env> [flags]}"
ENVIRONMENT="${2:?Usage: deploy-terraform.sh <plan|apply|destroy> <env> [flags]}"
shift 2
EXTRA_FLAGS=("$@")

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Required environment variables
: "${BACKEND_RESOURCE_GROUP:?BACKEND_RESOURCE_GROUP must be set}"
: "${BACKEND_STORAGE_ACCOUNT:?BACKEND_STORAGE_ACCOUNT must be set}"
export BACKEND_CONTAINER_NAME="${BACKEND_CONTAINER_NAME:-tfstate}"

# Validate command
case "${COMMAND}" in
  plan|apply|destroy) ;;
  *) echo "ERROR: command must be plan, apply, or destroy" >&2; exit 1 ;;
esac

export BACKEND_RESOURCE_GROUP BACKEND_STORAGE_ACCOUNT BACKEND_CONTAINER_NAME

echo "Fabric Gateway — ${COMMAND} — environment: ${ENVIRONMENT}"
echo "State: ${BACKEND_STORAGE_ACCOUNT}/${BACKEND_CONTAINER_NAME}"
echo ""

exec "${REPO_ROOT}/scripts/deploy-scaled.sh" "${COMMAND}" "${ENVIRONMENT}" "${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"}"
