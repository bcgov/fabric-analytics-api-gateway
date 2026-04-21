locals {
  configure_log_analytics_count   = local.create_environment_count == 1 && var.log_analytics_workspace_customer_id != null && trimspace(var.log_analytics_workspace_customer_id) != "" && var.log_analytics_workspace_key != null && trimspace(var.log_analytics_workspace_key) != "" ? 1 : 0
  container_apps_environment_name = var.container_apps_environment_name != null && trimspace(var.container_apps_environment_name) != "" ? var.container_apps_environment_name : "${var.app_name}-${var.app_env}-containerenv"
  create_environment_count        = var.container_apps_subnet_id != null && trimspace(var.container_apps_subnet_id) != "" && var.log_analytics_workspace_id != null && trimspace(var.log_analytics_workspace_id) != "" ? 1 : 0
  create_private_endpoint_count   = local.create_environment_count == 1 && var.private_endpoint_subnet_id != null && trimspace(var.private_endpoint_subnet_id) != "" ? 1 : 0
  dab_container_app_name          = var.dab_container_app_name != null && trimspace(var.dab_container_app_name) != "" ? var.dab_container_app_name : "${var.app_name}-${var.app_env}-dab"
  deploy_dab_count                = local.create_environment_count == 1 && var.deploy_dab_app ? 1 : 0
  deploy_kong_count               = local.create_environment_count == 1 && var.deploy_kong_app ? 1 : 0
  kong_container_app_name         = var.kong_container_app_name != null && trimspace(var.kong_container_app_name) != "" ? var.kong_container_app_name : var.kong_runtime_group_name != null && trimspace(var.kong_runtime_group_name) != "" ? "sdx-edge-${var.kong_runtime_group_name}" : "${var.app_name}-${var.app_env}-kong"
  kong_route_host                 = var.kong_route_host != null && trimspace(var.kong_route_host) != "" ? var.kong_route_host : var.kong_runtime_group_name != null && trimspace(var.kong_runtime_group_name) != "" ? "${var.kong_runtime_group_name}.servers.sdx" : null
}
