---
name: iac-coder
description: Guidance for creating or modifying Terraform, Bash, and GitHub Actions files in this repository.
---

# IaC Coder

Use this skill profile when creating or modifying infrastructure code, Bash scripts, or GitHub workflows in this repository.

> **Before any change, load the repo working agreement in [`AGENTS.md`](../../../AGENTS.md).**
> It carries the BC Gov shared guardrails that apply to every edit here — fix-first
> (no unrequested features), touch only files in the change path, terminal-verify before
> "Done", diff-as-receipt, the branch → rebase → PR git workflow, Conventional Commits, and
> secrets/state hygiene. The authoritative source is
> [`bcgov/copilot-instructions`](https://github.com/bcgov/copilot-instructions)
> (`.github/copilot-upstream.md`).

## Use When

- Adding or modifying Terraform files under `infra/`
- Editing `infra/deploy-terraform.sh`
- Adding or modifying GitHub Actions workflows under `.github/workflows/`
- Wiring Azure OIDC placeholders, Terraform backend configuration, or validation workflows

## Do Not Use When

- Editing only APS route and plugin configuration under `.gwa/`
- Editing only the DAB facade configuration under `facade/`
- Doing documentation-only work unrelated to infra behavior
- **Designing Azure subnets, NSGs, or private endpoints** (APIM / App Gateway / Container
  Apps subnet layout, delegation, PE sizing) → defer to the **`azure-networking`** skill
  from [`bcgov/agent-skills`](https://github.com/bcgov/agent-skills). This skill covers the
  Terraform/Bash wiring around them, not the network design itself.
- **Hardening the GitHub Actions chassis** (`permissions:` scoping, action pinning,
  fork-gate, required-check aggregation, Dependabot) → defer to the **`github-actions`**
  skill from `bcgov/agent-skills`. Use this skill for the workflow's Terraform/deploy logic.

## Input Contract

Before making changes, verify:

- Which environment is in scope (`dev`, `test`, `tools`, or `prod`)
- Whether the work is scaffold-only or deployment-ready
- Whether the repo contains real hostnames, images, and landing-zone identifiers or only placeholders
- Whether a change affects the separation between APS control-plane config and Azure data-plane hosting

## Output Contract

Every change should deliver:

- Minimal Terraform, Bash, or workflow edits scoped to the requested behavior
- Updated documentation when the structure or operator flow changes
- Placeholders instead of guessed subscription, tenant, network, or runtime values
- Validation evidence or a clear note when validation could not be run locally

## Scope

- Terraform root and modules under `infra/`
- Bash wrapper under `infra/deploy-terraform.sh`
- Reusable and caller workflows under `.github/workflows/`
- Repo-local guidance in `.github/copilot-instructions.md` and `AGENTS.md`

## Authoritative References (Azure Landing Zone) - CRITICAL
Follow BC Gov Azure Landing Zone guidance for networking and DNS behavior. This is critical and must be followed:
- https://raw.githubusercontent.com/bcgov/public-cloud-techdocs/refs/heads/main/docs/azure/design-build-deploy/networking.md
- https://raw.githubusercontent.com/bcgov/public-cloud-techdocs/refs/heads/main/docs/azure/design-build-deploy/next-steps.md
- https://github.com/bcgov/public-cloud-techdocs/blob/main/docs/azure/design-build-deploy/user-management.md

## Companion Skills (bcgov/agent-skills)

This skill owns Terraform/Bash/workflow logic. Defer the adjacent domains to the shared
catalogue — reference it, don't copy skills in (the catalogue is the source of truth):

- **`azure-networking`** — subnet / NSG / private-endpoint patterns.
- **`github-actions`** — workflow hardening (permissions, pinning, fork-gate, Dependabot).

List or install with `npx skills add bcgov/agent-skills --list` /
`npx skills add bcgov/agent-skills --skill <name>`. `openshift-deployment` does not apply
to this Azure-native repo.

## Terraform Conventions

Follow these rules in every Terraform file in this repository:

### File layout
- Always place local values in a dedicated `locals.tf` file — never inline `locals {}` blocks inside `main.tf` or other files.
- Every module and the root must have its own `locals.tf` even if it starts empty.

### Variable declarations (`variables.tf`)
- Sort all `variable` blocks alphabetically by name.
- Every variable that is not required must have an explicit `default` value. Use `default = null` rather than omitting the `default` argument — omitting it makes the variable required, which breaks `terraform plan` when the caller does not supply it.

### Count and conditional resources
- Never inline a boolean expression directly in `count = ...`. Instead, compute the count as a local value in `locals.tf`:
  ```hcl
  # locals.tf
  locals {
    deploy_thing = var.enable_thing ? 1 : 0
  }
  ```
  ```hcl
  # main.tf
  resource "azurerm_something" "this" {
    count = local.deploy_thing
    ...
  }
  ```
  This prevents `terraform plan` failures caused by values that are not known until apply time.

## Validation Gates

Run these when tools are available:

1. `terraform fmt -recursive` from `infra/`
2. `terraform validate` from `infra/`
3. `bash -n infra/deploy-terraform.sh` when the script changes
4. Review workflow-call inputs, secrets, and OIDC assumptions for consistency

If a gate cannot be run, say exactly what was not run and why.
