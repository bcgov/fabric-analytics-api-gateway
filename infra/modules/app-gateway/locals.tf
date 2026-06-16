locals {
  frontend_ip_config_name  = "${var.name}-feip"
  frontend_port_https_name = "${var.name}-port-443"
  frontend_port_http_name  = "${var.name}-port-80"
  backend_pool_name        = "${var.name}-apim-pool"
  http_setting_name        = "${var.name}-https-setting"
  probe_name               = "${var.name}-apim-probe"
  listener_https_name      = "${var.name}-https-listener"
  listener_http_name       = "${var.name}-http-listener"
  redirect_config_name     = "${var.name}-http-to-https"
  routing_rule_https_name  = "${var.name}-https-rule"
  routing_rule_http_name   = "${var.name}-http-rule"

  ssl_cert_name  = var.ssl_certificate_name
  needs_identity = var.key_vault_id != null

  ssl_policy = {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }
}
