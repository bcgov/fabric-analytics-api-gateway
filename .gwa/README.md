# APS Gateway Scaffold Notes

This folder holds the API Program Services gateway configuration that should be versioned with the project.

## Current Scaffold Choices

- Single config file for the spike: `gw-config.yaml`.
- APS resource-based format.
- Gateway ID is set to `gw-3c77e`; route hostname and upstream DAB hostname are still placeholders.
- BC Gov SSO and Entra are both in scope, but their plugin configuration is intentionally left as a TODO until issuer and audience values are confirmed.

## Publish Flow

1. Install the `gwa` CLI.
2. Create or identify the target gateway with `gwa gateway create`.
3. Authenticate with a user or service account.
4. Confirm the gateway context is set to `gw-3c77e` with `gwa gateway current`.
5. Replace the placeholders in `gw-config.yaml`, especially the DAB upstream host and public route host.
6. Publish with `gwa apply -i gw-config.yaml`.
7. Verify with `gwa status` or `gwa status --hosts`.

## Notes From APS Docs

- APS recommends storing gateway config in a `.gwa/` directory and publishing it through CI or local `gwa` workflows.
- Every service, route, and plugin must include a `ns.<gatewayId>` tag.
- If the repo later splits environments, the tags can be qualified, for example `ns.<gatewayId>.dev` and `ns.<gatewayId>.prod`.
- If the spike eventually requires APS-managed SSL certificate resources for custom domains or upstream mTLS certificates at Kong, reassess whether Kong format is required instead of the resource-based format.
