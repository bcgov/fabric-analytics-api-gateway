# ============================================================
# common.tfvars — dev environment
# Passed to: stacks/shared AND stacks/tenant
#
# Only variables that BOTH stacks declare and use belong here.
# Provider auth (subscription_id, tenant_id, client_id, use_oidc) and the
# Terraform state backend coordinates are intentionally NOT committed — they
# come from TF_VAR_* env vars and -backend-config (CI sets them; locally you
# export them). A committed value would beat TF_VAR_* in Terraform precedence
# and silently override CI, so they are kept out of version control.
# ============================================================

app_env  = "dev"
app_name = "fabric-gateway"
