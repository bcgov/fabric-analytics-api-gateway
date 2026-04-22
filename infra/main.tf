resource "azurerm_resource_group" "main" {
  count = local.create_resource_group_count

  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "terraform_data" "root_preconditions" {
  lifecycle {
    precondition {
      condition     = !var.deploy_dab_app || var.enable_container_apps
      error_message = "deploy_dab_app requires enable_container_apps=true so the DAB workload has a managed environment to run in."
    }
    precondition {
      condition     = !var.deploy_kong_app || var.enable_container_apps
      error_message = "deploy_kong_app requires enable_container_apps=true so the Kong workload has a managed environment to run in."
    }
    precondition {
      condition     = !local.deploy_kong_bootstrap_job_effective || var.enable_container_apps
      error_message = "deploy_kong_bootstrap_job requires enable_container_apps=true so the ACA bootstrap job has a managed environment to run in."
    }
    precondition {
      condition     = !local.deploy_kong_bootstrap_job_effective || local.enable_key_vault_effective
      error_message = "deploy_kong_bootstrap_job requires enable_key_vault=true so the ACA bootstrap job has a Key Vault target for the generated secrets."
    }
    precondition {
      condition     = !(var.enable_application_gateway && var.enable_front_door)
      error_message = "enable_application_gateway and enable_front_door are mutually exclusive ingress strategies. Choose one public edge for the Kong deployment."
    }
    precondition {
      condition     = !(var.enable_front_door && var.kong_mtls_required)
      error_message = "enable_front_door cannot be used with kong_mtls_required=true. Azure Front Door does not provide the Application Gateway mutual-auth passthrough path used by this scaffold and still terminates TLS before the private Kong backend."
    }
    precondition {
      condition     = !(var.kong_external_ingress_enabled && var.kong_mtls_required)
      error_message = "kong_external_ingress_enabled cannot be used with kong_mtls_required=true in the current ACA scaffold. The supported public edge is Application Gateway in front of the private ACA environment, so ACA external ingress must remain disabled."
    }
    precondition {
      condition     = !(var.enable_application_gateway && var.kong_external_ingress_enabled)
      error_message = "enable_application_gateway requires kong_external_ingress_enabled=false. The Application Gateway path expects Kong to remain private behind the internal ACA environment."
    }
    precondition {
      condition     = !var.enable_application_gateway || var.enable_container_apps
      error_message = "enable_application_gateway requires enable_container_apps=true so the gateway can target the internal ACA environment."
    }
    precondition {
      condition     = !var.enable_application_gateway || var.deploy_kong_app
      error_message = "enable_application_gateway currently fronts the Kong Container App, so deploy_kong_app must be true."
    }
    precondition {
      condition     = !var.enable_application_gateway || (var.application_gateway_frontend_certificate_pfx_base64 != null && trimspace(var.application_gateway_frontend_certificate_pfx_base64) != "" && var.application_gateway_frontend_certificate_password != null && trimspace(var.application_gateway_frontend_certificate_password) != "")
      error_message = "enable_application_gateway requires application_gateway_frontend_certificate_pfx_base64 and application_gateway_frontend_certificate_password so the HTTPS listener can present a certificate."
    }
    precondition {
      condition     = !var.enable_application_gateway || (var.existing_vnet_name != null && trimspace(var.existing_vnet_name) != "" && var.existing_vnet_resource_group_name != null && trimspace(var.existing_vnet_resource_group_name) != "")
      error_message = "enable_application_gateway requires existing_vnet_name and existing_vnet_resource_group_name so the gateway can join the landing-zone VNet and publish ACA private DNS."
    }
    precondition {
      condition     = !var.enable_application_gateway || var.enable_network || (var.application_gateway_subnet_id != null && trimspace(var.application_gateway_subnet_id) != "")
      error_message = "enable_application_gateway requires enable_network=true or an explicit application_gateway_subnet_id so the gateway has a dedicated subnet."
    }
  }
}

module "key_vault" {
  count  = local.create_key_vault_count
  source = "./modules/key-vault/"

  app_env                    = var.app_env
  app_name                   = var.app_name
  common_tags                = local.common_tags
  key_vault_name             = var.kong_key_vault_name
  location                   = var.location
  private_endpoint_subnet_id = var.private_endpoint_subnet_id != null ? var.private_endpoint_subnet_id : try(module.network[0].private_endpoint_subnet_id, null)
  resource_group_name        = local.resource_group_name

  depends_on = [azurerm_resource_group.main]
}

module "network" {
  count  = local.create_network_count
  source = "./modules/network"

  application_gateway_subnet_name = "${local.name_prefix}-agw-snet"
  common_tags                     = local.common_tags
  container_apps_subnet_name      = "${local.name_prefix}-aca-snet"
  enabled                         = var.enable_network
  location                        = var.location
  private_endpoint_subnet_name    = "${local.name_prefix}-pe-snet"
  resource_group_name             = local.resource_group_name
  vnet_name                       = var.existing_vnet_name
  vnet_resource_group_name        = var.existing_vnet_resource_group_name
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

  app_env                               = var.app_env
  app_name                              = var.app_name
  common_tags                           = local.common_tags
  container_apps_environment_name       = var.container_apps_environment_name
  container_apps_subnet_id              = var.container_apps_subnet_id != null ? var.container_apps_subnet_id : try(module.network[0].container_apps_subnet_id, null)
  container_cpu                         = var.container_cpu
  container_memory                      = var.container_memory
  dab_container_app_name                = var.dab_container_app_name
  dab_database_type                     = var.dab_database_type
  dab_external_ingress_enabled          = var.dab_external_ingress_enabled
  dab_image                             = var.dab_image
  dab_sql_connection_string             = var.dab_sql_connection_string
  dab_target_port                       = var.dab_target_port
  deploy_dab_app                        = var.deploy_dab_app
  deploy_kong_app                       = var.deploy_kong_app
  deploy_kong_bootstrap_job             = local.deploy_kong_bootstrap_job_effective
  enable_system_assigned_identity       = var.enable_system_assigned_identity
  kong_bootstrap_job_identity_client_id = try(module.key_vault[0].bootstrap_writer_identity_client_id, null)
  kong_bootstrap_job_identity_id        = try(module.key_vault[0].bootstrap_writer_identity_id, null)
  kong_container_app_name               = var.kong_container_app_name
  kong_client_tls_certificate_pem       = var.kong_client_tls_certificate_pem
  kong_client_tls_certificate_secret_id = local.kong_client_tls_certificate_secret_id
  kong_client_tls_private_key_pem       = var.kong_client_tls_private_key_pem
  kong_client_tls_private_key_secret_id = local.kong_client_tls_private_key_secret_id
  kong_edge_ca_pem                      = var.kong_edge_ca_pem
  kong_edge_ca_secret_id                = local.kong_edge_ca_secret_id
  kong_external_ingress_enabled         = var.kong_external_ingress_enabled
  kong_image                            = var.kong_image
  kong_key_vault_name                   = try(module.key_vault[0].key_vault_name, null)
  kong_key_vault_secret_prefix          = local.kong_key_vault_secret_prefix
  kong_key_vault_secret_identity_id     = try(module.key_vault[0].kong_secret_identity_id, null)
  kong_mtls_required                    = var.kong_mtls_required
  kong_nginx_proxy_include_config       = var.kong_nginx_proxy_include_config
  kong_public_ca_pem                    = var.kong_public_ca_pem
  kong_route_host                       = var.kong_route_host
  kong_runtime_group_name               = var.kong_runtime_group_name
  kong_sdx_control_url                  = var.kong_sdx_control_url
  kong_server_tls_certificate_pem       = var.kong_server_tls_certificate_pem
  kong_server_tls_certificate_secret_id = local.kong_server_tls_certificate_secret_id
  kong_server_tls_private_key_pem       = var.kong_server_tls_private_key_pem
  kong_server_tls_private_key_secret_id = local.kong_server_tls_private_key_secret_id
  kong_target_port                      = var.kong_target_port
  location                              = var.location
  log_analytics_workspace_customer_id   = try(module.monitoring[0].log_analytics_workspace_workspaceId, null)
  log_analytics_workspace_id            = try(module.monitoring[0].log_analytics_workspace_id, null)
  log_analytics_workspace_key           = try(module.monitoring[0].log_analytics_workspace_key, null)
  max_replicas                          = var.max_replicas
  min_replicas                          = var.min_replicas
  private_endpoint_subnet_id            = var.private_endpoint_subnet_id != null ? var.private_endpoint_subnet_id : try(module.network[0].private_endpoint_subnet_id, null)
  resource_group_name                   = local.resource_group_name
  sdx_bootstrap_token                   = var.sdx_bootstrap_token
  sdx_client_ca_url                     = var.sdx_client_ca_url
  sdx_server_ip_san                     = var.sdx_server_ip_san

  depends_on = [azurerm_resource_group.main]
}

module "application_gateway" {
  count  = local.create_application_gateway_count
  source = "./modules/application-gateway"

  application_gateway_frontend_certificate_password   = var.application_gateway_frontend_certificate_password
  application_gateway_frontend_certificate_pfx_base64 = var.application_gateway_frontend_certificate_pfx_base64
  application_gateway_host_name                       = var.application_gateway_host_name != null ? var.application_gateway_host_name : try(module.container_apps[0].kong_route_host, null)
  application_gateway_max_capacity                    = var.application_gateway_max_capacity
  application_gateway_min_capacity                    = var.application_gateway_min_capacity
  application_gateway_name                            = var.application_gateway_name
  application_gateway_public_ip_name                  = var.application_gateway_public_ip_name
  application_gateway_sku_name                        = var.application_gateway_sku_name
  application_gateway_subnet_id                       = var.application_gateway_subnet_id != null ? var.application_gateway_subnet_id : try(module.network[0].application_gateway_subnet_id, null)
  app_name                                            = var.app_name
  backend_fqdn                                        = try(module.container_apps[0].kong_latest_fqdn, null)
  common_tags                                         = local.common_tags
  container_apps_environment_fqdn                     = try(module.container_apps[0].container_apps_environment_fqdn, null)
  container_apps_environment_static_ip                = try(module.container_apps[0].container_apps_environment_static_ip, null)
  location                                            = var.location
  log_analytics_workspace_id                          = try(module.monitoring[0].log_analytics_workspace_id, null)
  resource_group_name                                 = local.resource_group_name
  vnet_name                                           = var.existing_vnet_name
  vnet_resource_group_name                            = var.existing_vnet_resource_group_name

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
