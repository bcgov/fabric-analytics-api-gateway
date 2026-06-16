data "terraform_remote_state" "shared" {
  # The shared stack must be deployed first (deploy-scaled.sh enforces this).
  # apim_id and apim_name outputs must be non-null (APIM must be enabled there).
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group
    storage_account_name = var.backend_storage_account
    container_name       = var.backend_container_name
    key                  = "${var.app_name}/${var.app_env}/shared.tfstate"
    subscription_id      = var.subscription_id
    tenant_id            = var.tenant_id
    client_id            = var.client_id
    use_oidc             = var.use_oidc
  }
}

# ---------------------------------------------------------------------------
# APIM Products — one per (tenant, product)
# ---------------------------------------------------------------------------
resource "azurerm_api_management_product" "fabric" {
  for_each = local.tenant_products

  product_id            = each.key
  api_management_name   = data.terraform_remote_state.shared.outputs.apim_name
  resource_group_name   = data.terraform_remote_state.shared.outputs.resource_group_name
  display_name          = "${each.value.tenant_config.display_name} — ${each.value.product_config.display_name}"
  description           = each.value.product_config.description
  subscription_required = each.value.product_config.subscription_required
  approval_required     = false
  published             = true

  lifecycle {
    precondition {
      condition     = local.apim_id != null
      error_message = "The shared stack must be applied with APIM enabled before the tenant stack can run (apim_id is null). Set shared_config.apim.enabled = true and apply the shared stack first."
    }
  }
}

# ---------------------------------------------------------------------------
# APIM APIs — one per (tenant, product, endpoint_type)
# ---------------------------------------------------------------------------
resource "azurerm_api_management_api" "graphql" {
  for_each = local.graphql_apis

  name                = each.key
  resource_group_name = data.terraform_remote_state.shared.outputs.resource_group_name
  api_management_name = data.terraform_remote_state.shared.outputs.apim_name
  revision            = "1"
  display_name        = "${each.value.tenant_config.display_name} — ${each.value.product_config.display_name} GraphQL"
  description         = "Fabric GraphQL endpoints for ${each.value.product_config.display_name}"
  # Path pattern: {tenant}/{product}/graphql  → e.g. wlrs/fish-wildlife/graphql
  path                  = "${each.value.tenant_key}/${each.value.product_key}/graphql"
  protocols             = ["https"]
  subscription_required = each.value.product_config.subscription_required
  api_type              = "http"

  depends_on = [azurerm_api_management_product.fabric]
}

resource "azurerm_api_management_api" "sql" {
  for_each = local.sql_apis

  name                = each.key
  resource_group_name = data.terraform_remote_state.shared.outputs.resource_group_name
  api_management_name = data.terraform_remote_state.shared.outputs.apim_name
  revision            = "1"
  display_name        = "${each.value.tenant_config.display_name} — ${each.value.product_config.display_name} SQL Analytics"
  description         = "Fabric SQL Analytics endpoints for ${each.value.product_config.display_name}"
  # Path pattern: {tenant}/{product}/sql  → e.g. wlrs/fish-wildlife/sql
  path                  = "${each.value.tenant_key}/${each.value.product_key}/sql"
  protocols             = ["https"]
  subscription_required = each.value.product_config.subscription_required
  api_type              = "http"

  depends_on = [azurerm_api_management_product.fabric]
}

# ---------------------------------------------------------------------------
# APIM Operations — catch-all for every HTTP method on each API
# ---------------------------------------------------------------------------
resource "azurerm_api_management_api_operation" "fabric" {
  for_each = local.api_operations

  operation_id        = "catchall-${lower(each.value.method)}"
  api_name            = each.value.api_key
  api_management_name = data.terraform_remote_state.shared.outputs.apim_name
  resource_group_name = data.terraform_remote_state.shared.outputs.resource_group_name
  display_name        = "Catch All ${each.value.method}"
  method              = each.value.method
  url_template        = "/*"
  description         = "Route ${each.value.method} requests to the appropriate Fabric endpoint"

  # Wait for APIs to be fully provisioned before adding operations to avoid
  # transient 400 ValidationError from Azure control plane.
  depends_on = [
    azurerm_api_management_api.graphql,
    azurerm_api_management_api.sql,
  ]

  response {
    status_code = 200
  }
}

# ---------------------------------------------------------------------------
# APIM Backends — one per individual Fabric endpoint URL
# ---------------------------------------------------------------------------
resource "azurerm_api_management_backend" "graphql" {
  for_each = local.graphql_backends

  name                = each.key
  resource_group_name = data.terraform_remote_state.shared.outputs.resource_group_name
  api_management_name = data.terraform_remote_state.shared.outputs.apim_name
  protocol            = "http"
  url                 = each.value.endpoint.backend_url
  description         = each.value.endpoint.description != "" ? each.value.endpoint.description : "Fabric GraphQL backend: ${each.value.endpoint.name}"

  circuit_breaker_rule {
    name                       = "fabric-graphql-breaker"
    trip_duration              = "PT1M"
    accept_retry_after_enabled = true

    failure_condition {
      count             = 3
      interval_duration = "PT1M"

      status_code_range {
        min = 500
        max = 599
      }
    }
  }
}

resource "azurerm_api_management_backend" "sql" {
  for_each = local.sql_backends

  name                = each.key
  resource_group_name = data.terraform_remote_state.shared.outputs.resource_group_name
  api_management_name = data.terraform_remote_state.shared.outputs.apim_name
  protocol            = "http"
  url                 = each.value.endpoint.backend_url
  description         = each.value.endpoint.description != "" ? each.value.endpoint.description : "Fabric SQL Analytics backend: ${each.value.endpoint.name}"

  circuit_breaker_rule {
    name                       = "fabric-sql-breaker"
    trip_duration              = "PT1M"
    accept_retry_after_enabled = true

    failure_condition {
      count             = 3
      interval_duration = "PT1M"

      status_code_range {
        min = 500
        max = 599
      }
    }
  }
}

# ---------------------------------------------------------------------------
# APIM API Policies — JWT validation (global) + endpoint routing (per-API)
# The global policy (set in shared stack) validates the BCGov Entra issuer.
# These per-API policies handle routing to the correct Fabric endpoint.
# ---------------------------------------------------------------------------
resource "azurerm_api_management_api_policy" "fabric" {
  for_each = local.all_api_policies

  api_name            = each.key
  api_management_name = data.terraform_remote_state.shared.outputs.apim_name
  resource_group_name = data.terraform_remote_state.shared.outputs.resource_group_name
  xml_content         = each.value

  # Policy XML references backends by name — Terraform can't infer that from
  # XML strings, so explicit depends_on is required.
  depends_on = [
    azurerm_api_management_backend.graphql,
    azurerm_api_management_backend.sql,
    azurerm_api_management_api_operation.fabric,
  ]
}

# ---------------------------------------------------------------------------
# Product ↔ API associations
# ---------------------------------------------------------------------------
resource "azurerm_api_management_product_api" "graphql" {
  for_each = local.graphql_apis

  api_name            = each.key
  product_id          = "${each.value.tenant_key}-${each.value.product_key}"
  api_management_name = data.terraform_remote_state.shared.outputs.apim_name
  resource_group_name = data.terraform_remote_state.shared.outputs.resource_group_name

  depends_on = [
    azurerm_api_management_product.fabric,
    azurerm_api_management_api.graphql,
  ]
}

resource "azurerm_api_management_product_api" "sql" {
  for_each = local.sql_apis

  api_name            = each.key
  product_id          = "${each.value.tenant_key}-${each.value.product_key}"
  api_management_name = data.terraform_remote_state.shared.outputs.apim_name
  resource_group_name = data.terraform_remote_state.shared.outputs.resource_group_name

  depends_on = [
    azurerm_api_management_product.fabric,
    azurerm_api_management_api.sql,
  ]
}

# ---------------------------------------------------------------------------
# Defender for APIs — registers each API with Defender for Cloud
# Skipped when APIM ID is null (APIM disabled in shared stack).
# Uses plan-time-known keys from local.graphql_apis / local.sql_apis.
# ---------------------------------------------------------------------------
resource "azapi_resource" "defender_graphql" {
  for_each = local.apim_id != null ? local.graphql_apis : {}

  type      = "Microsoft.Security/apiCollections@2023-11-15"
  name      = each.key
  parent_id = local.apim_id
  body      = {}

  depends_on = [azurerm_api_management_api.graphql]
}

resource "azapi_resource" "defender_sql" {
  for_each = local.apim_id != null ? local.sql_apis : {}

  type      = "Microsoft.Security/apiCollections@2023-11-15"
  name      = each.key
  parent_id = local.apim_id
  body      = {}

  depends_on = [azurerm_api_management_api.sql]
}
