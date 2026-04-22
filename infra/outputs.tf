output "application_gateway_id" {
  description = "Application Gateway resource ID when the Application Gateway module is enabled."
  value       = try(module.application_gateway[0].application_gateway_id, null)
}

output "application_gateway_name" {
  description = "Application Gateway resource name when the Application Gateway module is enabled."
  value       = try(module.application_gateway[0].application_gateway_name, null)
}

output "application_gateway_private_dns_zone_name" {
  description = "Private DNS zone name used to resolve the internal ACA environment from the Application Gateway subnet."
  value       = try(module.application_gateway[0].application_gateway_private_dns_zone_name, null)
}

output "application_gateway_public_ip_address" {
  description = "Public IP address bound to the Application Gateway listener when the module is enabled."
  value       = try(module.application_gateway[0].application_gateway_public_ip_address, null)
}

output "application_gateway_subnet_id" {
  description = "Application Gateway subnet ID when provided or exposed by the network scaffold."
  value       = var.application_gateway_subnet_id != null ? var.application_gateway_subnet_id : try(module.network[0].application_gateway_subnet_id, null)
}

output "resource_group_name" {
  description = "Resource group name used by the scaffold."
  value       = local.resource_group_name
}

output "container_apps_subnet_id" {
  description = "Container Apps subnet ID when the network scaffold is enabled."
  value       = var.container_apps_subnet_id != null ? var.container_apps_subnet_id : try(module.network[0].container_apps_subnet_id, null)
}

output "private_endpoint_subnet_id" {
  description = "Private endpoint subnet ID when provided or exposed by the network scaffold."
  value       = var.private_endpoint_subnet_id != null ? var.private_endpoint_subnet_id : try(module.network[0].private_endpoint_subnet_id, null)
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID when monitoring is enabled."
  value       = try(module.monitoring[0].log_analytics_workspace_id, null)
}

output "application_insights_connection_string" {
  description = "Application Insights connection string when monitoring is enabled."
  value       = try(module.monitoring[0].appinsights_connection_string, null)
  sensitive   = true
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key when monitoring is enabled."
  value       = try(module.monitoring[0].appinsights_instrumentation_key, null)
  sensitive   = true
}

output "log_analytics_workspace_customer_id" {
  description = "Log Analytics workspace customer ID when monitoring is enabled."
  value       = try(module.monitoring[0].log_analytics_workspace_workspaceId, null)
}

output "log_analytics_workspace_key" {
  description = "Log Analytics workspace primary shared key when monitoring is enabled."
  value       = try(module.monitoring[0].log_analytics_workspace_key, null)
  sensitive   = true
}

output "container_apps_environment_id" {
  description = "Container Apps environment ID when the environment scaffold is enabled."
  value       = try(module.container_apps[0].container_apps_environment_id, null)
}

output "container_apps_environment_name" {
  description = "Container Apps environment name when the environment scaffold is enabled."
  value       = try(module.container_apps[0].container_apps_environment_name, null)
}

output "container_apps_environment_fqdn" {
  description = "Container Apps environment default domain when the environment scaffold is enabled."
  value       = try(module.container_apps[0].container_apps_environment_fqdn, null)
  sensitive   = true
}

output "container_apps_environment_static_ip" {
  description = "Container Apps environment static IP when the environment scaffold is enabled."
  value       = try(module.container_apps[0].container_apps_environment_static_ip, null)
  sensitive   = true
}

output "dab_latest_fqdn" {
  description = "DAB Container App ingress FQDN when the Container Apps module is enabled."
  value       = try(module.container_apps[0].dab_latest_fqdn, null)
  sensitive   = true
}

output "kong_latest_fqdn" {
  description = "Kong Edge Runtime ingress FQDN when the Container Apps module is enabled."
  value       = try(module.container_apps[0].kong_latest_fqdn, null)
  sensitive   = true
}

output "kong_key_vault_id" {
  description = "Key Vault ID used for Kong bootstrap secrets when the bootstrap flow is enabled."
  value       = try(module.key_vault[0].key_vault_id, null)
}

output "kong_key_vault_name" {
  description = "Key Vault name used for Kong bootstrap secrets when the bootstrap flow is enabled."
  value       = try(module.key_vault[0].key_vault_name, null)
}

output "kong_bootstrap_job_name" {
  description = "Manual Azure Container Apps Job name used to bootstrap Kong SDX secrets into Key Vault."
  value       = try(module.container_apps[0].kong_bootstrap_job_name, null)
}

output "kong_key_vault_bootstrap_identity_id" {
  description = "User-assigned identity resource ID used by the ACA bootstrap job to write Key Vault secrets."
  value       = try(module.key_vault[0].bootstrap_writer_identity_id, null)
}

output "kong_key_vault_secret_prefix" {
  description = "Secret name prefix used for Kong bootstrap material in Key Vault when the bootstrap flow is enabled."
  value       = local.create_key_vault_count == 1 ? local.kong_key_vault_secret_prefix : null
}

output "kong_key_vault_uri" {
  description = "Key Vault URI used for Kong bootstrap secrets when the bootstrap flow is enabled."
  value       = try(module.key_vault[0].vault_uri, null)
}

output "kong_route_host" {
  description = "Configured SDX edge route host when the Container Apps module is enabled."
  value       = try(module.container_apps[0].kong_route_host, null)
}

output "frontdoor_id" {
  description = "Front Door profile ID when the Front Door module is enabled."
  value       = try(module.front_door[0].frontdoor_id, null)
}

output "frontdoor_resource_guid" {
  description = "Front Door profile resource GUID when the Front Door module is enabled."
  value       = try(module.front_door[0].frontdoor_resource_guid, null)
}

output "firewall_policy_id" {
  description = "Front Door firewall policy ID when the Front Door module is enabled."
  value       = try(module.front_door[0].firewall_policy_id, null)
}
