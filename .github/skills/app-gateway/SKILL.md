---
name: app-gateway
description: Guidance for Azure Application Gateway listener, rewrite-rule, certificate, WAF, and diagnostics work in this repository, where Application Gateway fronts Azure API Management (APIM).
---

# App Gateway

Use this skill profile when creating or modifying the Azure Application Gateway path that fronts the APIM (StandardV2) instance.

> **Before any change, load the repo working agreement in [`AGENTS.md`](../../../AGENTS.md)** —
> it carries the BC Gov shared guardrails (fix-first, diff-as-receipt, git workflow,
> Conventional Commits, secrets/state hygiene) that apply to every edit here.

## Use When

- Editing `infra/modules/app-gateway/`
- Editing `infra/stacks/shared/main.tf` (or its variables) for Application Gateway wiring
- Editing the WAF policy module `infra/modules/waf-policy/`
- Updating docs that describe the Application Gateway → APIM ingress path

## Do Not Use When

- Editing tenant APIM API / operation / backend wiring under `infra/stacks/tenant/` — use the `iac-coder` skill
- Designing the App Gateway or APIM subnet, NSG, or private-endpoint layout — defer to the
  **`azure-networking`** skill ([`bcgov/agent-skills`](https://github.com/bcgov/agent-skills))
- Hardening the GitHub Actions workflows — defer to the **`github-actions`** skill (`bcgov/agent-skills`)
- Documentation-only work unrelated to App Gateway behavior

## Required Facts

- Application Gateway's backend is the **APIM gateway**, addressed by APIM's gateway FQDN.
  There is **no Kong, ACA, AKS, or other intermediate runtime** on this path.
- The APIM health-probe path is `/status-0123456789abcdef`.
- App Gateway and APIM run on **pre-existing (BYO) subnets** passed in as
  `app_gateway_subnet_id` and `apim_subnet_id`; this stack does not create the VNet or subnets.
- App Gateway is created only when both App Gateway and APIM are enabled, and it
  `depends_on` APIM so the backend FQDN exists at apply time.
- WAF runs as a separate policy module (`waf-policy`) associated with App Gateway by ID.

## Architecture Contract

Keep this request flow intact unless the user explicitly asks to redesign it:

`Client -> Application Gateway listener/WAF/rewrite -> APIM (StandardV2) gateway -> Fabric GraphQL`

Implications:

- Listener-side TLS termination, WAF, and header rewrites happen at Application Gateway.
- The backend pool targets the APIM gateway FQDN using the `/status-0123456789abcdef` probe path.
- **APIM** (not App Gateway) validates the inbound BCGov Entra JWT via its global policy, then
  forwards the token unchanged to Fabric.

## Output Contract

Every App Gateway change should preserve or intentionally update:

- The dedicated App Gateway subnet and its association to the WAF policy
- The APIM backend FQDN targeting model and the `/status-0123456789abcdef` probe path
- Explicit certificate-source behavior: a pre-existing App Gateway cert, or a Key Vault-backed
  cert (with a user-assigned identity)
- The autoscale configuration
- Documentation sync in `README.md` when the operator contract changes

## Standard Module Shape

Prefer the reusable ALZ-style module pattern used in other BCGov repos:

- Optional reuse of an existing Public IP resource instead of always creating one
- Association with an external WAF policy ID
- Optional user-assigned identity plus Key Vault access for certificate-backed listeners
- Data-driven rewrite rule sets instead of hardcoded one-off blocks where practical
- TLS policy aligned to Landing Zone expectations
- Diagnostic settings using dedicated Log Analytics tables when diagnostics are enabled

## Validation Gates

1. `terraform fmt -recursive` from `infra/`
2. `terraform validate` from `infra/`
3. Confirm the App Gateway module still exposes the outputs consumed by the shared stack, and
   that the APIM backend FQDN + `/status-0123456789abcdef` probe path remain wired
4. Update `README.md` when the ingress contract or operator inputs change
