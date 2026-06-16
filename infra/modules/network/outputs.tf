output "apim_subnet_id" {
  description = "APIM subnet ID when the network scaffold is enabled (null otherwise)."
  value       = try(azapi_resource.apim_subnet[0].id, null)
}

output "application_gateway_subnet_id" {
  description = "Application Gateway subnet ID when the network scaffold is enabled."
  value       = try(azapi_resource.application_gateway_subnet[0].id, null)
}

output "private_endpoint_subnet_id" {
  description = "Private endpoint subnet ID when the network module manages one."
  value       = try(azapi_resource.privateendpoints_subnet[0].id, null)
}
