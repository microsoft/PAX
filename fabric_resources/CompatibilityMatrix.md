# PAX Compatibility Matrix

_This document captures the supported runtime contract for PAX as it is currently shipped._

> [!IMPORTANT]
> **Microsoft Agent 365 enrichment is temporarily disabled pending further testing.**
> The switches `-IncludeAgent365Info`, `-OnlyAgent365Info`, `-OutputPathAgent365Info`,
> and `-AppendAgent365Info` are gated at script startup and will cause PAX to exit
> immediately with a notice. References to Agent 365 elsewhere in this document are
> preserved for when the feature is re-enabled.

This document captures the **supported runtime contract** for PAX when run under any
of the three packaging modes (local pwsh, Azure Container Apps Job, Fabric notebook).
Operators planning a deployment should treat each row as a hard requirement unless
explicitly marked _best-effort_.

---

## 1. Host runtime

| Component                         | Supported version(s)                            | Notes |
|-----------------------------------|-------------------------------------------------|-------|
| PowerShell                        | **7.4 LTS** (container), **7.2+** (local pwsh)  | Container image is pinned to `mcr.microsoft.com/powershell:lts-7.4-ubuntu-22.04`. PowerShell 7+ is required for any Fabric-bound run — the embedded `deltalake` Python bridge and the parallel pull paths both depend on PS 7 features. |
| Container OS                      | Ubuntu 22.04                                    | Provided by the base image; not user-configurable. |
| Python (in container)             | **3.10** (Ubuntu 22.04 default)                 | Used by the embedded rollup post-processor and Fabric Delta writes. Older 3.x will fail on `pyarrow>=14`. |
| Tini                              | Whatever apt ships on Ubuntu 22.04              | Required for PID-1 signal handling under ACA Jobs. |

## 2. PowerShell modules (pinned)

These are installed by the Dockerfile and verified at startup in local-pwsh mode.

| Module                       | Pinned version | Why pinned |
|------------------------------|----------------|------------|
| Microsoft.Graph              | 2.25.0         | Auth + delegated/app-only `AuditLogQuery` calls. Drift causes 401 fallback bugs. |
| Az.Accounts                  | 3.0.4          | Managed-identity / token acquisition for Fabric & ACA. |
| ExchangeOnlineManagement     | 3.6.0          | `-UseEOM` path (Search-UnifiedAuditLog). |

## 3. Python packages (pinned)

| Package      | Version constraint | Purpose |
|--------------|--------------------|---------|
| orjson       | (latest)           | Fast JSON serialization in the rollup post-processor. |
| pyarrow      | `>= 14`            | Arrow tables for Delta-table writes. |
| deltalake    | `>= 0.15`          | Fabric Lakehouse Delta-table writes. |

## 4. Authentication × destination matrix

Storage tier is inferred from each `-OutputPath*` value's form (see §4a). All four tiers are supported under all four auth modes:

| `-Auth`             | Local CSV/XLSX | SharePoint | OneLake Files | Fabric Lakehouse Tables |
|---------------------|:--------------:|:----------:|:-------------:|:-----------------------:|
| Interactive         | ✅              | ✅          | ✅             | ✅                       |
| DeviceCode          | ✅              | ✅          | ✅             | ✅                       |
| AppRegistration     | ✅              | ✅          | ✅             | ✅                       |
| ManagedIdentity     | ✅              | ✅          | ✅             | ✅                       |
| Agent365 enrichment | Interactive / DeviceCode / AppRegistration only — **ManagedIdentity is rejected** (Graph requires a delegated context for the underlying endpoints). |

## 4a. Destination switch matrix

Each data type has an independent `-OutputPath*` / `-Append*` pair. Storage tier is inferred from the path form on every destination switch.

| Data destination switch | Paired append switch | Purpose |
|---|---|---|
| `-OutputPath` | `-AppendFile` | Purview audit output (raw, rollup, or event-level) |
| `-OutputPathUserInfo` | `-AppendUserInfo` | EntraUsers / MAC licensing CSV |
| `-OutputPathAgent365Info` | `-AppendAgent365Info` | Agent 365 catalog CSV |
| `-OutputPathLog` | _(n/a)_ | Run log |

Tier inference per path form:

| Form | Tier |
|---|---|
| Drive-rooted absolute path (`C:\Data\…`, `/mnt/data/…`) | Local |
| `https://…sharepoint.com/…` URL | SharePoint |
| `https://…onelake.dfs.fabric.microsoft.com/…Lakehouse/…` URL | Fabric |
| UNC (`\\server\share\…`) | **rejected** on all destination switches |

Validation rules enforced at parameter time:

- **Pair XOR.** For every stream in scope, exactly one of its `-OutputPath*` / `-Append*` pair must be supplied — both bound or neither bound is rejected.
- **Tier consistency.** All supplied `-OutputPath*` / `-Append*` URL-form values resolve to the same tier. Mixed Local/SP/Fabric in one run is rejected. (`-OutputPathLog` may target Fabric `Files/` while data destinations target Fabric `Tables/<schema>` — that is one tier.)
- **FullPath collision.** Any two destination switches that resolve to the same fully qualified path are rejected. Folder-only inputs that produce different default basenames in the same folder are not collisions.
- **Schemas-mode Fabric.** `Tables/<schema>` segment must match `[A-Za-z_][A-Za-z0-9_]*`. `Tables/*` is also accepted (non-Schemas Lakehouse).

## 4b. Appended-file schema additions

Three trailing columns are appended at merge time to **any appended file**:

| Column | Type | Semantics |
|---|---|---|
| `Date_Added` | `YYYY-MM-DD` | First-seen date in the merged file. Immutable after first write. |
| `Latest_Append_Date` | `YYYY-MM-DD` | Latest run timestamp that touched the file. Same value on every row; updated each append. |
| `In_Latest_Append` | `TRUE` / `FALSE` | Whether the row appeared in the latest run's audit window or membership snapshot. `FALSE` for retained-but-departed rows. |

The CopilotInteraction rollup Fact CSV additionally carries two trailing identity columns (always present, not just at append time) so per-run integer surrogates remain stable across appends: **`Message_Id_Raw`** (raw audit `Messages[].Id` GUID) and **`ThreadId_Raw`** (raw `CopilotEventData.ThreadId` GUID). Merge keys: `Message_Id_Raw` for the rollup Fact CSV, `RecordId` for the non-rollup raw audit CSV, `PersonId_Normalized` for the EntraUsers CSV, `AgentId` for the Agent 365 CSV.

**M365 rollup append anchoring (`-IncludeM365Usage` + `-Rollup` / `-RollupPlusRaw`).** The embedded M365 Bundle Explosion Processor produces a 3-file bundle in the destination folder/Lakehouse: `<stem>_Rollup.csv`, `<stem>_UserStats.csv`, `<stem>_SessionCohort.csv`. Only `_Rollup.csv` is union-mergeable (via Python's `--append-target-rollup` pre-seed). UserStats and SessionCohort are RECOMPUTED over the merged Rollup on every run, so they are anchored off the `-AppendFile` leaf stem and overwrite their derived destination URLs in-place. `-AppendFile` MUST point to a `_Rollup.csv` leaf; sidecar leaves (`_UserStats.csv`, `_SessionCohort.csv`) and CopilotInteraction (`_Interactions.csv`) / event-level (`_Exploded.csv`) leaves are rejected at pre-flight. Renamed AppendFile is fine as long as the leaf still ends in `_Rollup.csv` (e.g. `MyM365Rollup_Rollup.csv` produces sidecars `MyM365Rollup_UserStats.csv` and `MyM365Rollup_SessionCohort.csv`). Prior sidecars with different leaf names are not auto-deleted. On Fabric `Tables/<schema>`, all 3 leaves become 3 stable Delta tables under the same schema (table name = leaf stem), refreshed via `Convert-CsvToDelta -Mode overwrite` on every run.

**Pristine raw EntraUsers under `-AppendUserInfo`.** The raw Entra membership snapshot the audit phase writes is never overwritten by the append-merge. The merged union lands at the `-AppendUserInfo` target; the raw file keeps its natural timestamped leaf (`EntraUsers_MAClicensing_<ts>.csv`), or gets a `_raw` suffix on the rare path-and-leaf collision (`EntraUsers_MAClicensing_<ts>_raw.csv`).

## 5. Checkpoint compatibility

| Field                          | Type    | Required | Semantics |
|--------------------------------|---------|----------|-----------|
| `version`                      | int     | yes      | Legacy contract; supported range **1..2**. |
| `checkpointSchemaVersion`      | string  | yes      | SemVer; major mismatch is hard-rejected. |
| `compatibilityMinimumVersion`  | string  | yes      | Minimum PAX version required to read this checkpoint. |
| `createdByVersion`             | string  | yes      | PAX version that wrote the file. Drift is warned only. |
| `createdUtc`                   | ISO-8601| yes      | Wall-clock at creation. |
| `checkpointType`               | string  | yes      | Always `PurviewAudit` for this script. |

A checkpoint produced by an older PAX is readable as long as `version ∈ {1,2}` (legacy
behaviour preserved). A checkpoint produced by a future PAX is **hard-rejected** when
either (a) `compatibilityMinimumVersion > running version`, or (b) `checkpointSchemaVersion`
major exceeds 2. Operators should never edit checkpoints by hand.

## 6. ACA Job configuration contract

| Setting          | Required value         | Why |
|------------------|------------------------|-----|
| `replicaTimeout` | ≥ runtime of longest expected run (default 24h) | PAX cannot resume a replica killed mid-partition without manual re-resume. |
| `parallelism`    | **1**                  | Two replicas against the same OutputPath would corrupt the checkpoint. The script holds an exclusive lock but operators should not rely on it as a primary defence. |
| `PAX_NONINTERACTIVE` | **1**             | The image already sets this. Removing it re-enables Read-Host prompts that will silently hang on stdin in ACA. |
| Image user       | non-root (`pax`, UID 10001) | Enforced by the Dockerfile. |
| `OutputPath`     | Local path **or** URL (tier inferred from the path form) | Customer-visible output can be Local / SharePoint / OneLake. Checkpoint + `_PARTIAL` files always live on local container scratch internally and are mirrored to the remote tier by `Mirror-ResumeArtifactsToOneLake` so resume can re-open them. |

## 7. Environment variables PAX honours

| Variable                          | Default | Purpose |
|-----------------------------------|---------|---------|
| `PAX_NONINTERACTIVE`              | unset   | Force noninteractive mode (no Read-Host prompts; fail-fast on prompts that have no safe default). |
| `PAX_FORCE_INTERACTIVE`           | unset   | Override the auto-detect (rare; documented). |
| `PAX_SP_WAIT_TIMEOUT_SECONDS`     | 120     | Bounded wait in `Grant-PAXPermissions.ps1` for SP propagation. |
| `PAX_SP_WAIT_INTERVAL_SECONDS`    | 5       | Poll interval in the same wait. |

## 8. Known incompatibilities

- `-Auth ManagedIdentity` with `-IncludeAgent365Info` / `-OnlyAgent365Info` — rejected at startup.
- Two simultaneous PAX runs against the same `OutputPath` — guarded by an exclusive
  checkpoint lock; operators should still set ACA `parallelism = 1`.
- Remote (URL) `OutputPath` for checkpoint storage — checkpoints MUST be on the local
  filesystem so resume can re-open them safely.
- UNC paths (`\\server\share\…`) on any destination switch (`-OutputPath`, `-OutputPathUserInfo`, `-OutputPathAgent365Info`, `-OutputPathLog`, `-AppendFile`, `-AppendUserInfo`, `-AppendAgent365Info`) — rejected at parameter validation.
- Mixed-tier destinations in a single run — every supplied `-OutputPath*` / `-Append*` (URL form) must resolve to the same tier (Local / SharePoint / Fabric).
- `-OutputPathLog` resolving to a Fabric `Tables/*` URL — logs are not tabular; only Fabric `Files/…` is accepted.
