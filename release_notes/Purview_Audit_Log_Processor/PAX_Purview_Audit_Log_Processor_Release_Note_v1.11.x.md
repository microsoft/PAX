# Release Notes: v1.11.x

## Release Information

- **Latest Version:** 1.11.2
- **Latest Release Date:** 2026-05-17
- **Released By:** Microsoft Copilot Growth ROI Advisory Team (copilot-roi-advisory-team-gh@microsoft.com)

---

## Script Download & Support

Download the script below.  For questions or issues, refer to the documentation.

- **PAX Purview Audit Log Processor Script v1.11.2:** [PAX_Purview_Audit_Log_Processor_v1.11.2.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.11.2/PAX_Purview_Audit_Log_Processor_v1.11.2.ps1)
- **Documentation v1.11.x (Markdown):** [PAX_Purview_Audit_Log_Processor_Documentation_v1.11.x.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.11.x.md)

---

## Overview

### v1.11.2

Version 1.11.2 redesigns the output destination model around symmetric per-data-type switch pairs, extends cross-run append/merge to every data stream PAX produces, and introduces Microsoft Fabric Lakehouse Delta-table output. Existing v1.11.1 behavior is preserved when none of the new switches are used.

#### Unified Per-Data-Type Destination Model

A symmetric `-OutputPath*` / `-Append*` switch pair is provided for each output stream — Purview audit (`-OutputPath` / `-AppendFile`), EntraUsers / MAC licensing (`-OutputPathUserInfo` / `-AppendUserInfo`), Microsoft Agent 365 catalog (`-OutputPathAgent365Info` / `-AppendAgent365Info`), and run log (`-OutputPathLog`). Storage tier is inferred from each path's form: drive-rooted absolute paths resolve to Local, `https://...sharepoint.com/...` URLs resolve to SharePoint, and `https://...onelake.dfs.fabric.microsoft.com/...Lakehouse/...` URLs resolve to Fabric. UNC paths are rejected on every destination switch, and every destination supplied to a single run must resolve to the same storage tier. The legacy `-OutputPathSP` and `-OutputPathFabric` switches are removed — express remote destinations via any `-OutputPath*` value whose form is a SharePoint or OneLake URL.

#### Per-Dimension Append and Cross-Run Merge for All Outputs

`-AppendFile` now works across all rollup modes (`-Rollup`, `-RollupPlusRaw`) on all three storage tiers. Two new switches — `-AppendUserInfo` and `-AppendAgent365Info` — extend the same union-merge contract to the EntraUsers and Agent 365 catalog outputs respectively. Every append-mode run emits a standard `Retained / New / Departed / Union` merge tally for each merged stream; the merge is union-only — rows are never dropped from the target. `Departed` rows are kept in the merged file with `In_Latest_Append=FALSE`. Three provenance columns (`Date_Added`, `Latest_Append_Date`, `In_Latest_Append`) are appended to any merged file so analysts can see when each row first appeared and whether it was present in the most recent run. The CopilotInteraction rollup Fact CSV additionally gains two raw identity columns (`Message_Id_Raw`, `ThreadId_Raw`) so per-run integer surrogate keys remain stable across appends.

#### Microsoft Fabric Lakehouse Delta-Table Output

When any `-OutputPath*` value resolves to a Fabric OneLake URL, customer-visible outputs are written as Delta tables under the Lakehouse `Tables/` namespace — queryable directly from the Fabric SQL endpoint and consumable by Direct Lake Power BI semantic models. Table names are evergreen (CSV basename with the `_YYYYMMDD_HHMMSS` run-timestamp stripped), so the same table is overwritten run after run while CSV filenames continue to carry the timestamp suffix. Schema evolution is automatic via `schema_mode='merge'` so dynamic `-ExplodeDeep` columns are absorbed as new nullable columns on subsequent appends; mode mismatches across runs into the same target table are rejected at pre-flight. The `deltalake>=0.15` Python package is auto-installed on first use, mirroring the existing `orjson` install pattern. Resume artifacts are mirrored to durable OneLake storage at `<Lakehouse>/Files/.pax_resume/<RunTimestamp>/` so resume survives ephemeral container restarts.

#### Operational Hardening for Noninteractive Hosts

A new noninteractive-host detector and a bootstrap-log infrastructure layer harden PAX for execution inside Azure Container Apps Jobs, Windows services, scheduled tasks, and CI runners. The bootstrap log opens at the first executable line of the script body so pre-flight failures leave a readable log file behind; at log finalization the bootstrap content migrates into the final resolved log path.

#### Fabric / ACA Deployment Helpers (`fabric_resources/`)

A new top-level `fabric_resources/` folder ships two supported Fabric on-ramps and the shared prereqs script: a top-level overview / path decision guide, a Path A local-run README (laptop, on-prem server, or Azure VM with managed identity), a Path B Dockerfile and ACA Job deploy helper (with the mandatory Azure Files mount for the bootstrap-log volume), a shared scope-grant script, and a compatibility matrix.

#### Switch Surface Simplification

Alongside the new features above, v1.11.2 includes a focused streamlining pass that retires several optional features whose real-world adoption was narrow but whose code paths added a disproportionate amount of script complexity, test surface, and documentation overhead. Sharpening PAX around the workflows the majority of customers actually run leaves a smaller, more readable codebase and frees subsequent versions to land core improvements faster. Retired feature areas include the DSPM-for-AI activity-set helper, the in-script schema-explosion modes, native Excel workbook output, offline replay mode, the Microsoft Agent 365 catalog enrichment, and the separate remote-destination switches (now folded into a single tier-inferring `-OutputPath`). See [Switch Surface Simplification (v1.11.2)](#switch-surface-simplification-v1112) for the per-feature replacement path and rationale. The legacy `C:\Temp\` default on `-OutputPath` is also removed — `-OutputPath` is required for normal runs and may be omitted only when `-OnlyUserInfo` is used (in which case `-OutputPathUserInfo` carries the EntraUsers destination).

### v1.11.1

Version 1.11.1 is a large functional release. It introduces three flagship capabilities — the **`-Rollup` / `-RollupPlusRaw`** post-processor, **Microsoft Agent 365 catalog enrichment**, and **remote output destinations** (SharePoint and Microsoft Fabric / OneLake) — alongside a new `ManagedIdentity` auth mode for Azure-hosted unattended runs and major reliability and authentication hardening. Existing Purview audit-log processing behavior is unchanged when none of the new switches are used.

#### Rollup Post-Processor (`-Rollup` / `-RollupPlusRaw`)

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

> **Scope reminder.** The rollup outputs exist **solely** to feed the Microsoft Copilot Growth ROI Advisory Team's Power BI templates at <https://github.com/microsoft/Analytics-Hub>. Schema, column names, aggregation grain, and join keys are dictated by those data models. For generic analytics exports, run PAX without `-Rollup` / `-RollupPlusRaw` and consume the raw CSV directly.

See [Rollup Post-Processor: `-Rollup` / `-RollupPlusRaw` (v1.11.1)](#rollup-post-processor--rollup---rollupplusraw-v1111) below for the full feature matrix, blocked combinations, and examples.

#### Microsoft Agent 365 Catalog Enrichment (`-IncludeAgent365Info` / `-OnlyAgent365Info`)

A pair of new switches — **`-IncludeAgent365Info`** (audit run + Agent 365 enrichment) and **`-OnlyAgent365Info`** (Agent 365 enrichment only) — produce a dedicated `Agent365_<timestamp>.csv` (or `Agents365` Excel tab) whose 28-column schema matches the manual Agent 365 dashboard export. Data is sourced from the Microsoft Graph Agent Package Management API (`https://graph.microsoft.com/beta/copilot/admin/catalog/packages`). Available to tenants enrolled in the Microsoft Agent 365 Frontier program; signed-in caller must hold AI Administrator (preferred) or Global Administrator.

#### Remote Output Destinations — SharePoint & Microsoft Fabric / OneLake (`-OutputPathSP` / `-OutputPathFabric`)

Two new mutually-exclusive parameters extend `-OutputPath` (local directory) with first-class remote destinations so PAX can publish directly into a SharePoint document library or a Microsoft Fabric Lakehouse without an intermediate local copy.

- **`-OutputPathSP <SharePointFolderUrl>`** — Uploads every customer-visible artifact (CSV, XLSX, run log, metrics JSON) directly to a SharePoint Online document-library folder via Microsoft Graph (`createUploadSession` for files >4 MiB, `PUT /content` for small files). Folder hierarchy is created server-side if missing. Requires `Sites.ReadWrite.All` + `Files.ReadWrite.All` on the same identity used for the audit phase.
- **`-OutputPathFabric <OneLakeUrl>`** — Uploads to a Fabric Lakehouse / Warehouse `Files` path via the OneLake DFS REST surface (ADLS Gen2 create → append → flush). Requires Azure RBAC `Storage Blob Data Contributor` on the workspace plus Fabric portal `Contributor` membership; for service-principal / managed-identity runs the tenant setting *"Service principals can use Fabric APIs"* must be enabled.
- **Pre-flight probe with classified diagnostics.** Reachability and folder creation are validated immediately after authentication, before any audit query is issued. On failure, a single structured Cause / Action banner names the exact missing permission, role, workspace, or URL segment (401 vs 403 vs 404, delegated vs app-only, missing module vs IMDS unreachable for OneLake), and the run aborts cleanly with `exit 1` — no partial artifacts, no stack trace.
- **Long-run token-refresh infrastructure for OneLake.** A new Azure (storage-audience) access-token refresh layer mirrors the existing Graph token-refresh design so multi-hour Fabric runs survive the full audit window. Tokens are proactively refreshed every ~50 minutes (below the 60-minute issuance lifetime) with a transparent single-retry on the rare mid-flight 401.
- **Remote-aware path display.** Every output file / directory / log-path string emitted to the console and run log resolves to the SharePoint URL or OneLake URL when a remote destination is in effect — the temporary local scratch folder (`$env:TEMP\PAX_<RunTimestamp>\`) PAX uses internally is never surfaced to the customer.
- **Checkpoint and resume are LOCAL.** Checkpoint and partial-output files (`.pax_checkpoint_<RunTimestamp>.json`, `*_PARTIAL.csv`, `.pax_incremental/*.jsonl`) are always written to the local scratch folder and are never mirrored remotely. `-Resume` is a same-host operation — re-run from the same machine that produced the checkpoint. Only customer-visible final artifacts upload at end of run.

> **Fabric setup, deployment, and unattended-execution details.** For detailed guidance on configuring Microsoft Fabric for use with `-OutputPathFabric`, the Azure Container Apps Job runbook, managed-identity setup, and Fabric RBAC grants, see the `fabric_resources` folder distributed alongside the script.

#### Managed-Identity Authentication for Azure-Hosted Runs (`-Auth ManagedIdentity`)

New sixth value on the `-Auth` ValidateSet for Azure-hosted headless execution (Container Apps Jobs, Functions, App Service, VMs). Supports system-assigned and user-assigned identities (the latter via `AZURE_CLIENT_ID`) and binds both the Microsoft Graph and Azure (storage) contexts to the same identity, so a single managed identity drives both the audit pull and the Fabric upload. Failures (missing identity, missing consent, IMDS unreachable) exit cleanly with no interactive fallback. `-IncludeAgent365Info` and `-OnlyAgent365Info` are blocked under ManagedIdentity (no interactive sign-in surface for the Agent 365 delegated-only API).

#### Reliability & Authentication Hardening

- **Audit-query poll ceiling extended from 5 minutes to 4 hours** with heartbeat status messages and exponential backoff — eliminating premature timeouts on large-tenant queries (especially with `-IncludeM365Usage` or DSPM bundles).
- **AppRegistration authentication and certificate-handling fixes** that resolve intermittent token-refresh failures (`AADSTS70002`, `invalid handle`) and remove silent fallback to interactive sign-in in unattended scheduled-task scenarios.

---

## What's New

### v1.11.2

#### Unified Destination Model and Per-Stream Append Targets (v1.11.2)

| Area | Details |
| --- | --- |
| **Purpose** | Replace v1.11.1's `-OutputPathSP` / `-OutputPathFabric` with a symmetric per-data-type destination + append switch pair for each output stream. Storage tier is inferred from each path's form, so the same switch surface targets Local, SharePoint, and Fabric destinations interchangeably. |
| **Switch pairs** | `-OutputPath` / `-AppendFile` (Purview audit), `-OutputPathUserInfo` / `-AppendUserInfo` (EntraUsers / MAC licensing), `-OutputPathAgent365Info` / `-AppendAgent365Info` (Microsoft Agent 365 catalog — currently gated; see below), `-OutputPathLog` (run log; no paired append switch). |
| **Tier inference** | Drive-rooted absolute path (e.g. `C:\Exports\Foo.csv` or `C:\Exports\`) → Local. `https://...sharepoint.com/...` URL → SharePoint. `https://...onelake.dfs.fabric.microsoft.com/...Lakehouse/...` URL → Fabric. UNC paths (`\\server\share\...`) are rejected on every destination switch. |
| **Same-tier-per-run** | Every supplied destination must resolve to the same storage tier. Mixed-tier invocations are rejected at parameter validation. `-OutputPathLog` is the one minor exception in that it accepts a Fabric `Files/` target even when the data destinations are Tables/* paths (logs are not tabular data). |
| **Destination switch pair XOR** | For each stream in scope, exactly one of the `-OutputPath*` / `-Append*` switch pair must be supplied; both bound or neither bound is rejected. Out-of-scope streams (e.g. UserInfo when neither `-IncludeUserInfo` nor `-OnlyUserInfo` is set) reject either side being bound. |
| **Folder vs. full path** | Each `-OutputPath*` value may be a folder (the script auto-defaults the basename) or a full path including basename. |
| **Migration from v1.11.1** | `-OutputPathSP <url>` → `-OutputPath <url>` (and/or `-OutputPathUserInfo` / `-OutputPathAgent365Info` / `-OutputPathLog`). `-OutputPathFabric <url>` → `-OutputPath <url>` (same pattern). |

---

#### Cross-Run Append and Merge Behavior (v1.11.2)

| Area | Details |
| --- | --- |
| **Coverage** | `-AppendFile` extended to all rollup modes (`-Rollup`, `-RollupPlusRaw`). New `-AppendUserInfo` and `-AppendAgent365Info` switches add per-dimension append to the EntraUsers and Agent 365 catalog outputs. Behavior identical across Local, SharePoint, and Fabric tiers. |
| **Merge keys** | Raw Purview audit CSV → `RecordId`. Event-level exploded CSV (`-AppendFile -RollupPlusRaw`, 153-column shape) → `RecordId`. CopilotInteraction rollup Fact CSV (`-AppendFile -Rollup`) → `Message_Id_Raw`. EntraUsers CSV → `PersonId_Normalized`. M365 Bundle rollup CSVs → native (sum / min / max aggregates are associative; processor pre-seeds its accumulator). Agent 365 catalog → `AgentId`. |
| **Provenance columns** | Three trailing columns are added to any appended file: `Date_Added` (YYYY-MM-DD, immutable after first write), `Latest_Append_Date` (YYYY-MM-DD, updated on every append), `In_Latest_Append` (`TRUE` / `FALSE`). |
| **Stable surrogate keys** | The CopilotInteraction rollup Fact CSV adds two trailing raw-identity columns (`Message_Id_Raw`, `ThreadId_Raw`) so the per-run `Message_Id` / `ThreadId` integer surrogates remain stable across appends. The `UserKey` surrogate stays stable without a corresponding raw column on the Fact CSV — the processor loads `{PersonId_Normalized → UserKey}` from the merged Users CSV at fact-write time. |
| **Merge tally** | Each append-mode run emits a one-line summary per merged stream: `Retained=X New=Y Departed=Z Union=W`. `Retained` = rows present in both the target and this run (target's `Date_Added` preserved, last-write-wins on other columns, `In_Latest_Append=TRUE`). `New` = rows present only in this run (assigned `Date_Added = <run date>`, `In_Latest_Append=TRUE`). `Departed` = rows present only in the target (retained verbatim in the merged file with `In_Latest_Append=FALSE`; the merge is union-only — rows are never dropped). `Union` = the merged total. |
| **Pristine raw separation (EntraUsers)** | Under `-AppendUserInfo`, the EntraUsers CSV the audit phase writes is the pristine raw snapshot for that run; `Merge-UsersCsv` reads it alongside the `-AppendUserInfo` target and writes the union to the `-AppendUserInfo` path. On non-rollup paths the pristine raw is removed after the merge succeeds so the destination folder holds a single EntraUsers CSV at run-end. Rollup paths defer cleanup to the rollup post-processor's existing raw-retention logic (`-Rollup` deletes; `-RollupPlusRaw` retains). |
| **Run-summary messaging** | The end-of-run summary distinguishes the raw CSV the audit phase produces from the append target the rollup phase merges into. Pre-rollup lines appear as `Raw Purview CSV: <path>` and `Raw EntraUsers CSV: <path>`; after the merge completes an `Appended to: <url>` line is emitted for each merged stream, immediately preceded by the merge-statistics line. |
| **Pre-flight extension** | For append runs against Fabric Delta tables, the pre-flight probe reads the existing schema of every target table and verifies the merge-key column exists; mismatches reject before any audit query is issued. |

---

#### Microsoft Fabric Lakehouse Delta-Table Output (v1.11.2)

| Area | Details |
| --- | --- |
| **Activation** | Engaged automatically whenever any `-OutputPath*` value resolves to a Fabric OneLake URL. Customer-visible CSV outputs are written as Delta tables under the Lakehouse `Tables/` namespace; operational artifacts (run log, metrics JSON) and non-tabular artifacts land under `Files/`. |
| **Accepted URL forms** | Lakehouse root (`https://<region>-onelake.dfs.fabric.microsoft.com/<workspace>/<lakehouse>.Lakehouse`), the explicit `…/Tables` suffix (legacy non-Schemas Lakehouse), `…/Tables/<schema>` (Schemas-mode Lakehouse — current Fabric default, typically `dbo`), and `…/Files/...` (for `-OutputPathLog` and non-tabular artifacts). The `<schema>` segment must match `[A-Za-z_][A-Za-z0-9_]*`; malformed schema segments are rejected at parameter validation. |
| **Table naming** | Each CSV output is written to a Delta table whose name is the CSV basename with the trailing `_YYYYMMDD_HHMMSS` run-timestamp stripped. Tables are therefore evergreen (the same table is overwritten run after run) while the CSV filenames continue to carry the timestamp suffix. Example: `Purview_Audit_UsageActivity_CopilotInteraction_<ts>.csv` → table `Purview_Audit_UsageActivity_CopilotInteraction`. |
| **Append semantics** | Non-append runs overwrite each target Delta table with the run's output. Append runs (`-AppendFile`, `-AppendUserInfo`, `-AppendAgent365Info`) read the existing table into a scratch CSV via the `deltalake` Python library, feed it to the embedded processor as a seed input, and write the merged result back as a Delta overwrite. The merge logic is identical between local CSV and Fabric Delta destinations. |
| **Schema evolution** | The Delta writer uses `schema_mode='merge'` so dynamic columns produced by `-ExplodeDeep` (the `CopilotEventData.*` parent-key namespace) are absorbed as new nullable columns on subsequent appends. A schema-mode mismatch across runs into the same target table (for example, Standard 8-column vs. `-ExplodeArrays` 153-column) is detected at pre-flight and rejected with a clear error before any audit query is issued. |
| **Column-name sanitization** | The Delta format forbids the characters ` ,;{}()\n\t=` in column names. At Delta-write time only (the on-disk CSV is untouched), each forbidden character is replaced with `_`, with numeric disambiguation on collision. Example: `Has license` → `Has_license` and `License Status` → `License_Status` in the Delta table; the CSV consumed by the PBIP semantic model keeps the original names. |
| **Resume artifact persistence** | Fabric containers are ephemeral. The three resume artifacts (`.pax_checkpoint_<RunTimestamp>.json`, `.pax_incremental/*.jsonl`, `*_PARTIAL.csv`) are mirrored to a durable OneLake path at `<Lakehouse>/Files/.pax_resume/<RunTimestamp>/`. Working copies stay on container-local temp for fast I/O; after every checkpoint write the script uploads the artifact set to the mirror inside the same atomic block. On startup an in-progress run is detected by scanning the mirror and the local working copy is hydrated from it before any work begins; on successful completion the mirror is deleted. Local and SharePoint tiers do not mirror — their resume artifacts live in `$PSScriptRoot` only. |
| **Token reuse** | Reuses the existing OneLake storage-audience token managed by `Refresh-FabricTokenIfNeeded` so no independent authentication is needed inside the `deltalake` library. |
| **`deltalake` auto-install** | The `deltalake>=0.15` Python package is verified on first use; if absent, a quiet per-user `pip install` runs once. On failure a clear actionable error is emitted. Offline / locked-down hosts can pre-install the package manually and PAX will skip the install step. |
| **Restriction: `-ExportWorkbook`** | Restricted to Local and SharePoint tiers. Any `-OutputPath*` value that resolves to Fabric while `-ExportWorkbook` is set is rejected at parameter validation. |

---

#### Checkpoint Schema and Resume Behavior (v1.11.2)

The checkpoint snapshot persists the new destination and append fields (`outputPath`, `outputPathUserInfo`, `outputPathAgent365Info`, `outputPathLog`, `appendFile`, `appendUserInfo`, `appendAgent365Info`, `rollup`, `rollupPlusRaw`, and the feature-flag context the resumed run uses for path resolution) plus new compatibility metadata (`checkpointSchemaVersion`, `compatibilityMinimumVersion`, `createdByVersion`, `createdUtc`, `checkpointType`). A resumed run requires only `-Resume "<full checkpoint path>"` (plus optional auth overrides); the resume command line rejects any destination switch, so the checkpoint is the sole source of truth. The destination-pair XOR validation and the parse-time tier-inference / path-validation pipeline are re-run against the restored values on every resume so SharePoint and Fabric tiers re-engage the correct upload paths. Banners, parameter snapshots, output-files / log-file display lines, and date-range display are patched in place from the restored values after Read-Checkpoint completes so the displayed run identity always reflects the original run's intent rather than the resume command line's parse-time defaults. The legacy `includeDSPMForAI` field is ignored with a one-line warning when reading v1.11.1 checkpoints; v1.11.2 checkpoints opened by v1.11.1 are rejected by the existing checkpoint-version guard.

---

#### Fabric / ACA Deployment Helpers — `fabric_resources/` (v1.11.2)

A new top-level folder shipped alongside the script. Contents:

| File | Purpose |
| --- | --- |
| `fabric_resources/README.md` | Top-level overview and path decision guide for the two supported Fabric on-ramps. |
| `fabric_resources/CompatibilityMatrix.md` | Operator-facing compatibility reference for storage tiers, auth modes, Fabric URL shapes, destination switches, append-time schema additions, and known incompatibilities. |
| `fabric_resources/LocalRun/README.md` | Path A: laptop, on-prem server, or Azure VM with managed identity. Cert-AppReg / secret-AppReg / Azure-VM-MI variants; OneLake URL shapes (HTTPS only — `abfss://` is not accepted); verification checklist. |
| `fabric_resources/Dockerfile/PAX.Dockerfile` | Path B image. Non-root system user (UID/GID 10001, nologin shell); cleaned `PSModulePath`; durable bootstrap-log volume `/pax-logs`; optional build-time supply-chain verification of the released script. |
| `fabric_resources/Deploy/Deploy-PAXAcaJob.ps1` | Path B deploy helper. Provisions the ACA Job and registers the mandatory Azure Files mount for the bootstrap-log volume so pre-flight-failure logs survive container exit. Four-stage idempotent provisioning sequence with `$LASTEXITCODE` guards on every mutating `az` call. |
| `fabric_resources/Deploy/README.md` | Path B operator guide. Mandatory bootstrap-log mount, RBAC required by the deploy operator, accepted OneLake URL shapes. |
| `fabric_resources/Prereqs/Grant-PAXPermissions.ps1` | Shared scope-grant script. Grants the Graph application permissions PAX needs to the calling service principal, with optional `-IncludeM365Usage` to add the workload-specific scopes. Idempotent re-runs stay silent; real failures surface clearly. |

---

#### Switch Surface Simplification (v1.11.2)

A focused streamlining pass retires several optional features whose real-world adoption was narrow but whose code paths added a disproportionate amount of script complexity, test surface, and documentation overhead. Sharpening PAX around the workflows the majority of customers actually run leaves a smaller, more readable codebase, a cleaner first-time-user experience, and a faster path forward for the features customers depend on most. Each retired feature is summarized below with its replacement path and the reasoning behind retirement.

| Retired feature / switches | Replacement | Rationale |
| --- | --- | --- |
| `-IncludeDSPMForAI` (and the `-DSPMOutputMode` selector) | Pass the desired audit record types directly via `-ActivityTypes`. | The DSPM-for-AI helper was a thin auto-expansion wrapper over `-ActivityTypes` that obscured what was actually being queried. Direct `-ActivityTypes` invocation makes audit scope explicit and self-documenting. |
| In-script schema-explosion modes — `-ExplodeArrays`, `-ExplodeDeep`, `-ExplosionThreads` | Standard CSV output is unchanged. Customers who need flattened per-message rows can explode arrays in their downstream analytics layer (Power Query, notebooks, the Copilot Analytics Hub semantic models). | The explosion modes carried their own threading model, memory-tuning surface, parallel-aggregation logic, and schema-validation rules. Real-world telemetry showed most analytics pipelines preferred to flatten arrays in the downstream layer rather than at export time. Retiring the in-script path removes a large second code surface and a class of memory-tuning footguns. |
| Native Excel workbook output — `-ExportWorkbook` (including the Excel append / multi-tab modes) | Default CSV output. Excel, Power BI, Power Query, and the Copilot Analytics Hub consume CSV natively. | The workbook writer required an `ImportExcel` module dependency, a separate file-naming scheme, tab-collision handling, and append-time structural-error recovery that few consumers exercised. CSV is the more portable, more performant, and more analyst-friendly default. |
| Offline replay mode — `-RAWInputCSV` | Re-run PAX against the live audit log with the original parameters. | Replay was a developer-oriented feature for synthetic test harnesses; customer use was negligible relative to the cost of keeping replay parity with live-query behavior. |
| Separate remote-destination switches — `-OutputPathSP`, `-OutputPathFabric` | Pass the SharePoint folder URL or OneLake DFS URL directly to `-OutputPath`. The storage tier is inferred from the URL form (local folder vs. `*.sharepoint.com` URL vs. `onelake.dfs.fabric.microsoft.com` URL). | Two parallel destination switches with their own pre-flight, token-refresh, and error-banner branches collapse into a single `-OutputPath` whose target is inferred from the path shape. One switch, one mental model, three destinations. |
| Microsoft Agent 365 catalog enrichment — `-IncludeAgent365Info`, `-OnlyAgent365Info`, `-OutputPathAgent365Info`, `-AppendAgent365Info` | Use the Microsoft Agent 365 admin center export. | The Agent 365 enrichment shipped in v1.11.1 ahead of the underlying admin-center endpoints maturing (server-side paging, role-gate consistency, app-only support). Re-introducing in-script enrichment is on the table once the upstream surface stabilizes; for now, the public admin dashboard export remains the supported source. |

**Default-value change:** The legacy `-OutputPath` default of `C:\Temp\` is removed. `-OutputPath` is required for normal runs and may be omitted only when `-OnlyUserInfo` is used (in which case `-OutputPathUserInfo` carries the EntraUsers destination).

**Checkpoint compatibility:** Legacy fields for retired switches (`includeDSPMForAI`, `explodeArrays`, `explodeDeep`, `explosionThreads`, `rawInputCSV`, `exportWorkbook`, `outputPathSP`, `outputPathFabric`, `includeAgent365Info`, `onlyAgent365Info`, `outputPathAgent365Info`, `appendAgent365Info`) are ignored with a single one-line warning when reading a v1.11.1 checkpoint. v1.11.2 checkpoints opened by v1.11.1 are rejected by the existing checkpoint-version guard.

---

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

### v1.11.2

- **(v1.11.2) Append-merge correctness across all storage tiers and rollup modes.** Resolves several edge cases where `-AppendFile` / `-AppendUserInfo` could either leave the customer's target untouched, replace it with a header-only file, or report inverted merge statistics. The streaming-merge fast path now reliably emits the canonical `Retained / New / Departed / Union` tally; resume runs that find no skipped partitions preserve in-flight JSONL streaming state; header-only emissions on zero-records runs are skipped under `-AppendFile` so the customer's target byte-shape is unchanged; header-only CSV emissions now match the quoted-everywhere shape of populated CSVs; the zero-records early-exit branch emits the pipeline summary inline; and the embedded Python rollup processor no longer drops source rows whose `Message_Id` is seeded from the `-AppendFile` target (the dedup belongs to the PowerShell post-merge step, not the rollup loop).

- **(v1.11.2) Pristine-raw EntraUsers separation under `-AppendUserInfo` produces a single clean file at run-end.** Resolves a build issue where a non-rollup `-AppendUserInfo` run left two EntraUsers CSVs on disk (the merged union at the target leaf and a spurious `_raw`-suffixed companion). The pristine raw is now removed after the merge succeeds (matching `-AppendFile`'s single-file outcome); the `_raw` suffix path is reserved for the genuine same-leaf collision case where a customer-supplied `-AppendUserInfo` leaf and the natural raw leaf coincide.

- **(v1.11.2) `-OnlyUserInfo` + `-AppendUserInfo` and `-OnlyAgent365Info` + `-AppendAgent365Info` are valid combinations.** An earlier v1.11.2 validation block rejected these pairings as mutually exclusive. The underlying writer code already supported them — the validator was the only blocker. The remaining `-AppendFile` + `-Only*` blockers (which do reflect a genuine logic conflict — the `Only*` switches suppress audit-log retrieval, so there is no activity data to merge) keep their behavior with clearer error wording.

- **(v1.11.2) Resume runs display the original run's parameters in startup banners and the parameter snapshot.** The startup banner, parameter snapshot, output-files display, log-file line, authentication context, and date range now reflect the values restored from the checkpoint rather than the resume command line's parse-time defaults. The graceful-exit resume hint additionally includes the `-ClientSecret` slot for AppRegistration auth (the secret is intentionally never persisted to the checkpoint, so the hint is the only place the customer is reminded to re-supply it on resume).

- **(v1.11.2) Resume-mode wording distinguishes "QueryId reused from checkpoint" from a true cold start.** Earlier builds emitted the same `WARNING: No partial data found … Will start fresh data collection.` line in both cases, misleading operators into thinking PAX was re-issuing the Purview audit query when it was actually continuing to poll the original server-side query.

- **(v1.11.2) Checkpoint persists the customer-supplied `-OutputPath`, not the per-run scratch directory.** Resolves a regression where resume runs that originally targeted SharePoint or Fabric reclassified themselves as Local at end-of-run and left every artifact in scratch. New-run and resume-run code paths now both source the persisted value from the parse-time / restore-time canonical destination map, not the scratch redirect.

- **(v1.11.2) `-OutputPath` inferred from the dominant in-scope stream when omitted.** When the customer pinned a destination via `-AppendFile` / `-AppendUserInfo` / `-AppendAgent365Info` but did not also pass `-OutputPath`, secondary artifacts (run log, rollup scratch shards, embedded-processor temp files) previously leaked into the script's own folder (`$PSScriptRoot`). They now follow the dominant Append target's folder, with the inferred path announced in a single INFO host line so operators can see where the run is staging.

- **(v1.11.2) Run-log filename canonicalized on non-rollup `-AppendFile` runs.** The log filename now consistently follows the `Purview_Audit_<currentRunTs>.log` shape (matching non-append runs) instead of inheriting the AppendFile target's leaf or original timestamp. Subsequent `-AppendFile` runs against the same target no longer overwrite each other's logs, and the end-of-run "Output files created" listing correctly surfaces the run's log.

- **(v1.11.2) Path display in banners and summary lines resolves to the actual customer-visible URL.** The `OUTPUT DESTINATIONS` banner resolves every row (Purview audit, EntraUsers, Agent 365, run log) to a full file URL; post-streaming-merge summary URLs no longer carry a baked-in `_PARTIAL.csv` suffix; rollup intermediate-CSV delete log lines show the actual local scratch path with an explicit ` (scratch only; not uploaded)` qualifier; and the rollup seed-from URL surfaces the canonical customer-supplied path verbatim instead of a synthesized phantom URL.

- **(v1.11.2) Local end-of-run "Output files created" listing surfaces appended targets.** Append-mode runs that previously appeared to produce only the log file now list every in-place merge target with a trailing `[appended]` marker so customers can distinguish newly-created files from in-place merge updates.

- **(v1.11.2) `.pax_incremental/` rollup seed JSONs reaped on every run.** The post-rollup cleanup sweep now removes the per-run seed JSON files used by `-Rollup -AppendFile` / `-Rollup -AppendUserInfo` to pre-seed the embedded Python processor's surrogate-INT maps, so the `.pax_incremental/` directory itself is reliably removed at end of run regardless of whether the run used append seeds.

- **(v1.11.2) Pre-rollup EntraUsers append-merge deferred when the Python rollup will redo it.** Under `-AppendUserInfo -Rollup` (or `-AppendUserInfo -RollupPlusRaw`) in CopilotInteraction mode, the PowerShell-side pre-rollup merge and the post-rollup Python-side merge were both writing the same target back-to-back with potentially inconsistent stats. The PowerShell-side merge is now skipped on this combination and replaced with a single info line; the post-rollup merge runs as the sole writer.

- **(v1.11.2) Append/merge tally legend banner emitted once at run start.** A new one-time `APPEND/MERGE TALLY LEGEND` banner explains the `Retained / New / Departed / Union` vocabulary — especially the `Departed` count, which is naturally read as "rows removed" but in fact means "rows kept with `In_Latest_Append=FALSE` because they did not surface in the current run's audit window." Gated on `-Append*` being bound so non-append runs see no extra output.

- **(v1.11.2) Partition poll-loop network-message flood suppression.** During oscillating connectivity (blip → recover → blip → recover), the recovery side of the partition poll loop emitted a green `[NET] Connectivity restored after <N> minutes` banner on every successful poll while the matching transient-issue line on the error side was throttled to silence by the existing 60-second guard. The recovery banner now uses the same throttling logic so sustained outages still print exactly one paired transient/recovered cycle while short blips are silently absorbed.

- **(v1.11.2) Cosmetic log-output cleanups.** The embedded M365 Bundle rollup summary uses plain-ASCII `->` digraphs instead of the Unicode RIGHTWARDS ARROW (which mojibake'd to `ΓåÆ` on Windows hosts whose console code page defaulted to cp437 / cp1252). The graceful-exit `Partitions: X/Y complete` status line is now emitted as a single log entry instead of fragmenting into multiple timestamped log entries under the script's `Write-Host` proxy. The `Save-CheckpointToDisk` helper self-gates on `$script:CheckpointEnabled` so any caller forgetting the gate is a silent no-op rather than a wrong write. New `Assert-MetricsShape` and `Assert-PartitionStatusEntry` helpers freeze the required-field contracts of the `$script:metrics` and per-partition `$script:partitionStatus` entries, asserted once at init.

- **(v1.11.2) Inline merge derivation hardened against a PowerShell-7 parameter-set issue.** A `Split-Path -LiteralPath … -Parent` call inside the non-rollup `-AppendFile` streaming-merge inline merge block was unreachable in PowerShell 7 (the `-Parent` switch is not defined on the `-LiteralPath` parameter set), causing the script to abort immediately after the streaming-merge writer landed rows in the `_PARTIAL.csv` scratch but BEFORE the inline `Merge-FactCsv` call ran. Replaced with `[System.IO.Path]::GetDirectoryName($OutputFile)` so the inline merge runs to completion on all three storage tiers.

---

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

### v1.11.2

- **(v1.11.2) Storage tier inferred from each path's form:** Drive-rooted absolute paths resolve to Local; `https://...sharepoint.com/...` URLs resolve to SharePoint; `https://...onelake.dfs.fabric.microsoft.com/...Lakehouse/...` URLs resolve to Fabric. UNC paths (`\\server\share\...`) are rejected on every destination switch.

- **(v1.11.2) Same-tier-per-run rule:** Every `-OutputPath*` value in a single invocation must resolve to the same storage tier. `-OutputPathLog` is the one exception in that it accepts a Fabric `Files/` target even when the data destinations are Tables/* paths (logs are not tabular).

- **(v1.11.2) Destination switch pair XOR (per stream in scope):** For each output stream in scope, exactly one of the `-OutputPath*` / `-Append*` switch pair must be supplied; both bound or neither bound is rejected. Out-of-scope streams reject either side being bound.

- **(v1.11.2) Removed switches and default-value changes:** `-OutputPathSP`, `-OutputPathFabric`, and `-IncludeDSPMForAI` are removed. Migration: express SharePoint and Fabric destinations via any `-OutputPath*` switch whose value is a SharePoint or OneLake URL; pass the desired audit record types directly via `-ActivityTypes`. The legacy `C:\Temp\` default value on `-OutputPath` is also removed; `-OutputPath` is required for normal runs and may be omitted only when `-OnlyUserInfo` is used.

- **(v1.11.2) Microsoft Fabric Lakehouse Delta-table output:** When any `-OutputPath*` value is a OneLake URL, customer-visible outputs are written as Delta tables under the Lakehouse `Tables/` namespace (queryable from the Fabric SQL endpoint, consumable by Direct Lake Power BI semantic models). Tables are evergreen — the same table is overwritten run after run; CSV filenames continue to carry the run-timestamp suffix. Append runs read the existing table to scratch, merge, and overwrite — the merge logic is identical between local CSV and Fabric Delta destinations. The `deltalake>=0.15` Python package is auto-installed on first use; offline / locked-down hosts can pre-install it manually.

- **(v1.11.2) Fabric resume artifact persistence:** Resume artifacts (`.pax_checkpoint_<RunTimestamp>.json`, `.pax_incremental/*.jsonl`, `*_PARTIAL.csv`) are mirrored to durable OneLake storage at `<Lakehouse>/Files/.pax_resume/<RunTimestamp>/` so resume survives ephemeral container restarts. Local and SharePoint tiers do not mirror — their resume artifacts live in `$PSScriptRoot` only.

- **(v1.11.2) Resume command-line syntax:** A resumed run requires only `-Resume "<full checkpoint path>"` (plus optional auth overrides). All destination switches, date windows, and feature flags are restored from the checkpoint; the resume command line rejects any destination switch.

- **(v1.11.2) `-ExportWorkbook` restricted to Local and SharePoint tiers:** Any `-OutputPath*` value that resolves to Fabric while `-ExportWorkbook` is set is rejected at parameter validation.

- **(v1.11.2) Power BI semantic-model impact:** All new columns (`Message_Id_Raw`, `ThreadId_Raw`, `Date_Added`, `Latest_Append_Date`, `In_Latest_Append`) are appended at the tail of each affected schema. Power Query queries that select columns by name continue to work unmodified. Customers who do not want the provenance columns in their model can drop them in the first Power Query step (zero impact on model size, DAX, or visual performance).

- **(v1.11.2) Merge-tally legend reminder:** Append-mode runs emit a `Retained / New / Departed / Union` tally for each stream. `Departed` rows are kept in the merged file with `In_Latest_Append=FALSE`; the merge is union-only — rows are never dropped from the target.

- **(v1.11.2) Microsoft Agent 365 enrichment temporarily disabled:** The switches `-IncludeAgent365Info`, `-OnlyAgent365Info`, `-OutputPathAgent365Info`, and `-AppendAgent365Info` are gated at script entry pending further testing of upstream Microsoft admin center backend issues. PAX exits with one yellow notice line per bound switch and exit code `0` — not an error condition, just unavailable. All v1.11.1 Agent 365 guidance in this document is on hold until upstream stabilizes and the gate is removed.

- **(v1.11.2) Deprecations on track for removal:** `-ExportWorkbook`, `-RAWInputCSV`, `-ExplodeArrays`, and `-ExplodeDeep` are deprecated and will be removed in a future release. Binding any of them causes PAX to print a short deprecation notice and exit without processing; existing pipelines that use them should drop the switch.

---

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

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com) with any feedback.*
