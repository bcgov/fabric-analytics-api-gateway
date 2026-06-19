# Azure Front Door (Standard/Premium) in front of APIM.
#
# Provides a managed public hostname (*.azurefd.net) with a Microsoft-managed
# TLS cert — no vanity domain or certificate to manage. APIM is locked to this
# Front Door via the X-Azure-FDID header (see the shared stack global policy),
# so the shared AFD public IPs of other tenants cannot reach the origin.

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  # STABLE HOSTNAME (domain-label reuse): the public host is
  # <name>-<hash>.z01.azurefd.net. Azure reuses the SAME domain label (hash)
  # for an endpoint created with the SAME name in the SAME resource group, so
  # destroying and recreating this endpoint is hostname-stable as long as both
  # the endpoint name AND the resource group stay constant. There is no
  # Terraform setting for the hash — name + RG are the only levers.
  # Ref: https://learn.microsoft.com/azure/frontdoor/endpoint#reuse-of-an-endpoint-domain-name
  name                     = var.endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  tags                     = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_cdn_frontdoor_origin_group" "apim" {
  name                     = "${var.name}-apim-og"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    path                = var.probe_path
    protocol            = "Https"
    request_type        = "GET"
    interval_in_seconds = 60
  }
}

resource "azurerm_cdn_frontdoor_origin" "apim" {
  name                          = "${var.name}-apim-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.apim.id
  enabled                       = true

  # APIM's azure-api.net certificate CN matches the gateway hostname, so cert
  # name validation stays on.
  certificate_name_check_enabled = true

  host_name          = var.origin_host
  origin_host_header = var.origin_host
  http_port          = 80
  https_port         = 443
  priority           = 1
  weight             = 1000
}

resource "azurerm_cdn_frontdoor_route" "this" {
  name                          = "${var.name}-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.apim.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.apim.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly" # AFD → APIM always over TLS
  https_redirect_enabled = true        # client HTTP → HTTPS
  link_to_default_domain = true
}

# ---------------------------------------------------------------------------
# WAF
# Custom rules apply on Standard AND Premium. Microsoft-managed rule sets
# (OWASP DRS + Bot Manager) are Premium-only, so they're added conditionally
# on the SKU. The WAF firewall policy SKU must match the profile SKU.
# ---------------------------------------------------------------------------
locals {
  # WAF policy names must be alphanumeric only (no hyphens), start with a letter.
  waf_policy_name = "${replace(var.endpoint_name, "-", "")}waf"
  managed_waf     = var.sku_name == "Premium_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_firewall_policy" "this" {
  count = var.waf_enabled ? 1 : 0

  name                = local.waf_policy_name
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
  enabled             = true
  mode                = var.waf_mode
  tags                = var.tags

  # Per-client-IP rate limit.
  custom_rule {
    name                           = "RateLimitPerIP"
    enabled                        = true
    type                           = "RateLimitRule"
    action                         = "Block"
    priority                       = 100
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = var.waf_rate_limit_threshold

    match_condition {
      match_variable = "RemoteAddr"
      operator       = "IPMatch"
      match_values   = ["0.0.0.0/0", "::/0"] # all clients → counted per IP
    }
  }

  # Geo-filter: block everything except the allowed countries (default CA only).
  custom_rule {
    name     = "AllowedCountriesOnly"
    enabled  = true
    type     = "MatchRule"
    action   = "Block"
    priority = 200

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "GeoMatch"
      negation_condition = true # block when country is NOT in the allow-list
      match_values       = var.waf_allowed_countries
    }
  }

  # Block requests whose Authorization header is missing, empty, or not a Bearer
  # token (coarse pre-filter ahead of the APIM JWT validation).
  custom_rule {
    name     = "RequireBearerAuthorization"
    enabled  = true
    type     = "MatchRule"
    action   = "Block"
    priority = 300

    match_condition {
      match_variable     = "RequestHeader"
      selector           = "Authorization"
      operator           = "BeginsWith"
      negation_condition = true        # block when it does NOT begin with "bearer "
      match_values       = ["bearer "] # lower-cased below, so scheme match is case-insensitive
      transforms         = ["Lowercase"]
    }
  }

  # Managed OWASP + Bot rule sets — Premium only.
  dynamic "managed_rule" {
    for_each = local.managed_waf ? [1] : []
    content {
      type    = "Microsoft_DefaultRuleSet"
      version = "2.1"
      action  = "Block"
    }
  }

  dynamic "managed_rule" {
    for_each = local.managed_waf ? [1] : []
    content {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.0"
      action  = "Block"
    }
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Associate the WAF policy with the endpoint's default domain for all paths.
resource "azurerm_cdn_frontdoor_security_policy" "this" {
  count = var.waf_enabled ? 1 : 0

  name                     = "${var.endpoint_name}-secpol"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.this[0].id

      association {
        patterns_to_match = ["/*"]
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.this.id
        }
      }
    }
  }
}
