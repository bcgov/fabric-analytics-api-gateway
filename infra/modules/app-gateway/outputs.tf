output "id" {
  description = "App Gateway resource ID"
  value       = azurerm_application_gateway.this.id
}

output "name" {
  description = "App Gateway resource name"
  value       = azurerm_application_gateway.this.name
}

output "public_ip_address" {
  description = "App Gateway public IP address (null when using private frontend)"
  value       = var.public_ip_resource_id != null ? azurerm_application_gateway.this.frontend_ip_configuration[0].public_ip_address_id : null
}

output "identity_principal_id" {
  description = "Principal ID of the user-assigned identity (null when no Key Vault is attached)"
  value       = local.needs_identity ? azurerm_user_assigned_identity.appgw[0].principal_id : null
}
