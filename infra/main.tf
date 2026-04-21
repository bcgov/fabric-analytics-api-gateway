resource "azurerm_resource_group" "main" {
  count = local.create_resource_group_count

  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

module "network" {
  count  = local.create_network_count
  source = "./modules/network"

  common_tags                  = local.common_tags
  container_apps_subnet_name   = "${local.name_prefix}-aca-snet"
  enabled                      = var.enable_network
  location                     = var.location
  private_endpoint_subnet_name = "${local.name_prefix}-pe-snet"
  resource_group_name          = local.resource_group_name
  vnet_name                    = var.existing_vnet_name
  vnet_resource_group_name     = var.existing_vnet_resource_group_name
}

module "monitoring" {
  count  = local.create_monitoring_count
  source = "./modules/monitoring-stack"

  # Keep the root wired to the current monitoring module contract.
  app_name                     = var.app_name
  common_tags                  = local.common_tags
  location                     = var.location
  log_analytics_retention_days = var.log_analytics_retention_days
  log_analytics_sku            = var.log_analytics_sku
  resource_group_name          = local.resource_group_name

  depends_on = [azurerm_resource_group.main]
}

module "container_apps" {
  count  = local.create_container_apps_count
  source = "./modules/container-apps/"

  app_env                             = var.app_env
  app_name                            = var.app_name
  common_tags                         = local.common_tags
  container_apps_environment_name     = var.container_apps_environment_name
  container_apps_subnet_id            = var.container_apps_subnet_id != null ? var.container_apps_subnet_id : try(module.network[0].container_apps_subnet_id, null)
  container_cpu                       = var.container_cpu
  container_memory                    = var.container_memory
  dab_container_app_name              = var.dab_container_app_name
  dab_external_ingress_enabled        = var.dab_external_ingress_enabled
  dab_image                           = var.dab_image
  dab_target_port                     = var.dab_target_port
  deploy_dab_app                      = var.deploy_dab_app
  deploy_kong_app                     = var.deploy_kong_app
  enable_system_assigned_identity     = var.enable_system_assigned_identity
  kong_container_app_name             = var.kong_container_app_name
  kong_client_tls_certificate_pem     = var.kong_client_tls_certificate_pem
  kong_client_tls_private_key_pem     = var.kong_client_tls_private_key_pem
  kong_edge_ca_pem                    = var.kong_edge_ca_pem
  kong_external_ingress_enabled       = var.kong_external_ingress_enabled
  kong_image                          = var.kong_image
  kong_mtls_required                  = var.kong_mtls_required
  kong_nginx_proxy_include_config     = var.kong_nginx_proxy_include_config
  kong_public_ca_pem                  = var.kong_public_ca_pem
  kong_route_host                     = var.kong_route_host
  kong_runtime_group_name             = var.kong_runtime_group_name
  kong_sdx_control_url                = var.kong_sdx_control_url
  kong_server_tls_certificate_pem     = var.kong_server_tls_certificate_pem
  kong_server_tls_private_key_pem     = var.kong_server_tls_private_key_pem
  kong_target_port                    = var.kong_target_port
  location                            = var.location
  log_analytics_workspace_customer_id = try(module.monitoring[0].log_analytics_workspace_workspaceId, null)
  log_analytics_workspace_id          = try(module.monitoring[0].log_analytics_workspace_id, null)
  log_analytics_workspace_key         = try(module.monitoring[0].log_analytics_workspace_key, null)
  max_replicas                        = var.max_replicas
  min_replicas                        = var.min_replicas
  private_endpoint_subnet_id          = var.private_endpoint_subnet_id != null ? var.private_endpoint_subnet_id : try(module.network[0].private_endpoint_subnet_id, null)
  resource_group_name                 = local.resource_group_name

  depends_on = [azurerm_resource_group.main]
}

module "front_door" {
  count  = local.create_front_door_count
  source = "./modules/frontdoor"

  app_name                       = var.app_name
  common_tags                    = local.common_tags
  frontdoor_sku_name             = var.front_door_sku
  log_analytics_workspace_id     = try(module.monitoring[0].log_analytics_workspace_id, null)
  rate_limit_duration_in_minutes = var.front_door_rate_limit_duration_in_minutes
  rate_limit_threshold           = var.front_door_rate_limit_threshold
  resource_group_name            = local.resource_group_name

  depends_on = [azurerm_resource_group.main]
}
