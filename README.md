# fabric-analytics-api-gateway

Terraform IaC that stands up an Azure-native API gateway in front of Microsoft
Fabric, exposing Fabric **GraphQL** and **SQL Analytics** endpoints through a
managed, authenticated edge.

```
Client ──HTTPS──▶ Application Gateway (WAF_v2) ──▶ API Management (StandardV2) ──▶ Microsoft Fabric
                                                         │
                                                  Global JWT policy
                                            (validates BCGov Entra issuer)
```

- **Application Gateway + WAF policy** — public ingress, TLS termination, OWASP WAF.
- **API Management (StandardV2)** — fronts Fabric GraphQL & SQL Analytics endpoints.
- **Log Analytics** — diagnostics for APIM and App Gateway.
- **Global JWT validation** — an APIM global policy validates that every inbound
  `Authorization: Bearer` token is issued by the BCGov Entra tenant, then forwards
  it unchanged to Fabric, which performs its own authorization.

## Request routing

```
/{tenant}/{product}/graphql/{endpoint-name}  → Fabric GraphQL endpoint
/{tenant}/{product}/sql/{endpoint-name}      → Fabric SQL Analytics endpoint
```

## Repository layout

```
infra/
  stacks/
    shared/     # Foundation: RG, Log Analytics, WAF, App Gateway, APIM, global JWT policy
    tenant/     # Per-tenant/product APIM APIs, operations, backends, API policies
                #   (reads the shared stack via terraform_remote_state)
  modules/
    apim/  app-gateway/  waf-policy/  network/
  params/
    <env>/      # dev | test — common.tfvars + shared.tfvars + tenants/**/tenant.tfvars
    apim/       # global_policy.xml + templates/*.xml.tftpl (API policy templates)
  scripts/
    deploy-terraform.sh   # public entrypoint (plan/apply/destroy)
    deploy-scaled.sh      # internal stack engine (orchestrates shared → tenant)
  .tflint.hcl
.github/workflows/        # infra (reusable), infra-lint, infra-manual, pr
```

**Two stacks, ordered:** `shared` is applied first and exports `apim_id`, `apim_name`,
etc.; `tenant` consumes that via `terraform_remote_state`. On `destroy` the order
reverses (tenant → shared). The deploy script enforces this ordering.

## Prerequisites

- Terraform `>= 1.12`
- Azure CLI authenticated (`az login`), or OIDC in CI
- An Azure Storage account + container for remote Terraform state
- An existing VNet/subnet for App Gateway (and APIM, if VNet injection is enabled),
  or set `shared_config.network` to have the network module carve subnets for you

## Deploy

All commands run from `infra/`.

```bash
# Remote-state backend coordinates (export before running locally):
export BACKEND_RESOURCE_GROUP="<state-rg>"
export BACKEND_STORAGE_ACCOUNT="<state-storage-account>"
# BACKEND_CONTAINER_NAME defaults to "tfstate"

# Provider auth for local runs (CI sets these as TF_VAR_* via OIDC):
export TF_VAR_subscription_id="<subscription-id>"
export TF_VAR_tenant_id="<azure-ad-tenant-id>"

./scripts/deploy-terraform.sh plan    dev
./scripts/deploy-terraform.sh apply   dev [--auto-approve]
./scripts/deploy-terraform.sh destroy dev [--auto-approve]
```

- `<env>` must be one of `dev`, `test`, `prod`.
- The wrapper auto-discovers `params/<env>/common.tfvars`, `params/<env>/shared.tfvars`,
  and every `params/<env>/tenants/**/tenant.tfvars`, and uses the `azurerm` backend
  with key `fabric-gateway/<env>/<stack>.tfstate`.

### Before your first deploy — fill in the placeholders

The committed `params/<env>/*.tfvars` carry **placeholders**. Replace these before
`apply` (none are secrets, but several are environment-specific):

| File | Value | What to set |
|------|-------|-------------|
| `shared.tfvars` | `app_gateway_subnet_id` | Real subnet resource ID (or enable `shared_config.network`) |
| `shared.tfvars` | `apim_subnet_id` | Required only when `apim.vnet_injection_enabled = true` |
| `shared.tfvars` | `bcgov_entra_tenant_id` | The BCGov Entra tenant UUID (validated as a UUID) |
| `shared.tfvars` | `app_gateway.ssl_certificate_name` | Set after uploading the TLS cert; enables the HTTPS listener + HTTP→HTTPS redirect |

Add tenants/products by copying `params/<env>/tenants/<name>/tenant.tfvars.example`
to `tenant.tfvars` and filling in the real Fabric workspace/item IDs. Real
`tenant.tfvars` files are git-ignored.

## CI/CD

- **`pr.yml`** — on every PR: lint (`fmt` + `validate` + `tflint` + bash checks) and a
  Terraform **plan** against `test`. PRs preview only; they do not apply.
- **`infra-manual.yml`** — `workflow_dispatch` to run `plan` or `apply` against a chosen
  environment. Use this to apply after a PR merges.
- CI authenticates via Azure OIDC (`id-token: write`) and passes config as `TF_VAR_*`.
  Required GitHub secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
  `BACKEND_RESOURCE_GROUP`. Required vars: `BACKEND_STORAGE_ACCOUNT`
  (`BACKEND_CONTAINER_NAME` optional, defaults to `tfstate`).

## Validation gates

From `infra/`:

```bash
terraform fmt -recursive
terraform validate          # per stack — see .github/workflows/.infra-lint.yml
tflint --recursive
```

## Further reading

- `AGENTS.md` — architecture, conventions, and the BC Gov working agreement.
- `.github/skills/` — agent profiles (`iac-coder`, `app-gateway`).
