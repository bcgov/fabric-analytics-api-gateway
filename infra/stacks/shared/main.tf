resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

# ---------------------------------------------------------------------------
# Network — optional. Carves the App Gateway subnet out of an existing VNet when
# shared_config.network is enabled. Disabled by default; supply an existing
# app_gateway_subnet_id instead. This stack never creates the VNet itself.
# ---------------------------------------------------------------------------
module "network" {
  source = "../../modules/network"
  count  = local.network_count

  enabled                  = true
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  common_tags              = var.common_tags
  vnet_name                = local.vnet_name
  vnet_resource_group_name = local.vnet_resource_group_name
}

# ---------------------------------------------------------------------------
# Log Analytics
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "this" {
  count = local.log_analytics_config.enabled ? 1 : 0

  name                = "${local.name_prefix}-law"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = local.log_analytics_config.sku
  retention_in_days   = local.log_analytics_config.retention_days
  tags                = var.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

# ---------------------------------------------------------------------------
# WAF Policy
# ---------------------------------------------------------------------------
module "waf_policy" {
  source = "../../modules/waf-policy"
  count  = local.app_gateway_config.enabled ? 1 : 0

  name                = "${local.name_prefix}-waf"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  mode                = local.app_gateway_config.waf_mode
  tags                = var.common_tags
}

# ---------------------------------------------------------------------------
# App Gateway
# ---------------------------------------------------------------------------
module "app_gateway" {
  source = "../../modules/app-gateway"
  count  = local.app_gateway_config.enabled && local.apim_config.enabled ? 1 : 0

  # App Gateway needs APIM deployed first so the backend FQDN is available
  depends_on = [module.apim]

  name                  = "${local.name_prefix}-appgw"
  resource_group_name   = azurerm_resource_group.this.name
  location              = azurerm_resource_group.this.location
  subnet_id             = local.app_gateway_subnet_id
  waf_policy_id         = module.waf_policy[0].id
  frontend_hostname     = local.app_gateway_config.frontend_hostname
  public_ip_resource_id = local.app_gateway_config.public_ip_resource_id
  key_vault_id          = local.app_gateway_config.key_vault_id
  ssl_certificate_name  = local.app_gateway_config.ssl_certificate_name

  autoscale = local.app_gateway_config.autoscale

  backend_apim = {
    fqdn       = local.apim_gateway_fqdn
    probe_path = "/status-0123456789abcdef"
  }

  enable_diagnostics         = local.log_analytics_config.enabled
  log_analytics_workspace_id = local.log_analytics_config.enabled ? azurerm_log_analytics_workspace.this[0].id : null

  tags = var.common_tags
}

# ---------------------------------------------------------------------------
# APIM (StandardV2)
# ---------------------------------------------------------------------------
module "apim" {
  source = "../../modules/apim"
  count  = local.apim_config.enabled ? 1 : 0

  name                = "${local.name_prefix}-apim"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku_name            = local.apim_config.sku_name
  publisher_name      = local.apim_config.publisher_name
  publisher_email     = local.apim_config.publisher_email

  virtual_network_type = local.apim_config.vnet_injection_enabled && local.apim_subnet_id != null ? "External" : "None"
  virtual_network_configuration = local.apim_config.vnet_injection_enabled && local.apim_subnet_id != null ? {
    subnet_id = local.apim_subnet_id
  } : null

  enable_diagnostics         = local.log_analytics_config.enabled
  log_analytics_workspace_id = local.log_analytics_config.enabled ? azurerm_log_analytics_workspace.this[0].id : null

  tags = var.common_tags
}

# ---------------------------------------------------------------------------
# BCGov Entra tenant ID Named Value — referenced in global JWT validation policy
# ---------------------------------------------------------------------------
resource "azurerm_api_management_named_value" "bcgov_entra_tenant_id" {
  count = local.apim_config.enabled ? 1 : 0

  name                = "bcgov-entra-tenant-id"
  resource_group_name = azurerm_resource_group.this.name
  api_management_name = module.apim[0].name
  # display_name is the key the policy references via {{bcgov-entra-tenant-id}};
  # APIM resolves {{...}} against display_name, not name, so they must match.
  display_name = "bcgov-entra-tenant-id"
  value        = var.bcgov_entra_tenant_id
  secret       = false
}

# ---------------------------------------------------------------------------
# APIM Global Policy — validates all inbound tokens against BCGov Entra
# ---------------------------------------------------------------------------
resource "azurerm_api_management_policy" "global" {
  count = local.apim_config.enabled ? 1 : 0

  api_management_id = module.apim[0].id
  xml_content       = file("${path.root}/../../params/apim/global_policy.xml")

  depends_on = [azurerm_api_management_named_value.bcgov_entra_tenant_id]
}
