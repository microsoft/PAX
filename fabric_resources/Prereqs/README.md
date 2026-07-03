# PAX Purview Audit Log Processor — Prerequisites (Container path)

> [!IMPORTANT]
> **Microsoft Agent 365 enrichment is supported on the container path via app-only auth (opt-in / pre-GA).**
> The `-IncludeAgent365Info`, `-OnlyAgent365Info`, `-OutputPathAgent365Info`, and `-AppendAgent365Info` switches run under `-Auth ManagedIdentity` (app-only) once the managed identity holds the application permissions `CopilotPackages.Read.All` + `Application.Read.All` (admin-consented) — no interactive sign-in is required. Those permissions are **not** granted by default; pass **`-IncludeAgent365`** to `Grant-PAXPermissions.ps1` to add them. This app-only path is **pre-GA** — validate it in your tenant before relying on it in production. (Delegated sign-in by an AI Administrator or Global Administrator also works, e.g. on the local-run path.)

One-time setup before deploying the ACA Job. **Only required when you intend to run PAX as a containerized scheduled job on Azure Container Apps.** If you are running PAX directly from a host (laptop, on-prem server, Azure VM) and writing to Fabric/OneLake, see [`../LocalRun/README.md`](../LocalRun/README.md) instead — the prerequisites there are smaller and `Grant-PAXPermissions.ps1` is not required.

## What `Grant-PAXPermissions.ps1` does

1. Creates (or reuses) a **user-assigned managed identity**.
2. Grants **AcrPull** on the Azure Container Registry that hosts the `pax-purview` image.
3. Grants and admin-consents the following **Microsoft Graph application permissions** to the identity's service principal:

   Always:
   - `AuditLogsQuery.Read.All` — umbrella scope for `/security/auditLog/queries` (the endpoint PAX uses for every audit pull, including CopilotInteraction)
   - `User.Read.All` — `/users` for the EntraUsers CSV and license map
   - `Organization.Read.All` — `/subscribedSkus` for SKU → product-name resolution
   - `GroupMember.Read.All` — `/groups` and `/groups/{id}/members`, used only when PAX is invoked with `-GroupNames`. Pre-granted so the same image works for both call shapes.

   With `-IncludeM365Usage`:
   - `AuditLogsQuery-Exchange.Read.All`
   - `AuditLogsQuery-OneDrive.Read.All`
   - `AuditLogsQuery-SharePoint.Read.All`

   With `-IncludeAgent365` (opt-in / pre-GA — enables app-only Microsoft Agent 365 enrichment):
   - `CopilotPackages.Read.All`
   - `Application.Read.All`

   `-Mode SharePoint` only:
   - `Sites.ReadWrite.All`, `Files.ReadWrite.All`

4. **(Fabric mode only)** Grants `Storage Blob Data Contributor` on the Fabric workspace's OneLake (Azure RBAC).

### Permissions not granted by default

- `AuditLog.Read.All` — this is the Entra audit-activities permission, a different endpoint that PAX does not call. Earlier versions of this script granted it by mistake. **Never** granted.
- `CopilotPackages.Read.All` and `Application.Read.All` — the Microsoft Agent 365 application permissions. PAX **does** support Agent 365 under app-only auth (`-Auth ManagedIdentity` or `-Auth AppRegistration`) using these permissions, with no interactive sign-in. They are **opt-in** — not granted by default, to keep the identity least-privileged. Pass **`-IncludeAgent365`** to this script to grant + admin-consent them. This app-only Agent 365 path is **pre-GA**; validate it in your tenant before relying on it in production. (Delegated Agent 365 instead relies on the signed-in user's AI Administrator / Global Administrator directory role and needs no application permission.)

## Operator pre-reqs

- **Global Administrator** (or Privileged Role Administrator) — required for admin-consenting Graph application permissions.
- **Owner** or **User Access Administrator** on the ACR and (Fabric mode) the workspace — required for Azure role assignments.
- Azure CLI (`az`) installed and logged in.
- PowerShell 7.x.
- `Microsoft.Graph` module (the script installs it for you if missing).

## Examples

### SharePoint destination

```powershell
./Grant-PAXPermissions.ps1 `
    -SubscriptionId       '00000000-0000-0000-0000-000000000000' `
    -ResourceGroup        'rg-pax' `
    -ManagedIdentityName  'uai-pax' `
    -Location             'eastus' `
    -AcrResourceId        '/subscriptions/.../registries/paxacr' `
    -Mode                 SharePoint
```

### Fabric / OneLake destination

```powershell
./Grant-PAXPermissions.ps1 `
    -SubscriptionId            '00000000-0000-0000-0000-000000000000' `
    -ResourceGroup             'rg-pax' `
    -ManagedIdentityName       'uai-pax' `
    -Location                  'eastus' `
    -AcrResourceId             '/subscriptions/.../registries/paxacr' `
    -Mode                      Fabric `
    -FabricWorkspaceResourceId '/subscriptions/.../workspaces/PAX-Workspace'
```

### Fabric destination, also enabling `-IncludeM365Usage`

```powershell
./Grant-PAXPermissions.ps1 `
    -SubscriptionId            '00000000-0000-0000-0000-000000000000' `
    -ResourceGroup             'rg-pax' `
    -ManagedIdentityName       'uai-pax' `
    -Location                  'eastus' `
    -AcrResourceId             '/subscriptions/.../registries/paxacr' `
    -Mode                      Fabric `
    -FabricWorkspaceResourceId '/subscriptions/.../workspaces/PAX-Workspace' `
    -IncludeM365Usage
```

### Fabric destination, also enabling app-only Agent 365 (opt-in / pre-GA)

```powershell
./Grant-PAXPermissions.ps1 `
    -SubscriptionId            '00000000-0000-0000-0000-000000000000' `
    -ResourceGroup             'rg-pax' `
    -ManagedIdentityName       'uai-pax' `
    -Location                  'eastus' `
    -AcrResourceId             '/subscriptions/.../registries/paxacr' `
    -Mode                      Fabric `
    -FabricWorkspaceResourceId '/subscriptions/.../workspaces/PAX-Workspace' `
    -IncludeAgent365
```

> **Agent 365 is pre-GA.** `-IncludeAgent365` grants `CopilotPackages.Read.All` + `Application.Read.All` so the managed identity can run `-IncludeAgent365Info` / `-OnlyAgent365Info` app-only (no interactive sign-in). Validate in your tenant before relying on it in production.

> **Fabric note:** Azure RBAC alone is sometimes insufficient for OneLake DFS write access. After running the script, also add the managed identity as a **Contributor** on the Fabric workspace via the Fabric portal (Workspace settings → Manage access).

## Output

The script prints the managed identity's `resourceId` and `clientId`. Pass both to `../Deploy/Deploy-PAXAcaJob.ps1`:

```
-ManagedIdentityResourceId '/subscriptions/.../userAssignedIdentities/uai-pax'
-ManagedIdentityClientId   '11111111-2222-3333-4444-555555555555'
```

