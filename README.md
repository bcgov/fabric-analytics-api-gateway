# fabric-analytics-api-gateway

Spike scaffold for exposing Microsoft Fabric data through the BC Government API Program Services gateway, with Kong SDX Edge Runtime running on Azure Container Apps behind Azure Application Gateway.

## Status

Draft / PoC scaffold.

This repository now captures the architecture, trade-offs, and initial APS gateway configuration shape for a pilot that keeps the data plane in Azure Canada Central while using APS as the API control plane.

## Problem Statement

The spike is testing whether APS Kong SDX Edge Runtime is a better fit than Azure API Management for exposing Fabric-backed analytics and geospatial-style data products to BC Government and partner consumers.

The current working architecture is:

- Kong SDX Edge Runtime deployed in Azure Container Apps inside the spoke VNet.
- Azure Application Gateway provides the public HTTPS edge, targets the private Kong Container App FQDN inside the internal ACA environment, and uses listener-side mTLS passthrough plus request-header rewrites to forward the client certificate to Kong in `X-ARR-ClientCert` with companion metadata headers.
- A Data API Builder (DAB) service for tabular REST and GraphQL reads over Fabric.
- A thin custom sibling service only if spatial, OGC, or tile-specific behavior is required.
- Private connectivity from DAB and any optional spatial service to the Fabric SQL Analytics Endpoint.
- BC Gov SSO and Microsoft Entra ID both in scope for consumer authentication.

## Facade Decision

- DAB is the chosen tabular facade for the spike.
- The Fabric connection pattern uses `database-type` `dwsql`, an Entra-based connection string, and no `tcp:` prefix in the Fabric server name.
- The SQL analytics endpoint is read-only, so the DAB surface should stay read-focused.
- The checked-in DAB template under `dab/` now resolves `DB_TYPE` and `SQL_CONN_STRING` with `@env()`, matching the ACA runtime contract that injects `SQL_CONN_STRING` from a secret-backed environment variable.
- The `dab/Dockerfile` packages that checked-in config into a dedicated DAB image as `dab-config.json`.
- Spatial, OGC, and tile-specific requirements remain outside DAB and stay in scope for a separate thin service only if needed.

## Terraform Note

- The current Terraform root under `infra/` wires the `network`, `monitoring`, `container-apps`, `application-gateway`, and legacy `frontdoor` modules directly.
- The current Terraform root under `infra/` can scaffold the Kong bootstrap Key Vault independently with `enable_key_vault`, the ACA bootstrap job independently with `deploy_kong_bootstrap_job`, or both together through the legacy `enable_kong_key_vault_bootstrap` convenience toggle.
- The `container-apps` module now scaffolds separate Kong Edge Runtime and Data API Builder workloads inside the same Azure Container Apps environment.
- The DAB workload can now take its Fabric SQL settings from ACA environment variables, with `DB_TYPE` set from Terraform and `SQL_CONN_STRING` injected from an ACA secret instead of a plain-text env value.
- The root toggle surface is now stepwise: use `enable_*` variables for top-level modules and `deploy_*` variables for optional ACA workloads and jobs so you can apply the stack one slice at a time.
- The Kong workload now defaults to the published APS SDX runtime image `ghcr.io/bcgov/aps-devops/sdx-access-point:3.9-57ca71e3`, derived from the `sdx-edge` Helm chart `oci://ghcr.io/bcgov/aps-devops/sdx-edge:0.1.0`.
- The Azure Container Apps scaffold now supports two Kong certificate paths: direct PEM inputs, or a manual ACA Job bootstrap flow where Terraform runs a local script to start and wait for the in-VNet ACA job before the full apply continues.
- The `application-gateway` module now follows the reusable ALZ-style BCGov shape: availability zones by default, optional reuse of an existing Public IP, optional external WAF policy association, optional Key Vault-backed listener certificates via a user-assigned identity, data-driven rewrite rule sets, and an AzAPI patch that sets `verifyClientAuthMode = Passthrough` on the listener SSL profile.
- On this ingress path, Kong receives the client certificate as forwarded HTTP headers rather than as a raw downstream TLS handshake. If Kong needs to enforce that certificate itself, the compatible runtime path is a header-based plugin such as Header Cert Authentication, not direct `mtls-auth` on Kong's own listener.
- The Terraform stack now fails fast if you try to combine `kong_mtls_required=true` with Azure Front Door or ACA external ingress; the supported public edge in this scaffold is Azure Application Gateway in front of the private ACA environment.
- The Application Gateway listener requires a base64-encoded PFX certificate and password through `application_gateway_frontend_certificate_pfx_base64` and `application_gateway_frontend_certificate_password`.
- The `infra/deploy-terraform.sh` wrapper is the single source of truth for local and GitHub Actions Terraform runs, including optional tfvars file handling and the bootstrap pre-apply when `DEPLOY_KONG_BOOTSTRAP_JOB=true`; `ENABLE_KONG_KEY_VAULT_BOOTSTRAP=true` remains as a backward-compatible shortcut that turns on both the Key Vault and bootstrap job toggles.
- The root Terraform input surface has been trimmed to the current Kong plus DAB scaffold and no longer carries the reverted backend/Postgres placeholders.


