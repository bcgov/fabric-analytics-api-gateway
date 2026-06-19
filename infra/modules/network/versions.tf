terraform {
  required_version = ">= 1.12.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.8.0, < 3.0.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.60.0, < 5.0.0"
    }
  }
}
