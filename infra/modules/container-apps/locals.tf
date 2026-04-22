locals {
  configure_log_analytics_count         = local.create_environment_count == 1 && var.log_analytics_workspace_customer_id != null && trimspace(var.log_analytics_workspace_customer_id) != "" && var.log_analytics_workspace_key != null && trimspace(var.log_analytics_workspace_key) != "" ? 1 : 0
  container_apps_environment_name       = var.container_apps_environment_name != null && trimspace(var.container_apps_environment_name) != "" ? var.container_apps_environment_name : "${var.app_name}-${var.app_env}-containerenv"
  create_environment_count              = var.container_apps_subnet_id != null && trimspace(var.container_apps_subnet_id) != "" && var.log_analytics_workspace_id != null && trimspace(var.log_analytics_workspace_id) != "" ? 1 : 0
  create_private_endpoint_count         = local.create_environment_count == 1 && var.private_endpoint_subnet_id != null && trimspace(var.private_endpoint_subnet_id) != "" ? 1 : 0
  dab_container_app_name                = var.dab_container_app_name != null && trimspace(var.dab_container_app_name) != "" ? var.dab_container_app_name : "${var.app_name}-${var.app_env}-dab"
  dab_sql_connection_string_secret_name = "sql-conn-string"
  deploy_dab_count                      = local.create_environment_count == 1 && var.deploy_dab_app ? 1 : 0
  deploy_kong_count                     = local.create_environment_count == 1 && var.deploy_kong_app ? 1 : 0
  deploy_kong_bootstrap_job_count       = local.create_environment_count == 1 && var.deploy_kong_bootstrap_job ? 1 : 0
  kong_bootstrap_job_name               = var.kong_runtime_group_name != null && trimspace(var.kong_runtime_group_name) != "" ? "sdx-bootstrap-${var.kong_runtime_group_name}" : trimsuffix(substr(lower(replace("${var.app_name}-${var.app_env}-bootstrap", "_", "-")), 0, 32), "-")
  kong_bootstrap_job_run_count          = local.deploy_kong_bootstrap_job_count
  kong_bootstrap_run_fingerprint = local.kong_bootstrap_job_run_count == 1 ? sha256(jsonencode({
    bootstrap_token_sha     = sha256(nonsensitive(coalesce(var.sdx_bootstrap_token, "")))
    client_ca_url           = coalesce(var.sdx_client_ca_url, "")
    key_vault_name          = coalesce(var.kong_key_vault_name, "")
    key_vault_secret_prefix = coalesce(var.kong_key_vault_secret_prefix, "")
    route_host              = coalesce(local.kong_route_host, "")
    runtime_group_name      = coalesce(var.kong_runtime_group_name, "")
    server_ip_san           = coalesce(var.sdx_server_ip_san, "")
  })) : null
  kong_container_app_name     = var.kong_container_app_name != null && trimspace(var.kong_container_app_name) != "" ? var.kong_container_app_name : var.kong_runtime_group_name != null && trimspace(var.kong_runtime_group_name) != "" ? "sdx-edge-${var.kong_runtime_group_name}" : "${var.app_name}-${var.app_env}-kong"
  kong_identity_type          = local.kong_uses_key_vault_secrets ? var.enable_system_assigned_identity ? "SystemAssigned, UserAssigned" : "UserAssigned" : var.enable_system_assigned_identity ? "SystemAssigned" : "None"
  kong_route_host             = var.kong_route_host != null && trimspace(var.kong_route_host) != "" ? var.kong_route_host : var.kong_runtime_group_name != null && trimspace(var.kong_runtime_group_name) != "" ? "${var.kong_runtime_group_name}.servers.sdx" : null
  kong_uses_key_vault_secrets = var.kong_key_vault_secret_identity_id != null && trimspace(var.kong_key_vault_secret_identity_id) != ""
}
