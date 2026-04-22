# Copilot Instructions for fabric-analytics-api-gateway

## Repository Boundaries

- Treat `.gwa/` as APS control-plane configuration.
- Treat `infra/` as Azure data-plane hosting scaffold.
- Do not claim the repository contains a runnable Kong SDX Edge Runtime unless an actual runtime package, image build, or deployment artifact is added.

## No Assumptions

- Use repository files or authoritative documentation for every infrastructure or platform claim.
- Keep placeholder values explicit when tenant IDs, subscription IDs, hostnames, or image references are not yet known.
- Preserve the distinction between current APS test-host behavior and the future Azure Front Door target architecture.

## Documentation Sync

- If you change `infra/`, update `infra/README.md` and the root `README.md` in the same change.
- If you change `.gwa/`, update `.gwa/README.md` when the publication flow or host behavior changes.
- If you change `facade/`, update `facade/README.md` when DAB responsibilities, auth assumptions, or Fabric constraints change.

## Validation Expectations

- For Terraform changes, prefer `terraform fmt -recursive` and `terraform validate` from `infra/` when Terraform is available.
- For Bash changes, run `bash -n` on modified scripts when Bash is available.
- Keep reusable workflows under `.github/workflows/` and use OIDC placeholders rather than hardcoded credentials.

## Repo Skills

- Use `.github/skills/iac-coder/SKILL.md` for Terraform, Bash, and workflow work.
- Use `.github/skills/app-gateway/SKILL.md` for Azure Application Gateway listener, rewrite, certificate, WAF, and private-DNS work.
- Use `.github/skills/aps-gateway/SKILL.md` for APS gateway config work.
- Use `.github/skills/fabric-dab/SKILL.md` for DAB and Fabric facade work.
