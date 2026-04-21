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
