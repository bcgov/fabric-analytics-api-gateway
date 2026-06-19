resource "azurerm_web_application_firewall_policy" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled                     = true
    mode                        = var.mode
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  dynamic "managed_rules" {
    for_each = [1]
    content {
      dynamic "managed_rule_set" {
        for_each = var.managed_rule_sets
        content {
          type    = managed_rule_set.value.type
          version = managed_rule_set.value.version
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [tags]
  }
}
