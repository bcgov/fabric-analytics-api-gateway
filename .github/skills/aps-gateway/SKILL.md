---
name: aps-gateway
description: Guidance for working on APS gateway publication config and operator notes in this repository.
---

# APS Gateway

Use this skill profile when working on the APS-side gateway publication scaffold.

## Use When

- Editing `.gwa/gw-config.yaml`
- Editing `.gwa/README.md`
- Updating docs that describe APS route publication, gateway tags, or plugin strategy

## Do Not Use When

- Editing Azure Terraform infrastructure under `infra/`
- Editing only DAB runtime configuration under `facade/`

## Required Facts

- APS resources must carry the correct `ns.<gatewayId>` tag
- The current gateway ID in this repo is `gw-3c77e`
- The route host configured in APS test may be translated into a derived `test.api.gov.bc.ca` hostname
- The route host is not the same thing as the upstream service host

## Output Contract

Every APS change should preserve:

- Resource-based gateway YAML unless there is a proven need to switch formats
- Explicit TODOs where issuer, audience, or auth-plugin details are still unknown
- Clear distinction between public route host, test-host translation, and upstream host

## Validation Gates

1. Confirm the gateway tag remains consistent across service, route, and plugins
2. Validate YAML syntax through editor diagnostics when available
3. Update `.gwa/README.md` when publication flow or host behavior changes
