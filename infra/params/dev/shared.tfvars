# ============================================================
# shared.tfvars — dev environment
# Passed to: stacks/shared ONLY
# ============================================================

resource_group_name = "fabric-gateway-dev"
location            = "Canada Central"

common_tags = {
  environment = "dev"
  repo_name   = "infra-fabric-gateway"
  app_env     = "dev"
  managed_by  = "terraform"
}

# ---------------------------------------------------------------------------
# Shared infrastructure
# ---------------------------------------------------------------------------
shared_config = {
  log_analytics = {
    enabled        = true
    sku            = "PerGB2018"
    retention_days = 30
  }

  app_gateway = {
    enabled               = false # App Gateway not deployed yet — enable once APIM is stable
    frontend_hostname     = null
    waf_mode              = "Detection"
    public_ip_resource_id = null
    ssl_certificate_name  = null

    autoscale = {
      min_capacity = 1
      max_capacity = 2
    }
  }

  apim = {
    enabled                = true
    sku_name               = "StandardV2_1"
    publisher_name         = "BC Gov CSBC EO DMI"
    publisher_email        = "Omprakash.2.Mishra@gov.bc.ca"
    vnet_injection_enabled = false # Set true + provide apim_subnet_id to inject into VNet
  }

  # Optional: have the network module create the App Gateway subnet inside an
  # existing VNet instead of supplying app_gateway_subnet_id above. When enabled
  # with vnet_name + vnet_resource_group_name set, the App Gateway uses the
  # module-created subnet and app_gateway_subnet_id may be left null.
  network = {
    enabled = false
  }
}
