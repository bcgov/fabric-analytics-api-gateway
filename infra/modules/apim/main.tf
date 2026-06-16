# API Management instance
# Uses native azurerm_api_management for full lifecycle control.
# StandardV2 supports VNet injection (External or Internal mode).
resource "azurerm_api_management" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name
  tags                = var.tags

  virtual_network_type = var.virtual_network_type

  dynamic "virtual_network_configuration" {
    for_each = var.virtual_network_configuration != null ? [var.virtual_network_configuration] : []
    content {
      subnet_id = virtual_network_configuration.value.subnet_id
    }
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Diagnostic settings — sends gateway logs and metrics to Log Analytics.
# A separate null_resource trigger forces recreation when the destination type
# changes, working around an Azure API bug where in-place updates silently fail.
resource "azurerm_monitor_diagnostic_setting" "apim" {
  count = var.enable_diagnostics ? 1 : 0

  name                           = "${var.name}-diag"
  target_resource_id             = azurerm_api_management.this.id
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
