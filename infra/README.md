# Infrastructure Scaffold

This folder contains the Terraform scaffold for the Azure data-plane side of the Fabric analytics gateway spike.

## Current Modules

- `network`: derives and provisions a Container Apps subnet plus a private-endpoint subnet inside an existing VNet.
- `monitoring`: provisions Log Analytics and Application Insights.
- `container-apps`: provisions the shared Azure Container Apps environment and optional Kong Edge Runtime and Data API Builder container apps.
- `frontdoor`: provisions Azure Front Door profile resources, diagnostics, and WAF policy scaffolding.

## Current Container Apps Shape

- Kong Edge Runtime and DAB are modeled as separate container apps in the same managed environment.
- The managed environment keeps internal load balancing enabled and supports a private endpoint when a private-endpoint subnet ID is supplied.
- Log Analytics wiring is used for environment diagnostics and app log configuration.
- The Kong app now defaults to the published APS SDX runtime image `ghcr.io/bcgov/aps-devops/sdx-access-point:3.9-57ca71e3`, based on the `sdx-edge` Helm chart `oci://ghcr.io/bcgov/aps-devops/sdx-edge:0.1.0`.
- The Kong app mounts SDX route-host, control-plane, CA, and certificate material using Container Apps secrets and an init container that renders the expected file layout before the runtime starts.
- The Kubernetes-specific certificate bootstrap and renewal jobs from the Helm chart are not modeled in this Terraform scaffold; PEM material must be supplied to the Container App deployment out-of-band.
- Root Terraform variables are aligned to the current Kong and DAB scaffold rather than the reverted backend/Postgres placeholder shape.

## Validation

Run these from `infra/` when Terraform is available:

1. `terraform fmt -recursive`
2. `terraform init -backend=false`
3. `terraform validate`
