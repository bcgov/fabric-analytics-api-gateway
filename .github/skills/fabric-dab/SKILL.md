---
name: fabric-dab
description: Guidance for working on the Data API Builder facade and Fabric SQL analytics assumptions in this repository.
---

# Fabric DAB

Use this skill profile when editing the DAB facade configuration or related documentation.

## Use When

- Editing `facade/dab-config.template.json`
- Editing `facade/.env.example`
- Editing `facade/README.md`
- Updating docs that describe DAB, Fabric SQL analytics, or the tabular facade boundary

## Do Not Use When

- Editing only APS gateway route and plugin configuration
- Editing only Terraform infrastructure under `infra/`

## Required Facts

- DAB uses `dwsql` for the Fabric SQL analytics endpoint path in this repo
- The Fabric server name should not use a `tcp:` prefix
- The SQL analytics endpoint is read-only
- Documented DAB OBO support does not apply to `dwsql`
- Kong vs DAB JWT validation is still an explicit design decision, not a settled fact

## Output Contract

Every DAB change should preserve:

- Read-oriented API assumptions unless the Fabric access model changes
- Explicit placeholder values for hostnames, connection strings, and entities when they are not yet known
- The distinction between curated SQL views and richer spatial or OGC behavior that may still need a sibling service

## Validation Gates

1. Validate JSON syntax for `facade/dab-config.template.json`
2. Update `facade/README.md` when responsibilities or constraints change
3. Keep DAB constraints aligned with the root `README.md` and `docs/architecture.md`
