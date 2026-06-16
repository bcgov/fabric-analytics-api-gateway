variable "app_env" {
  description = "Deployment environment: dev, test, or prod"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.app_env)
    error_message = "app_env must be one of: dev, test, prod"
  }
}

variable "app_name" {
  description = "Application name used as a naming prefix for all resources"
  type        = string
  default     = "fabric-gateway"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "Canada Central"
}

variable "resource_group_name" {
  description = "Name of the resource group to create for shared infrastructure"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Azure provider authentication
# ---------------------------------------------------------------------------
variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID (the subscription's Entra tenant, used for Terraform OIDC auth)"
  type        = string
}

variable "client_id" {
  description = "Service principal client ID for OIDC authentication (leave empty for interactive auth)"
  type        = string
  default     = ""
}

variable "use_oidc" {
  description = "Whether to use OIDC (workload identity federation) for provider authentication"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Networking — supply an existing subnet ID, or let shared_config.network create
# the App Gateway subnet inside an existing VNet. Either way, this stack never
# creates the VNet itself.
# ---------------------------------------------------------------------------
variable "vnet_name" {
  description = "Name of the existing VNet to carve subnets from. Overrides shared_config.network.vnet_name; set via TF_VAR_vnet_name in CI."
  type        = string
  default     = null
}

variable "vnet_resource_group_name" {
  description = "Resource group of the existing VNet. Overrides shared_config.network.vnet_resource_group_name; set via TF_VAR_vnet_resource_group_name in CI."
  type        = string
  default     = null
}

variable "app_gateway_subnet_id" {
  description = "Resource ID of an existing subnet for App Gateway (a dedicated /27 or larger). Leave null to use the subnet created by the network module via shared_config.network."
  type        = string
  default     = null
}

variable "apim_subnet_id" {
  description = "Resource ID of the subnet for APIM StandardV2 VNet integration (must be a dedicated /27 or larger)"
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# BCGov Entra tenant — used to validate all inbound JWT tokens
# ---------------------------------------------------------------------------
variable "bcgov_entra_tenant_id" {
  description = "BCGov Entra (Azure AD) tenant ID. All inbound bearer tokens must be issued by this tenant."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.bcgov_entra_tenant_id))
    error_message = "bcgov_entra_tenant_id must be a valid UUID."
  }
}

# ---------------------------------------------------------------------------
# Shared infrastructure configuration
# ---------------------------------------------------------------------------
variable "shared_config" {
  description = "Configuration for shared infrastructure components"
  type = object({
    log_analytics = optional(object({
      enabled        = optional(bool, true)
      sku            = optional(string, "PerGB2018")
      retention_days = optional(number, 30)
    }), {})

    app_gateway = optional(object({
      enabled           = optional(bool, false)
      frontend_hostname = optional(string, null)
      waf_mode          = optional(string, "Prevention")
      autoscale = optional(object({
        min_capacity = optional(number, 1)
        max_capacity = optional(number, 3)
      }), { min_capacity = 1, max_capacity = 3 })
      public_ip_resource_id = optional(string, null)
      key_vault_id          = optional(string, null)
      ssl_certificate_name  = optional(string, null)
    }), {})

    apim = optional(object({
      enabled                = optional(bool, true)
      sku_name               = optional(string, "StandardV2_1")
      publisher_name         = optional(string, "BC Gov Digital Services")
      publisher_email        = optional(string, "digital@gov.bc.ca")
      vnet_injection_enabled = optional(bool, false)
    }), {})

    # When enabled with vnet_name + vnet_resource_group_name set, the network
    # module carves the App Gateway subnet out of an existing VNet, and the App
    # Gateway uses that subnet instead of var.app_gateway_subnet_id.
    network = optional(object({
      enabled                  = optional(bool, false)
      vnet_name                = optional(string, null)
      vnet_resource_group_name = optional(string, null)
    }), {})
  })
  default = {}
}
