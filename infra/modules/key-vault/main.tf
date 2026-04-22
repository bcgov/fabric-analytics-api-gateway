data "azurerm_client_config" "current" {}

resource "terraform_data" "key_vault_preconditions" {
  lifecycle {
    precondition {
      condition     = var.private_endpoint_subnet_id != null && trimspace(var.private_endpoint_subnet_id) != ""
      error_message = "private_endpoint_subnet_id must be set when the key-vault module is enabled so the vault can stay private within the landing-zone network."
    }
  }
}

resource "azurerm_key_vault" "main" {
  name                          = local.key_vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  public_network_access_enabled = false
  purge_protection_enabled      = true
  rbac_authorization_enabled    = true
  soft_delete_retention_days    = 90

  tags = merge(var.common_tags, {
    Component = "Key Vault"
    Purpose   = "Stores Kong SDX bootstrap secrets"
  })

  lifecycle {
    ignore_changes = [tags]
  }

  depends_on = [terraform_data.key_vault_preconditions]
}

resource "azurerm_user_assigned_identity" "kong_secret_reader" {
  name                = local.kong_secret_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.common_tags, {
    Component = "Managed Identity"
    Purpose   = "Reads Kong SDX bootstrap secrets from Key Vault"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_user_assigned_identity" "bootstrap_writer" {
  name                = local.bootstrap_writer_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(var.common_tags, {
    Component = "Managed Identity"
    Purpose   = "Writes Kong SDX bootstrap secrets to Key Vault from the ACA bootstrap job"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_role_assignment" "kong_secret_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.kong_secret_reader.principal_id
}

resource "azurerm_role_assignment" "bootstrap_writer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.bootstrap_writer.principal_id
}

resource "azurerm_private_endpoint" "key_vault" {
  count               = local.create_private_endpoint_count
  name                = local.key_vault_private_endpoint_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${local.key_vault_private_endpoint_name}-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  tags = var.common_tags

  lifecycle {
    ignore_changes = [
      private_dns_zone_group,
      tags,
    ]
  }

  depends_on = [azurerm_key_vault.main]
}

resource "null_resource" "wait_for_key_vault_private_dns_zone" {
  count = local.create_private_endpoint_count

  triggers = {
    resource_group_name   = var.resource_group_name
    private_endpoint_id   = azurerm_private_endpoint.key_vault[0].id
    private_endpoint_name = azurerm_private_endpoint.key_vault[0].name
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail

      if [[ -f "./scripts/wait-for-dns-zone.sh" ]]; then
        SCRIPT_PATH="./scripts/wait-for-dns-zone.sh"
      elif [[ -f "./infra/scripts/wait-for-dns-zone.sh" ]]; then
        SCRIPT_PATH="./infra/scripts/wait-for-dns-zone.sh"
      else
        echo "wait-for-dns-zone.sh not found. Expected ./scripts/wait-for-dns-zone.sh (from infra/) or ./infra/scripts/wait-for-dns-zone.sh (from repo root)." >&2
        exit 2
      fi

      bash "$SCRIPT_PATH" \
        --resource-group "${var.resource_group_name}" \
        --private-endpoint-name "${azurerm_private_endpoint.key_vault[0].name}" \
        --timeout "10m" \
        --interval "10s"
    EOT
  }

  depends_on = [azurerm_private_endpoint.key_vault]
}
