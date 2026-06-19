output "tenant_product_ids" {
  description = "Map of deployed APIM product IDs keyed by {tenant}-{product}"
  value = {
    for key, product in azurerm_api_management_product.fabric : key => product.id
  }
}

output "graphql_api_paths" {
  description = "Map of deployed GraphQL API paths keyed by API name"
  value = {
    for key, api in azurerm_api_management_api.graphql : key => api.path
  }
}

output "graphql_backend_urls" {
  description = "Map of deployed GraphQL backend URLs keyed by backend name"
  sensitive   = true # Fabric endpoint URLs — redacted (sensitive choice)
  value = {
    for key, backend in azurerm_api_management_backend.graphql : key => backend.url
  }
}

# ---------------------------------------------------------------------------
# Client-facing APIM URLs — what consumers actually call (gateway URL + path).
# Non-sensitive: these are the public APIM front door, not the Fabric backend.
# ---------------------------------------------------------------------------
output "apim_gateway_url" {
  description = "APIM gateway base URL (from the shared stack)"
  value       = data.terraform_remote_state.shared.outputs.apim_gateway_url
}

output "graphql_endpoint_urls" {
  description = "Client-facing APIM URL for each Fabric GraphQL endpoint, keyed by endpoint. Call these through APIM (the Fabric backend stays hidden)."
  value = {
    for key, b in local.graphql_backends :
    key => "${data.terraform_remote_state.shared.outputs.apim_gateway_url}/${b.tenant_key}/${b.product_key}/graphql/${b.endpoint.name}"
  }
}

