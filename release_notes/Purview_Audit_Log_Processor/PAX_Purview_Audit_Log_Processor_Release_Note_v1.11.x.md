# Release Notes: v1.11.x

## Release Information

- **Latest Version:** 1.11.1
- **Latest Release Date:** 2026-05-11
- **Released By:** Microsoft Copilot Growth ROI Advisory Team (copilot-roi-advisory-team-gh@microsoft.com)

---

## Script Download & Support

Download the script below.  For questions or issues, refer to the documentation.

- **PAX Purview Audit Log Processor Script v1.11.1:** [PAX_Purview_Audit_Log_Processor_v1.11.1.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.11.1/PAX_Purview_Audit_Log_Processor_v1.11.1.ps1)
- **Documentation v1.11.x (Markdown):** [PAX_Purview_Audit_Log_Processor_Documentation_v1.11.x.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.11.x.md)

---

## Overview

### v1.11.1

Version 1.11.1 is a large functional release. It introduces three flagship capabilities — the **`-Rollup` / `-RollupPlusRaw`** post-processor, **Microsoft Agent 365 catalog enrichment**, and **remote output destinations** (SharePoint and Microsoft Fabric / OneLake) — alongside a new `ManagedIdentity` auth mode for Azure-hosted unattended runs and major reliability and authentication hardening. Existing Purview audit-log processing behavior is unchanged when none of the new switches are used.

#### 🚀 Rollup Post-Processor (`-Rollup` / `-RollupPlusRaw`)

The new **`-Rollup`** and **`-RollupPlusRaw`** switches turn PAX into an end-to-end pipeline: as soon as the audit export succeeds, an embedded Python post-processor runs against the raw CSV(s) and emits **rolled-up CSVs shaped specifically for the Microsoft Copilot Growth ROI Advisory Team's Power BI templates** published at <https://github.com/microsoft/Analytics-Hub>. This collapses what was previously a multi-step, manual hand-off (run PAX → locate raw CSV → run a separate Python script → load into Power BI) into a single command line.

Highlights:

- **Two switches, one pipeline.** `-Rollup` deletes the raw CSV(s) on processor success (only the rollup output remains); `-RollupPlusRaw` keeps the raw CSV(s) alongside the rollup output. Mutually exclusive.
- **Auto-selected processor based on the audit run's shape.**
  - **CopilotInteraction-only run** → embedded `Purview_CopilotInteraction_Processor` v3.0.0. `-IncludeUserInfo` is auto-enabled because this processor consumes both the Purview CSV and the Entra users CSV. **Target Analytics-Hub dashboards:** *AI-in-One* and *AI Business Value*.
  - **`-IncludeM365Usage` run** → embedded `Purview_M365_Usage_Bundle_Explosion_Processor` v2.1.0. `-CombineOutput` is auto-enabled so a single combined Purview CSV is fed to the processor. **Target Analytics-Hub dashboard:** *M365 Usage Analytics*.
- **Single-file distribution preserved.** Both Python sources are embedded byte-for-byte inside the `.ps1`. At runtime the selected source is materialized into `.pax_incremental\PAX_<Label>_<RunTimestamp>.py`, executed, and reaped by the function's `finally` block plus an end-of-run safety-net sweep. No external Python files to ship or maintain.
- **Zero-friction Python bootstrap.** PAX auto-detects Python 3.10+ on PATH (`python` → `py -3.13/-3.12/-3.11/-3.10` → `python3`). If none is found it attempts a per-user silent install of Python 3.13 via winget (`Python.Python.3.13`), falling back to the python.org offline installer. `orjson` is installed best-effort for ~5–10× faster JSON parsing; both processors fall back to stdlib `json` on import failure.
- **Best-effort, non-destructive failure semantics.** A non-zero processor exit code logs an error and **keeps** the raw outputs (regardless of `-Rollup` vs `-RollupPlusRaw`); the raw CSV(s) already on disk remain the canonical successful artifact. The audit run is never marked failed because of a rollup failure.
- **Resume-safe.** The checkpoint snapshot persists `rollupMode` (`None` / `Rollup` / `RollupPlusRaw`) and `processorMode` (`None` / `CopilotInteraction` / `M365Bundle`). On `-Resume`, the original rollup intent is restored automatically; if the resume command line passes a rollup switch explicitly, last-write-wins (override logged in yellow).
- **Agent 365 companion file is always retained.** `-Rollup` is compatible with `-IncludeAgent365Info` and never deletes the `Agent365_<timestamp>.csv` — Analytics-Hub dashboards consume it as a companion input alongside the rollup output.

> ⚠️ **Scope reminder.** The rollup outputs exist **solely** to feed the Microsoft Copilot Growth ROI Advisory Team's Power BI templates at <https://github.com/microsoft/Analytics-Hub>. Schema, column names, aggregation grain, and join keys are dictated by those data models. For generic analytics exports, run PAX without `-Rollup` / `-RollupPlusRaw` and consume the raw CSV directly.

See [Rollup Post-Processor: `-Rollup` / `-RollupPlusRaw` (v1.11.1)](#rollup-post-processor--rollup---rollupplusraw-v1111) below for the full feature matrix, blocked combinations, and examples.

#### 🆕 Microsoft Agent 365 Catalog Enrichment (`-IncludeAgent365Info` / `-OnlyAgent365Info`)

A pair of new switches — **`-IncludeAgent365Info`** (audit run + Agent 365 enrichment) and **`-OnlyAgent365Info`** (Agent 365 enrichment only) — produce a dedicated `Agent365_<timestamp>.csv` (or `Agents365` Excel tab) whose 28-column schema matches the manual Agent 365 dashboard export. Data is sourced from the Microsoft Graph Agent Package Management API (`https://graph.microsoft.com/beta/copilot/admin/catalog/packages`). Available to tenants enrolled in the Microsoft Agent 365 Frontier program; signed-in caller must hold AI Administrator (preferred) or Global Administrator.

#### ☁️ Remote Output Destinations — SharePoint & Microsoft Fabric / OneLake (`-OutputPathSP` / `-OutputPathFabric`)

Two new mutually-exclusive parameters extend `-OutputPath` (local directory) with first-class remote destinations so PAX can publish directly into a SharePoint document library or a Microsoft Fabric Lakehouse without an intermediate local copy.

- **`-OutputPathSP <SharePointFolderUrl>`** — Uploads every customer-visible artifact (CSV, XLSX, run log, metrics JSON) directly to a SharePoint Online document-library folder via Microsoft Graph (`createUploadSession` for files >4 MiB, `PUT /content` for small files). Folder hierarchy is created server-side if missing. Requires `Sites.ReadWrite.All` + `Files.ReadWrite.All` on the same identity used for the audit phase.
- **`-OutputPathFabric <OneLakeUrl>`** — Uploads to a Fabric Lakehouse / Warehouse `Files` path via the OneLake DFS REST surface (ADLS Gen2 create → append → flush). Requires Azure RBAC `Storage Blob Data Contributor` on the workspace plus Fabric portal `Contributor` membership; for service-principal / managed-identity runs the tenant setting *"Service principals can use Fabric APIs"* must be enabled.
- **Pre-flight probe with classified diagnostics.** Reachability and folder creation are validated immediately after authentication, before any audit query is issued. On failure, a single structured Cause / Action banner names the exact missing permission, role, workspace, or URL segment (401 vs 403 vs 404, delegated vs app-only, missing module vs IMDS unreachable for OneLake), and the run aborts cleanly with `exit 1` — no partial artifacts, no stack trace.
- **Long-run token-refresh infrastructure for OneLake.** A new Azure (storage-audience) access-token refresh layer mirrors the existing Graph token-refresh design so multi-hour Fabric runs survive the full audit window. Tokens are proactively refreshed every ~50 minutes (below the 60-minute issuance lifetime) with a transparent single-retry on the rare mid-flight 401.
- **Remote-aware path display.** Every output file / directory / log-path string emitted to the console and run log resolves to the SharePoint URL or OneLake URL when a remote destination is in effect — the temporary local scratch folder (`$env:TEMP\PAX_<RunTimestamp>\`) PAX uses internally is never surfaced to the customer.
- **Checkpoint and resume are LOCAL.** Checkpoint and partial-output files (`.pax_checkpoint_<RunTimestamp>.json`, `*_PARTIAL.csv`, `.pax_incremental/*.jsonl`) are always written to the local scratch folder and are never mirrored remotely. `-Resume` is a same-host operation — re-run from the same machine that produced the checkpoint. Only customer-visible final artifacts upload at end of run.

> 📚 **Fabric setup, deployment, and unattended-execution details.** For detailed guidance on configuring Microsoft Fabric for use with `-OutputPathFabric`, the Azure Container Apps Job runbook, managed-identity setup, and Fabric RBAC grants, see the `fabric_resources` folder distributed alongside the script.

#### 🔐 Managed-Identity Authentication for Azure-Hosted Runs (`-Auth ManagedIdentity`)

New sixth value on the `-Auth` ValidateSet for Azure-hosted headless execution (Container Apps Jobs, Functions, App Service, VMs). Supports system-assigned and user-assigned identities (the latter via `AZURE_CLIENT_ID`) and binds both the Microsoft Graph and Azure (storage) contexts to the same identity, so a single managed identity drives both the audit pull and the Fabric upload. Failures (missing identity, missing consent, IMDS unreachable) exit cleanly with no interactive fallback. `-IncludeAgent365Info` and `-OnlyAgent365Info` are blocked under ManagedIdentity (no interactive sign-in surface for the Agent 365 delegated-only API).

#### 🛡️ Reliability & Authentication Hardening

- **Audit-query poll ceiling extended from 5 minutes to 4 hours** with heartbeat status messages and exponential backoff — eliminating premature timeouts on large-tenant queries (especially with `-IncludeM365Usage` or DSPM bundles).
- **AppRegistration authentication and certificate-handling fixes** that resolve intermittent token-refresh failures (`AADSTS70002`, `invalid handle`) and remove silent fallback to interactive sign-in in unattended scheduled-task scenarios.

---

## What's New

### v1.11.1

#### Microsoft Agent 365 Catalog Enrichment: `-IncludeAgent365Info` / `-OnlyAgent365Info` (v1.11.1)

| Area | Details |
| --- | --- |
| **Purpose** | Capture the Microsoft Agent 365 catalog for a tenant (the same data shown in the Agent 365 admin dashboard manual export) alongside or instead of a normal Purview audit run. |
| **Availability** | Tenants enrolled in the Microsoft Agent 365 Frontier program. Source: Microsoft Graph Agent Package Management API (`https://graph.microsoft.com/beta/copilot/admin/catalog/packages`). |
| **CLI usage** | `-IncludeAgent365Info` (audit run + Agent 365) or `-OnlyAgent365Info` (Agent 365 only — skips the audit pull). |
| **Output (CSV)** | `Agent365_<timestamp>.csv` — 28 columns matching the manual export schema, UTF-8 with BOM, dates formatted `yyyy-MM-dd HH:mm:ssZ` (UTC). |
| **Output (Excel)** | `Agents365` tab appended after the `EntraUsers` tab when `-ExportWorkbook` is used. |
| **Audit-log enrichment** | `Date created` and `Created by` columns are populated via a single narrow audit query through the existing `/security/auditLog/queries` infrastructure (~5–30 seconds added per run, independent of tenant size). In `-OnlyAgent365Info` mode these two columns are intentionally left blank. |
| **No fabrication** | Missing fields produce empty cells rather than synthesized values. |

##### Examples (v1.11.1)

```powershell
# Audit run with Agent 365 enrichment
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-04-01 `
  -EndDate 2026-04-08 `
  -IncludeAgent365Info `
  -OutputPath "C:\Exports\"

# Agent 365 catalog only (no audit pull)
./PAX_Purview_Audit_Log_Processor.ps1 `
  -OnlyAgent365Info `
  -OutputPath "C:\Exports\"
```

---

#### Authentication Behavior — Agent 365 (v1.11.1)

The Agent 365 catalog endpoint requires **two independent permission gates**, both of which must be satisfied:

1. **Microsoft Graph delegated scopes:** `CopilotPackages.Read.All` and `Application.Read.All`. The endpoint is **delegated only** — there is no app-only equivalent.
2. **Entra directory role:** The signed-in user must hold **AI Administrator** (preferred) or **Global Administrator**. Without the role, the endpoint returns 403 even when Graph consent is in place.

| Auth Mode | Behavior |
| --- | --- |
| **Interactive** (`WebLogin`, `DeviceCode`, `Credential`, `Silent`) | Required Graph scopes are expanded automatically when either new switch is set. Single sign-in — no second prompt. |
| **`-Auth AppRegistration` + `-IncludeAgent365Info`** (dual-context run) | The audit phase runs app-only as before. One **up-front** interactive sign-in (immediately after the Phase 1 connection is established) supplies the delegated Agent 365 scopes so the audit phase can run unattended afterward. The Agent 365 endpoint is also probed at startup so a missing Frontier enrollment / role surfaces before the audit begins. The app-only context is then restored without disconnecting the Mg SDK; the cached delegated MSAL token survives so Phase 2 reconnects silently at end of run with no second prompt. |
| **`-Auth AppRegistration` + `-OnlyAgent365Info`** | Rejected at parameter validation with an informational banner (no audit phase to justify a secondary interactive sign-in). |

---

#### Frontier Enrollment Probe (v1.11.1)

PAX performs an **eager** Frontier enrollment / role probe at startup. Tenants not enrolled in the Microsoft Agent 365 Frontier program (or callers without AI Administrator / Global Administrator role) receive an informational banner with a Microsoft Learn URL. The Agent 365 CSV / tab is silently skipped at end of run; the rest of the run continues unaffected.

All output banners, parameter snapshots, output-mode displays, Excel tab-list builders, and run-completion summaries honor the probe result — so unavailable tenants never see references to a file or tab that won't be produced.

---

#### Parameter Compatibility — Agent 365 (v1.11.1)

- `-IncludeAgent365Info` and `-OnlyAgent365Info` are mutually exclusive.
- Both new switches are blocked in `-RAWInputCSV` (replay mode) and `-UseEOM`.
- `-IncludeAgent365Info` IS compatible with `-Resume`. The checkpoint persists the flag, so the audit phase resumes from the checkpoint and Agent 365 enrichment runs automatically at end of run — no need to specify the switch again on the resume command line.
- `-IncludeUserInfo` is allowed with both new switches (still emits the `EntraUsers` CSV alongside).
- `-OnlyAgent365Info` is rejected when combined with any of: `-IncludeM365Usage`, `-IncludeCopilotInteraction`, `-IncludeDSPMForAI`, `-AgentsOnly`, `-ExcludeAgents`, `-CombineOutput`, `-OnlyUserInfo`, `-AppendFile`, `-Auth AppRegistration`, `-Resume`.

---

#### Permissions Display Banner (v1.11.1)

The startup `QUERY MODE: Microsoft Graph Security API` banner now reports the effective auth context for the run as **`APP-ONLY (application permissions)`**, **`DELEGATED (interactive user sign-in)`**, or **`DUAL-CONTEXT RUN`** (when `-Auth AppRegistration` is combined with `-IncludeAgent365Info`, with explicit Phase 1 / Phase 2 sub-lines).

Each Graph permission line is tagged with one of `[App-only]`, `[Delegated]`, or `[Role]` so the reader knows exactly where to grant it. The Agent 365 block always uses `[Delegated]` Graph scopes plus a `[Role]` line listing AI Administrator (preferred) / Global Administrator (alternative). The connection-success message and the AppRegistration + Agent 365 informational banner use matching Phase 1 / Phase 2 vocabulary.

---

#### Reliability — Audit-Query Poll 4-Hour Ceiling (v1.11.1)

The audit-query polling loop has been extended from a 5-minute hard timeout to a **4-hour ceiling** with periodic heartbeat status messages and exponential backoff between polls.

Large-tenant audit queries — especially with `-IncludeM365Usage` or DSPM bundles — that previously failed with a premature "query timed out" error now run to completion. No behavior change for fast queries.

---

#### Rollup Post-Processor: `-Rollup` / `-RollupPlusRaw` (v1.11.1)

> **Purpose & scope.** These switches exist **solely to produce input files for the Microsoft Copilot Growth ROI Advisory Team's Power BI templates** published at <https://github.com/microsoft/Analytics-Hub>. The rolled-up CSVs are shaped specifically for those templates — schema, column names, aggregation grain, and join keys are all dictated by the Power BI data models. **The rollup outputs are not intended for any other downstream use.** For generic analytics exports, run PAX without `-Rollup` / `-RollupPlusRaw` and consume the raw CSV directly.

| Area | Details |
| --- | --- |
| **Purpose** | Run an embedded Python post-processor against the audit run's final CSV immediately after a successful export, producing rolled-up CSV(s) shaped specifically for the Microsoft Copilot Growth ROI Advisory Team's Power BI templates at <https://github.com/microsoft/Analytics-Hub>. |
| **CLI usage** | `-Rollup` (deletes raw CSV(s) on processor success — only rollup output remains) **or** `-RollupPlusRaw` (keeps raw CSV(s) alongside the rollup output). Mutually exclusive. |
| **Auto-selected processor & target dashboard** | **CopilotInteraction-only run** (default activity type, or `-ActivityTypes 'CopilotInteraction'`) → embedded `Purview_CopilotInteraction_Processor` v3.0.0; `-IncludeUserInfo` is auto-enabled because this processor consumes both the Purview CSV and the Entra users CSV (`EntraUsers_MAClicensing_<timestamp>.csv`). **Target Analytics-Hub dashboards:** *AI-in-One* and *AI Business Value*. **`-IncludeM365Usage` run** → embedded `Purview_M365_Usage_Bundle_Explosion_Processor` v2.1.0; `-CombineOutput` is auto-enabled by `-IncludeM365Usage` so a single combined Purview CSV is fed to the processor. **Target Analytics-Hub dashboard:** *M365 Usage Analytics*. |
| **Agent 365 companion file** | `-IncludeAgent365Info` is **compatible** with rollup. The resulting `Agent365_<timestamp>.csv` is a **point-in-time snapshot of the live tenant catalog** at the moment the script runs (sourced from the Microsoft Graph Package Management API `/beta/copilot/admin/catalog/packages`, a current-inventory call with no historical / as-of semantic). It is **not** filtered by `-StartDate` / `-EndDate`, returns all currently-cataloged items regardless of age (deleted items are not retrievable), and is consumed by the same Analytics-Hub dashboards as a companion input alongside the rollup output. **Always retained** — `-Rollup` never deletes it. Created / Created By columns are populated via a separate Unified Audit Log join bounded by tenant audit retention (180 days E3 / 1 year E5 / up to 10 years with Audit Premium) and the run's date window (default 30 days). Note the temporal mismatch: rollup data spans the audit window, Agent 365 reflects catalog state at run time. |
| **Embedded sources** | Both Python sources are embedded byte-for-byte as single-quoted PowerShell here-strings inside the `.ps1`, preserving the single-file distribution. At runtime the selected source is materialized to a temp `PAX_<Label>_<RunTimestamp>.py` inside `.pax_incremental` (UTF-8 no-BOM), executed, and deleted in the function's `finally` block. The end-of-run cleanup sweep and the outer `finally`-block safety-net both reap any leftover `PAX_*_<RunTimestamp>.py` scoped to the current run. |
| **Python runtime** | Python **3.10+** is required (the embedded processors use PEP 604 union syntax). PAX auto-detects an interpreter on PATH (`python` → `py -3.13/-3.12/-3.11/-3.10` → `python3`). If none is found, PAX attempts a per-user silent install of Python 3.13 — **winget** (`Python.Python.3.13`) first, then the **python.org** offline installer (`https://www.python.org/ftp/python/3.13.1/python-3.13.1-amd64.exe`) as a fallback. `orjson` is installed best-effort for ~5–10× faster JSON parsing; both processors fall back to stdlib `json` on import failure. |
| **Failure semantics** | The embedded post-processor is best-effort. A non-zero exit code logs an error and **keeps** raw outputs (regardless of `-Rollup` vs `-RollupPlusRaw`). It does NOT throw past this point and does NOT mark the audit run as failed — the raw CSV(s) already on disk are the canonical successful artifact. |
| **Banner** | When a rollup switch is in effect, a cyan banner is emitted immediately after the permissions banner (which embedded processor will run, raw-CSV retention, Python auto-install note). |
| **Checkpoint persistence** | The checkpoint snapshot now persists `rollupMode` (`None` / `Rollup` / `RollupPlusRaw`) and `processorMode` (`None` / `CopilotInteraction` / `M365Bundle`). On `-Resume`, the original rollup intent is restored when the resume command line does not pass `-Rollup` or `-RollupPlusRaw`; if the resume command line DOES pass a rollup switch, **last-write-wins** (resume value overrides checkpoint, override logged in yellow). The processor mode is re-derived after the full resume merge so a checkpoint-restored `-IncludeM365Usage` correctly maps to `M365Bundle` even when the resume CLI omits it. |
| **Blocked combinations** | Validation exits with an error when `-Rollup` or `-RollupPlusRaw` is combined with any of: `-UseEOM`, `-ExportWorkbook`, `-OnlyUserInfo`, `-OnlyAgent365Info`, `-IncludeDSPMForAI`, `-RAWInputCSV`, `-AppendFile`, or `-ExcludeCopilotInteraction` without `-IncludeM365Usage`. |
| **PowerShell version gate** | The pre-existing PS-version guard was strengthened to hard-fail unless PowerShell 7+ is in use OR `-UseEOM` is set (previously the guard exempted `-RAWInputCSV` and `-Resume`). Rollup is incompatible with both `-UseEOM` and `-RAWInputCSV`, so the new guard correctly forces PS 7+ for any rollup run. |

##### Examples (v1.11.1)

```powershell
# CopilotInteraction-only run, deletes raw CSVs after rollup
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-04-01 `
  -EndDate 2026-04-08 `
  -Rollup `
  -OutputPath "C:\Exports\"

# CopilotInteraction-only run, keeps raw CSVs alongside rollup output
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-04-01 `
  -EndDate 2026-04-08 `
  -RollupPlusRaw `
  -OutputPath "C:\Exports\"

# M365 usage bundle run, deletes raw CSV after rollup
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-04-01 `
  -EndDate 2026-04-08 `
  -IncludeM365Usage `
  -Rollup `
  -OutputPath "C:\Exports\"
```

---

#### Remote Output Destinations: `-OutputPathSP` / `-OutputPathFabric` (v1.11.1)

| Area | Details |
| --- | --- |
| **Purpose** | Publish all customer-visible run artifacts (CSV, XLSX, run log, metrics JSON) directly to a SharePoint document library or Microsoft Fabric / OneLake Lakehouse `Files` path — no intermediate local copy required. |
| **CLI usage** | `-OutputPathSP <SharePointFolderUrl>` **or** `-OutputPathFabric <OneLakeUrl>`. Exactly one of `-OutputPath`, `-OutputPathSP`, `-OutputPathFabric` may be specified per run; mutually exclusive at parameter validation. |
| **SharePoint URL shape** | `https://<tenant>.sharepoint.com/sites/<site>/<library>[/<sub>...]`. Resolved at startup to a Graph drive item; missing folder segments are created server-side. |
| **OneLake URL shape** | `https://[<region>-]onelake.dfs.fabric.microsoft.com/<workspace>/<item>.Lakehouse/Files[/<sub>...]` (Lakehouse or Warehouse). Uses `x-ms-version: 2021-06-08` against the ADLS Gen2 DFS surface. |
| **Permissions — SharePoint** | `Sites.ReadWrite.All` + `Files.ReadWrite.All` on the auth identity. |
| **Permissions — Fabric / OneLake** | Azure RBAC `Storage Blob Data Contributor` on the workspace + Fabric portal `Contributor` membership. Service-principal / managed-identity runs additionally require the tenant setting *"Service principals can use Fabric APIs"*. |
| **Pre-flight probe** | Runs immediately after `Connect-PurviewAudit`, before any audit query is issued. Resolves the URL, verifies reachability, creates the destination folder hierarchy server-side for SharePoint. Failures abort with a single structured Cause / Action banner classified by HTTP status (401 / 403 / 404), auth context (delegated vs app-only), and destination class (workspace RBAC vs Fabric portal role vs IMDS unreachable). No stack trace, no partial artifacts. |
| **Token refresh (OneLake)** | A new Azure (storage-audience) token-refresh layer (`Refresh-FabricTokenIfNeeded`, `Invoke-FabricWebRequest`) mirrors the existing Graph token-refresh design. Proactive refresh ≥50 minutes age (below 60-minute issuance), 5-minute expiry buffer, single transparent 401 retry. Long-running Fabric uploads (multi-hour audit windows, `-IncludeM365Usage` bundles) no longer fail mid-stream. |
| **Scratch folder** | `$script:OutputDirectory` is transparently redirected to a per-run scratch folder under `$env:TEMP\PAX_<RunTimestamp>\` so all existing local-write code paths work unmodified. Each artifact uploads immediately after the local writer closes the handle. Scratch folder is removed on successful completion; failed runs preserve it for diagnostics. |
| **Checkpoint / resume** | Checkpoint and partial-output files (`.pax_checkpoint_<RunTimestamp>.json`, `*_PARTIAL.csv`, `.pax_incremental/*.jsonl`) are always written to the local scratch folder and are **never mirrored remotely**. `-Resume` is a same-host operation — re-run from the same machine that produced the checkpoint. Only customer-visible final artifacts upload at end of run. |
| **Remote-aware path display** | All ~25 console / log path-display sites (startup banner, parameter snapshot, output-mode block, rollup retained-file list, run-completion summary, log-file line, etc.) resolve to the remote URL when a remote destination is in effect. The local scratch folder is never surfaced to the customer. The embedded Python processors' input/output path lines are suppressed in remote mode so only the remote URL is shown. |
| **Detailed Fabric setup guidance** | See the `fabric_resources` folder distributed alongside the script for the Azure Container Apps Job runbook (Dockerfile, deployment templates, permission scripts, README) and step-by-step Fabric / OneLake configuration. |

##### Examples (v1.11.1)

```powershell
# Upload directly to a SharePoint document-library folder
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-04-01 `
  -EndDate 2026-04-08 `
  -OutputPathSP "https://contoso.sharepoint.com/sites/Analytics/Shared%20Documents/PAX/2026-04"

# Upload directly to a Fabric Lakehouse Files path
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-04-01 `
  -EndDate 2026-04-08 `
  -OutputPathFabric "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/2026-04"
```

---

#### `-Auth ManagedIdentity` (v1.11.1)

New sixth value on the `-Auth` ValidateSet for Azure-hosted headless execution.

| Area | Details |
| --- | --- |
| **Graph context** | `Connect-MgGraph -Identity` (system-assigned) or `Connect-MgGraph -Identity -ClientId $env:AZURE_CLIENT_ID` (user-assigned). The same Graph application permissions required by `-Auth AppRegistration` (`AuditLogsQuery.Read.All`, `Directory.Read.All`, etc.) must be consented to the managed-identity service principal via `New-MgServicePrincipalAppRoleAssignment`. |
| **Azure (storage) context** | `Connect-AzAccount -Identity` (system-assigned) or `Connect-AzAccount -Identity -AccountId $env:AZURE_CLIENT_ID` (user-assigned). Used when `-OutputPathFabric` is in effect. |
| **User-assigned identities** | Setting `AZURE_CLIENT_ID` switches both Graph and Az connect calls to the user-assigned identity automatically. The identity binding is logged at startup. |
| **Connected-as line** | Startup banner falls back to the managed-identity client ID with a `(managed identity)` qualifier when no UPN is available on the Graph context. |
| **Blocked combinations** | `-OnlyAgent365Info` (Agent Package Management API is delegated-only) and `-IncludeAgent365Info` (no interactive sign-in surface for the dual-context Phase 2 step). Validation emits explicit error messages. |
| **No interactive fallback** | ManagedIdentity failures (missing identity, missing consent, IMDS unreachable) exit cleanly with a clear error — matching the v1.11.1 AppRegistration hardening. |
| **Companion runbook** | See `fabric_resources` for the Azure Container Apps Job Dockerfile, deployment script, permission-grant script, and README for unattended scheduled runs. |

---

#### CSV Filename Convention (v1.11.1)

CSV output filenames now consistently identify the activity-type shape of the run.

- **Multiple activity types with `-CombineOutput`**: `Purview_Audit_UsageActivity_CombinedActivityTypes_<timestamp>.csv`
- **Single activity type** (whether queried alone, downgraded from multi-activity at runtime, split out from a combined run, or emitted as a zero-row header-only file): `Purview_Audit_UsageActivity_<ActivityType>_<timestamp>.csv` (e.g. `Purview_Audit_UsageActivity_CopilotInteraction_20260511_191638.csv`).

Excel filenames, Excel tab names, and the `EntraUsers_*` / `Agent365_*` filenames are unchanged. The rollup-input glob continues to match both patterns so `-Rollup` / `-RollupPlusRaw` workflows are unaffected.

---

## Bug Fixes

### v1.11.1

The following authentication and certificate-handling fixes apply to `-Auth AppRegistration` flows:

- **(v1.11.1) Ephemeral PFX key loading.** PFX certificate loading now uses `X509KeyStorageFlags.EphemeralKeySet` so the script never persists a private key to the local machine's user profile. Resolves failures in environments where the user account has no write access to the per-user MachineKeys folder.

- **(v1.11.1) Certificate pinning for the run.** The cached `X509Certificate2` object is pinned on `$script:` scope and reused for all token refreshes within a run. The `Dispose()` call that previously lived in the `finally` block — which invalidated the credential's `SafeCertContext` and produced intermittent `invalid handle` token-refresh failures — has been removed. EphemeralKeySet ensures no on-disk artifacts to clean up.

- **(v1.11.1) Token refresh certificate reuse.** Token refresh now binds to the same `X509Certificate2` instance acquired at initial connect, eliminating a class of intermittent `AADSTS70002` errors observed when MSAL re-resolved the cert by subject name.

- **(v1.11.1) No interactive fallback under `-Auth AppRegistration`.** When AppRegistration auth fails (bad thumbprint, expired cert, missing tenant consent, etc.) the script now exits cleanly with a clear error rather than silently falling back to interactive browser sign-in. App-only runs are expected to be fully unattended — silent fallback masked misconfigurations and produced wrong-identity results in scheduled-task scenarios.

- **(v1.11.1) App-only scope-warning suppression.** Suppressed the spurious "the following scopes are not granted" warnings emitted by `Connect-MgGraph` under app-only auth, where scopes are not the relevant permission model (app roles are). Reduces log noise without altering behavior.

- **(v1.11.1) Clean pre-flight failure exit for remote destinations.** When the `-OutputPathSP` / `-OutputPathFabric` pre-flight probe fails, the run aborts cleanly with `exit 1` immediately after the structured Cause / Action banner. No trailing `Script failed: …` line, no PowerShell stack trace, no `_PARTIAL` artifact rename, no local or remote partial artifacts. The structured banner is the entire failure output.

- **(v1.11.1) Eliminated duplicate upload-failure WARNINGs.** `Invoke-OutputUpload` no longer emits its own per-call failure WARNING; every caller (upload sweep, metrics, log file, checkpoint mirror) now handles its own messaging with caller-specific context. Previously each upload failure produced two log lines — a generic inner WARNING followed by the caller's own message.

- **(v1.11.1) Managed-identity "Connected as" line no longer shows `$null`.** The startup banner's `Connected as` line now falls back to the managed-identity client ID (with `(managed identity)` qualifier) when no UPN is available on the Graph context.

- **(v1.11.1) Checkpoint and incremental-file cleanup on successful runs.** Successful runs now reliably remove the `.pax_checkpoint_<RunTimestamp>.json` file and this run's `.pax_incremental\Part*_<RunTimestamp>_*.jsonl` files (the `.pax_incremental` directory is also removed when empty). Three independent regressions were fixed: (1) `Complete-CheckpointRun` was early-returning whenever the intermediate `_PARTIAL.csv` had already been deleted by CSV-split or `-ExportWorkbook` paths, orphaning the checkpoint — restructured so the missing partial file only skips the rename and checkpoint deletion always proceeds; (2) the JSONL cleanup wildcard (`*_<RunTimestamp>_*records.jsonl`) did not match per-page memory-flush files (`Part{N}_<RunTimestamp>_qid-<QueryId>_<JobRunId>.jsonl`) added in v1.10.7 — pattern broadened to `*_<RunTimestamp>_*.jsonl`, kept strictly per-run via the embedded run timestamp; (3) cleanup lived in the main `try` block, so any late-stage exception (Agent 365 phase, output summary) bypassed it — added an idempotent safety-net cleanup in the `finally` block, gated on the same success criteria as the `_PARTIAL` log-rename. Per-run scoping is preserved end-to-end: only files matching the current run's timestamp are deleted.

---

## Known Considerations

### v1.11.1

- **(v1.11.1) Agent 365 endpoint version:** The Microsoft Graph Agent Package Management API used for Agent 365 enrichment is currently published at `https://graph.microsoft.com/beta/copilot/admin/catalog/packages`. PAX uses defensive name fallbacks for known field variants and centralizes the endpoint URL in `Get-Agent365PackagesUri` so a future move to `https://graph.microsoft.com/v1.0/...` is a one-line change.
- **(v1.11.1) No app-only auth for Agent 365:** The Agent 365 catalog endpoint supports delegated permissions only. App-only audit runs that include `-IncludeAgent365Info` require one up-front interactive sign-in (see Authentication Behavior — Agent 365 above).
- **(v1.11.1) Frontier enrollment + directory role required:** Tenants must be enrolled in the Microsoft Agent 365 Frontier program AND the signed-in caller must hold AI Administrator (preferred) or Global Administrator. Either gap causes the Agent 365 phase to be skipped with an informational banner.
- **(v1.11.1) Point-in-time output:** The Agent 365 CSV reflects the catalog state at the moment of the API call. There is no historical / time-ranged Agent 365 data — `-StartDate` / `-EndDate` only scope the audit phase.
- **(v1.11.1) Rollup post-processor may auto-install Python:** When `-Rollup` or `-RollupPlusRaw` is used and no Python 3.10+ interpreter is on PATH, PAX attempts a per-user silent install of Python 3.13 via winget (`Python.Python.3.13`) and falls back to the python.org offline installer if winget is unavailable. The install is per-user (no admin elevation), runs unattended, and prepends the new install to the user PATH for the current process. Hosts that block winget AND outbound HTTPS to `python.org` will fail the rollup phase with a clear error; the underlying audit run still succeeds and raw CSV(s) are preserved.
- **(v1.11.1) Remote-output destinations require destination-specific permissions:** `-OutputPathSP` requires `Sites.ReadWrite.All` + `Files.ReadWrite.All` on the auth identity. `-OutputPathFabric` requires Azure RBAC `Storage Blob Data Contributor` on the workspace + Fabric portal `Contributor` membership; service-principal / managed-identity runs additionally require the tenant setting *"Service principals can use Fabric APIs"*. Both are validated at startup via the pre-flight probe — misconfiguration surfaces in a single classified Cause / Action banner before any audit query is issued.
- **(v1.11.1) Remote-output mode uses a local scratch folder:** `-OutputPathSP` / `-OutputPathFabric` write every artifact to `$env:TEMP\PAX_<RunTimestamp>\` first and upload after each writer closes. The scratch folder is removed on successful completion and preserved on failure for diagnostics. Hosts with restrictive `$env:TEMP` quotas may need to redirect `TEMP` for large M365 Usage exports.
- **(v1.11.1) `-Resume` is a same-host operation under remote-output mode:** Checkpoint and partial-output files are never mirrored to the remote destination. Re-run resume from the same machine that produced the original checkpoint.
- **(v1.11.1) Managed-identity blocks Agent 365 enrichment:** `-Auth ManagedIdentity` is incompatible with both `-IncludeAgent365Info` and `-OnlyAgent365Info` because the Agent Package Management API is delegated-only and managed identities provide no interactive sign-in surface. Use `-Auth AppRegistration` + `-IncludeAgent365Info` for the dual-context flow, or any interactive mode for `-OnlyAgent365Info`.
- **(carryover) Microsoft Graph permission enforcement (v1.10.9) still applies:** Audit-query runs continue to require `AuditLogsQuery.Read.All` (and the granular `AuditLogsQuery-*.Read.All` workload scopes when `-IncludeM365Usage` is set). See the v1.10.x release notes for full details.

---

## Action Items for Administrators

### v1.11.1

1. **(v1.11.1) Enroll the tenant in the Microsoft Agent 365 Frontier program** if Agent 365 enrichment is desired. PAX will detect non-enrolled tenants and skip the Agent 365 phase with a Microsoft Learn pointer.
2. **(v1.11.1) Assign AI Administrator (preferred) or Global Administrator** to the interactive user account that will run Agent 365 enrichment. The role is enforced server-side by Frontier and is required in addition to Graph consent.
3. **(v1.11.1) Consent the Graph delegated scopes** `CopilotPackages.Read.All` and `Application.Read.All` for the calling app.
4. **(v1.11.1) Plan the dual-context flow for unattended runs:** `-Auth AppRegistration -IncludeAgent365Info` requires one up-front interactive sign-in by an AI Admin / Global Admin user; the audit phase runs unattended afterward and Phase 2 reconnects silently at end of run. Use `-OnlyAgent365Info` for fully interactive Agent 365 captures.
5. **(v1.11.1) For `-OutputPathSP`:** Grant the auth identity `Sites.ReadWrite.All` + `Files.ReadWrite.All`, and ensure the identity is a Member on the target SharePoint site. The pre-flight probe will create missing folder segments server-side.
6. **(v1.11.1) For `-OutputPathFabric`:** Grant Azure RBAC `Storage Blob Data Contributor` on the Fabric workspace, add the identity as `Contributor` in the Fabric portal Workspace settings, and (for service-principal / managed-identity runs) enable the tenant setting *"Service principals can use Fabric APIs"*. See the `fabric_resources` folder for the full setup walkthrough.
7. **(v1.11.1) For unattended Azure-hosted runs:** Use `-Auth ManagedIdentity` with the Azure Container Apps Job templates in the `fabric_resources` folder (Dockerfile, deployment script, permission-grant script, README). Consent Graph application permissions to the managed-identity service principal via `New-MgServicePrincipalAppRoleAssignment` (the included permission-grant script automates this).

---

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com) with any feedback.*
