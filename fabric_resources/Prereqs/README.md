# PAX Purview Audit Log Processor — Prerequisites (Container path)

> [!IMPORTANT]
> **Microsoft Agent 365 enrichment is fully supported.**
> The `-IncludeAgent365Info`, `-OnlyAgent365Info`, `-OutputPathAgent365Info`, and `-AppendAgent365Info` switches require interactive (delegated) sign-in by an AI Administrator or Global Administrator; ManagedIdentity is not supported for this stream.

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

   `-Mode SharePoint` only:
   - `Sites.ReadWrite.All`, `Files.ReadWrite.All`

4. **(Fabric mode only)** Grants `Storage Blob Data Contributor` on the Fabric workspace's OneLake (Azure RBAC).

### Permissions intentionally NOT granted

- `AuditLog.Read.All` — this is the Entra audit-activities permission, a different endpoint that PAX does not call. Earlier versions of this script granted it by mistake.
- `CopilotPackages.Read.All` — Microsoft Agent 365 enrichment requires the AI Administrator or Global Administrator directory role, which can only be held by a signed-in user. A managed identity has no user principal and cannot satisfy this requirement. The PAX script rejects `-IncludeAgent365Info` / `-OnlyAgent365Info` under `-Auth ManagedIdentity` up-front. If you need Agent 365 enrichment, run PAX interactively (`-Auth WebLogin` or `DeviceCode`) or with `-Auth AppRegistration` (the script will interactively top up a delegated context for the Agent 365 phase only).
- `Application.Read.All` — only consumed by the Agent 365 path, which is unsupported under `-Auth ManagedIdentity`.

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

> **Fabric note:** Azure RBAC alone is sometimes insufficient for OneLake DFS write access. After running the script, also add the managed identity as a **Contributor** on the Fabric workspace via the Fabric portal (Workspace settings → Manage access).

## Output

The script prints the managed identity's `resourceId` and `clientId`. Pass both to `../Deploy/Deploy-PAXAcaJob.ps1`:

```
-ManagedIdentityResourceId '/subscriptions/.../userAssignedIdentities/uai-pax'
-ManagedIdentityClientId   '11111111-2222-3333-4444-555555555555'
```

