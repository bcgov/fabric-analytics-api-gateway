output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Resource group ID"
  value       = azurerm_resource_group.this.id
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.this.location
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID (null when disabled)"
  value       = local.log_analytics_config.enabled ? azurerm_log_analytics_workspace.this[0].id : null
}

output "apim_id" {
  description = "APIM resource ID"
  value       = local.apim_config.enabled ? module.apim[0].id : null
}

output "apim_name" {
  description = "APIM resource name"
  value       = local.apim_config.enabled ? module.apim[0].name : null
}

output "apim_gateway_url" {
  description = "APIM gateway URL"
  value       = local.apim_config.enabled ? module.apim[0].gateway_url : null
}

output "apim_principal_id" {
  description = "APIM system-assigned managed identity principal ID"
  value       = local.apim_config.enabled ? module.apim[0].principal_id : null
}

output "app_gateway_id" {
  description = "App Gateway resource ID (null when disabled)"
  value       = local.app_gateway_config.enabled && local.apim_config.enabled ? module.app_gateway[0].id : null
}

output "app_gateway_public_ip" {
  description = "App Gateway public IP address (null when using private frontend)"
  value       = local.app_gateway_config.enabled && local.apim_config.enabled ? module.app_gateway[0].public_ip_address : null
}

# ---------------------------------------------------------------------------
# Network module outputs — null when shared_config.network is disabled
# ---------------------------------------------------------------------------
output "apim_subnet_id" {
  description = "APIM subnet ID — module-created when shared_config.network is enabled, else null"
  value       = local.network_count > 0 ? module.network[0].apim_subnet_id : null
}

output "app_gateway_subnet_id" {
  description = "App Gateway subnet ID — module-created when shared_config.network is enabled, else null"
  value       = local.network_count > 0 ? module.network[0].application_gateway_subnet_id : null
}

output "private_endpoint_subnet_id" {
  description = "Private endpoint subnet ID — module-created when shared_config.network is enabled, else null"
  value       = local.network_count > 0 ? module.network[0].private_endpoint_subnet_id : null
}
