locals {
  normalized_app_name        = lower(replace(var.app_name, "_", "-"))
  application_gateway_name   = var.application_gateway_name != null && trimspace(var.application_gateway_name) != "" ? var.application_gateway_name : "${local.normalized_app_name}-agw"
  backend_address_pool_name  = "kong-backend-pool"
  backend_http_settings_name = "kong-backend-https"
  configured_ssl_certificates = merge(var.application_gateway_frontend_certificate_pfx_base64 != null && trimspace(var.application_gateway_frontend_certificate_pfx_base64) != "" ? {
    default = {
      name                = local.ssl_certificate_name
      data                = var.application_gateway_frontend_certificate_pfx_base64
      key_vault_secret_id = null
      password            = var.application_gateway_frontend_certificate_password
    }
  } : {}, var.ssl_certificates)
  create_diagnostics_count = var.log_analytics_workspace_id != null && trimspace(var.log_analytics_workspace_id) != "" ? 1 : 0
  create_public_ip_count   = var.application_gateway_public_ip_resource_id == null ? 1 : 0
  default_rewrite_rule_sets = {
    kong_request_rewrites = {
      name = local.rewrite_rule_set_name
      rewrite_rules = {
        forward_client_certificate = {
          name          = "forward-client-certificate"
          rule_sequence = 10
          request_header_configurations = {
            arr_client_cert = {
              header_name  = "X-ARR-ClientCert"
              header_value = "{var_client_certificate}"
            }
            client_cert = {
              header_name  = "X-Client-Cert"
              header_value = "{var_client_certificate}"
            }
            client_cert_fingerprint = {
              header_name  = "X-Client-Cert-Fingerprint"
              header_value = "{var_client_certificate_fingerprint}"
            }
            client_cert_issuer = {
              header_name  = "X-Client-Cert-Issuer"
              header_value = "{var_client_certificate_issuer}"
            }
            client_cert_subject = {
              header_name  = "X-Client-Cert-Subject"
              header_value = "{var_client_certificate_subject}"
            }
            client_cert_verification = {
              header_name  = "X-Client-Cert-Verification"
              header_value = "{var_client_certificate_verification}"
            }
            x_forwarded_host = {
              header_name  = "X-Forwarded-Host"
              header_value = "{var_host}"
            }
          }
        }
        add_x_forwarded_for = {
          name          = "add-x-forwarded-for"
          rule_sequence = 20
          request_header_configurations = {
            x_forwarded_for = {
              header_name  = "X-Forwarded-For"
              header_value = "{var_client_ip}"
            }
          }
        }
      }
    }
  }
  default_rewrite_rule_set_name  = length(local.rewrite_rule_sets) > 0 ? values(local.rewrite_rule_sets)[0].name : null
  enable_waf_configuration_count = var.application_gateway_sku_name == "WAF_v2" && var.waf_enabled && var.waf_policy_id == null ? 1 : 0
  frontend_ip_configuration_name = "public-frontend"
  frontend_port_name             = "https-443"
  gateway_ip_configuration_name  = "app-gateway-ip-config"
  http_listener_name             = "https-listener"
  needs_identity                 = length([for cert in values(local.configured_ssl_certificates) : cert if cert.key_vault_secret_id != null && trimspace(cert.key_vault_secret_id) != ""]) > 0
  private_dns_zone_link_name     = "${local.application_gateway_name}-vnet-link"
  probe_name                     = "kong-backend-probe"
  public_ip_name                 = var.application_gateway_public_ip_name != null && trimspace(var.application_gateway_public_ip_name) != "" ? var.application_gateway_public_ip_name : "${local.application_gateway_name}-pip"
  request_routing_rule_name      = "kong-routing-rule"
  rewrite_rule_set_name          = "kong-request-rewrites"
  rewrite_rule_sets              = var.rewrite_rule_sets != null ? var.rewrite_rule_sets : local.default_rewrite_rule_sets
  ssl_certificate_name           = "frontend-certificate"
  ssl_cert_name                  = var.ssl_certificate_name != null && trimspace(var.ssl_certificate_name) != "" ? var.ssl_certificate_name : length(local.configured_ssl_certificates) > 0 ? values(local.configured_ssl_certificates)[0].name : null
  ssl_policy = {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"
  }
  ssl_profile_name = "client-auth-profile"
}
