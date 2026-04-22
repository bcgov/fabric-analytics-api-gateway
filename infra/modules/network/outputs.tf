output "application_gateway_subnet_id" {
  description = "Application Gateway subnet ID when the network scaffold is enabled."
  value       = try(azapi_resource.application_gateway_subnet[0].id, null)
}

output "container_apps_subnet_id" {
  description = "Container Apps subnet ID when the network scaffold is enabled."
  value       = try(azapi_resource.container_apps_subnet[0].id, null)
}

output "private_endpoint_subnet_id" {
  description = "Private endpoint subnet ID when the network module manages one."
  value       = try(azapi_resource.privateendpoints_subnet[0].id, null)
}
