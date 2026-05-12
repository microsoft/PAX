# PAX Purview Audit Log Processor — Prerequisites

One-time setup before deploying the ACA Job.

## What `Grant-PAXPermissions.ps1` does

1. Creates (or reuses) a **user-assigned managed identity**.
2. Grants **AcrPull** on the Azure Container Registry that hosts the `pax-purview` image.
3. Grants and admin-consents the following **Microsoft Graph application permissions** to the identity's service principal:
   - `AuditLog.Read.All`
   - `User.Read.All`
   - `Organization.Read.All`
   - `Application.Read.All`
   - **(SharePoint mode only)** `Sites.ReadWrite.All`, `Files.ReadWrite.All`
4. **(Fabric mode only)** Grants `Storage Blob Data Contributor` on the Fabric workspace's OneLake (Azure RBAC).

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

> **Fabric note:** Azure RBAC alone is sometimes insufficient for OneLake DFS write access. After running the script, also add the managed identity as a **Contributor** on the Fabric workspace via the Fabric portal (Workspace settings → Manage access).

## Output

The script prints the managed identity's `resourceId` and `clientId`. Pass both to `../Deploy/Deploy-PAXAcaJob.ps1`:

```
-ManagedIdentityResourceId '/subscriptions/.../userAssignedIdentities/uai-pax'
-ManagedIdentityClientId   '11111111-2222-3333-4444-555555555555'
```
