output "container_apps_environment_fqdn" {
  description = "Default domain of the Container Apps Environment"
  value       = try(azurerm_container_app_environment.main[0].default_domain, null)
  sensitive   = true
}

output "container_apps_environment_id" {
  description = "ID of the Container Apps Environment"
  value       = try(azurerm_container_app_environment.main[0].id, null)
}

output "container_apps_environment_name" {
  description = "Name of the Container Apps Environment"
  value       = try(azurerm_container_app_environment.main[0].name, null)
}

output "container_apps_environment_static_ip" {
  description = "Static IP of the Container Apps Environment"
  value       = try(azurerm_container_app_environment.main[0].static_ip_address, null)
  sensitive   = true
}

output "dab_latest_fqdn" {
  description = "Internal FQDN of the DAB container app"
  value       = try(azurerm_container_app.dab[0].ingress[0].fqdn, null)
  sensitive   = true
}

output "kong_latest_fqdn" {
  description = "Internal FQDN of the Kong container app"
  value       = try(azurerm_container_app.kong[0].ingress[0].fqdn, null)
  sensitive   = true
}

output "kong_route_host" {
  description = "Configured SDX edge route host for the Kong container app"
  value       = local.kong_route_host
}

output "kong_bootstrap_job_name" {
  description = "Manual Azure Container Apps Job name used to bootstrap Kong SDX secrets into Key Vault"
  value       = try(azurerm_container_app_job.kong_bootstrap[0].name, null)
}
