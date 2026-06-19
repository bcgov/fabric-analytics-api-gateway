output "endpoint_hostname" {
  description = "Public Front Door hostname (*.azurefd.net) — call the gateway through this"
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
}

output "front_door_id" {
  description = "Front Door ID (profile resource GUID) — the value APIM matches against the X-Azure-FDID header to accept only this Front Door"
  value       = azurerm_cdn_frontdoor_profile.this.resource_guid
}

output "profile_id" {
  description = "Front Door profile resource ID"
  value       = azurerm_cdn_frontdoor_profile.this.id
}

output "waf_policy_id" {
  description = "Front Door WAF firewall policy ID (null when WAF is disabled)"
  value       = var.waf_enabled ? azurerm_cdn_frontdoor_firewall_policy.this[0].id : null
}

output "waf_managed_rules_enabled" {
  description = "Whether Microsoft-managed WAF rule sets are active (Premium only)"
  value       = var.waf_enabled && local.managed_waf
}
