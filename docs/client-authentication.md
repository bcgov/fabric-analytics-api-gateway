# Client authentication — getting a token

Every request to the gateway needs an `Authorization: Bearer <token>` header. For
that token to be accepted — and for Fabric to actually return data — it has to
clear two bars:

1. **Issued by the BCGov Entra tenant.** APIM checks the issuer and accepts both
   the v1.0 (`sts.windows.net/<tenant>/`) and v2.0
   (`login.microsoftonline.com/<tenant>/v2.0`) forms.
2. **Valid for Fabric** — audience `https://analysis.windows.net/powerbi/api`.
   APIM forwards the token to Fabric untouched, and Fabric runs its **own**
   authorization. So the calling identity also needs access to the Fabric
   workspace / GraphQL API.

> **The gateway only proves *who issued* the token — Fabric decides who may read
> the data.** Granting Fabric access (below) isn't optional: a perfectly valid
> token with no Fabric permission comes back as a Fabric-level error, not a
> gateway 401.

**Scope to request:** `https://analysis.windows.net/powerbi/api/.default` (v2
endpoint) — equivalently, resource `https://analysis.windows.net/powerbi/api`.

For quick interactive or dev testing,
`az account get-access-token --resource https://analysis.windows.net/powerbi/api`
is fine. Production workloads should use one of the flows below.

> **Authorization lives inside Fabric, not at the gateway.** Everything — including
> Row-Level Security (RLS) and Column-Level Security (CLS) — is enforced at the
> Fabric workspace level, so each user or service principal sees only the data it's
> been granted. The flows below cover *authentication* (proving identity); it's the
> Fabric grant (Flow A, step 3) that actually lets a call return data.

**Which flow do you need?**

- Running **on Azure** (App Service, Functions, Container Apps, AKS, VMs/VMSS) →
  **Flow B** (managed identity).
- Running **anywhere else** — on-prem, other clouds, COTS, CI systems,
  Kong-fronted services → **Flow A** (Entra app registration).

---

## BC Gov tenant: how identities are provisioned (read this first)

The token mechanics below are standard OAuth2. What's changed is **how you get the
Entra app registration in the BC Gov tenant** — so start here before you build.

- **Self-service app registration is no longer allowed by default.** You can't
  create an Entra app registration / service principal straight from the Entra
  admin center or `az ad app create` anymore — not without being granted temporary
  permission first. The portal and CLI steps still work, but **only inside the
  access-package window** described in Flow A, step 1.

- **Authentication for Fabric GraphQL endpoints** — this gateway exposes Fabric
  GraphQL endpoints for clients hosted *outside* Fabric (apps, APIs, Kong-fronted
  integration layers — not notebooks or pipelines inside a workspace).
  Two authentication patterns apply:
  1. **End-user (delegated) token** — an IDIR/Entra user signs in and the client
     calls Fabric on the user's behalf (including on-behalf-of / OBO from a
     backend). Use this where row-level / user-scoped authorization matters.
  2. **Service principal (client credentials)** — an Entra app registration with a
     client secret or certificate, for service-to-service / unattended workloads.
     The SP is added to the Fabric workspace and granted item-level permissions
     (e.g. *Read all data using Fabric GraphQL API*).

- **Managed Identity is still valid for workloads that run on Azure.** When the
  caller runs on Azure (App Service, Functions, Container Apps, AKS, VMs/VMSS), it
  can acquire the Fabric token through its managed identity. The **Azure platform
  issues the token**, so there's **no app registration to create and no IDMS access
  package to request**. That's why MI sits *outside* the access-package process —
  the IDMS engagement scoped the app-registration path for **non-Azure / external**
  callers — not because it's off-limits. A managed identity **is a service
  principal**, so its Fabric grant is identical to Flow A, step 3.

> **One app registration can hold both delegated and application permissions.** A
> single registration from Flow A can back *both* the end-user (delegated / OBO)
> and the service-principal (client-credentials) flows — you don't need a separate
> app per pattern. The one open question IDMS flagged is whether the *same*
> permission can be held both ways (application *and* delegated) on one app; if you
> hit that specific case, you may need a second registration. Otherwise, one
> registration with the right mix of delegated + application permissions is enough.

---

## Flow A — Entra app registration (delegated and/or application)

Use this for any caller that needs its own Entra app registration — i.e. anything
**not** running on Azure (on-prem, other clouds, COTS, CI systems, Kong-fronted
services). A single registration from the access package below can back **either or
both** of these token flows:

- **Application token (client credentials)** — the app authenticates *as itself* (a
  service principal) for unattended, service-to-service workloads. OAuth2
  **client-credentials** grant; the token's identity is the SP. Non-delegated.
- **Delegated / on-behalf-of (OBO) token** — an IDIR/Entra user signs in and the
  app calls Fabric *on the user's behalf*. OAuth2 **authorization-code** (or **OBO**)
  grant; the token's identity is the user. Use where row-/user-scoped authorization
  matters.

Set delegated permissions, application permissions, or **both** on the same
registration to match the consuming product (step 1). The matching token sub-flows
are in step 2.

### 1. Get an Entra app registration (via the IDMS access package)

In the BC Gov tenant, you request a **time-boxed access package** from IDMS that
temporarily lets you create app registrations. Here's the flow:

1. **Request the access package.** IDMS sends a request link; you answer a few
   questions (one is a justification for the access) and submit. Keep your answers
   **short** — the questions have character limits, and an over-long answer fails
   **silently** with no error.
2. **IDMS approves.** Approval opens a **one-hour window** to create the app
   registration(s) you need. There's **no cap** on how many you create in that
   window — just the one hour. Tell IDMS up front which apps you're creating and
   why, and supply the supporting documentation.
3. **Create the app, then set an owner right away.** Build the registration (portal
   or CLI) inside the hour. **Assign an owner immediately** — once you (or a
   security group) own the app, the one-hour limit no longer applies and you can
   edit it freely. The access package itself is **assigned to an individual** (not a
   group), but a **security group can own or review** the resulting apps. The
   NRIDS/EO-DMI Fabric service-owner group gives IDMS the list of named individuals
   who'll request packages.
4. **Re-request whenever you need to.** Out of time, or need more apps weeks later?
   Re-request the same access package — answer the short questions again for a fresh
   one-hour block.

**Naming conventions:** follow the convention IDMS provides. BC Gov Entra naming is
**ministry + environment + application name/function** — there's **no
hosting-platform segment**, since every registration lives in Entra.

**Accounts:** create and manage these registrations with your **normal named
account**. Cloud-only accounts aren't the established pattern here.

Create it in the portal (Entra admin center → **App registrations** → **New
registration**), or with the CLI **inside the granted window**:

```bash
APP_ID=$(az ad app create --display-name "fabric-gateway-client-<consumer>" --query appId -o tsv)
az ad sp create --id "$APP_ID"
az ad app credential reset --id "$APP_ID" --append --query password -o tsv   # the client secret
```

Record the **Application (client) ID**, the **Directory (tenant) ID**, and the
credential value.

**Credentials:** IDMS prefers a **certificate** over a client secret for
production. Store credentials in **Key Vault** and rotate them — confirm the
rotation cadence and Key Vault pattern with IDMS for your data class.

**API permissions and admin consent:**

- For the plain client-credentials path to `powerbi/api/.default`, Fabric
  authorizes the service principal through its **tenant setting + workspace roles**
  (step 3), not a Graph/Power BI API-permission grant. So a basic SP that's been
  added to the workspace can call the endpoint without an explicit
  application-permission grant.
- If your design **does** need application-level API permissions, those require
  **Global Admin** consent — IDMS can't grant application-level admin consent
  themselves. **Delegated** permissions have more leeway and IDMS can handle them
  directly. Application permissions need a documented justification.
- Before you lean on automation, check the **Fabric application-permissions
  checklist** (kept internally by the Fabric service team) — a CI/CD step validates
  the SP's permissions on every run and tells you what will and won't work.

> **Conditional Access:** every new app registration gets the **default CA policy
> (basic MFA)** automatically. Anything beyond that — e.g. data-class policies for
> Class B / Class C content — is added **after the fact by IDMS**, not self-serve,
> and the tenant caps how many CA policies it can hold. Raise any special CA,
> auditing, or access-review needs with IDMS separately.

### 2. Acquire a token

Pick the sub-flow that matches the identity the call should carry. Both request the
same scope (`…/powerbi/api/.default`) and return a token with audience
`https://analysis.windows.net/powerbi/api`.

#### 2a. Application token (client credentials) — non-delegated

The token's identity is the **service principal**.

```bash
curl -X POST "https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=<CLIENT_ID>" \
  -d "client_secret=<CLIENT_SECRET>" \
  -d "scope=https://analysis.windows.net/powerbi/api/.default"
# → { "access_token": "eyJ…", "token_type": "Bearer", "expires_in": 3599 }
```

SDK equivalent (cache and reuse the token until it expires):

```python
from azure.identity import ClientSecretCredential
cred  = ClientSecretCredential(tenant_id="<TENANT_ID>", client_id="<CLIENT_ID>", client_secret="<SECRET>")
token = cred.get_token("https://analysis.windows.net/powerbi/api/.default").token
```

```csharp
var cred  = new ClientSecretCredential("<TENANT_ID>", "<CLIENT_ID>", "<SECRET>");
var token = cred.GetToken(new TokenRequestContext(
                new[] { "https://analysis.windows.net/powerbi/api/.default" })).Token;
```

> Using a **certificate** credential (IDMS-preferred for production)? Swap
> `ClientSecretCredential` for `CertificateCredential` — same scope.

#### 2b. Delegated / on-behalf-of (OBO) token

The token's identity is the **signed-in user**. Two common shapes:

**Interactive sign-in (authorization-code / PKCE)** — the user authenticates and
the client gets a delegated token directly. Request scope
`https://analysis.windows.net/powerbi/api/.default` (delegated). With MSAL, the
client drives the standard auth-code redirect; a public client needs no app secret.

**On-behalf-of (OBO)** — a backend that already holds the user's incoming Entra
token exchanges it for a downstream Fabric token, so the call to Fabric still
carries the *user's* identity:

```bash
curl -X POST "https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
  -d "client_id=<CLIENT_ID>" \
  -d "client_secret=<CLIENT_SECRET>" \
  -d "assertion=<INCOMING_USER_ACCESS_TOKEN>" \
  -d "scope=https://analysis.windows.net/powerbi/api/.default" \
  -d "requested_token_use=on_behalf_of"
# → a delegated token whose identity is the original user
```

> Delegated/OBO calls are authorized in Fabric against the **user's** workspace
> access, not the service principal's (see step 3).

### 3. Grant access to Fabric

Fabric authorizes whichever **identity the token carries**, so grant access to the
right principal for the flow you're using:

- **Application token (2a):** the **service principal** needs the access.
- **Delegated / OBO token (2b):** the **signed-in user** needs the access — the
  *"Service principals can use Fabric APIs"* tenant setting doesn't apply to the
  user path.

This is done by a **Fabric/Power BI admin** and a **workspace admin**:

1. **Tenant setting (application/SP path only):** enable *"Service principals can
   use Fabric APIs"* (Fabric Admin portal → Tenant settings), ideally scoped to a
   security group; add the app's service principal to that group.
2. **Workspace access:** add the service principal *and/or* the user (or their
   groups) to the Fabric workspace with a role that can read the GraphQL API / data
   (e.g. Viewer or Member), and grant access to the GraphQL API item and the
   underlying data source.

> A token whose identity **isn't** in the target workspace yet returns a
> Fabric-level error (a 200 with no data, or an authorization error) — not a gateway
> 401. Adding that SP **or user** to the workspace fixes it.

---

## Flow B — Managed identity (Azure-originating workloads)

Use this when the **request originates from Azure** (App Service, Functions,
Container Apps, AKS, VMs/VMSS). The Azure platform issues the token, so there are
**no secrets to manage and no app registration / access package to request** —
which is exactly why this flow is independent of the IDMS access-package process in
Flow A. A managed identity is a service principal, so the Fabric grant (step 2) is
the same as Flow A, step 3.

### 1. Enable a managed identity

- **System-assigned:** turn it on for the resource (e.g. App Service → Identity →
  On), or in IaC.
- **User-assigned:** create one, assign it to the resource, and note its client ID.

### 2. Grant the managed identity access to Fabric

A managed identity **is a service principal**, so the grant is the same as Flow A
step 3: include the MI in the Fabric *"service principals can use Fabric APIs"*
group and add it to the Fabric workspace / GraphQL API.
(Find the MI's object id with `az <resource> identity show`, or from the resource's
Identity blade.)

### 3. Acquire a token

**SDK (recommended)** — `DefaultAzureCredential` picks up the MI automatically:

```python
from azure.identity import DefaultAzureCredential
token = DefaultAzureCredential().get_token(
    "https://analysis.windows.net/powerbi/api/.default").token
```

```csharp
var token = new DefaultAzureCredential().GetToken(new TokenRequestContext(
    new[] { "https://analysis.windows.net/powerbi/api/.default" })).Token;
```

For a **user-assigned** MI, pass its client id, e.g.
`DefaultAzureCredential(managed_identity_client_id="<UAMI_CLIENT_ID>")` (Python) /
`new DefaultAzureCredential(new DefaultAzureCredentialOptions { ManagedIdentityClientId = "<id>" })`.

**Raw HTTP** (no SDK):

```bash
# App Service / Functions / Container Apps (uses the injected identity endpoint):
curl "$IDENTITY_ENDPOINT?resource=https://analysis.windows.net/powerbi/api&api-version=2019-08-01" \
  -H "X-IDENTITY-HEADER: $IDENTITY_HEADER"

# VM / VMSS (IMDS); add &client_id=<UAMI_CLIENT_ID> for a user-assigned identity:
curl "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://analysis.windows.net/powerbi/api" \
  -H "Metadata: true"
```

---

## Call the gateway

First, get the public hostname (Front Door):

```bash
terraform -chdir=infra/stacks/shared output front_door_endpoint_hostname
```

Then make the call:

```bash
curl -X POST "https://<afd-hostname>/<tenant>/<product>/graphql/<endpoint>" \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"query":"query { ... }"}'
```

The token's path is: **client → Front Door (WAF) → APIM (issuer + Front-Door check)
→ Fabric**. You never send the `X-Azure-FDID` header yourself — Front Door injects
it.

---

## Troubleshooting

| Symptom | Likely cause |
|--------|--------------|
| `401 Unauthorized — a valid BCGov Entra ID token is required` | Token missing/expired, wrong tenant, or wrong audience. Re-acquire with scope `…/powerbi/api/.default`. |
| `403` from the WAF | Calling from a non-Canada IP (geo rule), missing/non-`Bearer` `Authorization` header, or hitting APIM directly instead of via Front Door (FDID lock). Call the AFD hostname from an allowed region. |
| `404` (HTML, `x-azure-ref`, `CONFIG_NOCACHE`) | Front Door edge config still propagating after a route/WAF change — wait ~5–10 min and retry. |
| `404` JSON `{"error":"GraphQL endpoint not found"}` | Wrong `{endpoint-name}` in the path — must match an endpoint `name` in the tenant config. |
| Fabric-level error (e.g. 401/403 from Fabric, not the gateway message) | The identity lacks Fabric workspace / GraphQL API access — complete the Fabric grant (Flow A step 3). |
| Token has `"ver":"1.0"` / `sts.windows.net` issuer | Expected for `powerbi/api` tokens — APIM accepts both v1.0 and v2.0 issuers. |
| Can't create the app registration (`Insufficient privileges`) | Self-service registration is disabled in the BC Gov tenant — request the IDMS access package and create the app inside the one-hour window (Flow A step 1). |
| App-level API permission greyed out / consent blocked | Application permissions need Global Admin consent (via IDMS) — delegated permissions have more leeway. |

---
