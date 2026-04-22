locals {
  deploy_kong_bootstrap_job_effective = var.deploy_kong_bootstrap_job || var.enable_kong_key_vault_bootstrap
  enable_key_vault_effective          = var.enable_key_vault || var.enable_kong_key_vault_bootstrap

  create_application_gateway_count = var.enable_application_gateway ? 1 : 0
  create_container_apps_count      = var.enable_container_apps ? 1 : 0
  create_front_door_count          = var.enable_front_door ? 1 : 0
  create_key_vault_count           = local.enable_key_vault_effective ? 1 : 0
  create_monitoring_count          = var.enable_monitoring ? 1 : 0
  create_network_count             = var.enable_network ? 1 : 0
  create_resource_group_count      = var.create_resource_group ? 1 : 0

  kong_key_vault_secret_prefix          = var.kong_key_vault_secret_prefix != null && trimspace(var.kong_key_vault_secret_prefix) != "" ? var.kong_key_vault_secret_prefix : var.kong_runtime_group_name != null && trimspace(var.kong_runtime_group_name) != "" ? "sdx-edge-${var.kong_runtime_group_name}" : "${local.name_prefix}-kong"
  kong_client_tls_certificate_secret_id = local.create_key_vault_count == 1 ? "${module.key_vault[0].vault_uri}secrets/${local.kong_key_vault_secret_prefix}-client-tls-certificate" : null
  kong_client_tls_private_key_secret_id = local.create_key_vault_count == 1 ? "${module.key_vault[0].vault_uri}secrets/${local.kong_key_vault_secret_prefix}-client-tls-private-key" : null
  kong_edge_ca_secret_id                = local.create_key_vault_count == 1 ? "${module.key_vault[0].vault_uri}secrets/${local.kong_key_vault_secret_prefix}-edge-ca" : null
  kong_server_tls_certificate_secret_id = local.create_key_vault_count == 1 ? "${module.key_vault[0].vault_uri}secrets/${local.kong_key_vault_secret_prefix}-server-tls-certificate" : null
  kong_server_tls_private_key_secret_id = local.create_key_vault_count == 1 ? "${module.key_vault[0].vault_uri}secrets/${local.kong_key_vault_secret_prefix}-server-tls-private-key" : null

  normalized_app_name = lower(replace(var.app_name, "_", "-"))
  normalized_env      = lower(var.app_env)
  name_prefix         = "${local.normalized_app_name}-${local.normalized_env}"

  resource_group_name = var.resource_group_name != null && trimspace(var.resource_group_name) != "" ? var.resource_group_name : "${local.name_prefix}-rg"

  common_tags = merge(
    {
      app         = var.app_name
      environment = var.app_env
      managed_by  = "Terraform"
      repository  = var.repo_name
    },
    var.tags,
  )
}
