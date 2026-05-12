# PAX Purview Audit Log Processor — ACA Job Deployment

Deploy or update the Azure Container Apps Job that runs the processor unattended on a schedule (or on demand) and writes outputs to **SharePoint** or **Fabric/OneLake**.

The container image itself is **auth-agnostic** — it just bakes in PowerShell + the PAX script. *Whatever `-Auth ...` flag you pass in `ScriptArgs` at runtime is what gets used.* This README covers the three patterns that make sense for containerized scheduled runs:

| Pattern | When to use | Setup effort | Secrets to manage |
|---|---|---|---|
| **`-Auth ManagedIdentity`** *(recommended for ACA Jobs)* | You're hosting in Azure already and want the simplest, most secure setup | Lowest | None |
| **`-Auth AppRegistration` + client secret** | You can't use managed identity (e.g., running outside Azure, or org policy), or you want to reuse an existing app reg | Medium | Client secret in Key Vault |
| **`-Auth AppRegistration` + certificate** | You need cert-based auth (compliance/policy) | Highest | Cert in Key Vault, mounted to container |

## Pre-reqs

1. Run `../Prereqs/Grant-PAXPermissions.ps1` once. Capture the printed `ManagedIdentityResourceId` and `ManagedIdentityClientId`.
2. Build and push the container image. The Dockerfile is fully self-contained — **download only `PAX.Dockerfile`** (no repo clone needed); the PAX script is pulled from the pinned GitHub release inside the build.
   ```powershell
   # In whatever folder contains PAX.Dockerfile. Pick the PAX version you want
   # from https://github.com/microsoft/PAX/releases. SCRIPT_VERSION is REQUIRED.
   $ver = '1.11.1'
   docker build --build-arg SCRIPT_VERSION=$ver `
     -f PAX.Dockerfile -t pax-purview:$ver .
   az acr login --name <acrName>
   docker tag pax-purview:$ver <acrName>.azurecr.io/pax-purview:$ver
   docker push <acrName>.azurecr.io/pax-purview:$ver
   ```
3. An existing **Azure Container Apps environment** in the same region. Consumption-only is sufficient.

## Deploy

### SharePoint destination, daily 06:00 UTC

```powershell
./Deploy-PAXAcaJob.ps1 `
    -SubscriptionId             '00000000-0000-0000-0000-000000000000' `
    -ResourceGroup              'rg-pax' `
    -EnvironmentName            'cae-pax' `
    -JobName                    'pax-purview-daily-sp' `
    -AcrName                    'paxacr' `
    -ImageTag                   '1.11.1' `
    -ManagedIdentityResourceId  '/subscriptions/.../userAssignedIdentities/uai-pax' `
    -ManagedIdentityClientId    '11111111-2222-3333-4444-555555555555' `
    -ScriptArgs @(
        '-Days','30',
        '-OutputPathSP','https://contoso.sharepoint.com/sites/PAX/Shared Documents/PAX_Output',
        '-Auth','ManagedIdentity',
        '-Rollup'
    ) `
    -CronExpression '0 6 * * *'
```

### Fabric / OneLake destination, on-demand

```powershell
./Deploy-PAXAcaJob.ps1 `
    -SubscriptionId             '00000000-0000-0000-0000-000000000000' `
    -ResourceGroup              'rg-pax' `
    -EnvironmentName            'cae-pax' `
    -JobName                    'pax-purview-fabric' `
    -AcrName                    'paxacr' `
    -ImageTag                   '1.11.1' `
    -ManagedIdentityResourceId  '/subscriptions/.../userAssignedIdentities/uai-pax' `
    -ManagedIdentityClientId    '11111111-2222-3333-4444-555555555555' `
    -ScriptArgs @(
        '-Days','30',
        '-OutputPathFabric','https://onelake.dfs.fabric.microsoft.com/PAX-Workspace/PAX.Lakehouse/Files/Audit',
        '-Auth','ManagedIdentity',
        '-Rollup'
    )
```

## Alternative: app registration instead of managed identity

`Deploy-PAXAcaJob.ps1` is opinionated for the managed-identity path because that's the simplest and most secure for ACA Jobs. If you must use **`-Auth AppRegistration`** instead (e.g., org policy forbids managed identities, or you're hosting the same image somewhere outside Azure), use the `az containerapp job create` recipes below.

### Pre-reqs (app registration)

1. **Entra ID app registration** with the same Microsoft Graph **application permissions** that `Grant-PAXPermissions.ps1` would have granted (`AuditLogsQuery.Read.All`, `User.Read.All`, `Directory.Read.All`, `Group.Read.All`, plus `Sites.ReadWrite.All` + `Files.ReadWrite.All` for SharePoint output, plus the OneLake/Fabric setup for `-OutputPathFabric`). All require admin consent.
2. **Either** a **client secret** stored in Azure Key Vault, **or** a **PFX certificate** stored in Key Vault.
3. The **ACA Job's user-assigned identity** (used only for ACR pull + Key Vault read) needs:
   - `AcrPull` on the ACR
   - `Get` on the Key Vault secret/cert (required for ACA Key Vault secret references)

### Relevant PAX switches (from the v1.11.x script)

For `-Auth AppRegistration`:

| Switch | Purpose | Equivalent env var |
|---|---|---|
| `-TenantId <guid>` | Entra tenant ID | `GRAPH_TENANT_ID` |
| `-ClientId <guid>` | App registration client ID | `GRAPH_CLIENT_ID` |
| `-ClientSecret <string>` | Client secret value | `GRAPH_CLIENT_SECRET` |
| `-ClientCertificateThumbprint <hex>` | Cert thumbprint in `My` store | `GRAPH_CLIENT_CERT_THUMBPRINT` |
| `-ClientCertificateStoreLocation <CurrentUser\|LocalMachine>` | Store location for thumbprint lookup (default `CurrentUser`) | — |
| `-ClientCertificatePath <path>` | Path to a PFX file on disk | `GRAPH_CLIENT_CERT_PATH` |
| `-ClientCertificatePassword <SecureString>` | PFX password | `GRAPH_CLIENT_CERT_PASSWORD` |

In a container, the env-var route is what you want — that way no secret value ever appears on the command line, in `--args`, in container logs, or in ACA revision history. PAX picks up the `GRAPH_*` env vars automatically when the matching parameter isn't passed.

### App registration + client secret

```powershell
$rg              = 'rg-pax'
$jobName         = 'pax-purview-appreg-sp'
$envName         = 'cae-pax'
$acrName         = 'paxacr'
$imageTag        = '1.11.1'
$tenantId        = '<tenant-guid>'
$clientId        = '<app-id>'
$kvName          = '<keyvault-name>'
$secretName      = 'pax-client-secret'   # Key Vault secret holding the client secret value
$miForAcr        = '/subscriptions/.../userAssignedIdentities/uai-pax-pull'  # AcrPull + KV Get

az containerapp job create `
    --name              $jobName `
    --resource-group    $rg `
    --environment       $envName `
    --trigger-type      Schedule `
    --cron-expression   '0 6 * * *' `
    --replica-timeout   21600 `
    --replica-retry-limit 0 `
    --parallelism       1 `
    --replica-completion-count 1 `
    --image             "$acrName.azurecr.io/pax-purview:$imageTag" `
    --cpu               2.0 --memory 4.0Gi `
    --mi-user-assigned  $miForAcr `
    --registry-server   "$acrName.azurecr.io" `
    --registry-identity $miForAcr `
    --secrets           "graph-client-secret=keyvaultref:https://$kvName.vault.azure.net/secrets/$secretName,identityref:$miForAcr" `
    --env-vars          "GRAPH_TENANT_ID=$tenantId" `
                        "GRAPH_CLIENT_ID=$clientId" `
                        "GRAPH_CLIENT_SECRET=secretref:graph-client-secret" `
    --args              "-Days 30 -OutputPathSP `"https://contoso.sharepoint.com/sites/PAX/Shared Documents/PAX_Output`" -Auth AppRegistration -Rollup"
```

> Note: only `-Auth AppRegistration` appears on the command line. `-TenantId`, `-ClientId`, and `-ClientSecret` are resolved from the `GRAPH_*` env vars at startup. If you prefer to be explicit you can pass `-TenantId $tenantId -ClientId $clientId` in `--args` — but **do not** put `-ClientSecret <value>` on the command line, ever.

### App registration + certificate (PFX from Key Vault)

ACA secret references can pull a Key Vault **secret** (the PFX bytes, base64-encoded) and a separate KV secret holding the PFX password. Decode the PFX into the container's filesystem at startup, then point PAX at it via `GRAPH_CLIENT_CERT_PATH` + `GRAPH_CLIENT_CERT_PASSWORD`.

```powershell
$rg              = 'rg-pax'
$jobName         = 'pax-purview-appreg-cert'
$envName         = 'cae-pax'
$acrName         = 'paxacr'
$imageTag        = '1.11.1'
$tenantId        = '<tenant-guid>'
$clientId        = '<app-id>'
$kvName          = '<keyvault-name>'
$pfxSecret       = 'pax-pfx-base64'      # PFX bytes, base64-encoded, stored as a KV secret
$pfxPwSecret     = 'pax-pfx-password'    # PFX export password, stored as a KV secret
$miForAcr        = '/subscriptions/.../userAssignedIdentities/uai-pax-pull'

az containerapp job create `
    --name              $jobName `
    --resource-group    $rg `
    --environment       $envName `
    --trigger-type      Schedule `
    --cron-expression   '0 6 * * *' `
    --replica-timeout   21600 `
    --replica-retry-limit 0 `
    --parallelism       1 `
    --replica-completion-count 1 `
    --image             "$acrName.azurecr.io/pax-purview:$imageTag" `
    --cpu               2.0 --memory 4.0Gi `
    --mi-user-assigned  $miForAcr `
    --registry-server   "$acrName.azurecr.io" `
    --registry-identity $miForAcr `
    --secrets           "pfx-b64=keyvaultref:https://$kvName.vault.azure.net/secrets/$pfxSecret,identityref:$miForAcr" `
                        "pfx-pw=keyvaultref:https://$kvName.vault.azure.net/secrets/$pfxPwSecret,identityref:$miForAcr" `
    --env-vars          "GRAPH_TENANT_ID=$tenantId" `
                        "GRAPH_CLIENT_ID=$clientId" `
                        "PAX_PFX_BASE64=secretref:pfx-b64" `
                        "GRAPH_CLIENT_CERT_PASSWORD=secretref:pfx-pw" `
                        "GRAPH_CLIENT_CERT_PATH=/tmp/pax.pfx" `
    --command           "/bin/bash" `
    --args              "-c","echo \"\$PAX_PFX_BASE64\" | base64 -d > /tmp/pax.pfx && pwsh -File /opt/pax/PAX_Purview_Audit_Log_Processor.ps1 -Days 30 -OutputPathSP \"https://contoso.sharepoint.com/sites/PAX/Shared Documents/PAX_Output\" -Auth AppRegistration -Rollup"
```

> Adjust the script path (`/opt/pax/...`) to wherever the Dockerfile drops the PAX script. Alternatively use `-ClientCertificateThumbprint` if your image bakes a cert into a store, but for ACA the PFX-from-Key-Vault pattern is the cleanest.

### Why we don't recommend app registration here

- **You're shipping a long-lived secret/cert into a containerized scheduled job.** Rotation is on you; managed identity has none.
- **Key Vault + ACA secret refs add an extra moving part** that can fail independently (network, Key Vault firewall, secret expiry, RBAC drift).
- **Managed identity gives you the same Graph application permissions** with no secret to leak. If you can use it, you should.



| Task | Command |
|---|---|
| Start manual run | `az containerapp job start --name <jobName> --resource-group <rg>` |
| List executions | `az containerapp job execution list --name <jobName> --resource-group <rg> --output table` |
| Stream logs | `az containerapp job logs show --name <jobName> --resource-group <rg> --container <jobName> --follow` |
| Pause schedule | `az containerapp job stop --name <jobName> --resource-group <rg>` |

## Notes

- **Replica timeout:** Default is 21600 s (6h). Override with `-ReplicaTimeoutSeconds`. Long Purview pulls can exceed this — bump as needed.
- **Resume:** On crash, the script writes a checkpoint to scratch AND mirrors it to the remote destination. A subsequent run with `-Resume` (in `ScriptArgs`) will pull the checkpoint and `_PARTIAL` artifacts from remote into a fresh container's scratch dir and continue.
- **Trigger change:** ACA Jobs do not support changing trigger type in-place. To switch Manual ↔ Schedule, delete and recreate the job.
- **Identity binding:** The script requires `AZURE_CLIENT_ID` so `Connect-MgGraph -Identity -ClientId` and `Connect-AzAccount -Identity -AccountId` resolve to the correct user-assigned identity. Deploy-PAXAcaJob.ps1 sets this automatically.
