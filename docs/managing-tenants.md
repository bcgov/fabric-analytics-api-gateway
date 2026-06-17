# Managing tenants and endpoints

The gateway exposes Microsoft Fabric **GraphQL** and **SQL Analytics** endpoints
through APIM, organized by *tenant* and *product*. This guide walks through adding a
new tenant and adding or updating endpoints on an existing one.

## How the model maps to URLs

```
tenants
└── <tenant>            # e.g. citz-eo-dmi-om  → first URL segment
    └── products
        └── <product>   # e.g. dmi             → second URL segment
            ├── graphql_endpoints[]        # each → /{tenant}/{product}/graphql/{name}
            └── sql_analytics_endpoints[]  # each → /{tenant}/{product}/sql/{name}
```

So a request routes like this:

```
POST /{tenant}/{product}/graphql/{endpoint-name}   → Fabric GraphQL backend
POST /{tenant}/{product}/sql/{endpoint-name}        → Fabric SQL Analytics backend
```

APIM checks that the inbound `Authorization: Bearer` token comes from the BCGov
Entra tenant, then forwards it to Fabric unchanged. Fabric handles its own
authorization from there (see
[client-authentication.md](client-authentication.md)).

## Config schema

You define a tenant in a `tenant.tfvars` file, as one entry in the `tenants` map:

```hcl
tenants = {
  "citz-eo-dmi-om" = {
    tenant_name  = "citz-eo-dmi-om"   # must equal the map key
    display_name = "CITZ EO DMI"
    enabled      = true               # set false to remove the tenant's APIs without deleting the file

    products = {
      "dmi" = {
        display_name          = "DMI Fabric Analytics"
        description           = "Fabric endpoints for CITZ EO DMI"
        subscription_required = false  # true → callers also need an APIM subscription key

        # Fabric GraphQL endpoints — one APIM backend each.
        graphql_endpoints = [
          {
            name        = "fabric"   # URL segment → /citz-eo-dmi-om/dmi/graphql/fabric
            backend_url = "https://<workspace-id>.<zone>.graphql.fabric.microsoft.com/v1/workspaces/<workspace-id>/graphqlapis/<api-id>/graphql"
            description = "CITZ EO DMI Fabric GraphQL API"
          },
        ]

        # Fabric SQL Analytics endpoints (Lakehouse/Warehouse SQL endpoint).
        sql_analytics_endpoints = [
          # {
          #   name        = "reporting"   # → /citz-eo-dmi-om/dmi/sql/reporting
          #   backend_url = "https://<workspace-id>.datawarehouse.fabric.microsoft.com"
          #   description = "Reporting warehouse"
          # },
        ]
      }
    }
  }
}
```

### Backend URL formats

| Type | `backend_url` shape |
|------|---------------------|
| Fabric GraphQL | `https://<wsid>.<zone>.graphql.fabric.microsoft.com/v1/workspaces/<wsid>/graphqlapis/<api-id>/graphql` (copy the exact POST URL from the Fabric GraphQL API page) |
| Fabric SQL Analytics | `https://<wsid>.datawarehouse.fabric.microsoft.com` (the SQL connection/endpoint host) |

The `backend_url` is **configuration, not a secret** — it's just resource GUIDs, and
access is gated by the JWT plus Fabric's own authorization. Even so, we keep it out
of the repo, and it's redacted in `terraform plan` output via `sensitive()`.

## Where tenant config lives

Real `tenant.tfvars` files are **never committed** — `**/tenants/**/tenant.tfvars`
is git-ignored. Instead, they live as blobs in the Terraform **state storage
account** (a public data plane, so no private endpoint needed), and the deploy
script pulls them down at apply time. That keeps Fabric endpoints out of both the
repo *and* GitHub secrets. (We avoided Key Vault here because its private endpoint
isn't reachable by the deploy identity; the state storage account's data plane is
publicly reachable, which sidesteps the problem.)

```
state storage account
└── container: tenant-config
    └── <env>/<tenant>.tfvars        # e.g. test/citz-eo-dmi-om.tfvars
```

The deploy script (`deploy-terraform.sh`) reads `TENANT_CONFIG_CONTAINER` and
downloads every `<env>/*.tfvars` blob, alongside any local
`params/<env>/tenants/**/tenant.tfvars` (handy for local-only iteration).

> **Guard:** if **no** tenant config turns up (no blob and no local file), the
> tenant stack is **skipped** — it's never applied with `tenants = {}`, which would
> otherwise destroy existing tenant APIs. To remove a tenant on purpose, see
> *Remove a tenant or endpoint* below.

## Add a new tenant

1. **Get the Fabric endpoint.** In Fabric, open the GraphQL API (or SQL endpoint)
   and copy the full POST URL.

2. **Create the tfvars** at `infra/params/<env>/tenants/<tenant>/tenant.tfvars`
   using the schema above (this path is git-ignored).

3. **Upload it to the config container** so CI — and other operators — can use it:

   ```bash
   # State storage account coordinates (test shown as example):
   STATE_RG="b9cee3-test-networking"
   STATE_SA="tftestfabricanalyticsapi"
   ENV="test"; TENANT="citz-eo-dmi-om"

   KEY=$(az storage account keys list -g "$STATE_RG" -n "$STATE_SA" --query '[0].value' -o tsv)

   az storage container create --account-name "$STATE_SA" --name tenant-config --account-key "$KEY"

   az storage blob upload \
     --account-name "$STATE_SA" --container-name tenant-config \
     --name "$ENV/$TENANT.tfvars" \
     --file "infra/params/$ENV/tenants/$TENANT/tenant.tfvars" \
     --overwrite --account-key "$KEY"
   ```

4. **Apply** (from `infra/`, with `TENANT_CONFIG_CONTAINER=tenant-config` and the
   backend/auth env exported — see the main [README](../README.md#deploy)):

   ```bash
   ./scripts/deploy-terraform.sh apply <env>          # local
   # or merge a PR → CI applies via .github/workflows/.infra.yml
   ```

5. **Get the client URL** (the AFD hostname plus the route path):

   ```bash
   terraform -chdir=stacks/shared output front_door_endpoint_hostname
   # → https://<that-host>/<tenant>/<product>/graphql/<endpoint-name>
   ```

## Add or update endpoints on an existing tenant

1. Edit the tenant's `tenant.tfvars` — append to `graphql_endpoints` (or
   `sql_analytics_endpoints`). Each new object's `name` becomes a new URL segment:

   ```hcl
   graphql_endpoints = [
     { name = "fabric",    backend_url = "https://…/graphql", description = "…" },
     { name = "reporting", backend_url = "https://…/graphqlapis/<other-id>/graphql", description = "…" },
   ]
   # → adds POST /{tenant}/{product}/graphql/reporting
   ```

2. **Re-upload the blob** (same `az storage blob upload … --overwrite` as above).

3. **Apply.** Terraform adds only the new APIM backend + routing; existing endpoints
   are left untouched.

To add a whole new **product** to a tenant, add a new key under `products` with its
own endpoint lists.

## Remove a tenant or endpoint

- **Remove an endpoint/product:** delete it from the tfvars, re-upload, apply.
  Terraform destroys just that backend/API.
- **Disable a tenant (keep config):** set `enabled = false`, re-upload, apply.
- **Remove the last tenant entirely:** because the empty-config guard skips the
  tenant stack, run a targeted destroy instead, e.g.
  `./scripts/deploy-terraform.sh destroy <env>` (tears down tenant then shared), or
  remove the specific resources with another tenant still present.

## Validate before applying

```bash
cd infra
terraform fmt -recursive
./scripts/deploy-terraform.sh plan <env>   # review: new backends/APIs to add
```

Endpoint URLs are exposed as non-sensitive outputs for convenience:

```bash
terraform -chdir=stacks/tenant output graphql_endpoint_urls
terraform -chdir=stacks/tenant output sql_endpoint_urls
```
