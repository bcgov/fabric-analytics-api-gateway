locals {
  name_prefix = "${var.app_name}-${var.app_env}"

  apim_config          = var.shared_config.apim
  app_gateway_config   = var.shared_config.app_gateway
  log_analytics_config = var.shared_config.log_analytics
  network_config       = var.shared_config.network

  # VNet identifiers — top-level vars (injected via TF_VAR_* in CI) take
  # precedence over shared_config.network so secrets never have to be committed.
  vnet_name                = var.vnet_name != null ? var.vnet_name : local.network_config.vnet_name
  vnet_resource_group_name = var.vnet_resource_group_name != null ? var.vnet_resource_group_name : local.network_config.vnet_resource_group_name

  # Create subnets in an existing VNet only when the network block is enabled
  # and both VNet identifiers are supplied. Computed here (not inline in count)
  # so plan never fails on an unknown-until-apply boolean.
  network_count = local.network_config.enabled && local.vnet_name != null && local.vnet_resource_group_name != null ? 1 : 0

  # Subnet IDs: prefer module-created subnets when the network module is enabled,
  # otherwise fall back to the explicitly supplied existing subnet IDs.
  app_gateway_subnet_id = local.network_count > 0 ? module.network[0].application_gateway_subnet_id : var.app_gateway_subnet_id
  apim_subnet_id        = local.network_count > 0 ? module.network[0].apim_subnet_id : var.apim_subnet_id

  # App Gateway backend: points to APIM gateway hostname once APIM is provisioned.
  # The FQDN is resolved via the VNet-linked private DNS zone.
  apim_gateway_fqdn = local.apim_config.enabled ? replace(module.apim[0].gateway_url, "https://", "") : ""
}
