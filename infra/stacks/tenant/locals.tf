locals {
  # APIM must be deployed (enabled in the shared stack) before the tenant stack
  # can run. Validate this at plan time rather than failing cryptically later.
  apim_id = data.terraform_remote_state.shared.outputs.apim_id

  # ---------------------------------------------------------------------------
  # Enabled tenants
  # ---------------------------------------------------------------------------
  enabled_tenants = {
    for key, config in var.tenants : key => config
    if try(config.enabled, true)
  }

  # ---------------------------------------------------------------------------
  # Flat map: one entry per (tenant, product)
  # Key: "{tenant_key}-{product_key}"
  # ---------------------------------------------------------------------------
  tenant_products = {
    for pair in flatten([
      for tenant_key, tenant_config in local.enabled_tenants : [
        for product_key, product_config in tenant_config.products : {
          key            = "${tenant_key}-${product_key}"
          tenant_key     = tenant_key
          product_key    = product_key
          product_config = product_config
          tenant_config  = tenant_config
        }
      ]
    ]) : pair.key => pair
  }

  # ---------------------------------------------------------------------------
  # APIs: one per (tenant, product, endpoint_type) where endpoints list is non-empty
  # Key: "{tenant_key}-{product_key}-graphql" or "{tenant_key}-{product_key}-sql"
  # ---------------------------------------------------------------------------
  graphql_apis = {
    for pair_key, pair in local.tenant_products : "${pair_key}-graphql" => pair
    if length(pair.product_config.graphql_endpoints) > 0
  }

  sql_apis = {
    for pair_key, pair in local.tenant_products : "${pair_key}-sql" => pair
    if length(pair.product_config.sql_analytics_endpoints) > 0
  }

  # All APIs combined for operations (same catch-all operation for both types)
  all_apis = merge(local.graphql_apis, local.sql_apis)

  # HTTP methods that receive catch-all operations on each API
  api_methods = ["POST", "GET", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]

  # Flat map: one entry per (api_key, method)
  api_operations = {
    for pair in flatten([
      for api_key in keys(local.all_apis) : [
        for method in local.api_methods : {
          key     = "${api_key}-${lower(method)}"
          api_key = api_key
          method  = method
        }
      ]
    ]) : pair.key => pair
  }

  # ---------------------------------------------------------------------------
  # Backends: one per individual Fabric endpoint
  # Keys: "{tenant}-{product}-graphql-{endpoint-name}" etc.
  # ---------------------------------------------------------------------------
  graphql_backends = {
    for triple in flatten([
      for api_key, pair in local.graphql_apis : [
        for endpoint in pair.product_config.graphql_endpoints : {
          key           = "${pair.tenant_key}-${pair.product_key}-graphql-${endpoint.name}"
          api_key       = api_key
          endpoint      = endpoint
          tenant_key    = pair.tenant_key
          product_key   = pair.product_key
          endpoint_type = "graphql"
        }
      ]
    ]) : triple.key => triple
  }

  sql_backends = {
    for triple in flatten([
      for api_key, pair in local.sql_apis : [
        for endpoint in pair.product_config.sql_analytics_endpoints : {
          key           = "${pair.tenant_key}-${pair.product_key}-sql-${endpoint.name}"
          api_key       = api_key
          endpoint      = endpoint
          tenant_key    = pair.tenant_key
          product_key   = pair.product_key
          endpoint_type = "sql"
        }
      ]
    ]) : triple.key => triple
  }

  # ---------------------------------------------------------------------------
  # APIM API policies — generated from template for each API
  # ---------------------------------------------------------------------------
  graphql_api_policies = {
    for api_key, pair in local.graphql_apis : api_key => templatefile(
      "${path.root}/../../params/apim/templates/fabric-graphql-api-policy.xml.tftpl",
      {
        tenant_name  = pair.tenant_key
        product_name = pair.product_key
        endpoints    = pair.product_config.graphql_endpoints
      }
    )
  }

  sql_api_policies = {
    for api_key, pair in local.sql_apis : api_key => templatefile(
      "${path.root}/../../params/apim/templates/fabric-sql-api-policy.xml.tftpl",
      {
        tenant_name  = pair.tenant_key
        product_name = pair.product_key
        endpoints    = pair.product_config.sql_analytics_endpoints
      }
    )
  }

  all_api_policies = merge(local.graphql_api_policies, local.sql_api_policies)
}
