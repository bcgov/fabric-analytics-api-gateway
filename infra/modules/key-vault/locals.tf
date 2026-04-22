locals {
  bootstrap_writer_identity_name  = substr(lower(replace("${var.app_name}-${var.app_env}-kong-kv-writer-mi", "_", "-")), 0, 128)
  create_private_endpoint_count   = var.private_endpoint_subnet_id != null && trimspace(var.private_endpoint_subnet_id) != "" ? 1 : 0
  key_vault_name                  = var.key_vault_name != null && trimspace(var.key_vault_name) != "" ? lower(var.key_vault_name) : substr(lower(replace("${var.app_name}-${var.app_env}-kong-kv", "_", "-")), 0, 24)
  key_vault_private_endpoint_name = substr(lower(replace("${var.app_name}-${var.app_env}-kong-kv-pe", "_", "-")), 0, 80)
  kong_secret_identity_name       = substr(lower(replace("${var.app_name}-${var.app_env}-kong-kv-mi", "_", "-")), 0, 128)
}
