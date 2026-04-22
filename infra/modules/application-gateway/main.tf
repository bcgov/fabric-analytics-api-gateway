data "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

resource "azurerm_user_assigned_identity" "appgw" {
  count = local.needs_identity ? 1 : 0

  name                = "${local.application_gateway_name}-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_role_assignment" "appgw_to_keyvault" {
  count = local.needs_identity && var.key_vault_id != null && trimspace(var.key_vault_id) != "" ? 1 : 0

  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.appgw[0].principal_id
}

resource "terraform_data" "application_gateway_preconditions" {
  lifecycle {
    precondition {
      condition     = trimspace(var.application_gateway_subnet_id) != ""
      error_message = "application_gateway_subnet_id must be provided to the Application Gateway module."
    }
    precondition {
      condition     = local.ssl_cert_name != null
      error_message = "One frontend certificate source must be provided: application_gateway_frontend_certificate_pfx_base64 with password, ssl_certificates, or ssl_certificate_name."
    }
    precondition {
      condition     = !((var.application_gateway_frontend_certificate_pfx_base64 != null && trimspace(var.application_gateway_frontend_certificate_pfx_base64) != "") && (var.application_gateway_frontend_certificate_password == null || trimspace(var.application_gateway_frontend_certificate_password) == ""))
      error_message = "application_gateway_frontend_certificate_password must be provided when application_gateway_frontend_certificate_pfx_base64 is set."
    }
    precondition {
      condition     = !((var.application_gateway_frontend_certificate_password != null && trimspace(var.application_gateway_frontend_certificate_password) != "") && (var.application_gateway_frontend_certificate_pfx_base64 == null || trimspace(var.application_gateway_frontend_certificate_pfx_base64) == ""))
      error_message = "application_gateway_frontend_certificate_pfx_base64 must be provided when application_gateway_frontend_certificate_password is set."
    }
    precondition {
      condition     = !local.needs_identity || (var.key_vault_id != null && trimspace(var.key_vault_id) != "")
      error_message = "key_vault_id must be provided when ssl_certificates use key_vault_secret_id values."
    }
    precondition {
      condition     = trimspace(var.backend_fqdn) != ""
      error_message = "backend_fqdn must be provided so Application Gateway can route to the Kong Container App."
    }
    precondition {
      condition     = trimspace(var.container_apps_environment_fqdn) != ""
      error_message = "container_apps_environment_fqdn must be provided so the module can create the private DNS zone used by Application Gateway."
    }
    precondition {
      condition     = trimspace(var.container_apps_environment_static_ip) != ""
      error_message = "container_apps_environment_static_ip must be provided so the module can create private DNS A records for the internal ACA environment."
    }
  }
}

resource "azurerm_private_dns_zone" "container_apps_environment" {
  name                = var.container_apps_environment_fqdn
  resource_group_name = var.resource_group_name

  tags = var.common_tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "container_apps_environment" {
  name                  = local.private_dns_zone_link_name
  private_dns_zone_name = azurerm_private_dns_zone.container_apps_environment.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = data.azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = var.common_tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_private_dns_a_record" "container_apps_environment_root" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.container_apps_environment.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.container_apps_environment_static_ip]
  tags                = var.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_private_dns_a_record" "container_apps_environment_wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.container_apps_environment.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.container_apps_environment_static_ip]
  tags                = var.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_public_ip" "main" {
  count               = local.create_public_ip_count
  name                = local.public_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.common_tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_application_gateway" "main" {
  depends_on = [
    azurerm_private_dns_a_record.container_apps_environment_root,
    azurerm_private_dns_a_record.container_apps_environment_wildcard,
    azurerm_role_assignment.appgw_to_keyvault,
    terraform_data.application_gateway_preconditions,
  ]

  name                = local.application_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  http2_enabled       = true
  zones               = var.application_gateway_zones
  firewall_policy_id  = var.waf_policy_id

  sku {
    name = var.application_gateway_sku_name
    tier = var.application_gateway_sku_name
  }

  autoscale_configuration {
    min_capacity = var.application_gateway_min_capacity
    max_capacity = var.application_gateway_max_capacity
  }

  gateway_ip_configuration {
    name      = local.gateway_ip_configuration_name
    subnet_id = var.application_gateway_subnet_id
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = var.application_gateway_public_ip_resource_id != null ? var.application_gateway_public_ip_resource_id : azurerm_public_ip.main[0].id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 443
  }

  dynamic "ssl_certificate" {
    for_each = local.configured_ssl_certificates
    content {
      name                = ssl_certificate.value.name
      key_vault_secret_id = lookup(ssl_certificate.value, "key_vault_secret_id", null)
      data                = lookup(ssl_certificate.value, "data", null)
      password            = lookup(ssl_certificate.value, "password", null)
    }
  }

  ssl_policy {
    policy_type = local.ssl_policy.policy_type
    policy_name = local.ssl_policy.policy_name
  }

  ssl_profile {
    name = local.ssl_profile_name
  }

  dynamic "identity" {
    for_each = local.needs_identity ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.appgw[0].id]
    }
  }

  backend_address_pool {
    name  = local.backend_address_pool_name
    fqdns = [var.backend_fqdn]
  }

  probe {
    name                                      = local.probe_name
    protocol                                  = "Https"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-499"]
    }
  }

  backend_http_settings {
    name                                = local.backend_http_settings_name
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    pick_host_name_from_backend_address = true
    probe_name                          = local.probe_name
    request_timeout                     = 30
  }

  http_listener {
    name                           = local.http_listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    host_name                      = var.application_gateway_host_name
    protocol                       = "Https"
    ssl_certificate_name           = local.ssl_cert_name
    ssl_profile_name               = local.ssl_profile_name
  }

  dynamic "rewrite_rule_set" {
    for_each = local.rewrite_rule_sets
    content {
      name = rewrite_rule_set.value.name

      dynamic "rewrite_rule" {
        for_each = lookup(rewrite_rule_set.value, "rewrite_rules", {}) != null ? rewrite_rule_set.value.rewrite_rules : {}
        content {
          name          = rewrite_rule.value.name
          rule_sequence = rewrite_rule.value.rule_sequence

          dynamic "condition" {
            for_each = lookup(rewrite_rule.value, "conditions", {}) != null ? rewrite_rule.value.conditions : {}
            content {
              variable    = condition.value.variable
              pattern     = condition.value.pattern
              ignore_case = lookup(condition.value, "ignore_case", false)
              negate      = lookup(condition.value, "negate", false)
            }
          }

          dynamic "request_header_configuration" {
            for_each = lookup(rewrite_rule.value, "request_header_configurations", {}) != null ? rewrite_rule.value.request_header_configurations : {}
            content {
              header_name  = request_header_configuration.value.header_name
              header_value = request_header_configuration.value.header_value
            }
          }

          dynamic "response_header_configuration" {
            for_each = lookup(rewrite_rule.value, "response_header_configurations", {}) != null ? rewrite_rule.value.response_header_configurations : {}
            content {
              header_name  = response_header_configuration.value.header_name
              header_value = response_header_configuration.value.header_value
            }
          }

          dynamic "url" {
            for_each = lookup(rewrite_rule.value, "url", null) != null ? [rewrite_rule.value.url] : []
            content {
              components   = lookup(url.value, "components", null)
              path         = lookup(url.value, "path", null)
              query_string = lookup(url.value, "query_string", null)
              reroute      = lookup(url.value, "reroute", null)
            }
          }
        }
      }
    }
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = local.http_listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.backend_http_settings_name
    rewrite_rule_set_name      = local.default_rewrite_rule_set_name
  }

  dynamic "waf_configuration" {
    for_each = local.enable_waf_configuration_count == 1 ? [1] : []
    content {
      enabled                  = true
      firewall_mode            = var.waf_mode
      rule_set_type            = "OWASP"
      rule_set_version         = "3.2"
      file_upload_limit_mb     = 100
      max_request_body_size_kb = 128
      request_body_check       = true
    }
  }

  tags = var.common_tags
  lifecycle {
    ignore_changes = [
      ssl_certificate,
      tags,
      tags["managed-by"],
    ]
  }
}

resource "azapi_update_resource" "mtls_passthrough" {
  type        = "Microsoft.Network/applicationGateways@2025-03-01"
  resource_id = azurerm_application_gateway.main.id

  body = {
    properties = {
      sslProfiles = [
        {
          name = local.ssl_profile_name
          properties = {
            clientAuthConfiguration = {
              verifyClientAuthMode     = "Passthrough"
              verifyClientCertIssuerDN = false
              verifyClientRevocation   = "None"
            }
          }
        }
      ]
    }
  }

  depends_on = [azurerm_application_gateway.main]
}

resource "azurerm_monitor_diagnostic_setting" "main" {
  count                          = local.create_diagnostics_count
  name                           = "${local.application_gateway_name}-diagnostics"
  target_resource_id             = azurerm_application_gateway.main.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  dynamic "enabled_log" {
    for_each = local.enable_waf_configuration_count == 1 ? [1] : []
    content {
      category = "ApplicationGatewayFirewallLog"
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }

  lifecycle {
    replace_triggered_by = [null_resource.diag_destination_type_trigger[0]]
  }
}

resource "null_resource" "diag_destination_type_trigger" {
  count = local.create_diagnostics_count

  triggers = {
    destination_type = "Dedicated"
  }
}
