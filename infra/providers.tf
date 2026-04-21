provider "azurerm" {
  features {}

  subscription_id = var.subscription_id != null && trimspace(var.subscription_id) != "" ? var.subscription_id : null
  tenant_id       = var.tenant_id != null && trimspace(var.tenant_id) != "" ? var.tenant_id : null
  client_id       = var.client_id != null && trimspace(var.client_id) != "" ? var.client_id : null
  use_oidc        = var.use_oidc
}
