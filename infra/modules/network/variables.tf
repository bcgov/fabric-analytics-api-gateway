variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  nullable    = false
}

variable "application_gateway_subnet_name" {
  description = "Name of the subnet to create for Azure Application Gateway."
  type        = string
  default     = "appgateway-subnet"
}

variable "container_apps_subnet_name" {
  description = "Name of the subnet to create for Azure Container Apps environment."
  type        = string
  default     = "aca-subnet"
}

variable "enabled" {
  description = "Enable network module to create subnets in an existing VNet."
  type        = bool
  default     = false
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Canada Central"
  nullable    = false
}

variable "private_endpoint_subnet_name" {
  description = "Name of the subnet for private endpoints"
  type        = string
  default     = "privateendpoints-subnet"
  nullable    = false
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  nullable    = false
}

variable "vnet_name" {
  description = "Name of the existing virtual network"
  type        = string
  nullable    = false
}

variable "vnet_resource_group_name" {
  description = "Name of the resource group containing the existing virtual network"
  type        = string
  nullable    = false
}
