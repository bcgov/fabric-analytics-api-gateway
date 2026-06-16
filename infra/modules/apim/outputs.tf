output "id" {
  description = "APIM resource ID"
  value       = azurerm_api_management.this.id
}

output "name" {
  description = "APIM resource name"
  value       = azurerm_api_management.this.name
}

output "gateway_url" {
  description = "APIM gateway URL (e.g. https://my-apim.azure-api.net)"
  value       = azurerm_api_management.this.gateway_url
}

output "management_api_url" {
  description = "APIM management API URL"
  value       = azurerm_api_management.this.management_api_url
}

output "principal_id" {
  description = "System-assigned managed identity principal ID"
  value       = azurerm_api_management.this.identity[0].principal_id
}
