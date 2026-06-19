output "id" {
  description = "WAF policy resource ID"
  value       = azurerm_web_application_firewall_policy.this.id
}

output "name" {
  description = "WAF policy resource name"
  value       = azurerm_web_application_firewall_policy.this.name
}
