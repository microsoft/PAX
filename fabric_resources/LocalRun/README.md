# PAX + Fabric — Local / Direct run (Path A)

Run PAX directly from a Windows laptop, on-prem server, or Azure VM and write outputs to a Fabric Lakehouse. **No container build, no ACR, no ACA, and no `Grant-PAXPermissions.ps1` are required.** This is the lower-setup path; pick it when you do not need a fully unattended Azure-hosted scheduled run, or when you need Microsoft Agent 365 enrichment (which is unsupported under managed identity — see the container path README).

For the side-by-side comparison of this path vs. the container path, see [`../README.md`](../README.md).

---

## What you need (one-time)

### 1. The host

Any machine that has all of the following on PATH:

- **PowerShell 7+** — verify with `pwsh -v`. Download from <https://github.com/PowerShell/PowerShell/releases>.
- **Microsoft Graph PowerShell SDK** — installs on first run, or pre-install with:
  ```powershell
  Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
  ```
- **Az.Accounts** — used by PAX to mint the OneLake storage-audience token:
  ```powershell
  Install-Module Az.Accounts -Scope CurrentUser -Force -AllowClobber
  ```
- **Python 3** with `pyarrow>=14` and `deltalake>=0.15`. PAX will pip-install them automatically on first Fabric run via its built-in `Install-DeltalakeIfMissing` helper. To pre-install:
  ```powershell
  python -m pip install --upgrade "pyarrow>=14" "deltalake>=0.15"
  ```
- Outbound HTTPS to `graph.microsoft.com`, `login.microsoftonline.com`, and `*.onelake.dfs.fabric.microsoft.com`.

### 2. The PAX script

Download the script from the pinned GitHub release: <https://github.com/microsoft/PAX/releases>. Pick `PAX_Purview_Audit_Log_Processor_v<x.y.z>.ps1` for the version you want. Save it anywhere on the host — `C:\PAX\` or your home directory both work.

### 3. The Fabric workspace

In the Fabric portal:

1. Open the workspace that contains the Lakehouse you want PAX to write to.
2. **Workspace → Manage access → Add people or groups.**
3. Add the identity PAX will sign in as (your own Entra user, the group it belongs to, or the service principal you plan to use for `-Auth AppRegistration`) with role **Contributor** or higher.

Without this grant, OneLake DFS writes return 403 no matter what Azure RBAC says.

### 4. Microsoft Graph permissions

The identity PAX authenticates with needs the following Microsoft Graph permissions. They are **delegated** when you use `-Auth WebLogin` / `DeviceCode` / `Credential` / `Silent`, and **application** when you use `-Auth AppRegistration`. Either way they require Global Admin consent.

Always:

- `AuditLogsQuery.Read.All`
- `User.Read.All`
- `Organization.Read.All`
- `GroupMember.Read.All` (only consumed when `-GroupNames` is used, but admins commonly pre-grant it)

When you intend to pass `-IncludeM365Usage`:

- `AuditLogsQuery-Exchange.Read.All`
- `AuditLogsQuery-OneDrive.Read.All`
- `AuditLogsQuery-SharePoint.Read.All`

If you want Microsoft Agent 365 enrichment (`-IncludeAgent365Info` / `-OnlyAgent365Info`), the **signed-in user** also needs the **AI Administrator** or **Global Administrator** directory role. This requirement is a server-side check on the Agent 365 endpoint and cannot be satisfied by application permissions alone. (Use `-Auth WebLogin`, `DeviceCode`, `Credential`, `Silent`, or `AppRegistration`. Managed identity is rejected up-front for Agent 365.)

---

## Step-by-step: first Fabric run from a laptop

This is the fastest possible Fabric-from-laptop on-ramp. It uses `-Auth WebLogin` (interactive browser sign-in) and writes to the Lakehouse's default Tables area.

1. **Install prerequisites** (one-time) — section 1 above.
2. **Grant Fabric workspace Contributor** to your Entra user account in the Fabric portal — section 3 above.
3. **Have Global Admin consent the Microsoft Graph delegated scopes** listed in section 4. PAX will prompt for the scopes interactively on first run; if you are not your own Global Admin, ask one to consent on your behalf (they can do this via `Connect-MgGraph -Scopes <list>` once, or via the Entra portal admin-consent UI).
4. **Find your Lakehouse OneLake URL.** In the Fabric portal: open the Lakehouse → click the **…** menu on `Tables` → *Copy ABFS path* → it looks like:
   ```
   abfss://<workspace-guid>@onelake.dfs.fabric.microsoft.com/<lakehouse-guid>/Tables
   ```
   PAX does **not** accept the `abfss://` form directly — convert it to the equivalent HTTPS DFS form. The quickest conversion keeps the GUIDs and only changes the scheme and host (move the workspace ID in front of the host, drop the `@`):
   ```
   https://onelake.dfs.fabric.microsoft.com/<workspace-guid>/<lakehouse-guid>/Tables
   ```
   You can equivalently use the workspace and Lakehouse display names shown in the Fabric portal, in which case the item takes the `.Lakehouse` suffix:
   ```
   https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables
   ```
   For Schemas-mode Lakehouses (the current Fabric default), append the schema name — typically `dbo` (either form):
   ```
   https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo
   ```
5. **Run PAX:**
   ```powershell
   pwsh -File .\PAX_Purview_Audit_Log_Processor_v<x.y.z>.ps1 `
       -OutputPath 'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo' `
       -OutputPathLog 'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Files/pax_logs' `
       -Auth WebLogin `
       -Rollup
   ```
   (No `-StartDate` / `-EndDate` => script defaults to the last 30 days, UTC. To pin a window, pass e.g. `-StartDate '2026-04-14' -EndDate '2026-05-14'`.)
   You will get a browser prompt for the Graph scopes and (separately) for Az.Accounts to mint the OneLake storage token. After both succeed the script writes the audit Delta table(s) under `Tables/dbo/` and the run log under `Files/pax_logs/`.

   > **Dashboard selection.** `-Rollup` targets the **AI-in-One (AIO)** dashboard by default. Add `-Dashboard AIBV` for the **AI Business Value** dashboard, or `-Dashboard M365` (equivalently `-IncludeM365Usage`) for **M365 Usage Analytics**. AIO and AIBV are produced from the same CopilotInteraction + Entra/MAC licensing data — no other switches change.

   > **Anonymized output (`-Deidentify`).** Add `-Deidentify` to replace every identity (including the identity fields inside the raw `AuditData` JSON) with an irreversible, deterministic token **before** anything is written to the lakehouse — useful when the Fabric data will be shared more broadly. Off by default, works under any auth mode, and needs no extra Graph scope. See the main PAX documentation for the full field list.

   > **Org / manager hierarchy.** AIO / AIBV rollups automatically add org/manager-hierarchy columns to the Users output (level, manager, full management chain, direct/total report counts) from the Entra manager data PAX already collects — ready for parent-child org views in Power BI. `-FillerLabel` (`Self` / `RepeatManager` / `Fixed`, with `-FillerLabelText "<text>"` for the literal) only controls how empty deeper level columns are labelled. The M365 dashboard has no hierarchy.

That is the full minimum path. The rest of this README covers the variants you are likely to want next.

---

## Variant: scheduled run on the same host

If the laptop is replaced by a server (or just any always-on Windows host) and you want PAX to run on a schedule, use Windows Task Scheduler with either of the auth modes below.

### Option 1: `-Auth AppRegistration` with a certificate (recommended for unattended)

1. **Create an Entra ID app registration** in the portal. Note its tenant ID and application (client) ID.
2. **Add the Microsoft Graph application permissions** from section 4 to the app registration. Click **Grant admin consent** at the API permissions blade.
3. **Add the app registration as Contributor on the Fabric workspace** — section 3 (use the app registration's display name, not your user account).
4. **Upload a certificate** to the app registration (Certificates & secrets blade). Install the matching PFX on the host machine into `CurrentUser\My` (or `LocalMachine\My` — PAX searches both stores automatically). Note the thumbprint.
5. **Set environment variables** for the scheduled task (so secrets never appear on the command line):
   ```powershell
   [Environment]::SetEnvironmentVariable('GRAPH_TENANT_ID',                '<tenant-guid>',     'User')
   [Environment]::SetEnvironmentVariable('GRAPH_CLIENT_ID',                '<app-guid>',        'User')
   [Environment]::SetEnvironmentVariable('GRAPH_CLIENT_CERT_THUMBPRINT',   '<thumbprint-hex>',  'User')
   ```
6. **Create the scheduled task** to run a small wrapper script (PAX has no `-Days` parameter, so the wrapper computes the window dynamically):
   ```powershell
   # C:\PAX\Invoke-PAXDaily.ps1 — daily yesterday-only pull, registered as a Scheduled Task action.
   $end   = (Get-Date).ToUniversalTime().Date
   $start = $end.AddDays(-1)
   pwsh -NoProfile -File "C:\PAX\PAX_Purview_Audit_Log_Processor_v<x.y.z>.ps1" `
       -StartDate $start.ToString('yyyy-MM-dd') `
       -EndDate   $end.ToString('yyyy-MM-dd')   `
       -OutputPath 'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo' `
       -OutputPathLog 'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Files/pax_logs' `
       -Auth AppRegistration `
       -Rollup
   ```
   PAX picks up `GRAPH_TENANT_ID`, `GRAPH_CLIENT_ID`, and `GRAPH_CLIENT_CERT_THUMBPRINT` from the env automatically; no `-TenantId` / `-ClientId` / `-ClientCertificateThumbprint` need to be passed.

### Option 2: `-Auth AppRegistration` with a client secret

Same as Option 1, except the app registration holds a client secret instead of a cert. Set:
```powershell
[Environment]::SetEnvironmentVariable('GRAPH_TENANT_ID',     '<tenant-guid>', 'User')
[Environment]::SetEnvironmentVariable('GRAPH_CLIENT_ID',     '<app-guid>',    'User')
[Environment]::SetEnvironmentVariable('GRAPH_CLIENT_SECRET', '<secret>',      'User')
```
Cert is preferred over secret because rotation is harder with secrets and certs can be stored more securely on the host.

---

## Variant: run from an Azure VM with a managed identity

If you want unattended runs but prefer not to manage a cert or secret, host PAX on an Azure VM and use the VM's managed identity:

1. **Enable a managed identity on the VM** (system-assigned, or attach a user-assigned identity).
2. **Add that identity as Contributor on the Fabric workspace** in the Fabric portal.
3. **Grant the Microsoft Graph application permissions** from section 4 to the identity's service principal (the same scopes `Prereqs/Grant-PAXPermissions.ps1` grants in the container path — you can run that script with `-Mode Fabric` against this VM's MI if you want, even though you are not using ACA; only steps 1, 3, and 5 are relevant). Note that `Grant-PAXPermissions.ps1` still requires `-AcrResourceId` even in non-container scenarios — pass any ACR resource ID you have access to (the AcrPull grant in step 2 is harmless on an unused ACR). If you do not have any ACR, grant the scopes manually via the Entra portal admin-consent UI or a one-line `New-MgServicePrincipalAppRoleAssignment` script and skip `Grant-PAXPermissions.ps1` entirely.
4. **Install the runtime prerequisites** (section 1) on the VM.
5. **Set `AZURE_CLIENT_ID`** to the identity's client ID, then invoke (wrap in a small ps1 if you want a dynamic yesterday-only window — PAX has no `-Days` parameter):
   ```powershell
   $env:AZURE_CLIENT_ID = '<mi-client-id>'
   $end   = (Get-Date).ToUniversalTime().Date
   $start = $end.AddDays(-1)
   pwsh -NoProfile -File "C:\PAX\PAX_Purview_Audit_Log_Processor_v<x.y.z>.ps1" `
       -StartDate $start.ToString('yyyy-MM-dd') `
       -EndDate   $end.ToString('yyyy-MM-dd')   `
       -OutputPath 'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo' `
       -OutputPathLog 'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Files/pax_logs' `
       -Auth ManagedIdentity `
       -Rollup
   ```

This is functionally identical to the container path but skips the ACR + ACA layer. **Remember: Agent 365 enrichment is rejected up-front under `-Auth ManagedIdentity`.**

---

## Per-data-type destinations and append targets

Each output stream has an independent `-OutputPath*` / `-Append*` switch pair. **Storage tier is inferred from each path's form** (drive-rooted = Local, `https://…sharepoint.com/…` = SharePoint, `https://…onelake.dfs.fabric.microsoft.com/…` = Fabric). UNC paths (`\\server\share\…`) are rejected on every destination switch.

| Stream | Destination | Append target |
|---|---|---|
| Purview audit (raw / rollup / event-level) | `-OutputPath` | `-AppendFile` |
| EntraUsers / MAC licensing | `-OutputPathUserInfo` | `-AppendUserInfo` (auto-enables `-IncludeUserInfo`) |
| Agent 365 catalog | `-OutputPathAgent365Info` | `-AppendAgent365Info` (auto-enables `-IncludeAgent365Info`) |
| Run log | `-OutputPathLog` | _(n/a)_ |

Rules enforced at parameter validation:

- **Tier consistency.** All supplied `-OutputPath*` / `-Append*` values must resolve to the same tier. `-OutputPathLog` is the only exception in the Fabric direction: it may target Fabric `Files/…` while data destinations target Fabric `Tables/<schema>` (this is still one tier). Fabric `Tables/*` URLs on `-OutputPathLog` are rejected (logs are not tabular).
- **Pair XOR.** For each stream in scope, exactly one of `-OutputPath*` or `-Append*` must be bound.

### Example: Fabric run, every stream to its own Lakehouse location

```powershell
pwsh -File .\PAX_Purview_Audit_Log_Processor_v<x.y.z>.ps1 `
    -OutputPath               'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo' `
    -OutputPathUserInfo       'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo' `
    -OutputPathAgent365Info   'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo' `
    -OutputPathLog            'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Files/pax_logs' `
    -IncludeUserInfo `
    -IncludeAgent365Info `
    -Auth WebLogin `
    -Rollup
```

### Example: append run that merges into existing Fabric Delta tables

```powershell
pwsh -File .\PAX_Purview_Audit_Log_Processor_v<x.y.z>.ps1 `
    -AppendFile            'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo/Purview_Audit_CombinedUsageActivity_Interactions' `
    -AppendUserInfo        'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo/EntraUsers_MAClicensing_Users' `
    -OutputPathAgent365Info 'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo' `
    -OutputPathLog         'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Files/pax_logs' `
    -IncludeUserInfo `
    -IncludeAgent365Info `
    -Auth WebLogin `
    -Rollup
```

`-AppendFile` is supported under `-Rollup` and `-RollupPlusRaw` on all three tiers. The same example works against SharePoint or local paths by changing the URL / path form — no other switches change.

> **Two append cautions when writing to Fabric Delta tables.**
> - **Hierarchy / schema drift.** AIO / AIBV rollups add org/manager-hierarchy columns to the Users output. The Fabric Users append tolerates *added* columns but rejects *missing* ones — so appending current output into an older Users Delta table just adds the columns, but appending older (pre-hierarchy) output into a table that already has them fails the schema check. Keep a Users table on one PAX version line or recreate it.
> - **Deidentify consistency.** Appending a `-Deidentify` run into a non-deidentified table (or the reverse) is hard-rejected at pre-flight — use the same `-Deidentify` choice for every run that targets a given file/table.

### M365 rollup append anchoring (`-IncludeM365Usage` + `-Rollup` / `-RollupPlusRaw`)

The embedded M365 Bundle Explosion Processor produces 4 outputs into a single destination — `<stem>_Rollup.csv`, `<stem>_UserStats.csv`, `<stem>_SessionCohort.csv`, `<stem>_SessionStats.csv`. Only `_Rollup.csv` is the merge anchor; UserStats and SessionCohort are recomputed sidecars over the merged Rollup, and SessionStats is union-merged in place (additive counters keyed on `UserId`, `CreationDate`, `AppHost`). All three sidecars are anchored off the `-AppendFile` leaf stem so they overwrite their derived destination URLs in-place each run.

**Rules:**

- `-AppendFile` MUST point to a `_Rollup.csv` leaf (local path / SharePoint URL / Fabric URL); a timestamped `_Rollup_<YYYYMMDD_HHMMSS>.csv` leaf is also accepted. Sidecar leaves (`_UserStats.csv`, `_SessionCohort.csv`, `_SessionStats.csv`) and other rollup shapes (`_Interactions.csv`, `_Exploded.csv`) are rejected at pre-flight with a leaf-specific error.
- The three sidecar files are written next to the AppendFile target (same parent) using the leaves `<anchor_stem>_UserStats.csv`, `<anchor_stem>_SessionCohort.csv`, and `<anchor_stem>_SessionStats.csv`. Across runs, the destination always has exactly one current set of all 4 files.
- Renamed AppendFile is fine as long as the leaf still ends in `_Rollup.csv` (e.g. `MyM365_Rollup.csv` → sidecars `MyM365_UserStats.csv` / `MyM365_SessionCohort.csv` / `MyM365_SessionStats.csv`).
- Prior sidecars with different leaf names (from a previous run before renaming) are NOT auto-deleted; clean them up manually if you want zero orphans.
- First-time append: run once WITHOUT `-AppendFile` to produce the initial `_Rollup.csv` (plus sidecars), then point `-AppendFile` at that `_Rollup.csv` on subsequent runs.

**Example: M365 rollup append against a Fabric Lakehouse**

```powershell
pwsh -File .\PAX_Purview_Audit_Log_Processor_v<x.y.z>.ps1 `
    -AppendFile          'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo/Purview_Audit_UsageActivity_CombinedActivityTypes_20260101_120000_Rollup.csv' `
    -AppendUserInfo      'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Tables/dbo/EntraUsers_MAClicensing_20260101_120000_Users.csv' `
    -OutputPathLog       'https://onelake.dfs.fabric.microsoft.com/<Workspace>/<Lakehouse>.Lakehouse/Files/pax_logs' `
    -IncludeM365Usage `
    -IncludeUserInfo `
    -Auth WebLogin `
    -Rollup
```

On Fabric `Tables/<schema>`, the destination ends up with 4 stable Delta tables under the same schema: `<anchor_stem>_Rollup`, `<anchor_stem>_UserStats`, `<anchor_stem>_SessionCohort`, `<anchor_stem>_SessionStats`. The merged-and-recomputed CSVs land via `Convert-CsvToDelta -Mode overwrite` on every run.

### Provenance columns on appended files

Every appended file gains three trailing columns at merge time:

| Column | Type | Semantics |
|---|---|---|
| `Date_Added` | `YYYY-MM-DD` | First-seen date in the merged file. Immutable. |
| `Latest_Append_Date` | `YYYY-MM-DD` | Latest run that touched the file (same on every row). |
| `In_Latest_Append` | `TRUE` / `FALSE` | Whether the row appeared in this run's audit window / membership snapshot. `FALSE` for rows retained from prior runs that no longer surface today. |

The CopilotInteraction rollup Fact CSV additionally carries two stable identity columns: **`Message_Id_Raw`** and **`ThreadId_Raw`**. These keep the per-run integer surrogates (`Message_Id`, `ThreadId`) stable across appends so multi-month threads remain a single thread in downstream models.

### Pristine raw EntraUsers under `-AppendUserInfo`

Under `-AppendUserInfo` (rollup or non-rollup), the EntraUsers CSV the audit phase writes is kept **pristine** at its natural timestamped name (`EntraUsers_MAClicensing_<RunTimestamp>.csv`) — it is never overwritten by the append-merge. The merged union is written to the `-AppendUserInfo` target instead. If the AppendUserInfo target's leaf would collide with the raw file in the same folder, the raw is suffixed with `_raw` so both files coexist on disk.

The end-of-run summary reports the raw path and the merged target on separate lines (`Raw EntraUsers CSV: …` and `Appended to: …`).

---

## OneLake URL shapes PAX accepts

| Shape | Use as | Example |
|---|---|---|
| Lakehouse root | `-OutputPath` | `https://onelake.dfs.fabric.microsoft.com/PAX-Workspace/PAX.Lakehouse` |
| Explicit `Tables/` | `-OutputPath` | `…/PAX.Lakehouse/Tables` |
| Schemas-mode `Tables/<schema>` | `-OutputPath` (recommended for current Fabric) | `…/PAX.Lakehouse/Tables/dbo` |
| `Files/<subpath>` | `-OutputPathLog`, other non-tabular outputs | `…/PAX.Lakehouse/Files/pax_logs` |

In every shape above, the workspace and item may be addressed either by **name** (the item taking the `.Lakehouse` suffix, as shown) or by their **GUIDs** with no suffix — for example `https://onelake.dfs.fabric.microsoft.com/<workspace-guid>/<lakehouse-guid>/Tables/dbo`. The GUIDs are the values shown in the Lakehouse's Fabric portal page URL.

Delta table names come from the local CSV basename (with the `_YYYYMMDD_HHMMSS` run-timestamp suffix stripped), not from the trailing segment of your URL. Successive runs against the same URL therefore overwrite the same Delta table.

---

## Verifying the run

After a successful run:

- In the Fabric portal, open the Lakehouse → **Tables** view. You should see `PAX_Purview_Audit_Log`, `EntraUsers` (if `-IncludeUserInfo`), and so on as Delta tables.
- The run log lives under `Files/pax_logs/` (or whatever `-OutputPathLog` you passed). Open it in the Files viewer.
- The script also prints a local "Output files created" summary at the end, listing every artifact and its size, plus the upload sweep results.

If a Fabric write fails, the most common cause is missing workspace Contributor membership for the identity PAX signed in as — re-check section 3.
