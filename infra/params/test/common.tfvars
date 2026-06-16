# ============================================================
# common.tfvars — test environment
# Passed to: stacks/shared AND stacks/tenant
#
# Only variables that BOTH stacks declare and use belong here.
# Provider auth and Terraform state backend coordinates are intentionally NOT
# committed — they come from TF_VAR_* env vars and -backend-config so a committed
# value can never override CI.
# ============================================================

app_env  = "test"
app_name = "fabric-gateway"
