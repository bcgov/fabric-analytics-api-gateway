---
name: app-gateway
description: Guidance for Azure Application Gateway listener, rewrite-rule, certificate, WAF, and private-DNS work in this repository.
---

# App Gateway

Use this skill profile when creating or modifying the Azure Application Gateway path that fronts the private ACA-hosted Kong runtime.

## Use When

- Editing `infra/modules/application-gateway/`
- Editing `infra/main.tf` or `infra/variables.tf` for Application Gateway wiring
- Editing `infra/modules/network/` when the App Gateway subnet or NSG behavior changes
- Updating docs that describe the Application Gateway to ACA to Kong ingress path

## Do Not Use When

- Editing only APS route and plugin configuration under `.gwa/`
- Editing only DAB runtime or facade configuration
- Making Azure Front Door-only changes for non-SDX experiments

## Required Facts

- Kong runs on Azure Container Apps, not App Service, in this repository.
- The supported SDX public edge here is Application Gateway in front of the private ACA environment.
- Application Gateway can forward the client certificate via rewrite server variables, but ACA HTTP ingress still terminates the backend TLS hop before Kong sees the request.
- Kong therefore receives forwarded HTTP headers on this path, not the original downstream TLS handshake.

## Architecture Contract

Keep this request flow intact unless the user explicitly asks to redesign it:

`Client -> Application Gateway listener/WAF/rewrite -> private ACA ingress -> Kong`

Implications:

- Listener-side mutual-auth passthrough and header rewrites happen at Application Gateway.
- Private DNS records for the ACA environment must keep resolving from the App Gateway subnet.
- If Kong must validate the forwarded certificate itself, the compatible runtime path is header-based auth, not direct `mtls-auth` on Kong's own listener.

## Output Contract

Every App Gateway change should preserve or intentionally update:

- The dedicated App Gateway subnet and private DNS link to the internal ACA environment
- The Kong backend FQDN targeting model
- The client-certificate forwarding headers and their ordering when rewrites are used
- Explicit certificate-source behavior: direct PFX, pre-existing App Gateway cert, or Key Vault-backed cert
- Documentation sync in `README.md` and `infra/README.md` when the operator contract changes

## Standard Module Shape

Prefer the reusable ALZ-style module pattern used in other BCGov repos:

- Optional reuse of an existing Public IP resource instead of always creating one
- Optional association with an external WAF policy ID
- Optional user-assigned identity plus Key Vault access for certificate-backed listeners
- Data-driven rewrite rule sets instead of hardcoded one-off blocks where practical
- TLS policy aligned to Landing Zone expectations
- Diagnostic settings using dedicated Log Analytics tables when diagnostics are enabled

## Validation Gates

1. `terraform fmt -recursive` from `infra/`
2. `terraform validate` from `infra/`
3. Confirm the App Gateway module still exposes the current Kong/ACA outputs consumed by the root module
4. Update `README.md` and `infra/README.md` when the ingress contract or operator inputs change
