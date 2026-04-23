variable "app_env" {
  description = "Application environment name."
  type        = string
  nullable    = false
}

variable "app_name" {
  description = "Application name used for resource naming."
  type        = string
  nullable    = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  nullable    = false
}

variable "container_apps_environment_name" {
  description = "Optional override for the Container Apps environment name."
  type        = string
  default     = null
}

variable "container_apps_subnet_id" {
  description = "Subnet ID for the Container Apps environment."
  type        = string
  default     = null
}

variable "container_cpu" {
  description = "CPU allocation for each container app workload in cores."
  type        = number
  default     = 0.5
  nullable    = false
}

variable "container_memory" {
  description = "Memory allocation for each container app workload."
  type        = string
  default     = "1Gi"
  nullable    = false
}

variable "dab_container_app_name" {
  description = "Optional override for the DAB container app name."
  type        = string
  default     = null
}

variable "dab_database_type" {
  description = "Database type exposed to DAB via the DB_TYPE environment variable. Use dwsql for the Fabric SQL analytics endpoint path in this repo."
  type        = string
  default     = "dwsql"
}

variable "dab_external_ingress_enabled" {
  description = "Whether DAB should expose ingress outside the Container Apps environment."
  type        = bool
  default     = true
  nullable    = false
}

variable "dab_image" {
  description = "Container image for the DAB workload."
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
  description = "Ingress target port for DAB."
  type        = number
  default     = 5000
  nullable    = false
}

variable "deploy_dab_app" {
  description = "Whether to create the DAB container app."
  type        = bool
  default     = false
  nullable    = false
}

variable "deploy_kong_app" {
  description = "Whether to create the Kong Edge Runtime container app."
  type        = bool
  default     = false
  nullable    = false
}

variable "deploy_kong_bootstrap_job" {
  description = "Whether to create the manual ACA job that bootstraps Kong SDX secrets into Key Vault."
  type        = bool
  default     = false
  nullable    = false
}

variable "enable_system_assigned_identity" {
  description = "Whether the container apps should use system-assigned managed identities."
  type        = bool
  default     = true
  nullable    = false
}

variable "kong_container_app_name" {
  description = "Optional override for the Kong container app name."
  type        = string
  default     = null
}

variable "kong_bootstrap_job_identity_client_id" {
  description = "Client ID of the user-assigned identity used by the ACA bootstrap job to authenticate to Azure."
  type        = string
  default     = null
}

variable "kong_bootstrap_job_identity_id" {
  description = "Resource ID of the user-assigned identity used by the ACA bootstrap job to write Key Vault secrets."
  type        = string
  default     = null
}

variable "kong_client_tls_certificate_pem" {
  description = "PEM-encoded SDX edge client certificate mounted into the Kong runtime."
  type        = string
  default     = null
  sensitive   = true
}

variable "kong_client_tls_certificate_secret_id" {
  description = "Versioned or versionless Key Vault secret ID for the SDX edge client certificate."
  type        = string
  default     = null
}

variable "kong_client_tls_private_key_pem" {
  description = "PEM-encoded private key for the SDX edge client certificate."
  type        = string
  default     = null
  sensitive   = true
}

variable "kong_client_tls_private_key_secret_id" {
  description = "Versioned or versionless Key Vault secret ID for the SDX edge client private key."
  type        = string
  default     = null
}

variable "kong_edge_ca_pem" {
  description = "PEM-encoded SDX edge CA bundle used by the runtime for local trust material."
  type        = string
  default     = null
  sensitive   = true
}

variable "kong_edge_ca_secret_id" {
  description = "Versioned or versionless Key Vault secret ID for the SDX edge CA bundle."
  type        = string
  default     = null
}

variable "kong_external_ingress_enabled" {
  description = "Whether Kong should expose ingress outside the Container Apps environment. Leave false for the Application Gateway-backed SDX path because Kong stays private behind the internal ACA environment."
  type        = bool
  default     = false
  nullable    = false
}

variable "kong_image" {
  description = "Container image for the Kong SDX edge runtime. Defaults to the runtime image used by the published sdx-edge Helm chart version 0.1.0."
  type        = string
  default     = "ghcr.io/bcgov/aps-devops/sdx-access-point:3.9-57ca71e3"
}

variable "kong_key_vault_name" {
  description = "Key Vault name used by the ACA bootstrap job when writing Kong bootstrap secrets."
  type        = string
  default     = null
}

variable "kong_key_vault_secret_prefix" {
  description = "Key Vault secret prefix used by the ACA bootstrap job when writing Kong bootstrap material."
  type        = string
  default     = null
}

variable "kong_key_vault_secret_identity_id" {
  description = "User-assigned managed identity resource ID used by the Kong container app to resolve Key Vault secret references."
  type        = string
  default     = null
}

variable "kong_mtls_required" {
  description = "Whether the SDX edge runtime requires mTLS from clients (sets KONG_NGINX_PROXY_SSL_VERIFY_CLIENT=on and verify_depth=3). Matches the sdx-edge Helm chart's mtls_required value."
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

variable "kong_server_tls_certificate_secret_id" {
  description = "Versioned or versionless Key Vault secret ID for the SDX edge server certificate."
  type        = string
  default     = null
}

variable "kong_server_tls_private_key_pem" {
  description = "PEM-encoded private key for the SDX edge server certificate."
  type        = string
  default     = null
  sensitive   = true
}

variable "kong_server_tls_private_key_secret_id" {
  description = "Versioned or versionless Key Vault secret ID for the SDX edge server private key."
  type        = string
  default     = null
}

variable "kong_target_port" {
  description = "Ingress target port for Kong inside ACA. The SDX edge runtime listens on 8000 for internal HTTP and 8443 for direct TLS, while the public :443 edge in this scaffold is owned by Application Gateway rather than ACA external ingress."
  type        = number
  default     = 8000
  nullable    = false
}

variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
  nullable    = false
}

variable "log_analytics_workspace_customer_id" {
  description = "Log Analytics workspace customer ID used to configure environment app logs."
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID for the Container Apps environment."
  type        = string
  default     = null
}

variable "log_analytics_workspace_key" {
  description = "Log Analytics workspace primary shared key used to configure environment app logs."
  type        = string
  default     = null
  sensitive   = true
}

variable "max_replicas" {
  description = "Maximum number of replicas for each workload."
  type        = number
  default     = 10
  nullable    = false
}

variable "min_replicas" {
  description = "Minimum number of replicas for each workload."
  type        = number
  default     = 1
  nullable    = false
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID used for the Container Apps environment private endpoint."
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

variable "resource_group_name" {
  description = "Resource group name for Container Apps resources."
  type        = string
  nullable    = false
}
