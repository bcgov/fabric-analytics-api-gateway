# AGENTS.md

Guidance for AI coding agents working in **fabric-analytics-api-gateway**.

> Status: **draft / POC.** This repo exposes Microsoft Fabric data (GraphQL and SQL
> Analytics endpoints) through an Azure API gateway. Expect real hostnames,
> subscription/tenant IDs, and network identifiers to be **placeholders** unless a
> task says otherwise — never guess them.

## What this repo does

Terraform IaC that stands up an Azure-native gateway in front of Microsoft Fabric:

- **Azure API Management (StandardV2)** — fronts Fabric GraphQL & SQL Analytics endpoints.
- **Application Gateway + WAF policy** — public ingress to APIM.
- **Log Analytics** — diagnostics for APIM and App Gateway.
- **BCGov Entra JWT validation** — a global APIM policy validates that every inbound
  `Authorization: Bearer` token is issued by the BCGov Entra tenant, then forwards it
  unchanged to Fabric, which performs its own authorization.

Request routing:

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
    apim/  app-gateway/  waf-policy/
  params/
    <env>/      # dev | test — shared.tfvars + tenants/**/tenant.tfvars
    apim/       # global_policy.xml + templates/*.xml.tftpl (API policy templates)
  scripts/
    deploy-terraform.sh   # single deploy script: plan / apply / destroy / import
  .tflint.hcl
.github/
  workflows/    # detect-changes, infra, infra-lint, infra-manual, pr, builds
  skills/       # iac-coder, app-gateway (agent profiles)
```

**Two stacks, ordered:** `shared` is applied first and exports `apim_id` etc.; `tenant`
consumes that remote state. On `destroy` the order reverses (tenant → shared).

## Build / deploy

All commands run from `infra/`. Requires Terraform `>= 1.12` and Azure auth (OIDC in CI).

```bash
# Backend state config (export before running locally):
export BACKEND_RESOURCE_GROUP="<state-rg>"
export BACKEND_STORAGE_ACCOUNT="<state-storage-account>"
# BACKEND_CONTAINER_NAME defaults to "tfstate"

./scripts/deploy-terraform.sh plan    dev
./scripts/deploy-terraform.sh apply   dev [--auto-approve]
./scripts/deploy-terraform.sh destroy dev [--auto-approve]
```

- `<env>` must be one of `dev`, `test`, `prod`.
- The wrapper auto-discovers `params/<env>/shared.tfvars` and every
  `params/<env>/tenants/**/tenant.tfvars`, and uses the `azurerm` backend with key
  `fabric-gateway/<env>/<stack>.tfstate`.
- CI passes config as `TF_VAR_*` env vars and authenticates via Azure OIDC
  (`id-token: write`). Do not commit secrets — use GitHub secrets/vars.

## Terraform conventions (authoritative — from `.github/skills/iac-coder`)

- **Locals live in `locals.tf`.** Never inline `locals {}` in `main.tf`. Every module and
  root has its own `locals.tf`, even if empty.
- **`variables.tf`:** sort `variable` blocks alphabetically. Every non-required variable
  must declare an explicit `default` (use `default = null`, never omit it).
- **Conditional resources:** never inline a boolean in `count = ...`. Compute it as a
  local (`local.deploy_thing = var.enable_thing ? 1 : 0`) and use `count = local.deploy_thing`.
  This avoids plan-time "unknown until apply" failures.
- Tag resources via `var.common_tags`; resources use `lifecycle { ignore_changes = [tags] }`.
- Providers: `azurerm` (`>= 4.38`) and `azapi` (`>= 2.5`), authenticated by the
  `subscription_id` / `tenant_id` / `client_id` / `use_oidc` variables.

## Validation gates (run when tools are available)

1. `terraform fmt -recursive` (from `infra/`)
2. `terraform validate` (from `infra/`)
3. `tflint` (config in `infra/.tflint.hcl` — azurerm rules, naming, required version/providers)
4. `bash -n infra/scripts/deploy-terraform.sh` when a script changes
5. Review workflow-call inputs, secrets, and OIDC assumptions for consistency

If a gate cannot be run, state exactly what was not run and why. Prefer minimal edits
scoped to the requested behavior, and update docs when structure or operator flow changes.

## Working agreement (BC Gov shared guardrails)

These rules come from the BC Gov shared Copilot guidance
([`bcgov/copilot-instructions`](https://github.com/bcgov/copilot-instructions),
authoritative file `.github/copilot-upstream.md`). They apply to every agent change here.

**Think & plan**
- State assumptions; if a request has multiple interpretations, list them before acting.
- Default to the simplest approach; propose simpler alternatives when you see one.
- **Fix first, ask second:** make the requested change, then ask before any broader
  refactor or enhancement. Never implement unrequested features.

**Implementation discipline**
- Touch only files in the logical path of the change; refactor only on real duplication.
- Match adjacent file style (naming, patterns); remove unused variables/imports.
- Verify in the terminal (`ls`, `git status`, the validation gates above) before reporting
  "Done" — never claim completion unverified.
- **Diff-as-receipt:** end every turn that edits files with the `git diff`, inside a
  collapsible `<details>` block.
- **Zero speculation:** verify APIs, resource arguments, and workflow triggers with tools
  (search, `terraform validate`, `--help`) — never guess.

**Hard stops (never)**
- Never branch from a feature branch — start from a fresh checkout of `main`.
- Never push to `main` or merge PRs; leave merging to humans.
- Never rewrite history (`git rebase -i`, `--autosquash`, `git merge --squash`).
- Never commit credentials, secrets, or PII; never commit local state
  (`.terraform-data/`, `*.tfstate`).
- Never silence diagnostics or linters (`# tflint-ignore`, `@ts-ignore`, etc.) — fix the
  root cause. Never delete a failing test/check to make it pass.
- Never impersonate or speak on behalf of a human in commits, PRs, or comments.
- Never run `oc` (OpenShift access is restricted).
- In Markdown output, wrap code/manifests in **four-backtick** blocks, not triple.

**Git workflow**
1. Branch: `git checkout main && git pull && git switch -c feat/name && git push -u origin feat/name`
2. Open PR: `git fetch origin && git rebase origin/main`, then push the feature branch
   (push and open PRs to feature branches without asking).
3. Close issues with `Closes #<n>` **only** when the number is given in the prompt or
   branch name — never guess issue numbers.

**Project standards**
- Conventional Commits; derive the scope from the primary directory changed
  (e.g. `feat(apim):`, `ci(workflows):`, `docs(infra):`). One commit = one logical change.
- Use latest stable package/provider versions; never downgrade or edit lock files silently.
- GitHub Actions run with **minimum necessary permissions** (this repo needs
  `contents: read` + `id-token: write` for OIDC — nothing broader).
- Don't mark work complete until it is verified, committed, pushed, and a PR is opened.

> **Recommended:** vendor `.github/copilot-upstream.md` into this repo so these guardrails
> load automatically in every agent session.

## BC Gov Azure Landing Zone — CRITICAL

Networking and DNS must follow BC Gov public-cloud guidance. Treat these as binding:

- https://raw.githubusercontent.com/bcgov/public-cloud-techdocs/refs/heads/main/docs/azure/design-build-deploy/networking.md
- https://raw.githubusercontent.com/bcgov/public-cloud-techdocs/refs/heads/main/docs/azure/design-build-deploy/next-steps.md
- https://github.com/bcgov/public-cloud-techdocs/blob/main/docs/azure/design-build-deploy/user-management.md

## Conventions for agents

- Use **placeholders**, not guessed values, for subscription/tenant/network/runtime IDs.
- Keep the **shared → tenant** stack boundary intact; the tenant stack must read shared
  outputs via remote state, not duplicate foundation resources.
- Add a new tenant/product by extending `params/<env>/tenants/**/tenant.tfvars` (the
  `tenants` variable map), not by hand-editing resource blocks.
- Match the existing module/stack structure and the conventions above before adding files.

## Companion skills (bcgov/agent-skills)

This repo's own agent profiles live in `.github/skills/` (`iac-coder` for infra work,
`app-gateway` for the App Gateway → APIM path). For domains the local skills don't cover,
defer to the BC Gov shared catalogue
[`bcgov/agent-skills`](https://github.com/bcgov/agent-skills) — reference it rather than
copying skills in:

| Task | Skill | Source |
|------|-------|--------|
| Terraform / Bash / workflow edits under `infra/` & `.github/` | `iac-coder` | local |
| Application Gateway listener / WAF / cert / APIM-backend work | `app-gateway` | local |
| Azure subnet, NSG, private-endpoint design | `azure-networking` | `bcgov/agent-skills` |
| GitHub Actions hardening — `permissions:`, pinning, fork-gate, Dependabot | `github-actions` | `bcgov/agent-skills` |

`openshift-deployment` from that catalogue is **not** applicable (Azure-native, no
OpenShift). List with `npx skills add bcgov/agent-skills --list`.

## References

- BC Gov shared Copilot guardrails — https://github.com/bcgov/copilot-instructions
  (always-on rules in `.github/copilot-upstream.md`; mirrored in `.github/copilot-instructions.md`)
- BC Gov shared agent skills catalogue — https://github.com/bcgov/agent-skills
- BC Gov Azure Landing Zone networking/DNS/user-management — see the three links above
- Repo-local agent profiles: `.github/skills/iac-coder/SKILL.md`, `.github/skills/app-gateway/SKILL.md`
