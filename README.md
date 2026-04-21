# fabric-analytics-api-gateway

Spike scaffold for exposing Microsoft Fabric data through the BC Government API Program Services gateway, with Kong SDX Edge Runtime running on Azure Container Apps behind Azure Front Door.

## Status

Draft / PoC scaffold.

This repository now captures the architecture, trade-offs, and initial APS gateway configuration shape for a pilot that keeps the data plane in Azure Canada Central while using APS as the API control plane.

## Problem Statement

The spike is testing whether APS Kong SDX Edge Runtime is a better fit than Azure API Management for exposing Fabric-backed analytics and geospatial-style data products to BC Government and partner consumers.

The current working architecture is:

- Azure Front Door for public ingress, WAF, TLS, and IP controls.
- Kong SDX Edge Runtime deployed in Azure Container Apps inside the spoke VNet.
- A Data API Builder (DAB) service for tabular REST and GraphQL reads over Fabric.
- A thin custom sibling service only if spatial, OGC, or tile-specific behavior is required.
- Private connectivity from DAB and any optional spatial service to the Fabric SQL Analytics Endpoint.
- BC Gov SSO and Microsoft Entra ID both in scope for consumer authentication.

## Facade Decision

- DAB is the chosen tabular facade for the spike.
- The Fabric connection pattern uses `database-type` `dwsql`, an Entra-based connection string, and no `tcp:` prefix in the Fabric server name.
- The SQL analytics endpoint is read-only, so the DAB surface should stay read-focused.
- Spatial, OGC, and tile-specific requirements remain outside DAB and stay in scope for a separate thin service only if needed.

## Terraform Note

- The current Terraform root under `infra/` wires the `network`, `monitoring`, `container-apps`, and `frontdoor` modules directly.
- The `container-apps` module now scaffolds separate Kong Edge Runtime and Data API Builder workloads inside the same Azure Container Apps environment.
- The Kong workload now defaults to the published APS SDX runtime image `ghcr.io/bcgov/aps-devops/sdx-access-point:3.9-57ca71e3`, derived from the `sdx-edge` Helm chart `oci://ghcr.io/bcgov/aps-devops/sdx-edge:0.1.0`.
- The Azure Container Apps scaffold expects SDX runtime-group metadata and PEM certificate material as inputs; it does not yet model the Helm chart's Kubernetes bootstrap and renewal jobs.
- The root Terraform input surface has been trimmed to the current Kong plus DAB scaffold and no longer carries the reverted backend/Postgres placeholders.


