## Portable Audit eXporter (PAX) - Purview Audit Log Exporter

Script: `PAX_Purview_Audit_Log_Processor_v1.4.4.ps1`  
Audience: IT admins, security/compliance analysts, BI/data teams  
Runtime: PowerShell 5.1 (compatible) / 7+ (recommended)

> **Summary**  
> Export enriched Unified Audit Log events (Copilot & related). Adds: token & model signals, adaptive query subdivision, limit & throttling awareness, canonical Purview exploded schema (29 cols) + optional deep flattening, composite progress, and (on PS 7+) controlled parallel query execution. Offline replay supported.

---

### 1. What It Does

Retrieves Copilot-related audit events and writes:

- CSV (structured rows; optionally exploded & flattened)
- Log file (parameters, adaptive sizing, warnings, metrics)

Core behaviors:

- Adaptive block sizing + automatic subdivision on dense periods
- Detection & warning for 10K per-search service cap
- (Planned) license-tier proximity mitigation (100K / 1M) – logic design prepared
- Optional explosion of arrays + deep flatten of nested JSON
- Usage & ROI fields (tokens, model, latency, acceptance metrics)

---

### 2. Key Features (At a Glance)

| Capability               | Benefit                                    |
| ------------------------ | ------------------------------------------ |
| Adaptive time slicing    | Reduces data loss, speeds sparse periods   |
| Throttle resilience      | Retries w/ backoff + jitter                |
| 10K cap detection        | Immediate visibility + mitigation guidance |
| Deep flatten / explosion | Analytics‑ready wide schema                |
| Lightweight default path | Fast 1:1 row mode                          |
| Rich usage metrics       | Tokens, outcomes, participants, actions    |
| Parallel (PS7+)          | Faster multi-activity harvest              |
| Composite progress       | Single weighted percentage                 |
| Version pinning          | `$ScriptVersion` aligns with release tag   |

---

### 3. When To Use / Not Use

Use for: adoption reporting, governance insights, performance & usage trending, enrichment before BI load.  
Not for: real-time streaming, evidentiary chain-of-custody (unless you hash outputs), or replacing native retention.

---

### 4. Prerequisites

| Requirement               | Notes                                                                           |
| ------------------------- | ------------------------------------------------------------------------------- |
| PowerShell 5.1 / 7+       | 7+ recommended (parallel, perf, UTF‑8)                                          |
| ExchangeOnlineManagement  | Any reasonably current version (baseline check removed; no forced auto-upgrade) |
| Unified Audit Log enabled | Confirm in tenant compliance center                                             |
| Audit permissions         | e.g. _View-Only Audit Logs_ or _Audit Logs_                                     |
| Network access            | M365 compliance endpoints reachable                                             |

> **RBAC Tip:** Use least privilege; test with a narrow time window first.

---

### 5. Why PowerShell 7

| Benefit           | PS 7+ Value                                               |
| ----------------- | --------------------------------------------------------- |
| Parallel fetching | `ForEach-Object -Parallel` (speed on multi-activity sets) |
| Performance       | Faster JSON + pipeline under newer .NET                   |
| Modern TLS        | Current cipher/protocol negotiation                       |
| Cross‑platform    | Same script on Windows/macOS/Linux                        |
| UTF‑8 default     | Predictable CSV/log encoding                              |
| Side-by-side      | Does not disturb Windows PowerShell 5.1                   |

Download: https://aka.ms/powershell

---

### 6. Quick Start

```powershell
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile C:\Temp\Copilot.csv
```

Interactive sign-in unless you specify `-Auth DeviceCode` / `Credential` / `Silent`.

---

### 7. Parameter Overview

| Parameter                | Default                                | Purpose                                                               |
| ------------------------ | -------------------------------------- | --------------------------------------------------------------------- |
| `StartDate`              | (auto = prev UTC day start if omitted) | UTC (yyyy-MM-dd) inclusive start (live auto); replay: optional filter |
| `EndDate`                | (auto = StartDate + 1 day if omitted)  | UTC end exclusive (live auto); replay: optional filter                |
| `OutputFile`             | Timestamped path                       | CSV target                                                            |
| `Auth`                   | WebLogin                               | WebLogin / DeviceCode / Credential / Silent                           |
| `BlockHours`             | 0.5                                    | Initial window size (learned thereafter)                              |
| `ResultSize`             | 10000                                  | Records per activity target (pre-subdivision)                         |
| `PacingMs`               | 0                                      | Inter-page delay for throttle tuning                                  |
| `ActivityTypes`          | CopilotInteraction                     | Operations set                                                        |
| `ExplodeArrays`          | (off)                                  | Purview exploded 29-column schema                                     |
| `ExplodeDeep`            | (off)                                  | 29-column schema + deep CopilotEventData.\*                           |
| `RAWInputCSV`            | (blank)                                | Offline replay of prior raw Purview audit CSV (forces explosion)      |
| `MaxConcurrency`         | 2                                      | Per-group concurrency cap                                             |
| `ParallelMode`           | Off                                    | Off / On / Auto (heuristic)                                           |
| `MaxParallelGroups`      | 3                                      | Limit concurrent groups                                               |
| `NoProgress`             | (off)                                  | Suppress progress bars                                                |
| `ExportProgressInterval` | 10                                     | Row interval for export updates                                       |

Date range tip: If 10K window warnings appear, reduce `BlockHours` or shorten the total span.

Live date defaults: Omitting BOTH `StartDate` and `EndDate` in live mode auto-runs for the previous full UTC day. Provide both to override (partial specification is rejected).
Replay date behavior: With `-RAWInputCSV`, omitting `StartDate`/`EndDate` applies no date filtering (entire CSV ingested). Supplying either/both filters by `CreationDate` (inclusive lower / exclusive upper).

RAWInputCSV notes: When you supply `-RAWInputCSV` the script skips live queries and always produces at least the 29‑column exploded schema. Allowed additional switches with `-RAWInputCSV`: `StartDate`, `EndDate`, `ActivityTypes`, `OutputFile`, `-ExplodeDeep`, `-NoProgress`, `-ExportProgressInterval`. Disallowed (error if present): `BlockHours`, `ResultSize`, `PacingMs`, `Auth`, `ParallelMode`, `MaxParallelGroups`, `MaxConcurrency`, `EnableParallel`.

Replay progress weighting: Because no live query phase runs, the Query weight is removed and the Explosion / Export weights are re-normalized so Overall begins at 0% (no immediate 30% jump after trivial ingestion). Live mode retains 30/60/10 weighting (Query/Explosion/Export) when explosion is active; non-exploded runs use 80/20 (Query/Export).

---

### 8. Outputs

| File | Contents                                          |
| ---- | ------------------------------------------------- |
| CSV  | Structured (exploded if chosen) rows              |
| LOG  | Parameters, adaptive decisions, warnings, metrics |

Behavioral notes:

- Header-only stability: If zero rows are returned (no matching audit events after filtering) the script still writes a CSV containing ONLY the header row (base 29 columns plus any deep `CopilotEventData.*` columns if `-ExplodeDeep`). This guarantees downstream pipelines always see a stable schema instead of a missing file.
- Encoding: UTF-8 (no BOM) via in-process `StreamWriter`.
- Line endings: CRLF on Windows, LF elsewhere (PowerShell default). Either is generally auto-handled by BI tools.

---

### 9. Purview Exploded Schema (Base 29 Columns)

`RecordId`, `CreationDate`, `RecordType`, `Operation`, `UserId`, `AssociatedAdminUnits`, `AssociatedAdminUnitsNames`, `AgentId`, `AgentName`, `AppIdentity_AppId`, `AppIdentity_DisplayName`, `AppIdentity_PublisherId`, `ApplicationName`, `CreationTime`, `ClientRegion`, `Audit_UserId`, `AppHost`, `ThreadId`, `Context_Id`, `Context_Type`, `Message_Id`, `Message_isPrompt`, `AccessedResource_Action`, `AccessedResource_PolicyDetails`, `AccessedResource_SiteUrl`, `AISystemPlugin_Id`, `AISystemPlugin_Name`, `ModelTransparencyDetails_ModelName`, `MessageIds`.

Deep mode appends additional `CopilotEventData.*` flattened columns (dynamic; order stable after base 29). Standard mode instead keeps a single `CopilotEventData` JSON blob.

Date/time normalization:

- `CreationDate` (record ingestion) and `CreationTime` (event occurrence) are emitted in invariant ISO 8601 UTC with millisecond precision: `yyyy-MM-ddTHH:mm:ss.fffZ`.
- All other date/time fields introduced in deep mode (if any) follow the same normalization strategy.
- Input `-StartDate` / `-EndDate` are interpreted as UTC dates (midnight boundaries) before filtering.

---

### 10. Handling the 10K Per-Window Limit

Service returns max 10,000 for a single `Search-UnifiedAuditLog` window. Script behavior:

1. Emits CRITICAL warning when exactly 10K boundary hit.
2. Notes the affected time window.
3. Auto-subdivides (binary or aggressive) if feasible.
4. Advises re-run with finer granularity (≤ 30 min) if still saturated.

---

### 11. Offline Replay (`-RAWInputCSV`)

Use when you already have a raw Unified Audit export (containing `AuditData` JSON column). The script will:

1. Skip authentication and live queries entirely (no ExchangeOnline connection).
2. Force Purview row explosion (equivalent to `-ExplodeArrays`) even if you don't specify it **(so adding `-ExplodeArrays` while using `-RAWInputCSV` is redundant but harmless)**.
3. Optionally honor `-ExplodeDeep` (if supplied) to append deep `CopilotEventData.*` columns.
4. Treat each CSV row as if returned by `Search-UnifiedAuditLog` and then explode.

Optional filters when using `-RAWInputCSV`:

| Filter Param    | Behavior (Replay Mode)                                                                 |
| --------------- | -------------------------------------------------------------------------------------- |
| `StartDate`     | Inclusive lower UTC boundary (row `CreationDate` >= StartDate) if provided             |
| `EndDate`       | Exclusive upper UTC boundary (row `CreationDate` < EndDate) if provided                |
| `ActivityTypes` | Only keep rows whose `Operation` matches one of the provided values (case-insensitive) |

Ideal for: reproducible transformations, development against synthetic datasets, or working offline.

Example commands (replay):

```powershell
# Simple replay (forced explosion implied)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -OutputFile .\replay_exploded.csv

# Replay with date & activity filtering + deep flatten
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -ActivityTypes CopilotInteraction -OutputFile .\replay_deep.csv

# Replay limiting to multiple operations
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ActivityTypes CopilotInteraction MessageSent FileAccessed -OutputFile .\replay_multi.csv
```

Limitations: Does not re-profile adaptive block sizing (query metrics minimal). Ensure source CSV includes `AuditData`. Non‑exploded mode is disabled in replay for consistency.

Safeguard: If you provide `-RAWInputCSV`, you must NOT supply live query / performance parameters (`BlockHours`, `ResultSize`, `PacingMs`, `Auth`, `ParallelMode`, `MaxParallelGroups`, `MaxConcurrency`, `EnableParallel`). These are ignored in offline mode and will trigger an error if present. Filtering parameters (`StartDate`, `EndDate`, `ActivityTypes`) remain allowed and optional.

### 11a. Parameter Applicability (Live vs. Replay)

| Parameter                 | Live Mode        | Replay (-RAWInputCSV) | Notes                                                              |
| ------------------------- | ---------------- | --------------------- | ------------------------------------------------------------------ |
| `StartDate`               | Yes (required)   | Optional (filter)     | Inclusive lower UTC boundary in both; replay filters existing rows |
| `EndDate`                 | Yes (required)   | Optional (filter)     | Exclusive upper UTC boundary; replay filters existing rows         |
| `OutputFile`              | Yes              | Yes                   | Target CSV path (always honored)                                   |
| `Auth`                    | Yes              | Error                 | Authentication skipped in replay                                   |
| `BlockHours`              | Yes              | Error                 | Adaptive query window sizing not used in replay                    |
| `ResultSize`              | Yes              | Error                 | Pagination sizing irrelevant in replay                             |
| `PacingMs`                | Yes              | Error                 | Throttle pacing not applicable offline                             |
| `ActivityTypes`           | Yes              | Optional (filter)     | Live=operations to query; replay=post-filter by Operation          |
| `ExplodeArrays`           | Optional         | Forced (redundant)    | Replay always produces at least exploded schema                    |
| `ExplodeDeep`             | Optional         | Optional              | Adds deep CopilotEventData.\* columns in both                      |
| `RAWInputCSV`             | (unused)         | Required to enable    | Presence switches script to replay mode                            |
| `MaxConcurrency`          | Yes (PS7+)       | Error                 | Parallelism not executed in replay                                 |
| `ParallelMode`            | Yes (PS7+)       | Error                 | Parallel heuristics skipped offline                                |
| `MaxParallelGroups`       | Yes (PS7+)       | Error                 | Group parallelization not used offline                             |
| `EnableParallel` (legacy) | Yes (maps to On) | Error                 | Legacy synonym still enforced as disallowed in replay              |
| `NoProgress`              | Optional         | Optional              | Suppresses progress UI both modes                                  |
| `ExportProgressInterval`  | Optional         | Optional              | Affects row progress emission; replay counts exploded rows         |

Legend: "Error" = script terminates if provided with `-RAWInputCSV`.

### 12. Parallel Mode

| Mode | Use When                             | Avoid When                     |
| ---- | ------------------------------------ | ------------------------------ |
| Off  | Predictable processing               | Large multi-activity harvests  |
| On   | You need maximum speed & PS 7+       | High throttle sensitivity      |
| Auto | Mixed workloads; let heuristics gate | You demand guaranteed parallel |

Auto criteria: PS 7+, ≤1 High group, ≥1 Medium/Low, total activities ≤15, >1 group, concurrency >1.

---

### 13. Privacy / Compliance

- No anonymization/redaction
- Treat exported identities as sensitive
- Restrict access & apply retention externally

---

### 13. Troubleshooting (Common)

| Symptom                         | Cause                     | Action                                                                                  |
| ------------------------------- | ------------------------- | --------------------------------------------------------------------------------------- |
| 10K limit warning               | Dense window              | Reduce `BlockHours` / narrow range                                                      |
| Zero records (header-only file) | No activity / permissions | Verify RBAC / test recent small window (header-only CSV is expected schema placeholder) |
| Frequent throttling             | Service load              | Add `-PacingMs`, accept retries                                                         |
| Slow deep mode                  | Large nested arrays       | Start with standard mode first                                                          |
| Parallel ignored                | PS 5.1 / heuristic off    | Force with `-ParallelMode On` (PS7+)                                                    |

---

### 14. Security Recommendations

- Use modern auth (WebLogin / DeviceCode)
- Store CSV + log in secure location

---

### 15. Versioning

`$ScriptVersion` logged (header & completion). Git history = authoritative change trail (no separate CHANGELOG).

---

### 16. Known Limitations & Operational Notes

| Area                        | Limitation / Behavior                                                          | Mitigation / Guidance                                                                                        |
| --------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| Unified Audit 10K cap       | Each `Search-UnifiedAuditLog` window tops at 10,000 records                    | Script auto-subdivides; if still saturated, re-run with smaller `-BlockHours` (≤30m)                         |
| Row explosion cap           | Per original record explosion capped at 1,000 rows (`ExplosionTruncated` flag) | Investigate fan-out; consider narrower date, filter operations, or deep analysis separately                  |
| JSON / flatten depth        | JSON serialization depth fixed at 60; deep flatten recursion capped at 120     | Extremely deep structures beyond caps truncated; adjust constants `$JsonDepth`, `$FlatDepthDeep` if required |
| Memory usage                | Streaming, chunked export by default                                           | Tune with `-StreamingSchemaSample` / `-StreamingChunkSize`; shard by date for extreme spans                  |
| Replay mode                 | Non‑exploded mode disabled; always at least exploded schema                    | Use live mode if raw 1:1 row shape required                                                                  |
| Parallel mode               | Only helps multi-activity sets; single high-volume activity remains serial     | Add more activity types or accept serial path; do not force parallel for a lone high group                   |
| ExchangeOnline module       | Any reasonably current version works (baseline enforcement removed)            | Optional: update to latest for new auth features, but not required                                           |
| Time zones                  | Dates interpreted as UTC; `yyyy-MM-dd` must be UTC                             | Convert local times to UTC prior to invocation to avoid DST drift                                            |
| Explosion truncation signal | Truncated rows flagged only via `ExplosionTruncated` column                    | Downstream pipelines should check & alert if true appears                                                    |
| Streaming export            | Always on (chunked)                                                            | Adjust sample/chunk sizes for schema width & memory balance                                                  |

Streaming export (default): samples an initial set (default 2k via `-StreamingSchemaSample`) to finalize the column schema, writes header, then processes & flushes rows in chunks (default 5k via `-StreamingChunkSize`) to bound peak memory. After schema freeze the chunk size auto-adjusts LOWER when column count exceeds thresholds ( >250, >500, >750, >1000 ) to maintain memory efficiency and AUTO-BOOSTS for narrow schemas (≤60 columns) up to 15K to reduce flush overhead. New columns discovered after schema freeze are counted & ignored (warning emitted); increase sample size if needed.

Fast CSV writer: The export path now uses an in-process UTF‑8 `StreamWriter` + manual escaping rather than repeated `Export-Csv` invocations. Benefits: fewer allocations, no header re-discovery per chunk, materially lower overhead on large (>300K rows) replay transformations. This is transparent—no parameter required.

Timestamp normalization: All emitted timestamps are already in UTC and rendered in ISO 8601 with millisecond precision (`yyyy-MM-ddTHH:mm:ss.fffZ`) to simplify downstream parsing and eliminate locale ambiguity.

Parallel replay explosion (PS 7+ only): When replaying a raw CSV and the remaining unprocessed records substantially exceed the schema sample, the script switches to a controlled parallel explosion phase (dynamic throttle + batch resizing targeting ~0.8s–2.5s batches). Metrics `ParallelBatchSizeFinal`, `ParallelThrottleFinal`, and structured explosion counters are emitted at completion.

---

### 17. FAQ

**Modify data?** No (read-only).  
**Timezone?** Input interpreted as UTC; output UTC.  
**Filter by user/model at source?** Not currently—filter after export.  
**Flatten depth?** Standard explode: 60; deep (`-ExplodeDeep`): 120; JSON serialization depth: 60 (constants: `$FlatDepthStandard`, `$FlatDepthDeep`, `$JsonDepth`).

---

### 18. Support & Feedback

Open a GitHub Issue (no SLA). Include PowerShell version, log excerpt, parameter line (omit sensitive paths).

---

### 19. License & Disclaimer

MIT License. “AS IS” – no warranties or official support. Validate fit for purpose before production use.

---

### 20. Power BI (Preview Guidance)

1. Get Data → Text/CSV → pick export.
2. Set data types (e.g., `CreationTime` Date/Time; tokens numeric).
3. Split semicolon multi-value fields for dimension tables as needed.
4. Create measures (Interactions, Avg Tokens, Acceptance Rate).
5. Build visuals (trend, latency distribution, acceptance funnel).

---

### 21. Execution Flow

1. Connect & collect tenant indicators
2. Build query plan (volume-classification)
3. Adaptive block querying + pagination
4. Optional parallel groups (PS7+)
5. Transform (explode/flatten) & enrich
6. Metrics + limit warnings
7. Export CSV + log summary

---

### 22. Command Reference

```powershell
# Standard (1:1)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile .\Copilot.csv

# Array explosion
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile .\Copilot_exploded.csv

# Deep flatten + explosion
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile .\Copilot_deep.csv

# Offline replay (forced explosion)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -OutputFile .\Copilot_replay_exploded.csv

# Offline replay deep flatten + filtering
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -ActivityTypes CopilotInteraction -OutputFile .\Copilot_replay_deep.csv

# Parallel heuristic (PS7+)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -ParallelMode Auto -ActivityTypes CopilotInteraction MessageSent FileAccessed

# Force parallel
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -ParallelMode On -MaxConcurrency 3 -MaxParallelGroups 2 -ActivityTypes CopilotInteraction MessageSent

# Deep flatten (wide schema) – advanced streaming tuning
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 4000 -StreamingChunkSize 3000 -OutputFile .\Copilot_deep_tuned.csv

# Extremely wide / memory sensitive: increase sample to capture columns, shrink chunk to lower peak memory
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 6000 -StreamingChunkSize 1500 -OutputFile .\Copilot_deep_memoryguard.csv

# Faster header freeze for narrow schemas (accept risk of late columns ignored)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 800 -StreamingChunkSize 6000 -OutputFile .\Copilot_deep_fastfreeze.csv

# Replay deep flatten with tuned streaming (large historical file)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ExplodeDeep -StreamingSchemaSample 5000 -StreamingChunkSize 2500 -OutputFile .\Copilot_replay_deep_tuned.csv
```

Windows PowerShell 5.1: prefix with `powershell -File`; PS 7+: `pwsh -File` (syntax identical).

---

### 23. Comprehensive Examples

Below is a fuller catalog of invocation patterns. Adjust paths/dates as needed. Dates are UTC.

```powershell
# 1. Minimal (defaults for everything else)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# 2. Specify explicit output path (creates folder if missing)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile C:\Data\Copilot\copilot_20251001.csv

# 3. Multiple activity types (mix of presumed high & medium volume)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-03 -ActivityTypes CopilotInteraction MessageSent FileAccessed MeetingDetail

# 4. Narrow block size to improve completeness under heavy load
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -StartDate 2025-10-05 -EndDate 2025-10-05 -BlockHours 0.25

# 5. Larger initial block (sparse historical data, multi-day span)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -StartDate 2025-09-01 -EndDate 2025-09-04 -BlockHours 4

# 6. Reduce ResultSize (fetch fewer records per window intentionally)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -ResultSize 2500

# 7. Add pacing between pages (mitigate throttling bursts)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -StartDate 2025-10-02 -EndDate 2025-10-03 -PacingMs 500

# 8. Array explosion only (one extra row per element of target arrays)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile .\copilot_exploded.csv

# 9. Deep flatten (explosion + wide column set)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile .\copilot_deep.csv

# 10. Parallel (forced) with tuned concurrency (PS 7+ only)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -ParallelMode On -MaxConcurrency 4 -MaxParallelGroups 3 -ActivityTypes CopilotInteraction MessageSent FileAccessed MeetingDetail SearchQueryPerformed

# 11. Parallel heuristic (Auto) – lets script decide
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -ParallelMode Auto -ActivityTypes CopilotInteraction MessageSent FileAccessed

# 12. Disable progress UI (clean logs / quiet CI runs)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -NoProgress

# 13. Increase export progress granularity (update every 1 row)
./PAX_Purview_Audit_Log_Processor_v1.4.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-01 -ExportProgressInterval 1

# 14. Device code authentication (good for headless terminals)
./CopilotInteraction_Purview_Export.ps1 -Auth DeviceCode -StartDate 2025-10-01 -EndDate 2025-10-02

# 15. Interactive credential prompt (stores credential only in memory)
./CopilotInteraction_Purview_Export.ps1 -Auth Credential -StartDate 2025-10-01 -EndDate 2025-10-02

# 16. Attempt silent auth first (fall back if not applicable)
./CopilotInteraction_Purview_Export.ps1 -Auth Silent -StartDate 2025-10-01 -EndDate 2025-10-02

# 17. Long span + conservative block + pacing (dense tenant mitigation)
./CopilotInteraction_Purview_Export.ps1 -StartDate 2025-09-20 -EndDate 2025-09-27 -BlockHours 0.5 -PacingMs 250 -ActivityTypes CopilotInteraction MessageSent FileAccessed

# 18. Focus only on Copilot interactions with deeper structure for BI
./CopilotInteraction_Purview_Export.ps1 -ExplodeDeep -ActivityTypes CopilotInteraction -StartDate 2025-10-01 -EndDate 2025-10-02

# 19. Mixed mode: multiple activities but only explode arrays (faster than deep)
./CopilotInteraction_Purview_Export.ps1 -ExplodeArrays -ActivityTypes CopilotInteraction MessageSent -StartDate 2025-10-01 -EndDate 2025-10-02

# 20. Tune for very sparse historical backfill (huge blocks)
./CopilotInteraction_Purview_Export.ps1 -StartDate 2025-07-01 -EndDate 2025-07-15 -BlockHours 12 -ActivityTypes CopilotInteraction

# 21. Combine: deep flatten + parallel + pacing (aggressive, watch throttling)
./CopilotInteraction_Purview_Export.ps1 -ExplodeDeep -ParallelMode On -MaxConcurrency 3 -PacingMs 200 -StartDate 2025-10-01 -EndDate 2025-10-02

# 22. Small block hours when consistently hitting 10K in larger windows
./CopilotInteraction_Purview_Export.ps1 -BlockHours 0.25 -StartDate 2025-10-03 -EndDate 2025-10-03 -ActivityTypes CopilotInteraction

# 23. Custom output directory with spaces (quote the path)
./CopilotInteraction_Purview_Export.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile "C:\Data Exports\Copilot\copilot.csv"

# 24. Sequential override (explicit) even if Auto would enable parallel
./CopilotInteraction_Purview_Export.ps1 -ParallelMode Off -ActivityTypes CopilotInteraction MessageSent FileAccessed -StartDate 2025-10-01 -EndDate 2025-10-02

# 25. Lower ResultSize + pacing to reduce transient throttling noise
./CopilotInteraction_Purview_Export.ps1 -ResultSize 4000 -PacingMs 300 -StartDate 2025-10-01 -EndDate 2025-10-01

# 26. Export with minimal console noise (quiet mode + custom file)
./CopilotInteraction_Purview_Export.ps1 -NoProgress -OutputFile C:\Temp\quiet_run.csv -StartDate 2025-10-01 -EndDate 2025-10-01

# 27. High fan-out: many operations, let Auto decide; if disabled you can review heuristics in log
./CopilotInteraction_Purview_Export.ps1 -ParallelMode Auto -ActivityTypes CopilotInteraction MessageSent FileAccessed MeetingDetail SearchQueryPerformed FileModified MailItemsAccessed -StartDate 2025-10-01 -EndDate 2025-10-02

# 28. PowerShell 5.1 invocation (explicit host) standard mode
powershell -ExecutionPolicy Bypass -File .\CopilotInteraction_Purview_Export.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# 29. PowerShell 7 (pwsh) parallel deep flatten
pwsh -File .\CopilotInteraction_Purview_Export.ps1 -ExplodeDeep -ParallelMode On -MaxConcurrency 4 -StartDate 2025-10-01 -EndDate 2025-10-01

# 30. Credential reuse pattern (capture credential once)
$cred = Get-Credential
./CopilotInteraction_Purview_Export.ps1 -Auth Credential -StartDate 2025-10-01 -EndDate 2025-10-02 -ActivityTypes CopilotInteraction MessageSent -OutputFile C:\Temp\copilot_secure.csv

# 31. Silent auth attempt (useful in managed workstation with cached token)
./CopilotInteraction_Purview_Export.ps1 -Auth Silent -ActivityTypes CopilotInteraction -StartDate 2025-10-01 -EndDate 2025-10-02

# 32. Very granular export progress (for small test windows)
./CopilotInteraction_Purview_Export.ps1 -ExportProgressInterval 2 -StartDate 2025-10-01 -EndDate 2025-10-01
```

```powershell
# 33. Offline replay (basic forced explosion)
./CopilotInteraction_Purview_Export.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -OutputFile .\replay_exploded.csv

# 34. Offline replay with date filtering & selected operations
./CopilotInteraction_Purview_Export.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -StartDate 2025-10-01 -EndDate 2025-10-02 -ActivityTypes CopilotInteraction MessageSent -OutputFile .\replay_filtered.csv

# 35. Offline replay deep flatten for BI readiness
./CopilotInteraction_Purview_Export.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ExplodeDeep -ActivityTypes CopilotInteraction -OutputFile .\replay_deep.csv

# 36. (Demonstration) Disallowed param with RAWInputCSV (will error) – do NOT use together
# ./CopilotInteraction_Purview_Export.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ResultSize 5000
```

Guidance:

- Prefer smaller `-BlockHours` if you frequently see the 10K limit warning in logs.
- Use `-PacingMs` only when throttling messages appear; too much pacing slows total throughput.
- `-ExplodeDeep` can significantly increase CSV width and processing time—validate with a short window first.
- `-ParallelMode On` + large activity sets may increase throttling; review retries in the log.
- `-ResultSize` below 10K can smooth memory usage when exploding deeply nested records.

---

## Contributing & Governance

Community contributions are welcome via Issues and Pull Requests. By participating you agree to follow the project’s **[Code of Conduct](./CODE_OF_CONDUCT.md)**. For responsible disclosure of security vulnerabilities, **do not** open a public issue—follow the process in **[SECURITY.md](./SECURITY.md)** instead. Code is released under the **[MIT License](./LICENSE)**; include copyright and license notices in any redistributed copies. High‑level workflow:

1. Open an Issue describing enhancement / bug (include repro steps & environment).
2. Fork & branch (`feat/short-description` or `fix/short-description`).
3. Add or update minimal tests / manual test notes where applicable.
4. Submit PR referencing the Issue; CI or manual review validates build & script syntax.
5. Respond to review feedback; maintain clean, focused commits (squash if requested).

Scope guidelines:

- Feature PRs: keep UI, script logic, and docs changes in separate commits for review clarity.
- Avoid introducing new runtime dependencies without discussion.
- Security-impacting changes (auth flows, script execution policy, module installation paths) must note risk tradeoffs in the PR description.

Questions outside security or code changes? Open a Discussion/Issue with the appropriate label.

---

© Microsoft Corporation — MIT Licensed.
