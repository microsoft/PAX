# PAX + Microsoft Fabric — the two supported paths

> [!IMPORTANT]
> **Microsoft Agent 365 enrichment is temporarily disabled pending further testing.**
> The switches `-IncludeAgent365Info`, `-OnlyAgent365Info`, `-OutputPathAgent365Info`,
> and `-AppendAgent365Info` are gated at script startup and will cause PAX to exit
> immediately with a notice. References to Agent 365 elsewhere in this document are
> preserved for when the feature is re-enabled.

PAX writes Delta tables and files to a Microsoft Fabric Lakehouse whenever an `-OutputPath*` parameter points at a OneLake URL. **There are two officially supported hosting patterns** for that, and they have very different setup costs. Pick the one that matches how you actually want to run.

| | **Path A — Local / direct run** | **Path B — Container (ACA Job)** |
|---|---|---|
| **You run PAX from** | A Windows laptop, on-prem server, or Azure VM | An Azure Container Apps Job (scheduled or on-demand) |
| **Setup complexity** | Low — no Azure resources required beyond the Fabric workspace itself | High — ACR, ACA environment, managed identity, image build |
| **What invokes the script** | You (or Task Scheduler / cron on the host) | ACA Job runtime, on a cron expression |
| **Auth modes that fit** | `-Auth WebLogin`, `-Auth DeviceCode`, `-Auth AppRegistration` (cert or secret), `-Auth Credential`, `-Auth Silent` | `-Auth ManagedIdentity` (recommended) or `-Auth AppRegistration` |
| **Agent 365 enrichment (`-IncludeAgent365Info` / `-OnlyAgent365Info`) supported?** | Yes — under any delegated auth mode | No (under `-Auth ManagedIdentity`). Yes if you use `-Auth AppRegistration` (PAX top-ups a delegated context for the agent phase only). |
| **Secret rotation** | Your responsibility (if using `AppRegistration` with a secret) | None when using managed identity |
| **Setup scripts in this folder** | None required. See [`LocalRun/README.md`](LocalRun/README.md) for the step-by-step. | [`Prereqs/Grant-PAXPermissions.ps1`](Prereqs/Grant-PAXPermissions.ps1) and [`Deploy/Deploy-PAXAcaJob.ps1`](Deploy/Deploy-PAXAcaJob.ps1). See [`Prereqs/README.md`](Prereqs/README.md) and [`Deploy/README.md`](Deploy/README.md). |
| **Image** | Not needed | Built from [`Dockerfile/PAX.Dockerfile`](Dockerfile/PAX.Dockerfile), pushed to ACR |

## Which one should I pick?

- **Pick Path A** if you want the fastest possible time-to-first-write, you are okay with the run being tied to whatever host you put it on, and / or you need Agent 365 enrichment.
- **Pick Path B** if you want a fully unattended scheduled run hosted entirely inside Azure, with no long-lived secrets, and you do not need Agent 365 enrichment.

Both paths write to the **same Fabric workspace and lakehouse** in the same way — the script does not detect whether it is containerized. The only difference is where the script runs and how its identity is established.

## What every Fabric run needs (regardless of path)

The script itself requires the same runtime and the same Fabric permissions in both paths. The only thing that varies is how those are provisioned.

**On the host that runs the script:**

- PowerShell 7+ (the script's own `#requires` line).
- The `Microsoft.Graph` PowerShell module.
- The `Az.Accounts` module (used to mint the OneLake storage-audience token when an `-OutputPath*` is a OneLake URL).
- Python 3 with `pyarrow>=14` and `deltalake>=0.15` available on PATH. PAX will pip-install them on demand via its `Install-DeltalakeIfMissing` helper, but pre-installing avoids cold-start time.
- Outbound HTTPS to `graph.microsoft.com`, `*.onelake.dfs.fabric.microsoft.com`, and `login.microsoftonline.com`.

**On the Fabric workspace:**

- The identity PAX runs as (your user account, a service principal, or a managed identity) must have **Contributor or higher** on the Fabric workspace that backs the target lakehouse. This is granted in the Fabric portal: *Workspace → Manage access → Add people or groups*. Without it, OneLake DFS writes return 403 regardless of any Azure RBAC role.
- For the container path only, the same identity also needs `Storage Blob Data Contributor` at the workspace's Azure resource scope — `Grant-PAXPermissions.ps1` does this for you.

**Microsoft Graph permissions on the identity that PAX authenticates with:**

Always:
- `AuditLogsQuery.Read.All` — for `/security/auditLog/queries`
- `User.Read.All` — for `/users` and the EntraUsers CSV
- `Organization.Read.All` — for `/subscribedSkus` license-SKU lookups
- `GroupMember.Read.All` — only when `-GroupNames` is used, but pre-grant for headless runs

With `-IncludeM365Usage`:
- `AuditLogsQuery-Exchange.Read.All`
- `AuditLogsQuery-OneDrive.Read.All`
- `AuditLogsQuery-SharePoint.Read.All`

(The container path's `Prereqs/Grant-PAXPermissions.ps1` provisions all of these for you. The local path defers to whatever auth mode you pick — see `LocalRun/README.md`.)

## Destination model

PAX routes each data type to its own destination through a symmetric `-OutputPath*` / `-Append*` switch pair. **Storage tier is inferred from the path form on every destination switch:**

- Drive-rooted absolute path (`C:\Data\…`) → Local tier.
- `https://…sharepoint.com/…` URL → SharePoint tier.
- `https://…onelake.dfs.fabric.microsoft.com/…Lakehouse/…` URL → Fabric tier.
- UNC paths (`\\server\share\…`) are rejected on every destination switch.

The seven switches and their pairings:

| Data destination switch | Paired append switch | Purpose |
|---|---|---|
| `-OutputPath` | `-AppendFile` | Purview audit output (raw, rollup, or event-level) |
| `-OutputPathUserInfo` | `-AppendUserInfo` | EntraUsers / MAC licensing CSV |
| `-OutputPathAgent365Info` | `-AppendAgent365Info` | Agent 365 catalog CSV |
| `-OutputPathLog` | _(n/a)_ | Run log |

Operating rules:

- **Tier consistency.** All destination switches supplied to a single run must resolve to the same storage tier (Local, SharePoint, or Fabric). Mixed-tier invocations are rejected at parameter validation. `-OutputPathLog` may target Fabric `Files/` even when the data destinations target Fabric `Tables/<schema>`; Fabric `Tables/*` URLs on `-OutputPathLog` itself are rejected (logs are not tabular).
- **Pair XOR.** For each stream in scope, exactly one of its `-OutputPath*` / `-Append*` pair must be supplied — both bound or neither bound is rejected.
- **Append surface.** `-AppendFile` works under `-Rollup` and `-RollupPlusRaw` on all three tiers. Per-dimension `-AppendUserInfo` and `-AppendAgent365Info` perform a union merge on the EntraUsers and Agent 365 catalog respectively, keyed on `PersonId_Normalized` and `AgentId`.
- **M365 rollup append.** Under `-IncludeM365Usage` + `-Rollup` / `-RollupPlusRaw`, the embedded M365 Bundle processor emits four files into the same destination — `_Rollup.csv`, `_UserStats.csv`, `_SessionCohort.csv`, and `_SessionStats.csv`. `-AppendFile` MUST point to the `_Rollup.csv` leaf; the three sidecars are recomputed/merged each run, anchored off the same leaf stem, and overwrite their derived destination URLs in-place (`_SessionStats.csv` is union-merged in place with additive counter semantics). Sidecar leaves (`_UserStats.csv`, `_SessionCohort.csv`, `_SessionStats.csv`) and CopilotInteraction (`_Interactions.csv`) / event-level (`_Exploded.csv`) leaves are rejected at pre-flight.
- **Provenance columns.** Every appended file (Fact CSV, raw `-AppendFile` audit CSV, EntraUsers CSV) gains three trailing columns at merge time: `Date_Added`, `Latest_Append_Date`, `In_Latest_Append`. Rows that departed from the latest audit window are retained in the union with `In_Latest_Append = FALSE` so historical fact-table joins continue to resolve. The CopilotInteraction rollup Fact CSV additionally carries two stable raw-identity columns: `Message_Id_Raw` and `ThreadId_Raw`.
- **Pristine raw EntraUsers under `-AppendUserInfo`.** The raw Entra membership snapshot written by the audit phase is never overwritten by the append-merge. The union lands at the `-AppendUserInfo` target; the raw file keeps its natural timestamped leaf (or gets a `_raw` suffix on the rare path/leaf collision).

When any `-OutputPath*` resolves to a Fabric OneLake URL, customer-visible outputs are written as **Delta tables** under the Lakehouse `Tables/` namespace (Schemas-mode Lakehouse `Tables/<schema>` is the current Fabric default; `dbo` is typical). Operational artifacts (run log, metrics JSON) land under `Files/`. The Python `deltalake` package is auto-installed on first use; offline hosts can pre-install it (see `LocalRun/README.md` and `Dockerfile/PAX.Dockerfile`).

## Folder map

```
fabric_resources/
├── README.md                ← this file (overview + destination model)
├── CompatibilityMatrix.md   ← supported runtime contract (host runtime, modules, auth × destination matrix)
├── LocalRun/
│   └── README.md        ← Path A: run PAX directly from a host (laptop / VM / server)
├── Prereqs/             ← Path B only
│   ├── README.md
│   └── Grant-PAXPermissions.ps1    (one-time managed-identity bootstrap)
├── Deploy/              ← Path B only
│   ├── README.md
│   └── Deploy-PAXAcaJob.ps1        (deploy / update the ACA Job)
└── Dockerfile/          ← Path B only
    └── PAX.Dockerfile              (image build)
```
