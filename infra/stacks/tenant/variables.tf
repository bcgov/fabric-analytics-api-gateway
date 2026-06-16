variable "app_env" {
  description = "Deployment environment: dev, test, or prod"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.app_env)
    error_message = "app_env must be one of: dev, test, prod"
  }
}

variable "app_name" {
  description = "Application name, must match the value used in the shared stack"
  type        = string
  default     = "fabric-gateway"
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
  description = "Service principal client ID for OIDC authentication"
  type        = string
  default     = ""
}

variable "use_oidc" {
  description = "Whether to use OIDC for provider authentication"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Remote state — reads APIM name and resource group from the shared stack.
# Values are supplied via TF_VAR_backend_* by deploy-terraform.sh (never committed).
# ---------------------------------------------------------------------------
variable "backend_resource_group" {
  description = "Resource group containing the Terraform state storage account"
  type        = string
}

variable "backend_storage_account" {
  description = "Storage account name for Terraform state"
  type        = string
}

variable "backend_container_name" {
  description = "Blob container name for Terraform state"
  type        = string
  default     = "tfstate"
}

# ---------------------------------------------------------------------------
# Tenant configurations
# ---------------------------------------------------------------------------
variable "tenants" {
  description = <<-EOT
    Map of tenant configurations. Each tenant key becomes the URL prefix segment
    (e.g. "wlrs" → paths starting with /wlrs/...).

    Each tenant has a map of products. Each product has graphql_endpoints and/or
    sql_analytics_endpoints. Each endpoint carries a name (URL segment) and a
    backend_url pointing to the Fabric REST API endpoint.

    URL routing:
      GET/POST /{tenant}/{product}/graphql/{endpoint-name}  → Fabric GraphQL endpoint
      GET/POST /{tenant}/{product}/sql/{endpoint-name}      → Fabric SQL Analytics endpoint

    APIM validates that the inbound Authorization Bearer token is issued by the
    BCGov Entra tenant, then forwards it unchanged to Fabric. Fabric performs
    its own authorization check.
  EOT
  type = map(object({
    tenant_name  = string
    display_name = string
    enabled      = optional(bool, true)
    products = optional(map(object({
      display_name          = string
      description           = optional(string, "")
      subscription_required = optional(bool, false)
      graphql_endpoints = optional(list(object({
        name        = string
        backend_url = string
        description = optional(string, "")
      })), [])
      sql_analytics_endpoints = optional(list(object({
        name        = string
        backend_url = string
        description = optional(string, "")
      })), [])
    })), {})
  }))
  default = {}
}
