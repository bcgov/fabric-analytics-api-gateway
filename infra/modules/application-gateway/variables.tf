variable "application_gateway_frontend_certificate_password" {
  description = "Password for the base64-encoded PFX certificate bound to the Application Gateway HTTPS listener."
  type        = string
  default     = null
  sensitive   = true
}

variable "application_gateway_frontend_certificate_pfx_base64" {
  description = "Base64-encoded PFX certificate presented by the Application Gateway HTTPS listener."
  type        = string
  default     = null
  sensitive   = true
}

variable "application_gateway_host_name" {
  description = "Optional host name to bind on the HTTPS listener. When null, the listener accepts requests for any host name."
  type        = string
  default     = null
}

variable "application_gateway_max_capacity" {
  description = "Maximum autoscale capacity for the Application Gateway v2 deployment."
  type        = number
  default     = 2
}

variable "application_gateway_min_capacity" {
  description = "Minimum autoscale capacity for the Application Gateway v2 deployment."
  type        = number
  default     = 1
}

variable "application_gateway_name" {
  description = "Override for the Application Gateway resource name."
  type        = string
  default     = null
}

variable "application_gateway_public_ip_name" {
  description = "Override for the Application Gateway public IP resource name."
  type        = string
  default     = null
}

variable "application_gateway_public_ip_resource_id" {
  description = "Optional resource ID of an existing Public IP to associate with the Application Gateway frontend. When null, this module creates a Standard static Public IP."
  type        = string
  default     = null

  validation {
    condition     = var.application_gateway_public_ip_resource_id == null || can(regex("^/subscriptions/", var.application_gateway_public_ip_resource_id))
    error_message = "application_gateway_public_ip_resource_id must be a valid Azure resource ID (starting with /subscriptions/) or null."
  }
}

variable "application_gateway_sku_name" {
  description = "Application Gateway v2 SKU name. Use Standard_v2 or WAF_v2."
  type        = string
  default     = "WAF_v2"

  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.application_gateway_sku_name)
    error_message = "application_gateway_sku_name must be Standard_v2 or WAF_v2."
  }
}

variable "application_gateway_subnet_id" {
  description = "Subnet ID for the dedicated Application Gateway subnet."
  type        = string
  nullable    = false
}

variable "application_gateway_zones" {
  description = "Availability zones for the Application Gateway deployment."
  type        = set(string)
  default     = ["1", "2", "3"]
}

variable "app_name" {
  description = "Logical application name used for naming Application Gateway resources."
  type        = string
  nullable    = false
}

variable "backend_fqdn" {
  description = "Container App ingress FQDN used as the Application Gateway backend target."
  type        = string
  nullable    = false
}

variable "common_tags" {
  description = "Common tags to apply to Application Gateway resources."
  type        = map(string)
  nullable    = false
}

variable "container_apps_environment_fqdn" {
  description = "Container Apps environment default domain used to build the private DNS zone for the internal ACA environment."
  type        = string
  nullable    = false
}

variable "container_apps_environment_static_ip" {
  description = "Static IP address of the internal Container Apps environment."
  type        = string
  nullable    = false
}

variable "key_vault_id" {
  description = "Optional Key Vault resource ID used when SSL certificates are referenced via key_vault_secret_id."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region for Application Gateway resources."
  type        = string
  nullable    = false
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace to receive Application Gateway diagnostics. When null, diagnostics are skipped."
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "Resource group name that owns the Application Gateway resources."
  type        = string
  nullable    = false
}

variable "rewrite_rule_sets" {
  description = "Optional rewrite rule sets for header and URL manipulation. When null, the module emits the default Kong client-certificate forwarding rewrites."
  type = map(object({
    name = string
    rewrite_rules = optional(map(object({
      name          = string
      rule_sequence = number
      conditions = optional(map(object({
        ignore_case = optional(bool)
        negate      = optional(bool)
        pattern     = string
        variable    = string
      })))
      request_header_configurations = optional(map(object({
        header_name  = string
        header_value = string
      })))
      response_header_configurations = optional(map(object({
        header_name  = string
        header_value = string
      })))
      url = optional(object({
        components   = optional(string)
        path         = optional(string)
        query_string = optional(string)
        reroute      = optional(bool)
      }))
    })))
  }))
  default = null
}

variable "ssl_certificate_name" {
  description = "Optional name of an SSL certificate already present on the Application Gateway. When set, the module binds the listener to that cert instead of creating one."
  type        = string
  default     = null
}

variable "ssl_certificates" {
  description = "Optional SSL certificates to create on the Application Gateway, either from Key Vault secret IDs or direct PFX data and password."
  type = map(object({
    name                = string
    key_vault_secret_id = optional(string)
    data                = optional(string)
    password            = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for cert_name, cert in var.ssl_certificates :
      (
        cert.key_vault_secret_id != null && cert.key_vault_secret_id != "" &&
        (cert.data == null || cert.data == "") &&
        (cert.password == null || cert.password == "")
        ) || (
        cert.data != null && cert.data != "" &&
        cert.password != null && cert.password != "" &&
        (cert.key_vault_secret_id == null || cert.key_vault_secret_id == "")
      )
    ])
    error_message = "Each ssl_certificates entry must use exactly one mode: key_vault_secret_id, or data plus password."
  }
}

variable "vnet_name" {
  description = "Existing virtual network name that hosts the internal Container Apps environment and Application Gateway subnet."
  type        = string
  nullable    = false
}

variable "vnet_resource_group_name" {
  description = "Resource group containing the existing virtual network."
  type        = string
  nullable    = false
}

variable "waf_enabled" {
  description = "Whether to enable inline WAF configuration when no external WAF policy ID is supplied."
  type        = bool
  default     = true
}

variable "waf_mode" {
  description = "Inline WAF mode when no external WAF policy ID is supplied."
  type        = string
  default     = "Prevention"

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "waf_mode must be Detection or Prevention."
  }
}

variable "waf_policy_id" {
  description = "Optional resource ID of an external WAF policy to associate with the Application Gateway."
  type        = string
  default     = null
}
