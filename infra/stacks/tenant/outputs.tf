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

output "sql_api_paths" {
  description = "Map of deployed SQL Analytics API paths keyed by API name"
  value = {
    for key, api in azurerm_api_management_api.sql : key => api.path
  }
}

output "graphql_backend_urls" {
  description = "Map of deployed GraphQL backend URLs keyed by backend name"
  value = {
    for key, backend in azurerm_api_management_backend.graphql : key => backend.url
  }
}

output "sql_backend_urls" {
  description = "Map of deployed SQL Analytics backend URLs keyed by backend name"
  value = {
    for key, backend in azurerm_api_management_backend.sql : key => backend.url
  }
}
