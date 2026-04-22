variable "app_env" {
  description = "Application environment name."
  type        = string
  nullable    = false
}

variable "app_name" {
  description = "Application name used for resource naming."
  type        = string
  nullable    = false
}

variable "common_tags" {
  description = "Common tags applied to Key Vault resources."
  type        = map(string)
  nullable    = false
}

variable "key_vault_name" {
  description = "Optional override for the Kong bootstrap Key Vault name."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
  nullable    = false
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID used for the Key Vault private endpoint."
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "Resource group name for Key Vault resources."
  type        = string
  nullable    = false
}
