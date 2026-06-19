# Application Gateway — WAF_v2 with SSL termination and APIM backend
# Uses native azurerm_application_gateway (not AVM) so lifecycle.ignore_changes
# can suppress SSL certificate drift from portal uploads.

# ---------------------------------------------------------------------------
# User-Assigned MI for Key Vault SSL certificate access
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "appgw" {
  count = local.needs_identity ? 1 : 0

  name                = "${var.name}-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "appgw_to_keyvault" {
  count = var.key_vault_id != null && local.needs_identity ? 1 : 0

  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.appgw[0].principal_id
}

# ---------------------------------------------------------------------------
# Application Gateway
# ---------------------------------------------------------------------------
resource "azurerm_application_gateway" "this" {
  depends_on = [azurerm_role_assignment.appgw_to_keyvault]

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  zones               = var.zones
  tags                = var.tags
  firewall_policy_id  = var.waf_policy_id

  sku {
    name     = var.sku.name
    tier     = var.sku.tier
    capacity = var.autoscale == null ? var.sku.capacity : null
  }

  dynamic "autoscale_configuration" {
    for_each = var.autoscale != null ? [var.autoscale] : []
    content {
      min_capacity = autoscale_configuration.value.min_capacity
      max_capacity = autoscale_configuration.value.max_capacity
    }
  }

  gateway_ip_configuration {
    name      = "${var.name}-gwip"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                          = local.frontend_ip_config_name
    public_ip_address_id          = var.public_ip_resource_id
    subnet_id                     = var.public_ip_resource_id == null ? var.subnet_id : null
    private_ip_address_allocation = var.public_ip_resource_id == null ? "Dynamic" : null
  }

  frontend_port {
    name = local.frontend_port_https_name
    port = 443
  }

  frontend_port {
    name = local.frontend_port_http_name
    port = 80
  }

  backend_address_pool {
    name  = local.backend_pool_name
    fqdns = [var.backend_apim.fqdn]
  }

  backend_http_settings {
    name                                = local.http_setting_name
    port                                = var.backend_apim.https_port
    protocol                            = "Https"
    cookie_based_affinity               = "Disabled"
    request_timeout                     = 240
    pick_host_name_from_backend_address = true
    probe_name                          = local.probe_name
  }

  probe {
    name                                      = local.probe_name
    protocol                                  = "Https"
    path                                      = var.backend_apim.probe_path
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
    }
  }

  dynamic "ssl_certificate" {
    for_each = var.ssl_certificates
    content {
      name                = ssl_certificate.value.name
      key_vault_secret_id = lookup(ssl_certificate.value, "key_vault_secret_id", null)
      data                = lookup(ssl_certificate.value, "data", null)
      password            = lookup(ssl_certificate.value, "password", null)
    }
  }

  # TLS policy required by BC Gov Landing Zone policy
  ssl_policy {
    policy_type = local.ssl_policy.policy_type
    policy_name = local.ssl_policy.policy_name
  }

  dynamic "identity" {
    for_each = local.needs_identity ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.appgw[0].id]
    }
  }

  # HTTPS listener — created only when an SSL certificate is configured
  dynamic "http_listener" {
    for_each = local.ssl_cert_name != null ? [1] : []
    content {
      name                           = local.listener_https_name
      frontend_ip_configuration_name = local.frontend_ip_config_name
      frontend_port_name             = local.frontend_port_https_name
      protocol                       = "Https"
      host_name                      = var.frontend_hostname
      ssl_certificate_name           = local.ssl_cert_name
    }
  }

  http_listener {
    name                           = local.listener_http_name
    frontend_ip_configuration_name = local.frontend_ip_config_name
    frontend_port_name             = local.frontend_port_http_name
    protocol                       = "Http"
    host_name                      = var.frontend_hostname
  }

  dynamic "redirect_configuration" {
    for_each = local.ssl_cert_name != null ? [1] : []
    content {
      name                 = local.redirect_config_name
      redirect_type        = "Permanent"
      target_listener_name = local.listener_https_name
      include_path         = true
      include_query_string = true
    }
  }

  dynamic "request_routing_rule" {
    for_each = local.ssl_cert_name != null ? [1] : []
    content {
      name                       = local.routing_rule_https_name
      rule_type                  = "Basic"
      http_listener_name         = local.listener_https_name
      backend_address_pool_name  = local.backend_pool_name
      backend_http_settings_name = local.http_setting_name
      priority                   = 100
    }
  }

  request_routing_rule {
    name               = local.routing_rule_http_name
    rule_type          = "Basic"
    http_listener_name = local.listener_http_name
    priority           = 200

    redirect_configuration_name = local.ssl_cert_name != null ? local.redirect_config_name : null
    backend_address_pool_name   = local.ssl_cert_name == null ? local.backend_pool_name : null
    backend_http_settings_name  = local.ssl_cert_name == null ? local.http_setting_name : null
  }

  dynamic "waf_configuration" {
    for_each = var.waf_enabled && var.waf_policy_id == null ? [1] : []
    content {
      enabled          = true
      firewall_mode    = var.waf_mode
      rule_set_type    = "OWASP"
      rule_set_version = "3.2"
    }
  }

  lifecycle {
    ignore_changes = [
      ssl_certificate,
      tags,
    ]
  }
}

# ---------------------------------------------------------------------------
# Diagnostic settings
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "appgw" {
  count = var.enable_diagnostics ? 1 : 0

  name                           = "${var.name}-diag"
  target_resource_id             = azurerm_application_gateway.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }

  lifecycle {
    replace_triggered_by = [null_resource.diag_trigger[0]]
  }
}

resource "null_resource" "diag_trigger" {
  count = var.enable_diagnostics ? 1 : 0

  triggers = {
    destination_type = "Dedicated"
  }
}
