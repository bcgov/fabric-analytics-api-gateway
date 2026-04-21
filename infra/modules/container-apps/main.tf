# =============================================================================
# Azure Container Apps Module - Kong Edge Runtime and DAB
# =============================================================================
# This module creates the Container Apps environment plus optional Kong and DAB
# container apps for the gateway data-plane scaffold.

# -----------------------------------------------------------------------------
# Container Apps Environment with Consumption Workload Profile
# -----------------------------------------------------------------------------
# Fail loudly when the module is invoked without the inputs that
# `local.create_environment_count` silently relies on, instead of producing
# a no-op plan that confuses callers who set `enable_container_apps=true`.
resource "terraform_data" "container_apps_preconditions" {
  lifecycle {
    precondition {
      condition     = var.container_apps_subnet_id != null && trimspace(var.container_apps_subnet_id) != ""
      error_message = "container_apps_subnet_id must be set (enable the network module or pass an existing subnet id) when the container-apps module is enabled."
    }
    precondition {
      condition     = var.log_analytics_workspace_id != null && trimspace(var.log_analytics_workspace_id) != ""
      error_message = "log_analytics_workspace_id must be set (enable the monitoring module) when the container-apps module is enabled."
    }
    precondition {
      condition     = !var.deploy_kong_app || (var.kong_runtime_group_name != null && trimspace(var.kong_runtime_group_name) != "")
      error_message = "kong_runtime_group_name must be set when deploy_kong_app is true. The APS SDX runtime group docs require a short runtime-group identifier."
    }
    precondition {
      condition     = !var.deploy_kong_app || length(regexall("^[a-z0-9]{3,8}$", coalesce(var.kong_runtime_group_name, ""))) > 0
      error_message = "kong_runtime_group_name must be 3 to 8 lowercase alphanumeric characters when deploy_kong_app is true."
    }
    precondition {
      condition     = !var.deploy_kong_app || (var.kong_sdx_control_url != null && trimspace(var.kong_sdx_control_url) != "")
      error_message = "kong_sdx_control_url must be set when deploy_kong_app is true."
    }
    precondition {
      condition     = !var.deploy_kong_app || (var.kong_public_ca_pem != null && trimspace(var.kong_public_ca_pem) != "")
      error_message = "kong_public_ca_pem must be set when deploy_kong_app is true."
    }
    precondition {
      condition     = !var.deploy_kong_app || (var.kong_edge_ca_pem != null && trimspace(var.kong_edge_ca_pem) != "")
      error_message = "kong_edge_ca_pem must be set when deploy_kong_app is true."
    }
    precondition {
      condition     = !var.deploy_kong_app || (var.kong_client_tls_certificate_pem != null && trimspace(var.kong_client_tls_certificate_pem) != "")
      error_message = "kong_client_tls_certificate_pem must be set when deploy_kong_app is true."
    }
    precondition {
      condition     = !var.deploy_kong_app || (var.kong_client_tls_private_key_pem != null && trimspace(var.kong_client_tls_private_key_pem) != "")
      error_message = "kong_client_tls_private_key_pem must be set when deploy_kong_app is true."
    }
    precondition {
      condition     = !var.deploy_kong_app || (var.kong_server_tls_certificate_pem != null && trimspace(var.kong_server_tls_certificate_pem) != "")
      error_message = "kong_server_tls_certificate_pem must be set when deploy_kong_app is true."
    }
    precondition {
      condition     = !var.deploy_kong_app || (var.kong_server_tls_private_key_pem != null && trimspace(var.kong_server_tls_private_key_pem) != "")
      error_message = "kong_server_tls_private_key_pem must be set when deploy_kong_app is true."
    }
  }
}

resource "azurerm_container_app_environment" "main" {
  count                              = local.create_environment_count
  name                               = local.container_apps_environment_name
  location                           = var.location
  resource_group_name                = var.resource_group_name
  log_analytics_workspace_id         = var.log_analytics_workspace_id
  infrastructure_subnet_id           = var.container_apps_subnet_id
  public_network_access              = "Disabled"                      # Disable public access to the environment
  infrastructure_resource_group_name = "ME-${var.resource_group_name}" # changing this will force , delete and recreate the managed environment
  internal_load_balancer_enabled     = true                            # Enable internal load balancer for private access
  # Consumption workload profile (serverless)
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = merge(var.common_tags, {
    Component = "Container Apps Environment"
    Purpose   = "Managed environment for Kong and DAB container apps"
    Workload  = "Consumption"
  })

  lifecycle {
    ignore_changes = [tags]
  }
  logs_destination = "log-analytics"
}
# -----------------------------------------------------------------------------
# Fix Log Analytics Configuration
# -----------------------------------------------------------------------------
# The azurerm_container_app_environment resource doesn't properly set the
# Log Analytics shared key. Use azapi to patch the configuration.
resource "azapi_update_resource" "container_app_env_logs" {
  count       = local.configure_log_analytics_count
  type        = "Microsoft.App/managedEnvironments@2024-03-01"
  resource_id = azurerm_container_app_environment.main[0].id

  body = {
    properties = {
      appLogsConfiguration = {
        destination = "log-analytics"
        logAnalyticsConfiguration = {
          customerId = var.log_analytics_workspace_customer_id
          sharedKey  = var.log_analytics_workspace_key
        }
      }
    }
  }

  depends_on = [azurerm_container_app_environment.main]
}


# Private Endpoint for Container Apps Environment
# Note: DNS zone association will be automatically managed by Azure Policy
resource "azurerm_private_endpoint" "containerapps" {
  count               = local.create_private_endpoint_count
  name                = "${var.app_name}-containerapps-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.app_name}-containerapps-psc"
    private_connection_resource_id = azurerm_container_app_environment.main[0].id
    subresource_names              = ["managedEnvironments"]
    is_manual_connection           = false
  }

  tags = var.common_tags

  # Lifecycle block to ignore DNS zone group changes managed by Azure Policy
  lifecycle {
    ignore_changes = [
      private_dns_zone_group,
      tags
    ]
  }
}
# Wait for Private Endpoint DNS zone association to complete

resource "null_resource" "wait_for_containerapps_private_dns_zone" {
  count = local.create_private_endpoint_count

  triggers = {
    resource_group_name   = var.resource_group_name
    private_endpoint_id   = azurerm_private_endpoint.containerapps[0].id
    private_endpoint_name = azurerm_private_endpoint.containerapps[0].name
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail

      # Terraform may be run from repo root OR from infra/. Support both.
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
        --private-endpoint-name "${azurerm_private_endpoint.containerapps[0].name}" \
        --timeout "10m" \
        --interval "10s"
    EOT
  }

  depends_on = [azurerm_private_endpoint.containerapps]
}

# -----------------------------------------------------------------------------
# Kong SDX Edge Runtime Container App
# The published sdx-edge Helm chart wraps this runtime image plus Kubernetes-only
# bootstrap and renewal jobs. The ACA scaffold below maps the runtime container,
# mounted cert/config files, and control-plane wiring, while leaving cert
# bootstrap and rotation as an operator concern outside this module.
# -----------------------------------------------------------------------------
resource "azurerm_container_app" "kong" {
  count                        = local.deploy_kong_count
  name                         = local.kong_container_app_name
  container_app_environment_id = azurerm_container_app_environment.main[0].id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type = var.enable_system_assigned_identity ? "SystemAssigned" : "None"
  }

  secret {
    name  = "kong-client-tls-certificate"
    value = var.kong_client_tls_certificate_pem
  }

  secret {
    name  = "kong-client-tls-private-key"
    value = var.kong_client_tls_private_key_pem
  }

  secret {
    name  = "kong-edge-ca-pem"
    value = var.kong_edge_ca_pem
  }

  secret {
    name  = "kong-nginx-proxy-include-config"
    value = var.kong_nginx_proxy_include_config
  }

  secret {
    name  = "kong-public-ca-pem"
    value = var.kong_public_ca_pem
  }

  secret {
    name  = "kong-server-tls-certificate"
    value = var.kong_server_tls_certificate_pem
  }

  secret {
    name  = "kong-server-tls-private-key"
    value = var.kong_server_tls_private_key_pem
  }

  template {
    max_replicas                     = var.max_replicas
    min_replicas                     = var.min_replicas
    termination_grace_period_seconds = 30

    init_container {
      name    = "write-sdx-runtime-files"
      image   = var.kong_image
      cpu     = 0.25
      memory  = "0.5Gi"
      command = ["/bin/sh"]
      args = ["-c", <<-EOT
        set -eu

        mkdir -p /work/sdx-edge-client-cert
        mkdir -p /work/sdx-edge-server-cert
        mkdir -p /work/sdx-public-ca
        mkdir -p /work/sdx-edge-ca
        mkdir -p /work/kong-nginx-proxy-include

        printf '%s' "$KONG_CLIENT_TLS_CERTIFICATE_PEM" > /work/sdx-edge-client-cert/tls.crt
        printf '%s' "$KONG_CLIENT_TLS_PRIVATE_KEY_PEM" > /work/sdx-edge-client-cert/tls.key
        printf '%s' "$KONG_SERVER_TLS_CERTIFICATE_PEM" > /work/sdx-edge-server-cert/tls.crt
        printf '%s' "$KONG_SERVER_TLS_PRIVATE_KEY_PEM" > /work/sdx-edge-server-cert/tls.key
        printf '%s' "$KONG_PUBLIC_CA_PEM" > /work/sdx-public-ca/ca.crt
        printf '%s' "$KONG_EDGE_CA_PEM" > /work/sdx-edge-ca/ca.crt
        printf '%s' "$KONG_NGINX_PROXY_INCLUDE_CONFIG" > /work/kong-nginx-proxy-include/config

        chmod 0600 /work/sdx-edge-client-cert/tls.key /work/sdx-edge-server-cert/tls.key
      EOT
      ]

      env {
        name        = "KONG_CLIENT_TLS_CERTIFICATE_PEM"
        secret_name = "kong-client-tls-certificate"
      }

      env {
        name        = "KONG_CLIENT_TLS_PRIVATE_KEY_PEM"
        secret_name = "kong-client-tls-private-key"
      }

      env {
        name        = "KONG_EDGE_CA_PEM"
        secret_name = "kong-edge-ca-pem"
      }

      env {
        name        = "KONG_NGINX_PROXY_INCLUDE_CONFIG"
        secret_name = "kong-nginx-proxy-include-config"
      }

      env {
        name        = "KONG_PUBLIC_CA_PEM"
        secret_name = "kong-public-ca-pem"
      }

      env {
        name        = "KONG_SERVER_TLS_CERTIFICATE_PEM"
        secret_name = "kong-server-tls-certificate"
      }

      env {
        name        = "KONG_SERVER_TLS_PRIVATE_KEY_PEM"
        secret_name = "kong-server-tls-private-key"
      }

      volume_mounts {
        name = "sdx-edge-client-cert"
        path = "/work/sdx-edge-client-cert"
      }

      volume_mounts {
        name = "sdx-edge-server-cert"
        path = "/work/sdx-edge-server-cert"
      }

      volume_mounts {
        name = "sdx-public-ca"
        path = "/work/sdx-public-ca"
      }

      volume_mounts {
        name = "sdx-edge-ca"
        path = "/work/sdx-edge-ca"
      }

      volume_mounts {
        name = "kong-nginx-proxy-include"
        path = "/work/kong-nginx-proxy-include"
      }
    }

    container {
      name   = "kong"
      image  = var.kong_image
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "KONG_CLUSTER_DP_LABELS"
        value = "data-plane:${local.kong_container_app_name},endpoint:${local.kong_route_host},role:sdx-access-point"
      }

      env {
        name  = "KONG_CLUSTER_CONTROL_PLANE"
        value = var.kong_sdx_control_url
      }

      env {
        name  = "KONG_NGINX_PROXY_SSL_VERIFY_CLIENT"
        value = var.kong_mtls_required ? "on" : "optional"
      }

      env {
        name  = "KONG_NGINX_PROXY_SSL_VERIFY_DEPTH"
        value = var.kong_mtls_required ? "3" : "1"
      }

      env {
        name  = "KONG_PROXY_ACCESS_LOG"
        value = "off"
      }

      env {
        name  = "KONG_PROXY_LISTEN"
        value = "0.0.0.0:8000, [::]:8000, 0.0.0.0:8443 http2 ssl, [::]:8443 http2 ssl, 0.0.0.0:3443 http2 ssl"
      }

      env {
        name  = "KONG_LUA_SSL_TRUSTED_CERTIFICATE"
        value = "/etc/ssl/certs/ca-certificates.crt,/etc/secrets/sdx-public-ca/ca.crt"
      }

      liveness_probe {
        path             = "/status"
        port             = 8100
        transport        = "HTTP"
        initial_delay    = 5
        interval_seconds = 10
        timeout          = 5
      }

      readiness_probe {
        path                    = "/status/ready"
        port                    = 8100
        transport               = "HTTP"
        initial_delay           = 5
        interval_seconds        = 10
        success_count_threshold = 1
        timeout                 = 5
      }

      volume_mounts {
        name = "kong-prefix-dir"
        path = "/kong_prefix/"
      }

      volume_mounts {
        name = "kong-tmp-dir"
        path = "/tmp"
      }

      volume_mounts {
        name = "sdx-edge-server-cert"
        path = "/etc/secrets/sdx-edge-server-cert"
      }

      volume_mounts {
        name = "sdx-edge-client-cert"
        path = "/etc/secrets/sdx-edge-signing-cert"
      }

      volume_mounts {
        name = "sdx-edge-client-cert"
        path = "/etc/secrets/sdx-edge-client-cert"
      }

      volume_mounts {
        name = "sdx-edge-client-cert"
        path = "/etc/secrets/sdx-edge-cluster-cert"
      }

      volume_mounts {
        name = "sdx-edge-client-cert"
        path = "/etc/secrets/kong-upstream-jwt"
      }

      volume_mounts {
        name = "sdx-public-ca"
        path = "/etc/secrets/sdx-public-ca"
      }

      volume_mounts {
        name = "sdx-edge-ca"
        path = "/etc/secrets/sdx-edge-ca"
      }

      volume_mounts {
        name = "kong-nginx-proxy-include"
        path = "/etc/secrets/kong-nginx-proxy-include"
      }

      volume_mounts {
        name = "kong-luarocks-dir"
        path = "/.luarocks"
      }
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = "20"
    }

    volume {
      name         = "kong-prefix-dir"
      storage_type = "EmptyDir"
    }

    volume {
      name         = "kong-tmp-dir"
      storage_type = "EmptyDir"
    }

    volume {
      name         = "sdx-edge-client-cert"
      storage_type = "EmptyDir"
    }

    volume {
      name         = "sdx-edge-server-cert"
      storage_type = "EmptyDir"
    }

    volume {
      name         = "sdx-public-ca"
      storage_type = "EmptyDir"
    }

    volume {
      name         = "sdx-edge-ca"
      storage_type = "EmptyDir"
    }

    volume {
      name         = "kong-nginx-proxy-include"
      storage_type = "EmptyDir"
    }

    volume {
      name         = "kong-luarocks-dir"
      storage_type = "EmptyDir"
    }
  }

  ingress {
    external_enabled = var.kong_external_ingress_enabled
    target_port      = var.kong_target_port
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

    allow_insecure_connections = false
  }

  tags = merge(var.common_tags, {
    Component = "Kong Edge Runtime"
    Purpose   = "Gateway runtime based on the APS SDX edge image"
    Workload  = "Consumption"
  })

  lifecycle {
    ignore_changes = [tags]
  }


  depends_on = [azurerm_container_app_environment.main, null_resource.wait_for_containerapps_private_dns_zone]
}

# -----------------------------------------------------------------------------
# Data API Builder Container App
# -----------------------------------------------------------------------------
resource "azurerm_container_app" "dab" {
  count                        = local.deploy_dab_count
  name                         = local.dab_container_app_name
  container_app_environment_id = azurerm_container_app_environment.main[0].id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type = var.enable_system_assigned_identity ? "SystemAssigned" : "None"
  }

  template {
    max_replicas                     = var.max_replicas
    min_replicas                     = var.min_replicas
    termination_grace_period_seconds = 10

    container {
      name   = "dab"
      image  = var.dab_image
      cpu    = var.container_cpu
      memory = var.container_memory
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = "20"
    }
  }

  ingress {
    external_enabled = var.dab_external_ingress_enabled
    target_port      = var.dab_target_port
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

    allow_insecure_connections = false
  }

  tags = merge(var.common_tags, {
    Component = "Data API Builder"
    Purpose   = "Fabric tabular facade"
    Workload  = "Consumption"
  })

  lifecycle {
    ignore_changes = [tags]
  }

  depends_on = [azurerm_container_app_environment.main, null_resource.wait_for_containerapps_private_dns_zone]
}

# ---------------------------------------------------------------------------
# Container Apps Environment Diagnostic Settings
# ---------------------------------------------------------------------------
# Environment-level sink that aggregates telemetry for ALL container apps
# running inside this managed environment.
#
# ── How to view logs in the Azure Portal ─────────────────────────────────────
# 1. Open the Log Analytics workspace in the Portal.
# 2. Click "Logs" in the left nav (under General).
# 3. Dismiss the query picker and paste any KQL below into the editor.
# 4. Adjust the time range picker (top-right) — ingestion lag is ~2-5 min.
# ---------------------------------------------------------------------------
#
# IMPORTANT: Azure appends the "_CL" custom-log suffix when it writes these
# categories to Log Analytics.  The Terraform category values below are the
# Azure resource-provider identifiers (without "_CL"); the LAW table names
# you must use in KQL queries carry the "_CL" suffix.
#
# Log categories:
#
#  ContainerAppConsoleLogs — stdout/stderr from every container in the
#                            environment.  Primary source for runtime errors,
#                            stack traces, and application debug output.
#                            LAW table: ContainerAppConsoleLogs_CL
#                            Key fields: ContainerAppName_s, ContainerName_s,
#                            Log_s, Stream_s (stdout|stderr), RevisionName_s.
#
#    KQL — recent log lines from all apps:
#      ContainerAppConsoleLogs_CL
#      | project TimeGenerated, ContainerAppName_s, ContainerName_s,
#                Log_s, Stream_s, RevisionName_s
#      | order by TimeGenerated desc
#
#    KQL — stderr errors across all revisions:
#      ContainerAppConsoleLogs_CL
#      | where Stream_s == "stderr"
#      | project TimeGenerated, ContainerAppName_s, Log_s,
#                RevisionName_s, ContainerImage_s
#      | order by TimeGenerated desc
#
#  ContainerAppSystemLogs — platform events scoped to the environment:
#                           scaling decisions (KEDA), replica start/stop,
#                           revision activation, and health-check outcomes.
#                           LAW table: ContainerAppSystemLogs_CL
#                           Key fields: ContainerAppName_s, EventSource_s
#                           (KEDA|ContainerAppController), Type_s
#                           (Normal|Warning), Reason_s, Log_s.
#
#    KQL — all system events ordered by time:
#      ContainerAppSystemLogs_CL
#      | project TimeGenerated, ContainerAppName_s, EventSource_s,
#                Type_s, Reason_s, Log_s, Level, RevisionName_s
#      | order by TimeGenerated desc
#
#    KQL — KEDA scaling events:
#      ContainerAppSystemLogs_CL
#      | where EventSource_s == "KEDA"
#      | project TimeGenerated, ContainerAppName_s, Reason_s, Log_s,
#                RevisionName_s, ReplicaName_s
#      | order by TimeGenerated desc
#
#  AllMetrics — environment-level metrics: active replica count,
#               CPU/memory utilisation per environment, and request
#               concurrency (used by KEDA http-scaling).
#
#    KQL — replica count and CPU over time:
#      AzureMetrics
#      | where ResourceProvider == "MICROSOFT.APP"
#      | where MetricName in ("Replicas", "CpuPercentage", "MemoryPercentage")
#      | summarize avg(Average) by MetricName, bin(TimeGenerated, 5m)
#      | order by TimeGenerated desc
#
#    KQL — request concurrency for KEDA scaling visibility:
#      AzureMetrics
#      | where ResourceProvider == "MICROSOFT.APP"
#      | where MetricName == "Requests"
#      | summarize sum(Total) by bin(TimeGenerated, 1m)
#      | order by TimeGenerated desc
resource "azurerm_monitor_diagnostic_setting" "container_app_env_diagnostics" {
  count                      = local.create_environment_count
  name                       = "${var.app_name}-ca-env-diagnostics"
  target_resource_id         = azurerm_container_app_environment.main[0].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # stdout/stderr from all containers in the environment — main debug log source.
  # LAW table: ContainerAppConsoleLogs_CL (note the _CL suffix in KQL queries)
  # KQL: ContainerAppConsoleLogs_CL
  #      | project TimeGenerated, ContainerAppName_s, ContainerName_s,
  #                Log_s, Stream_s, RevisionName_s
  #      | order by TimeGenerated desc
  enabled_log {
    category = "ContainerAppConsoleLogs"
  }

  # Platform events: scaling, restarts, revision activations, health probes.
  # LAW table: ContainerAppSystemLogs_CL (note the _CL suffix in KQL queries)
  # KQL: ContainerAppSystemLogs_CL
  #      | project TimeGenerated, ContainerAppName_s, EventSource_s,
  #                Type_s, Reason_s, Log_s, Level, RevisionName_s
  #      | order by TimeGenerated desc
  enabled_log {
    category = "ContainerAppSystemLogs"
  }

  # Replica count, CPU/memory, and concurrency metrics for the environment.
  # KQL: AzureMetrics | where ResourceProvider == "MICROSOFT.APP"
  #      | where MetricName in ("Replicas","CpuPercentage","MemoryPercentage")
  #      | summarize avg(Average) by MetricName, bin(TimeGenerated, 5m)
  enabled_metric {
    category = "AllMetrics"
  }
}
