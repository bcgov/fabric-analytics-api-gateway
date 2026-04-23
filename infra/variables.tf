variable "app_env" {
  description = "Deployment environment name."
  type        = string
  default     = "test"

  validation {
    condition     = contains(["dev", "test", "tools", "prod"], lower(var.app_env))
    error_message = "app_env must be one of: dev, test, tools, prod."
  }
}

variable "app_name" {
  description = "Logical application name used for resource naming."
  type        = string
  default     = "fabric-analytics"
}

variable "application_gateway_frontend_certificate_password" {
  description = "Password for the base64-encoded PFX certificate bound to the Application Gateway HTTPS listener."
  type        = string
  default     = null
  sensitive   = true
}

variable "application_gateway_frontend_certificate_pfx_base64" {
  description = "Base64-encoded PFX certificate presented by the Application Gateway HTTPS listener."
  type        = string
  default     = null
  sensitive   = true
}

variable "application_gateway_host_name" {
  description = "Optional public host name bound to the Application Gateway HTTPS listener. Defaults to kong_route_host when omitted."
  type        = string
  default     = null
}

variable "application_gateway_max_capacity" {
  description = "Maximum autoscale capacity for the Application Gateway v2 deployment."
  type        = number
  default     = 2
}

variable "application_gateway_min_capacity" {
  description = "Minimum autoscale capacity for the Application Gateway v2 deployment."
  type        = number
  default     = 1
}

variable "application_gateway_name" {
  description = "Override for the Application Gateway resource name."
  type        = string
  default     = null
}

variable "application_gateway_public_ip_name" {
  description = "Override for the Application Gateway public IP resource name."
  type        = string
  default     = null
}

variable "application_gateway_sku_name" {
  description = "Application Gateway v2 SKU name. Use Standard_v2 or WAF_v2."
  type        = string
  default     = "WAF_v2"

  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.application_gateway_sku_name)
    error_message = "application_gateway_sku_name must be Standard_v2 or WAF_v2."
  }
}

variable "application_gateway_subnet_id" {
  description = "Existing dedicated Application Gateway subnet ID when it is managed outside the network module."
  type        = string
  default     = null
}

variable "client_id" {
  description = "Azure client ID for GitHub Actions OIDC or other non-interactive auth."
  type        = string
  default     = null
  sensitive   = true
}

variable "container_apps_environment_name" {
  description = "Override for the Container Apps environment name."
  type        = string
  default     = null
}

variable "container_apps_subnet_id" {
  description = "Existing Container Apps subnet ID when the network module is not the source of truth."
  type        = string
  default     = null
}

variable "container_cpu" {
  description = "CPU allocation for each Kong or DAB container app in cores."
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Memory allocation for each Kong or DAB container app."
  type        = string
  default     = "1Gi"
}

variable "create_resource_group" {
  description = "Create the resource group in this stack instead of expecting it to exist already."
  type        = bool
  default     = false
}

variable "dab_container_app_name" {
  description = "Override for the DAB Container App name."
  type        = string
  default     = null
}

variable "dab_database_type" {
  description = "Database type exposed to DAB via the DB_TYPE environment variable. Use dwsql for the Fabric SQL analytics endpoint path in this repo."
  type        = string
  default     = "dwsql"
}

variable "dab_external_ingress_enabled" {
  description = "Whether the DAB Container App should expose external ingress."
  type        = bool
  default     = true
}

variable "dab_image" {
  description = "Container image for the DAB deployment."
  type        = string
  default     = null
}

variable "dab_sql_connection_string" {
  description = "Fabric SQL connection string exposed to DAB through the SQL_CONN_STRING ACA secret-backed environment variable."
  type        = string
  default     = null
  sensitive   = true
}

variable "dab_target_port" {
  description = "Ingress target port for the DAB Container App."
  type        = number
  default     = 5000
}

variable "deploy_dab_app" {
  description = "Create the DAB Container App placeholder resource when true."
  type        = bool
  default     = false
}

variable "deploy_kong_app" {
  description = "Create the Kong SDX edge runtime Container App when true."
  type        = bool
  default     = false
}

variable "deploy_kong_bootstrap_job" {
  description = "Create the manual ACA bootstrap job when true. This can be enabled independently after the Key Vault and Container Apps environment exist."
  type        = bool
  default     = false
}

variable "enable_application_gateway" {
  description = "Enable Azure Application Gateway in front of the internal Container Apps environment for the Kong SDX edge runtime."
  type        = bool
  default     = false
}

variable "enable_container_apps" {
  description = "Enable Azure Container Apps environment scaffolding."
  type        = bool
  default     = false
}

variable "enable_front_door" {
  description = "Enable legacy Azure Front Door scaffolding for non-SDX experiments. This must remain false when kong_mtls_required is true."
  type        = bool
  default     = false
}

variable "enable_key_vault" {
  description = "Enable the Kong bootstrap Key Vault module so it can be applied independently from the ACA bootstrap job."
  type        = bool
  default     = false
}

variable "enable_kong_key_vault_bootstrap" {
  description = "Legacy convenience toggle that enables both the Kong bootstrap Key Vault module and the ACA bootstrap job together. Prefer enable_key_vault and deploy_kong_bootstrap_job for step-by-step applies."
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable Log Analytics and Application Insights scaffolding."
  type        = bool
  default     = false
}

variable "enable_network" {
  description = "Enable subnet scaffolding inside an existing spoke VNet."
  type        = bool
  default     = false
}

variable "enable_system_assigned_identity" {
  description = "Whether Kong and DAB container apps should use system-assigned managed identities."
  type        = bool
  default     = true
}

variable "existing_vnet_name" {
  description = "Existing landing-zone VNet name for subnet integration."
  type        = string
  default     = null
}

variable "existing_vnet_resource_group_name" {
  description = "Resource group containing the existing landing-zone VNet."
  type        = string
  default     = null
}

variable "front_door_custom_domain" {
  description = "Reserved placeholder for a future Front Door custom domain."
  type        = string
  default     = null
}

variable "front_door_endpoint_name" {
  description = "Override for the Azure Front Door endpoint name."
  type        = string
  default     = null
}

variable "front_door_rate_limit_duration_in_minutes" {
  description = "Front Door WAF rate-limit window in minutes."
  type        = number
  default     = 1
}

variable "front_door_rate_limit_threshold" {
  description = "Front Door WAF request threshold for rate limiting per source IP within the rate-limit window."
  type        = number
  default     = 1000
}

variable "front_door_origin_certificate_name_check_enabled" {
  description = "Whether Front Door verifies the origin TLS certificate hostname. Keep true for any non-IP origin."
  type        = bool
  default     = true
}

variable "front_door_origin_host_header" {
  description = "Optional host header override for the Front Door origin."
  type        = string
  default     = null
}

variable "front_door_origin_host_name" {
  description = "Origin hostname for Front Door, typically the Kong ingress hostname."
  type        = string
  default     = null
}

variable "front_door_profile_name" {
  description = "Override for the Azure Front Door profile name."
  type        = string
  default     = null
}

variable "front_door_sku" {
  description = "Front Door SKU. Premium_AzureFrontDoor is required to use Private Link to internal Container Apps origins (https://learn.microsoft.com/en-us/azure/frontdoor/private-link)."
  type        = string
  default     = "Premium_AzureFrontDoor"

  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.front_door_sku)
    error_message = "front_door_sku must be Standard_AzureFrontDoor or Premium_AzureFrontDoor."
  }
}

variable "kong_container_app_name" {
  description = "Override for the Kong Container App name."
  type        = string
  default     = null
}

variable "kong_client_tls_certificate_pem" {
  description = "PEM-encoded SDX edge client certificate mounted into the Kong runtime."
  type        = string
  default     = null
  sensitive   = true
}

variable "kong_client_tls_private_key_pem" {
  description = "PEM-encoded private key for the SDX edge client certificate."
  type        = string
  default     = null
  sensitive   = true
}

variable "kong_edge_ca_pem" {
  description = "PEM-encoded SDX edge CA bundle used by the runtime for local trust material."
  type        = string
  default     = null
  sensitive   = true
}

variable "kong_external_ingress_enabled" {
  description = "Whether the Kong Container App should expose external ingress. Leave false for the Application Gateway-backed SDX path because Kong stays private behind the internal ACA environment."
  type        = bool
  default     = false
}

variable "kong_image" {
  description = "Container image for the Kong SDX edge runtime. Defaults to the runtime image used by the published sdx-edge Helm chart version 0.1.0."
  type        = string
  default     = "ghcr.io/bcgov/aps-devops/sdx-access-point:3.9-57ca71e3"
}

variable "kong_key_vault_name" {
  description = "Optional override for the Key Vault that stores Kong bootstrap secrets."
  type        = string
  default     = null
}

variable "kong_key_vault_secret_prefix" {
  description = "Optional override for the Key Vault secret prefix used for Kong bootstrap material. Defaults to sdx-edge-<runtime-group> when the runtime group name is set."
  type        = string
  default     = null
}

variable "kong_mtls_required" {
  description = "Whether the SDX edge runtime requires mTLS from clients. Maps to the sdx-edge Helm chart's mtls_required value."
  type        = bool
  default     = true
  nullable    = false
}

variable "kong_nginx_proxy_include_config" {
  description = "Rendered nginx include content mounted for the SDX edge runtime. Defaults include a larger proxy header buffer for forwarded client certificates. Replace the placeholder session secret before real deployments."
  type        = string
  default     = <<-EOT
  large_client_header_buffers      8 24k;
  set $session_storage             shm;
  set $session_secret              replace-me-session-secret;
  EOT
  sensitive   = true
}

variable "kong_public_ca_pem" {
  description = "PEM-encoded public CA bundle trusted by the SDX edge runtime."
  type        = string
  default     = null
  sensitive   = true
}

variable "kong_route_host" {
  description = "Route host presented by the SDX edge runtime. Defaults to <kong_runtime_group_name>.servers.sdx when omitted."
  type        = string
  default     = null
}

variable "kong_runtime_group_name" {
  description = "APS runtime group name used for the SDX edge deployment. APS requires 3 to 8 lowercase alphanumeric characters."
  type        = string
  default     = null

  validation {
    condition     = var.kong_runtime_group_name == null || length(regexall("^[a-z0-9]{3,8}$", var.kong_runtime_group_name)) > 0
    error_message = "kong_runtime_group_name must be 3 to 8 lowercase alphanumeric characters when provided."
  }
}

variable "kong_sdx_control_url" {
  description = "SDX control plane URL used by the edge runtime data plane."
  type        = string
  default     = null
}

variable "kong_server_tls_certificate_pem" {
  description = "PEM-encoded server certificate mounted into the SDX edge runtime."
  type        = string
  default     = null
  sensitive   = true
}

variable "kong_server_tls_private_key_pem" {
  description = "PEM-encoded private key for the SDX edge server certificate."
  type        = string
  default     = null
  sensitive   = true
}

variable "kong_target_port" {
  description = "Ingress target port for the Kong Container App inside ACA. The SDX edge runtime listens on 8000 for internal HTTP and 8443 for direct TLS, while the public :443 edge in this scaffold is owned by Application Gateway rather than ACA external ingress."
  type        = number
  default     = 8000
}

variable "location" {
  description = "Azure region for resources."
  type        = string
  default     = "Canada Central"
}

variable "log_analytics_retention_days" {
  description = "Retention period for Log Analytics data in days."
  type        = number
  default     = 30
}

variable "log_analytics_sku" {
  description = "SKU for the Log Analytics workspace."
  type        = string
  default     = "PerGB2018"
}

variable "max_replicas" {
  description = "Maximum number of replicas for each Kong or DAB container app."
  type        = number
  default     = 10
}

variable "min_replicas" {
  description = "Minimum number of replicas for each Kong or DAB container app."
  type        = number
  default     = 1
}

variable "private_endpoint_subnet_id" {
  description = "Existing private endpoint subnet ID when it is managed outside the network module."
  type        = string
  default     = null
}

variable "repo_name" {
  description = "Repository name used for tags and defaults."
  type        = string
  default     = "fabric-analytics-api-gateway"
}

variable "resource_group_name" {
  description = "Existing or to-be-created resource group name."
  type        = string
  default     = null
}

variable "sdx_bootstrap_token" {
  description = "One-time APS bootstrap token used to request the Kong edge certificate during the ACA bootstrap flow."
  type        = string
  default     = null
  sensitive   = true
}

variable "sdx_client_ca_url" {
  description = "SDX client CA URL used by the ACA bootstrap job to sign the edge certificate."
  type        = string
  default     = null
}

variable "sdx_server_ip_san" {
  description = "Optional IP SAN added to the ACA bootstrap certificate request."
  type        = string
  default     = null
}

variable "subscription_id" {
  description = "Azure subscription ID used by OIDC or local auth flows."
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "Additional tags applied to supported Azure resources."
  type        = map(string)
  default     = {}
}

variable "tenant_id" {
  description = "Azure tenant ID used by OIDC or local auth flows."
  type        = string
  default     = null
  sensitive   = true
}

variable "use_oidc" {
  description = "Whether Terraform should attempt OIDC auth when credentials are present."
  type        = bool
  default     = true
}
