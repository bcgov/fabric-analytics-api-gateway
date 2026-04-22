# DAB Facade

This folder captures the Data API Builder runtime contract for the Fabric tabular facade used in this repository.

## Files

- `Dockerfile`: packages the checked-in DAB config into an image based on the official Data API Builder container image.
- `dab-config.template.json`: template DAB config that reads `DB_TYPE` and `SQL_CONN_STRING` via `@env()`.
- `.env.example`: local-development example values for the same environment variables.

## Runtime Contract

- Use `dwsql` as `DB_TYPE` for the Fabric SQL analytics endpoint path in this repo.
- Keep the Fabric SQL endpoint host name without the `tcp:` prefix in the connection string.
- Keep `SQL_CONN_STRING` in a secret store or a secret-backed platform setting. In Azure Container Apps, this repo now injects it through an ACA secret-backed environment variable rather than a plain-text env value.
- The SQL analytics endpoint is read-only, so keep DAB entities read-oriented and prefer curated views or tables instead of exposing raw internal objects.

## How This Fits The Infra

- The Terraform Container Apps module under `infra/` now sets `DB_TYPE` as a regular environment variable for the DAB container.
- The same module injects `SQL_CONN_STRING` from the sensitive Terraform input `dab_sql_connection_string` into an ACA secret-backed environment variable.
- The `Dockerfile` in this folder packages the checked-in config into a DAB image by copying `dab-config.template.json` to `dab-config.json`, which matches DAB's default startup expectation.
- Build the image from the repository root with `docker build -f dab/Dockerfile -t <your-registry>/<your-image>:<tag> .`.

## Next Steps

1. Replace the placeholder entity in `dab-config.template.json` with the curated Fabric table or view you actually want to publish.
2. Set a real `SQL_CONN_STRING` value through your deployment secret mechanism rather than committing it.
3. Keep the DAB facade read-focused unless the Fabric access model changes.
