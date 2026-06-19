variable "name" {
  description = "Front Door profile name"
  type        = string
}

variable "endpoint_name" {
  description = "Front Door endpoint name. The public hostname is <endpoint_name>-<hash>.z01.azurefd.net. Azure reuses the same domain label for the same endpoint name in the same resource group, so keeping BOTH the name and the resource group constant makes destroy/recreate hostname-stable. Changing either changes the public hostname. Ref: learn.microsoft.com/azure/frontdoor/endpoint#reuse-of-an-endpoint-domain-name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "sku_name" {
  description = "Front Door SKU. Standard_AzureFrontDoor (no WAF/Private Link) or Premium_AzureFrontDoor."
  type        = string
  default     = "Standard_AzureFrontDoor"

  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.sku_name)
    error_message = "sku_name must be Standard_AzureFrontDoor or Premium_AzureFrontDoor."
  }
}

variable "origin_host" {
  description = "Public hostname of the origin (APIM gateway FQDN, e.g. fabric-gateway-test-apim.azure-api.net). Front Door reaches APIM over its public External-mode gateway."
  type        = string
}

variable "probe_path" {
  description = "Health probe path on the origin. APIM's service status endpoint returns 200 without auth and bypasses the global JWT policy."
  type        = string
  default     = "/status-0123456789abcdef"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# WAF
# ---------------------------------------------------------------------------
variable "waf_enabled" {
  description = "Attach a Front Door WAF policy to the endpoint. Custom rules (rate limit, geo, require-Authorization) apply on both SKUs; Microsoft-managed rule sets (OWASP DRS + Bot) are added only on Premium."
  type        = bool
  default     = true
}

variable "waf_mode" {
  description = "WAF mode. Prevention enforces (blocks); Detection only logs. Custom Block rules take effect only in Prevention."
  type        = string
  default     = "Prevention"

  validation {
    condition     = contains(["Prevention", "Detection"], var.waf_mode)
    error_message = "waf_mode must be Prevention or Detection."
  }
}

variable "waf_allowed_countries" {
  description = "Two-letter country codes allowed through the WAF geo-filter; all others are blocked. Default: Canada only."
  type        = list(string)
  default     = ["CA"]
}

variable "waf_rate_limit_threshold" {
  description = "Max requests per client IP per minute before the WAF rate-limit rule blocks."
  type        = number
  default     = 1000
}
