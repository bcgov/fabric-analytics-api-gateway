variable "name" {
  description = "APIM instance name"
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

variable "sku_name" {
  description = "APIM SKU name (e.g. StandardV2_1, Developer_1)"
  type        = string
  default     = "StandardV2_1"
}

variable "publisher_name" {
  description = "Publisher display name shown in the developer portal"
  type        = string
}

variable "publisher_email" {
  description = "Publisher contact email"
  type        = string
}

variable "virtual_network_type" {
  description = "VNet integration type: None (public), External (StandardV2 inbound from internet, outbound to VNet), or Internal (private only)"
  type        = string
  default     = "None"

  validation {
    condition     = contains(["None", "External", "Internal"], var.virtual_network_type)
    error_message = "virtual_network_type must be None, External, or Internal."
  }
}

variable "virtual_network_configuration" {
  description = "Required when virtual_network_type is External or Internal — provides the subnet for VNet injection"
  type = object({
    subnet_id = string
  })
  default = null
}

variable "enable_diagnostics" {
  description = "Whether to send APIM diagnostic logs and metrics to Log Analytics"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID (required when enable_diagnostics = true)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
