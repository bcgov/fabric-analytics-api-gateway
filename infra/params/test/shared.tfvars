# ============================================================
# shared.tfvars — test environment
# Passed to: stacks/shared ONLY
# ============================================================

resource_group_name = "fabric-gateway-test"
location            = "Canada Central"

common_tags = {
  environment = "test"
  repo_name   = "infra-fabric-gateway"
  app_env     = "test"
  managed_by  = "terraform"
}

# ---------------------------------------------------------------------------
# Shared infrastructure
# ---------------------------------------------------------------------------
shared_config = {
  log_analytics = {
    enabled        = true
    sku            = "PerGB2018"
    retention_days = 90
  }

  app_gateway = {
    enabled               = false # App Gateway not deployed yet — enable once APIM is stable
    frontend_hostname     = "fabric-api-test.nrs.gov.bc.ca"
    waf_mode              = "Prevention"
    public_ip_resource_id = null
    ssl_certificate_name  = null

    autoscale = {
      min_capacity = 1
      max_capacity = 3
    }
  }

  apim = {
    enabled                = true
    sku_name               = "StandardV2_1"
    publisher_name         = "BC Gov CSBC EO DMI"
    publisher_email        = "Omprakash.2.Mishra@gov.bc.ca"
    vnet_injection_enabled = true
  }

  network = {
    enabled = true
  }
}
