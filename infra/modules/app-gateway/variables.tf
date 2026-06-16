variable "name" {
  description = "Application Gateway name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "subnet_id" {
  description = "Dedicated subnet for the Application Gateway (must be /27 or larger)"
  type        = string
}

variable "sku" {
  description = "SKU configuration"
  type = object({
    name     = optional(string, "WAF_v2")
    tier     = optional(string, "WAF_v2")
    capacity = optional(number, 2)
  })
  default = {}
}

variable "autoscale" {
  description = "Autoscale configuration — when set, overrides sku.capacity"
  type = object({
    min_capacity = optional(number, 1)
    max_capacity = optional(number, 3)
  })
  default = null
}

variable "waf_policy_id" {
  description = "Resource ID of an external WAF policy to associate"
  type        = string
  default     = null
}

variable "waf_enabled" {
  description = "Enable WAF inline configuration (used only when waf_policy_id is null)"
  type        = bool
  default     = true
}

variable "waf_mode" {
  description = "WAF mode: Detection or Prevention (used only when waf_policy_id is null)"
  type        = string
  default     = "Prevention"
}

variable "frontend_hostname" {
  description = "Hostname for the HTTPS/HTTP listener"
  type        = string
  default     = null
}

variable "public_ip_resource_id" {
  description = "Resource ID of a pre-created public IP. When null, App Gateway uses a private frontend."
  type        = string
  default     = null

  validation {
    condition     = var.public_ip_resource_id == null || can(regex("^/subscriptions/", var.public_ip_resource_id))
    error_message = "public_ip_resource_id must be a valid Azure resource ID or null."
  }
}

variable "ssl_certificates" {
  description = "SSL certificates from Key Vault (key_vault_secret_id) or direct PFX (data+password)"
  type = map(object({
    name                = string
    key_vault_secret_id = optional(string)
    data                = optional(string)
    password            = optional(string)
  }))
  default = {}
}

variable "ssl_certificate_name" {
  description = "Name of an SSL certificate already present on the gateway (uploaded via portal/CLI). Enables HTTPS listener and HTTP→HTTPS redirect."
  type        = string
  default     = null
}

variable "key_vault_id" {
  description = "Key Vault resource ID — required when ssl_certificates references Key Vault secrets"
  type        = string
  default     = null
}

variable "backend_apim" {
  description = "APIM backend the App Gateway proxies to"
  type = object({
    fqdn       = string
    http_port  = optional(number, 80)
    https_port = optional(number, 443)
    probe_path = optional(string, "/status-0123456789abcdef")
  })
}

variable "enable_diagnostics" {
  description = "Send App Gateway logs and metrics to Log Analytics"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID"
  type        = string
  default     = null
}

variable "zones" {
  description = "Availability zones for the App Gateway"
  type        = set(string)
  default     = ["1", "2", "3"]
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
