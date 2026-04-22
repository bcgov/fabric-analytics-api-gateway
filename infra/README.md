# Infrastructure Scaffold

This folder contains the Terraform scaffold for the Azure data-plane side of the Fabric analytics gateway spike.

## Current Modules

- `network`: derives and provisions dedicated subnets for Application Gateway, Container Apps, and private endpoints inside an existing VNet.
- `key-vault`: provisions the private Key Vault, private endpoint, and managed identities used by the Kong bootstrap flow.
- `monitoring`: provisions Log Analytics and Application Insights.
- `container-apps`: provisions the shared Azure Container Apps environment, the manual Kong bootstrap ACA Job, and optional Kong Edge Runtime and Data API Builder container apps.
- `application-gateway`: provisions the public Application Gateway v2 listener, internal ACA private DNS zone records, request-header rewrites that emit `X-ARR-ClientCert` plus companion client-certificate metadata for Kong, and the AzAPI patch that enables listener passthrough mode.
- `frontdoor`: retains legacy Azure Front Door profile resources, diagnostics, and WAF policy scaffolding for non-SDX experiments. It is not compatible with `kong_mtls_required = true`.
- Root toggles are stepwise: `enable_*` variables control top-level modules, while `deploy_kong_app`, `deploy_dab_app`, and `deploy_kong_bootstrap_job` control the optional workloads inside the Container Apps module. The legacy `enable_kong_key_vault_bootstrap` flag still enables the Key Vault and bootstrap job together for backward compatibility.

## Current Container Apps Shape

- Kong Edge Runtime and DAB are modeled as separate container apps in the same managed environment.
- The DAB container app now exposes `DB_TYPE` as a normal environment variable and `SQL_CONN_STRING` as an ACA secret-backed environment variable, so a DAB config that uses `@env('DB_TYPE')` and `@env('SQL_CONN_STRING')` can read the Fabric connection cleanly without storing the full string in plain app settings.
- The managed environment keeps internal load balancing enabled and supports a private endpoint when a private-endpoint subnet ID is supplied.
- Log Analytics wiring is used for environment diagnostics and app log configuration.
- The Kong app now defaults to the published APS SDX runtime image `ghcr.io/bcgov/aps-devops/sdx-access-point:3.9-57ca71e3`, based on the `sdx-edge` Helm chart `oci://ghcr.io/bcgov/aps-devops/sdx-edge:0.1.0`.
- The Kong app mounts SDX route-host, control-plane, CA, and certificate material using Container Apps secrets and an init container that renders the expected file layout before the runtime starts.
- The scaffold now supports an ACA Job bootstrap flow that mirrors the upstream `sdx-edge` chart: GitHub invokes Terraform, Terraform runs `infra/scripts/run-aca-job.sh` as `local-exec`, and that script starts and waits for the manual in-VNet job that generates the CSR and key with `step-cli`, signs the cert via the SDX client CA, and writes the resulting artifacts to Azure Key Vault.
- The bootstrap flow creates a user-assigned managed identity for Kong with `Key Vault Secrets User`, a separate user-assigned identity for the ACA Job with `Key Vault Secrets Officer`, and a private endpoint for the vault so no Key Vault data-plane writes happen from the GitHub-hosted runner.
- Kong stays private inside the internal ACA environment. The public edge is Azure Application Gateway, which resolves the internal ACA default domain through a private DNS zone and targets the Kong Container App FQDN over HTTPS.
- The Application Gateway listener uses the new mutual-authentication passthrough mode and forwards the presented client certificate to Kong in the App Service-compatible `X-ARR-ClientCert` header, alongside companion metadata headers such as fingerprint, issuer, subject, and verification status. The passthrough flag is patched with `azapi_update_resource` because the current `azurerm_application_gateway` resource does not yet expose `verifyClientAuthMode`.
- The Application Gateway module now uses the repo's reusable ALZ-style shape: zone-aware deployment by default, optional reuse of an existing Public IP, optional external WAF policy association, optional Key Vault-backed listener certificates via a user-assigned identity, and data-driven rewrite rule sets that keep the current Kong client-certificate forwarding headers as the default behavior.
- Because the backend hop still terminates at ACA ingress, Kong does not receive a raw downstream client TLS handshake on this path. If Kong must validate the forwarded client certificate itself, use a header-based auth flow such as Kong Header Cert Authentication rather than relying on direct `mtls-auth` on Kong's own TLS listener.
- The default `kong_nginx_proxy_include_config` now raises `large_client_header_buffers` so the forwarded client certificate header fits through the Kong proxy server block.
- The stack now rejects Azure Front Door and ACA external ingress when `kong_mtls_required = true`; the supported ingress path in this scaffold is the private ACA environment behind Application Gateway.
- To enable the Application Gateway path, provide `application_gateway_frontend_certificate_pfx_base64` and `application_gateway_frontend_certificate_password`, plus either `enable_network = true` or an explicit `application_gateway_subnet_id`.
- Terraform fingerprints the bootstrap token and related ACA job inputs, so reapplying with the same token and same bootstrap settings does not rerun the job.
- `infra/deploy-terraform.sh` is the single entrypoint for local and GitHub Actions runs: it maps the optional Kong bootstrap environment variables into `TF_VAR_*`, understands the new `ENABLE_KEY_VAULT` and `DEPLOY_KONG_BOOTSTRAP_JOB` stepwise toggles, appends `TFVARS_FILE` when present, and runs the targeted bootstrap apply before the full apply when the job toggle is enabled.
- For step-by-step GitHub Actions or local applies, set `ENABLE_KEY_VAULT=true` to create only the Key Vault slice, then add `DEPLOY_KONG_BOOTSTRAP_JOB=true` when you want the ACA job to run. `ENABLE_KONG_KEY_VAULT_BOOTSTRAP=true` remains supported as a one-flag shortcut that enables both. Provide `KONG_RUNTIME_GROUP_NAME`, `KONG_SDX_CONTROL_URL`, and `SDX_CLIENT_CA_URL` as environment variables, and store the one-time `SDX_BOOTSTRAP_TOKEN` as an environment secret. `KONG_ROUTE_HOST`, `KONG_KEY_VAULT_NAME`, `KONG_KEY_VAULT_SECRET_PREFIX`, and `SDX_SERVER_IP_SAN` remain optional overrides.
- Root Terraform variables are aligned to the current Kong and DAB scaffold rather than the reverted backend/Postgres placeholder shape.

## Validation

Run these from `infra/` when Terraform is available:

1. `terraform fmt -recursive`
2. `terraform init -backend=false`
3. `terraform validate`
