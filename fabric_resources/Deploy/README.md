# PAX Purview Audit Log Processor — ACA Job Deployment (Container path)

> [!IMPORTANT]
> **Microsoft Agent 365 enrichment is temporarily disabled pending further testing.**
> The switches `-IncludeAgent365Info`, `-OnlyAgent365Info`, `-OutputPathAgent365Info`,
> and `-AppendAgent365Info` are gated at script startup and will cause PAX to exit
> immediately with a notice. References to Agent 365 elsewhere in this document are
> preserved for when the feature is re-enabled.

> **Two ways to use PAX with Fabric.** This README covers the **container path** — a scheduled, unattended run hosted on Azure Container Apps Jobs using a managed identity. If you want to run PAX directly from a laptop, on-prem server, or Azure VM and still write to Fabric/OneLake, see [`../LocalRun/README.md`](../LocalRun/README.md) (no container build, no ACR, no ACA — just PowerShell + an Entra identity that has Fabric workspace access). The top-level [`../README.md`](../README.md) compares the two paths side-by-side.

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
   # SCRIPT_SHA256 is OPTIONAL but RECOMMENDED for any non-dev image — see
   # "Picking the SCRIPT_SHA256 mode" below.
   $ver  = '<x.y.z>'
   $hash = '<sha256-digest>'   # leave empty for dev-only builds
   docker build --build-arg SCRIPT_VERSION=$ver `
     --build-arg SCRIPT_SHA256=$hash `
     -f PAX.Dockerfile -t pax-purview:$ver .
   az acr login --name <acrName>
   docker tag pax-purview:$ver <acrName>.azurecr.io/pax-purview:$ver
   docker push <acrName>.azurecr.io/pax-purview:$ver
   ```

   ### Picking the SCRIPT_SHA256 mode

   PAX is intentionally edit-friendly — you may customize the script for your environment. The build's optional `--build-arg SCRIPT_SHA256=<digest>` check is a *content-integrity* gate, not a vendor-lock: it verifies the script on disk matches the digest you supplied. Three modes cover every legitimate use:

   | You are running… | Use this digest | What it buys you |
   |---|---|---|
   | **The stock vendor script** (no edits) | The digest published in the matching GitHub release notes / sidecar `.sha256` file | Cryptographic proof the curl pulled the exact bytes Microsoft shipped — defends against tampered mirrors and accidental wrong-version pulls. |
   | **A customized script** (you forked or edited it) | Compute your own digest from the edited file and pin to that | Change-control: any accidental drift, re-download of the stock script, or unintended re-edit fails the build loudly instead of shipping silently. *Pinning to the stock vendor digest after editing will correctly fail the build — use your own digest.* |
   | **Dev / inner-loop iteration** | Omit `--build-arg SCRIPT_SHA256` (or pass empty) | Build emits a clear `WARNING: SCRIPT_SHA256 build-arg not supplied — supply-chain verification SKIPPED. Use only for dev images.` and continues. Do not ship the resulting image to production. |

   Compute the digest on either platform:

   ```powershell
   # Windows / pwsh
   (Get-FileHash .\PAX_Purview_Audit_Log_Processor_v<x.y.z>.ps1 -Algorithm SHA256).Hash.ToLower()
   ```
   ```bash
   # Linux / macOS
   sha256sum PAX_Purview_Audit_Log_Processor_v<x.y.z>.ps1
   ```
3. An existing **Azure Container Apps environment** in the same region. Consumption-only is sufficient.
4. The user-assigned identity used by `az` when running `Deploy-PAXAcaJob.ps1` needs `Storage Account Contributor` on the resource group (to create the bootstrap-log storage account on first run) and `Contributor` on the ACA environment (to register environment storage). Subsequent runs against an existing storage account need only environment-scoped Contributor.

## Deploy

> **Dashboard selection.** In `-ScriptArgs`, `-Rollup` targets the **AI-in-One (AIO)** dashboard by default. Add `'-Dashboard','AIBV'` for the **AI Business Value** dashboard, or `'-Dashboard','M365'` (equivalently `'-IncludeM365Usage'`) for **M365 Usage Analytics**. AIO and AIBV are produced from the same CopilotInteraction + Entra/MAC licensing data — no other args change.

> **Anonymization & hierarchy.** Add `'-Deidentify'` to `-ScriptArgs` to write anonymized output to the destination — every identity is replaced with an irreversible token on the host before upload (off by default; works under managed identity and app registration alike; no extra Graph permission). AIO / AIBV rollups automatically include org/manager-hierarchy columns in the Users output; `'-FillerLabel','Fixed','-FillerLabelText','<text>'` only controls how empty deeper org levels are labelled (the M365 dashboard has no hierarchy).

### SharePoint destination, daily 06:00 UTC

```powershell
./Deploy-PAXAcaJob.ps1 `
    -SubscriptionId             '00000000-0000-0000-0000-000000000000' `
    -ResourceGroup              'rg-pax' `
    -EnvironmentName            'cae-pax' `
    -JobName                    'pax-purview-daily-sp' `
    -AcrName                    'paxacr' `
    -ImageTag                   '<x.y.z>' `
    -ManagedIdentityResourceId  '/subscriptions/.../userAssignedIdentities/uai-pax' `
    -ManagedIdentityClientId    '11111111-2222-3333-4444-555555555555' `
    -BootstrapLogStorageAccount 'paxbootstraplogs' `
    -ScriptArgs @(
        # No -StartDate / -EndDate => script defaults to the last 30 days (UTC).
        # For a different window pass: '-StartDate','2026-04-14','-EndDate','2026-05-14'
        '-OutputPath','https://contoso.sharepoint.com/sites/PAX/Shared Documents/PAX_Output',
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
    -ImageTag                   '<x.y.z>' `
    -ManagedIdentityResourceId  '/subscriptions/.../userAssignedIdentities/uai-pax' `
    -ManagedIdentityClientId    '11111111-2222-3333-4444-555555555555' `
    -BootstrapLogStorageAccount 'paxbootstraplogs' `
    -ScriptArgs @(
        # No -StartDate / -EndDate => script defaults to the last 30 days (UTC).
        '-OutputPath','https://onelake.dfs.fabric.microsoft.com/PAX-Workspace/PAX.Lakehouse/Tables/dbo',
        '-OutputPathLog','https://onelake.dfs.fabric.microsoft.com/PAX-Workspace/PAX.Lakehouse/Files/logs',
        '-Auth','ManagedIdentity',
        '-Rollup'
    )
```

## Per-data-type destinations and append targets

The two examples above route every output to the same location (Purview audit, EntraUsers, Agent 365 catalog, and run log all land at `-OutputPath`'s folder or the run log's `Files/logs/` sibling). PAX lets each stream go to its own location through a symmetric `-OutputPath*` / `-Append*` switch pair. **Storage tier is inferred from each path's form** — drive-rooted = Local, `https://…sharepoint.com/…` = SharePoint, `https://…onelake.dfs.fabric.microsoft.com/…` = Fabric.

| Stream | Destination switch | Append switch |
|---|---|---|
| Purview audit (raw / rollup / event-level) | `-OutputPath` | `-AppendFile` |
| EntraUsers / MAC licensing | `-OutputPathUserInfo` | `-AppendUserInfo` (auto-enables `-IncludeUserInfo`) |
| Agent 365 catalog | `-OutputPathAgent365Info` | `-AppendAgent365Info` (auto-enables `-IncludeAgent365Info`) |
| Run log | `-OutputPathLog` | _(n/a)_ |

Rules enforced at parameter validation: every supplied URL must resolve to the same tier (mixed Local/SP/Fabric is rejected); UNC paths are rejected on every destination switch; exactly one of each stream's pair must be bound.

### Example: scheduled Fabric run that appends to existing Delta tables

```powershell
./Deploy-PAXAcaJob.ps1 `
    -SubscriptionId             '00000000-0000-0000-0000-000000000000' `
    -ResourceGroup              'rg-pax' `
    -EnvironmentName            'cae-pax' `
    -JobName                    'pax-purview-fabric-append-daily' `
    -AcrName                    'paxacr' `
    -ImageTag                   '<x.y.z>' `
    -ManagedIdentityResourceId  '/subscriptions/.../userAssignedIdentities/uai-pax' `
    -ManagedIdentityClientId    '11111111-2222-3333-4444-555555555555' `
    -BootstrapLogStorageAccount 'paxbootstraplogs' `
    -ScriptArgs @(
        # All four switches resolve to the same Fabric workspace -> tier-consistent.
        '-AppendFile',            'https://onelake.dfs.fabric.microsoft.com/PAX-Workspace/PAX.Lakehouse/Tables/dbo/Purview_Audit_CombinedUsageActivity_Interactions',
        '-AppendUserInfo',        'https://onelake.dfs.fabric.microsoft.com/PAX-Workspace/PAX.Lakehouse/Tables/dbo/EntraUsers_MAClicensing_Users',
        '-OutputPathAgent365Info','https://onelake.dfs.fabric.microsoft.com/PAX-Workspace/PAX.Lakehouse/Tables/dbo',
        '-OutputPathLog',         'https://onelake.dfs.fabric.microsoft.com/PAX-Workspace/PAX.Lakehouse/Files/pax_logs',
        '-IncludeUserInfo',
        '-IncludeAgent365Info',
        '-Auth','ManagedIdentity',
        '-Rollup'
    ) `
    -CronExpression '0 6 * * *'
```

### Provenance columns on appended files

Every appended file (rollup Fact CSV under `-AppendFile`, raw audit CSV under non-rollup `-AppendFile`, EntraUsers CSV under `-AppendUserInfo`) gains three trailing columns at merge time: `Date_Added`, `Latest_Append_Date`, `In_Latest_Append`. Rows that departed from the current run's audit window are retained in the union with `In_Latest_Append = FALSE` so historical fact-table joins continue to resolve. The CopilotInteraction rollup Fact CSV additionally carries two stable identity columns (`Message_Id_Raw`, `ThreadId_Raw`) so per-run integer surrogates remain stable across appends. Under `-AppendUserInfo`, the raw Entra membership snapshot the audit phase writes is kept **pristine** — the union lands at the `-AppendUserInfo` target, the raw file keeps its natural timestamped name (or gets a `_raw` suffix on the rare path-and-leaf collision).

**Under `-Deidentify`:** `PersonId_Normalized` is tokenized but deterministic (still a stable join key), while `Message_Id_Raw` / `ThreadId_Raw` keep their real GUID values; appending a deidentified run into a non-deidentified target (or vice-versa) is hard-rejected. **Org / manager-hierarchy columns** are added to the rollup Users output on AIO / AIBV runs — the Fabric Users append adds new columns but rejects appends that are *missing* existing columns, so keep a given Users Delta table on one PAX version line (or recreate it) to avoid mixed-schema appends.

## Alternative: app registration instead of managed identity

`Deploy-PAXAcaJob.ps1` is opinionated for the managed-identity path because that's the simplest and most secure for ACA Jobs. If you must use **`-Auth AppRegistration`** instead (e.g., org policy forbids managed identities, or you're hosting the same image somewhere outside Azure), use the `az containerapp job create` recipes below.

> **Bootstrap-log mount still required.** PAX always writes to `/pax-logs`, regardless of `-Auth` mode. Before running the `az containerapp job create` recipes in this section, run the four `az storage account create` / `az storage share-rm create` / `az containerapp env storage set` / `az resource update --set ...volumes`/`...volumeMounts` commands that `Deploy-PAXAcaJob.ps1` would have run (see the **Bootstrap-log durable mount** section above for the exact sequence and the source script). Or use `Deploy-PAXAcaJob.ps1` to provision the storage + register the env-storage + lay down a placeholder job, then run `az containerapp job update` with your AppRegistration env-vars/secrets on top — the volume mount survives `--set-env-vars` updates.

### Pre-reqs (app registration)

2. **Entra ID app registration** with the same Microsoft Graph **application permissions** that `Grant-PAXPermissions.ps1` would have granted (`AuditLogsQuery.Read.All`, `User.Read.All`, `Organization.Read.All`, `GroupMember.Read.All`, plus `AuditLogsQuery-Exchange.Read.All` + `-OneDrive.Read.All` + `-SharePoint.Read.All` when `-IncludeM365Usage` is used, plus `Sites.ReadWrite.All` + `Files.ReadWrite.All` for SharePoint output, plus the OneLake/Fabric setup for Fabric `-OutputPath*` URLs). All require admin consent.
2. **Either** a **client secret** stored in Azure Key Vault, **or** a **PFX certificate** stored in Key Vault.
3. The **ACA Job's user-assigned identity** (used only for ACR pull + Key Vault read) needs:
   - `AcrPull` on the ACR
   - `Get` on the Key Vault secret/cert (required for ACA Key Vault secret references)

### Relevant PAX switches

For `-Auth AppRegistration`:

| Switch | Purpose | Equivalent env var |
|---|---|---|
| `-TenantId <guid>` | Entra tenant ID | `GRAPH_TENANT_ID` |
| `-ClientId <guid>` | App registration client ID | `GRAPH_CLIENT_ID` |
| `-ClientSecret <string>` | Client secret value | `GRAPH_CLIENT_SECRET` |
| `-ClientCertificateThumbprint <hex>` | Cert thumbprint in `My` store | `GRAPH_CLIENT_CERT_THUMBPRINT` |
| `-ClientCertificateStoreLocation <CurrentUser\|LocalMachine>` | Preferred store to search first for the thumbprint (default `CurrentUser`); PAX checks the other store automatically if not found | — |
| `-ClientCertificatePath <path>` | Path to a PFX file on disk | `GRAPH_CLIENT_CERT_PATH` |
| `-ClientCertificatePassword <SecureString>` | PFX password | `GRAPH_CLIENT_CERT_PASSWORD` |

In a container, the env-var route is what you want — that way no secret value ever appears on the command line, in `--args`, in container logs, or in ACA revision history. PAX picks up the `GRAPH_*` env vars automatically when the matching parameter isn't passed.

### App registration + client secret

```powershell
$rg              = 'rg-pax'
$jobName         = 'pax-purview-appreg-sp'
$envName         = 'cae-pax'
$acrName         = 'paxacr'
$imageTag        = '<x.y.z>'
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
    --args              "-OutputPath `"https://contoso.sharepoint.com/sites/PAX/Shared Documents/PAX_Output`" -Auth AppRegistration -Rollup"
#   ^ no -StartDate/-EndDate => PAX defaults to the last 30 days (UTC). For a different window add e.g. -StartDate 2026-04-14 -EndDate 2026-05-14.
```

> Note: only `-Auth AppRegistration` appears on the command line. `-TenantId`, `-ClientId`, and `-ClientSecret` are resolved from the `GRAPH_*` env vars at startup. If you prefer to be explicit you can pass `-TenantId $tenantId -ClientId $clientId` in `--args` — but **do not** put `-ClientSecret <value>` on the command line, ever.

### App registration + certificate (PFX from Key Vault)

ACA secret references can pull a Key Vault **secret** (the PFX bytes, base64-encoded) and a separate KV secret holding the PFX password. Decode the PFX into the container's filesystem at startup, then point PAX at it via `GRAPH_CLIENT_CERT_PATH` + `GRAPH_CLIENT_CERT_PASSWORD`.

```powershell
$rg              = 'rg-pax'
$jobName         = 'pax-purview-appreg-cert'
$envName         = 'cae-pax'
$acrName         = 'paxacr'
$imageTag        = '<x.y.z>'
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
    --args              "-c","echo \"\$PAX_PFX_BASE64\" | base64 -d > /tmp/pax.pfx && pwsh -File /app/PAX_Purview_Audit_Log_Processor.ps1 -OutputPath \"https://contoso.sharepoint.com/sites/PAX/Shared Documents/PAX_Output\" -Auth AppRegistration -Rollup"
# NOTE: PAX has no -Days parameter; omit it (=> 30-day default) or pass -StartDate/-EndDate explicitly.
```

> The script lives at `/app/PAX_Purview_Audit_Log_Processor.ps1` inside the image (see `../Dockerfile/PAX.Dockerfile`). Alternatively use `-ClientCertificateThumbprint` if your image bakes a cert into a store, but for ACA the PFX-from-Key-Vault pattern is the cleanest.

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

## Bootstrap-log durable mount (mandatory, provisioned automatically)

PAX opens its run log **before** parameter validation and before the destination pre-flight probe so that auth failures, bad `-OutputPath*` URLs, and other early errors are written to disk and not just stderr. Inside the container the log lands at `$env:PAX_BOOTSTRAP_LOG_DIR` (the image sets this to `/pax-logs`) until the script resolves its final output location, at which point the bootstrap file is `Move-Item`'d to the run's real log path and uploaded to your `-OutputPathLog` (or alongside the CSVs).

On a **successful** run the end-of-run upload block sends the final log to your SharePoint or Fabric destination, so nothing additional is needed — the log is in the cloud regardless of what happens to the container.

On a **pre-flight failure** (auth error, bad URL, validation reject) no upload runs and the container exits. To keep the bootstrap log readable after the container is gone, `/pax-logs` must be backed by a persistent Azure Files mount. **`Deploy-PAXAcaJob.ps1` does this for you** when you pass `-BootstrapLogStorageAccount <name>`:

1. Creates the storage account (Standard_LRS / StorageV2 / TLS 1.2 / no public blob) if missing.
2. Creates the file share (default name `pax-bootstrap-logs`, default 5 Gi quota) if missing.
3. Registers the share with the ACA environment as named storage `pax-logs`.
4. After the job is created/updated, patches `properties.template.volumes` and `properties.template.containers[0].volumeMounts` via `az resource update --set` (the only way to attach a volume to an ACA Job — there is no `--volume`/`--bind-mount` flag on `az containerapp job create/update`).

All four stages are idempotent — re-running `Deploy-PAXAcaJob.ps1` with the same `-BootstrapLogStorageAccount` is a no-op once the resources exist.

### Retrieving a failed-run bootstrap log

```powershell
az storage file list --account-name <storageAccount> --share-name pax-bootstrap-logs --output table
az storage file download --account-name <storageAccount> --share-name pax-bootstrap-logs --path PAX_bootstrap_<pid>_<timestamp>.log --dest .\bootstrap.log
```

Or open the file share in Azure Storage Explorer / Azure portal. The failed container can be deleted (or auto-cleaned by ACA's execution-history limit) immediately after exit — the log is on the share.

### Cost notes

- Standard_LRS StorageV2 + 5 Gi quota = roughly USD 0.30 / month at list price. ZRS roughly 1.5×.
- One file share is shared across all jobs you deploy with the same `-EnvironmentName` and `-BootstrapLogStorageAccount` — reuse the same storage account for all your PAX jobs in a region.
- The bootstrap log itself is 10-50 KiB per run, so the default 5 Gi quota holds ~100,000 run logs before housekeeping is needed.

### Overrides

| Parameter | Default | When to override |
|---|---|---|
| `-BootstrapLogShareName` | `pax-bootstrap-logs` | You already have a different share you want to reuse. |
| `-BootstrapLogShareQuotaGi` | `5` | You want a larger budget for retained logs. |
| `-BootstrapLogStorageSku` | `Standard_LRS` | Use `Standard_ZRS` for zonal redundancy. |

## Notes

- **Agent 365 enrichment is NOT supported under `-Auth ManagedIdentity`.** PAX rejects `-IncludeAgent365Info` and `-OnlyAgent365Info` up-front when `-Auth ManagedIdentity` is in effect. The Microsoft Graph Agent Package Management API requires the AI Administrator or Global Administrator directory role, which can only be held by a signed-in user; a managed identity has no user principal and cannot satisfy the requirement, even with admin-consented application permissions. If you need Agent 365 enrichment, run PAX interactively (`-Auth WebLogin` or `DeviceCode`), or with `-Auth AppRegistration` (PAX will interactively top up a delegated context for the Agent 365 phase only). For the unattended ACA-Job pattern this README covers, simply omit those switches.
- **Fabric `-OutputPath` shapes the script accepts:**
  - `https://<tenant>.onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse` — main Delta tables go under the Lakehouse's default `Tables/` area.
  - `…/<Lakehouse>.Lakehouse/Tables` — explicit non-Schemas form.
  - `…/<Lakehouse>.Lakehouse/Tables/<schema>` — Schemas-enabled Lakehouse (current Fabric default; typical value is `dbo`).
  - The workspace and item may be addressed by their **GUIDs** with no `.Lakehouse` suffix instead of by name (e.g. `…/<workspace-guid>/<lakehouse-guid>/Tables/dbo`) — the GUIDs shown in the Lakehouse's Fabric portal page URL.
  Pass `-OutputPathLog "…/<Lakehouse>.Lakehouse/Files/<subpath>"` for the run log (`Files/` namespace).
- **Delta table names come from the local CSV filename**, not from the trailing segment of your `-OutputPath*` URL. PAX strips the `_YYYYMMDD_HHMMSS` run-timestamp suffix and uses what remains (e.g. `PAX_Purview_Audit_Log`, `EntraUsers`, `Agent365`). Successive runs against the same URL therefore overwrite the same Delta table.
- **Replica timeout:** Default is 21600 s (6h). Override with `-ReplicaTimeoutSeconds`. Long Purview pulls can exceed this — bump as needed.
- **Resume:** On crash, the script writes a checkpoint to scratch AND mirrors it to the remote destination. A subsequent run with `-Resume` (in `ScriptArgs`) will pull the checkpoint and `_PARTIAL` artifacts from remote into a fresh container's scratch dir and continue.
- **Trigger change:** ACA Jobs do not support changing trigger type in-place. To switch Manual ↔ Schedule, delete and recreate the job.
- **Identity binding:** The script requires `AZURE_CLIENT_ID` so `Connect-MgGraph -Identity -ClientId` and `Connect-AzAccount -Identity -AccountId` resolve to the correct user-assigned identity. Deploy-PAXAcaJob.ps1 sets this automatically.
