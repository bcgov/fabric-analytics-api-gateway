output "application_gateway_id" {
  description = "Application Gateway resource ID."
  value       = azurerm_application_gateway.main.id
}

output "application_gateway_name" {
  description = "Application Gateway resource name."
  value       = azurerm_application_gateway.main.name
}

output "application_gateway_private_dns_zone_name" {
  description = "Private DNS zone name used to resolve the internal ACA environment from the Application Gateway subnet."
  value       = azurerm_private_dns_zone.container_apps_environment.name
}

output "application_gateway_public_ip_address" {
  description = "Public IP address bound to the Application Gateway frontend listener."
  value       = try(azurerm_public_ip.main[0].ip_address, null)
}

output "application_gateway_public_ip_id" {
  description = "Public IP resource ID used by the Application Gateway frontend listener."
  value       = var.application_gateway_public_ip_resource_id != null ? var.application_gateway_public_ip_resource_id : try(azurerm_public_ip.main[0].id, null)
}

output "application_gateway_principal_id" {
  description = "Principal ID of the optional user-assigned identity used for Key Vault-backed SSL certificates."
  value       = try(azurerm_user_assigned_identity.appgw[0].principal_id, null)
}
