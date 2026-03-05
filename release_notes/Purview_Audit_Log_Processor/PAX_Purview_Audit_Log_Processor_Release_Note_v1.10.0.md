# Release Notes: v1.10.x

## Release Information

- **Version:** 1.10.x
- **Release Date:** 2026-03-05
- **Released By:** Microsoft Copilot Growth ROI Advisory Team (copilot-roi-advisory-team-gh@microsoft.com)

---

## Script Download & Support

Download the script below.  For questions or issues, refer to the documentation.

- **PAX Purview Audit Log Processor Script v1.10.7:** [PAX_Purview_Audit_Log_Processor_v1.10.7.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.10.7/PAX_Purview_Audit_Log_Processor_v1.10.7.ps1)
- **Documentation v1.10.x (Markdown):** [PAX_Purview_Audit_Log_Processor_Documentation_v1.10.x.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.10.0.md)

---

## Overview

Version 1.10.x introduces two major capabilities: the **Microsoft 365 Usage Bundle** and **Checkpoint & Resume** for long-running exports.

The **Microsoft 365 Usage Bundle** (`-IncludeM365Usage`) is a single-switch activation that captures productivity activity across Outlook, Teams, SharePoint, OneDrive, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, and PowerApps alongside Copilot data. This enables organizations to correlate Copilot adoption with broader Microsoft 365 usage patterns for ROI analysis and productivity benchmarking.

**Checkpoint & Resume** (`-Resume`) enables recovery from interrupted exports—a critical capability for multi-hour queries spanning large date ranges. PAX automatically saves progress after each partition completes, allowing seamless resumption after token expiry, network interruptions, or system restarts. Combined with intelligent token refresh (silent refresh attempts before prompting, proactive refresh for AppRegistration), this ensures reliable completion of even the longest exports.

Additional enhancements include **memory management** (`-MaxMemoryMB`) to prevent out-of-memory crashes on large exports by streaming records through JSONL files instead of accumulating them in memory, **parallel explosion processing** (`-ExplosionThreads`) for faster post-retrieval performance on PS7+, **automatic 1M record limit detection** for Graph API queries (with BlockHours auto-subdivision), new CopilotInteraction control switches, an execution telemetry export option, improved automation support with the `-Force` parameter, and UX safeguards when many output files or tabs are expected.

---

## What's New

### Microsoft 365 Usage Bundle: `-IncludeM365Usage`

| Area | Details |
| --- | --- |
| **Purpose** | Single-switch activation of a curated activity type bundle spanning core Microsoft 365 productivity apps, enabling Copilot ROI analysis alongside traditional collaboration signals. |
| **Availability** | Graph API mode (default). The switch is blocked in EOM mode (`-UseEOM`) and replay mode (`-RAWInputCSV`). |
| **CLI usage** | `-IncludeM365Usage` with optional `-ExcludeCopilotInteraction` to capture only non-AI collaboration data. |
| **Output modes** | Recommend `-CombineOutput` (single merged file) or `-ExportWorkbook` (Excel with tabs) when using this bundle to avoid generating many separate files. |

#### Activity Type Categories

The bundle includes activity types across these categories:

| Category | Activity Types |
| --- | --- |
| **Outlook/Exchange** | MailboxLogin, MailItemsAccessed, Send, SendOnBehalf, SoftDelete, HardDelete, MoveToDeletedItems, CopyToFolder |
| **SharePoint/OneDrive (Files)** | FileAccessed, FileDownloaded, FileUploaded, FileModified, FileDeleted, FileMoved, FileCheckedIn, FileCheckedOut, FileRecycled, FileRestored, FileVersionsAllDeleted |
| **SharePoint/OneDrive (Sharing)** | SharingSet, SharingInvitationCreated, SharingInvitationAccepted, SharedLinkCreated, SharingRevoked, AddedToSecureLink, RemovedFromSecureLink, SecureLinkUsed |
| **Groups/Unified Groups** | AddMemberToUnifiedGroup, RemoveMemberFromUnifiedGroup |
| **Teams (Team/Channel)** | TeamCreated, TeamDeleted, TeamArchived, TeamSettingChanged, TeamMemberAdded, TeamMemberRemoved, MemberAdded, MemberRemoved, MemberRoleChanged, ChannelAdded, ChannelDeleted, ChannelSettingChanged, ChannelOwnerResponded, ChannelMessageSent, ChannelMessageDeleted, BotAddedToTeam, BotRemovedFromTeam, TabAdded, TabRemoved, TabUpdated, ConnectorAdded, ConnectorRemoved, ConnectorUpdated |
| **Teams (Chat/Messaging)** | TeamsSessionStarted, ChatCreated, ChatRetrieved, ChatUpdated, MessageSent, MessageRead, MessageDeleted, MessageUpdated, MessagesListed, MessageCreation, MessageCreatedHasLink, MessageEditedHasLink, MessageHostedContentRead, MessageHostedContentsListed, SensitiveContentShared |
| **Teams (Meetings)** | MeetingCreated, MeetingUpdated, MeetingDeleted, MeetingStarted, MeetingEnded, MeetingParticipantJoined, MeetingParticipantLeft, MeetingParticipantRoleChanged, MeetingRecordingStarted, MeetingRecordingEnded, MeetingDetail, MeetingParticipantDetail, LiveNotesUpdate, AINotesUpdate, RecordingExported, TranscriptsExported |
| **Teams (Apps/Approvals)** | AppInstalled, AppUpgraded, AppUninstalled, CreatedApproval, ApprovedRequest, RejectedApprovalRequest, CanceledApprovalRequest |
| **Office Apps (Word, Excel, PowerPoint, OneNote)** | Create, Edit, Open, Save, Print |
| **Forms** | CreateForm, EditForm, DeleteForm, ViewForm, CreateResponse, SubmitResponse, ViewResponse, DeleteResponse |
| **Stream** | StreamModified, StreamViewed, StreamDeleted, StreamDownloaded |
| **Planner** | PlanCreated, PlanDeleted, PlanModified, TaskCreated, TaskDeleted, TaskModified, TaskAssigned, TaskCompleted |
| **PowerApps** | LaunchedApp, CreatedApp, EditedApp, DeletedApp, PublishedApp |
| **Copilot** | CopilotInteraction (removable via `-ExcludeCopilotInteraction`) |

#### Why it matters

- **Copilot ROI Analysis:** Compare user productivity patterns before and after Copilot deployment
- **Baseline Establishment:** Use `-IncludeM365Usage -ExcludeCopilotInteraction` to capture pre-Copilot baselines
- **Single-pass efficiency:** Consolidate Copilot and M365 usage data in one execution instead of multiple runs

#### Example

```powershell
# Full M365 usage bundle with combined output
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-01-08 `
  -IncludeM365Usage `
  -CombineOutput `
  -OutputPath "C:\Exports\"

# M365 usage WITHOUT Copilot (baseline capture)
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-01-08 `
  -IncludeM365Usage `
  -ExcludeCopilotInteraction `
  -CombineOutput `
  -OutputPath "C:\Exports\"
```

---

### CopilotInteraction Control Switches

| Switch | Purpose |
| --- | --- |
| `-IncludeCopilotInteraction` | Explicitly add CopilotInteraction to custom activity type lists (useful when combining custom types with Copilot data) |
| `-ExcludeCopilotInteraction` | Remove CopilotInteraction from any bundle that includes it (e.g., `-IncludeM365Usage -ExcludeCopilotInteraction`) |

**Conflict Resolution:** If both switches are specified, the script prompts for resolution (or honors `-Force` to exclude).

---

### Execution Telemetry Export: `-IncludeTelemetry`

| Area | Details |
| --- | --- |
| **Purpose** | Export a per-partition telemetry CSV alongside audit data for performance analysis and troubleshooting. |
| **Output** | Creates `*_Telemetry_*.csv` with partition timing, record counts, retry attempts, and status information. |
| **Use case** | Diagnose slow queries, analyze partition distribution, optimize future exports. |

#### Example

```powershell
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-01-02 `
  -IncludeTelemetry `
  -OutputPath "C:\Exports\"
```

---

### Automation Support: `-Force` Parameter

| Area | Details |
| --- | --- |
| **Purpose** | Suppress interactive prompts for unattended/scheduled execution. |
| **Behavior** | Auto-accepts default choices for DSPM billing prompts, CopilotInteraction conflicts, and multi-output warnings. |
| **Use case** | CI/CD pipelines, scheduled tasks, and automation scenarios where no operator is present. |

---

### Checkpoint & Resume: `-Resume`

PAX automatically saves progress during long-running operations for all authentication modes. This enables resumption after Ctrl+C, network failures, token expiry, or any interruption without losing completed work.

#### Enhanced Token Refresh

Token refresh behavior has been significantly improved:

| Auth Mode | Behavior |
|-----------|----------|
| **AppRegistration** | ✅ Proactive refresh at ~45-50 minutes (before expiry) + reactive on 401 as backup. Fully automatic and silent. |
| **WebLogin/DeviceCode** | ✅ On 401 error, attempts silent refresh first (using SDK's cached refresh token). Only prompts user if silent refresh fails. |
| **403 Forbidden** | ⚠️ Detected separately from 401 errors. Indicates a permissions issue—token refresh won't help. Script provides clear guidance to check `AuditLog.Read.All` consent and role assignments. |

#### When Checkpoints Are Created

| Authentication Mode | Checkpoint Created | Reason |
|--------------------|--------------------|--------|
| WebLogin | ✅ Yes | Enables resume after any interruption |
| DeviceCode | ✅ Yes | Enables resume after any interruption |
| AppRegistration | ✅ Yes | Enables resume after any interruption |

#### Checkpoint Lifecycle

1. **Creation:** Checkpoint file created at start of Graph API query execution
2. **Updates:** Saved after each partition completes successfully
3. **Location:** `<OutputPath>\.pax_checkpoint_<timestamp>.json`
4. **Deletion:** Automatically removed on successful run completion

#### Incremental Data Saves

To prevent data loss during authentication failures, PAX saves completed partition data immediately to disk:

| Item | Details |
|------|--------|
| **Location** | `<OutputPath>\.pax_incremental\` (hidden folder) |
| **Format** | JSON Lines (JSONL) files named `Part<N>_<timestamp>_<count>records.jsonl` |
| **When Created** | After each partition completes successfully |
| **Cleanup** | Automatically merged and deleted on successful completion |

> 💡 **Note:** If a run is interrupted, the `.pax_incremental` folder may contain partial data. This data is automatically merged when you resume with `-Resume`, or you can manually recover the JSONL files if needed (one JSON record per line).

#### Resume Mode: Standalone Behavior

**IMPORTANT:** The `-Resume` switch is standalone. All processing parameters are restored from the checkpoint file to ensure data consistency. You cannot specify other parameters with `-Resume` (except authentication overrides).

**Allowed with `-Resume`:**

| Parameter | Purpose |
|-----------|----------|
| `-Resume` | Auto-discover checkpoint in current directory, or specify path to checkpoint file |
| `-Force` | Use most recent checkpoint without prompting (when multiple found) |
| `-Auth` | Override authentication method for resumed session |
| `-TenantId`, `-ClientId`, `-ClientSecret` | Auth credentials for AppRegistration mode |
| `-ExplosionThreads` | Override thread count for parallel explosion (e.g., resuming on different hardware) |

**NOT Allowed with `-Resume`:**
- Any other parameter (dates, activities, explosion settings, M365 bundles, partitioning, output settings, etc.)

This restriction prevents schema inconsistencies, such as first half of data exported with explosion and second half without.

#### What Gets Restored

The checkpoint file preserves ALL processing parameters:

| Category | Parameters |
|----------|------------|
| Date Range | StartDate, EndDate |
| Activity Filtering | ActivityTypes, RecordTypes, ServiceTypes, UserIds, GroupNames |
| Agent Filtering | AgentId, AgentsOnly, ExcludeAgents |
| Schema/Explosion | ExplodeArrays, ExplodeDeep, FlatDepth, StreamingSchemaSample, StreamingChunkSize, ExplosionThreads |
| M365/User Info | IncludeM365Usage, IncludeUserInfo, IncludeDSPMForAI |
| Partitioning | BlockHours, PartitionHours, MaxPartitions |
| Output | OutputPath, ExportWorkbook, CombineOutput |
| Auth (method only) | Auth, TenantId, ClientId (no secrets stored) |
| Partition State | Completed partitions, query IDs, record counts |

#### Resume Options

| Option | Behavior |
|--------|----------|
| `-Resume` | Auto-discover checkpoint in current directory; prompts if multiple found |
| `-Resume "path\to\file.json"` | Use specific checkpoint file |
| `-Resume -Force` | Use most recent checkpoint without prompting |
| `-Resume -Auth <method>` | Resume with different authentication method |

#### Example

```powershell
# Original run interrupted due to token expiry
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-01-15 `
  -ExplodeDeep `
  -IncludeM365Usage `
  -OutputPath "C:\Exports\"

# Resume (all settings restored automatically from checkpoint)
./PAX_Purview_Audit_Log_Processor.ps1 -Resume

# Resume from specific checkpoint file
./PAX_Purview_Audit_Log_Processor.ps1 -Resume "C:\Exports\.pax_checkpoint_20260115_143022.json"

# Resume with Force (unattended - use most recent checkpoint)
./PAX_Purview_Audit_Log_Processor.ps1 -Resume -Force

# Resume with different auth for unattended completion
./PAX_Purview_Audit_Log_Processor.ps1 -Resume -Auth AppRegistration -ClientId "xxx" -TenantId "yyy"
```

#### Best Practices

1. **Use AppRegistration for long queries:** Tokens refresh proactively at ~45-50 minutes and reactively on 401 errors—fully automatic, no checkpoints needed
2. **Interactive modes are smarter now:** On 401 errors, PAX first attempts silent token refresh using the SDK's cached refresh token. You're only prompted if silent refresh fails.
3. **401 vs 403 errors:** PAX differentiates these error types. 401 (Unauthorized) triggers token refresh; 403 (Forbidden) indicates a permissions issue where refresh won't help—check `AuditLog.Read.All` consent and role assignments.
4. **Keep OutputPath accessible:** Resume requires access to checkpoint file location
5. **Verify completion:** Check final output for expected record counts
5. **Change auth if needed:** Use `-Resume -Auth DeviceCode` to switch auth methods
6. **Incremental saves protect data:** Completed partition data is saved immediately, so even if auth fails, no data is lost

#### Checkpoint File Format

```json
{
  "version": 2,
  "runTimestamp": "20260115_143022",
  "created": "2026-01-15T14:30:22.000Z",
  "lastUpdated": "2026-01-15T15:45:00.000Z",
  "parameters": {
    "startDate": "2026-01-01T00:00:00Z",
    "endDate": "2026-01-15T00:00:00Z",
    "activityTypes": ["CopilotInteraction"],
    "explodeDeep": true,
    "explosionThreads": 0,
    "includeM365Usage": true,
    "blockHours": 0.5,
    "auth": "WebLogin",
    "tenantId": "abc-123",
    "clientId": null
  },
  "outputFiles": {
    "partialCsv": "Purview_Audit_CopilotInteraction_PARTIAL_20260115_143022.csv",
    "finalCsv": "Purview_Audit_CopilotInteraction_20260115_143022.csv"
  },
  "partitions": {
    "total": 720,
    "completed": [
      { "index": 0, "queryId": "abc123", "records": 4500 },
      { "index": 1, "queryId": "def456", "records": 3200 }
    ],
    "queryCreated": [
      { "index": 2, "queryId": "ghi789" }
    ]
  },
  "statistics": {
    "totalRecordsSaved": 7700,
    "partitionsComplete": 2,
    "partitionsRemaining": 718
  }
}
```

---

### Multi-Output Warning (UX Enhancement)

When more than 10 activity types are selected without `-CombineOutput`, the script now prompts users to confirm they want separate output files/tabs:

- **[Y] YES** — Continue with separate files/tabs
- **[C] COMBINE** — Enable `-CombineOutput` and continue with a single merged output
- **[E] EXIT** — Cancel script execution

This warning applies to both CSV mode (multiple files) and Excel mode (multiple tabs). The `-Force` parameter bypasses this prompt for automation.

---

### Graph Filter Passthrough (Enhanced)

The `-RecordTypes` and `-ServiceTypes` parameters now include improved behavior:

- **With `-IncludeM365Usage`:** Your specified record types are merged with the bundle's record types (deduplicated automatically)
- **ServiceTypes ignored:** When `-IncludeM365Usage` is active, `-ServiceTypes` is silently set to `$null` for single-pass query efficiency

---

### Parallel Explosion Processing: `-ExplosionThreads`

The explosion phase (converting records to rows with `-ExplodeArrays` or `-ExplodeDeep`) can now be parallelized on PowerShell 7+ for significant performance improvements on large datasets.

#### How It Works

| Aspect | Details |
|--------|--------|
| **When Activated** | Automatically on PS7+ when >500 records retrieved and `-ExplosionThreads` ≠ 1 |
| **Job Queue Pattern** | Records split into small chunks (~1000 each); N concurrent workers process chunks from queue |
| **Load Balancing** | As each chunk completes, worker grabs next from queue—better utilization when record complexity varies |
| **Schema Discovery** | Full scan of ALL rows for 100% column coverage (serial mode uses sampling via `-StreamingSchemaSample`) |
| **Fallback** | Serial processing on PowerShell 5.1 (parallel requires PS7+) |

#### `-ExplosionThreads` Parameter

| Value | Behavior |
|-------|----------|
| `0` (default) | Auto-detect based on CPU cores (2 to 8 threads) |
| `1` | Force serial processing (disable parallel explosion) |
| `2-8` | Explicit thread count (capped at 8 for stability) |

#### Example

```powershell
# Auto parallel (default—uses 2-8 threads based on CPU)
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-01-15 `
  -ExplodeDeep `
  -OutputPath "C:\Exports\"

# Explicit 8 threads
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-01-15 `
  -ExplodeDeep `
  -ExplosionThreads 8 `
  -OutputPath "C:\Exports\"

# Force serial (for debugging or comparison)
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-01-15 `
  -ExplodeDeep `
  -ExplosionThreads 1 `
  -OutputPath "C:\Exports\"
```

#### Checkpoint Support

The `-ExplosionThreads` value is saved in checkpoint files and restored on `-Resume`. You can override it on resume by specifying a different value (e.g., resume on a machine with different CPU count).

---

### Graph API 1,000,000 Record Limit: Auto-Subdivision

PAX now automatically detects and handles the Microsoft Graph API's 1,000,000 record limit per query—ensuring data completeness for high-volume tenants without manual intervention.

#### How It Works

| Aspect | Details |
|--------|--------|
| **Detection** | When a partition returns exactly 1,000,000 records with no continuation token (nextLink), PAX recognizes the limit was reached |
| **Auto-Subdivision** | Uses the same BlockHours subdivision algorithm as EOM 10K limit handling—partition time window is halved and re-queried recursively |
| **Minimum Window** | 0.016667 hours (1 minute)—cannot subdivide below this threshold |
| **Fallback** | If minimum window reached and still hitting limit, warning displayed and available records returned |

#### Console Output

When the 1M limit is detected:

```
[SUBDIVISION] Partition 5/20 - Fetched 1,000,000 records (Graph API limit reached) - Needs subdivision (0.5h window)
```

If minimum window reached:

```
[LIMIT] Partition 5/20 - Fetched 1,000,000 records at minimum subdivision window (0.02h, cannot subdivide further)
```

#### Recommendations for High-Volume Tenants

| Scenario | Recommendation |
|----------|----------------|
| Seeing `[SUBDIVISION]` messages frequently | Use smaller `-BlockHours` (e.g., 0.25 or 0.1) to avoid hitting limits |
| Large enterprise with millions of daily events | Consider shorter date ranges for initial exports |
| Automation/scheduled exports | Monitor logs for `[SUBDIVISION]` or `[LIMIT]` warnings to tune `-BlockHours` |

#### Example

```powershell
# For very high-volume tenants, use smaller BlockHours proactively
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-01-02 `
  -BlockHours 0.25 `
  -OutputPath "C:\Exports\"
```

---

### Memory Management: `-MaxMemoryMB`

| Area | Details |
| --- | --- |
| **Purpose** | Automatically prevents out-of-memory conditions during large audit log exports (100K+ records) by streaming records directly to JSONL files on disk instead of accumulating them in memory. Active by default — no switch required. |
| **Default** | `-1` (auto-detect: 75% of system RAM). Use `0` to disable and restore original unlimited behavior. |
| **How It Works** | Records are written directly to JSONL files on disk instead of accumulating in memory. At export time, records are streamed from JSONL files to CSV in batches with HashSet-based deduplication. |
| **Limitation** | Not compatible with explosion modes (`-ExplodeDeep`/`-ExplodeArrays`), which require all records in memory. When explosion is specified, `-MaxMemoryMB` is ignored with a warning. |
| **Checkpoint** | Value is saved in checkpoint JSON and restored on `-Resume`. Can be overridden on the resume command line. |

#### Example

```powershell
# Default (auto-detect 75% of system RAM)
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-02-01 `
  -OutputPath "C:\Exports\"

# Explicit 4GB limit
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-02-01 `
  -MaxMemoryMB 4096 `
  -OutputPath "C:\Exports\"

# Disable memory management (unlimited, original behavior)
./PAX_Purview_Audit_Log_Processor.ps1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-02-01 `
  -MaxMemoryMB 0 `
  -OutputPath "C:\Exports\"
```

---

## Bug Fixes

- **(v1.10.0) Activity Type Breakdown metrics:** Fixed an issue where "Retrieved" counts showed 0 in the Activity Type Breakdown and Pipeline Summary sections. Per-activity retrieved counts now display correctly in all code paths.

- **(v1.10.1) CopilotEventData explosion regression:** Fixed a critical regression where CopilotInteraction records were not being properly exploded in replay mode. The `ConvertTo-FlatColumns` function was incorrectly serializing all arrays to JSON strings instead of recursively expanding them. Smart array handling now recursively expands single-element arrays while JSON-serializing multi-element arrays (Messages, Contexts, AccessedResources, AISystemPlugin, ModelTransparencyDetails are row-exploded separately).

- **(v1.10.1) Unified replay header for all activity types:** Refactored replay mode to use a new `Get-UnifiedReplayHeader` function that auto-detects all activity types from the input CSV. This eliminates the need for `-IncludeM365Usage` in replay mode and ensures flat column names (e.g., `AppHost`, `ThreadId`, `Message_Id`) instead of prefixed names (e.g., `CopilotEventData.AppHost`). The function skips `CopilotEventData.*` paths during JSON schema detection since explosion already produces flat column names.

- **(v1.10.1) Non-explosion fast path metrics:** Fixed an issue where the "Activity Type Breakdown" section showed "Exported: 0 rows" for all activity types when running in standard 1:1 (non-explosion) mode. The fast path now properly tracks both "Retrieved" and "Exported" per-activity counts.

- **(v1.10.1) Activity Type Breakdown display consistency:** Fixed inconsistent formatting in the Activity Type Breakdown section where some activities showed "Retrieved/Filtered/Exported" lines while others only showed "Retrieved". The "Exported" line now always displays for every activity type.

- **(v1.10.2) AppRegistration auth parameter scoping:** Fixed an issue where `-TenantId`, `-ClientId`, `-ClientSecret`, and certificate parameters were not accessible within the `Connect-PurviewAudit` function when using `-Auth AppRegistration`. Script-level parameters are now properly promoted to script scope for function access.

- **(v1.10.2) Connect-MgGraph parameter set conflict:** Fixed "Parameter set cannot be resolved" error when authenticating with client secret. The `-ClientId` parameter was incorrectly passed alongside `-ClientSecretCredential`, but the Graph SDK expects the ClientId to be embedded in the PSCredential username field only.

- **(v1.10.3) Power BI template compatibility:** Enhanced Entra user export column names and structure to support seamless import into all of the Copilot ROI Analytics team's Power BI templates.

- **(v1.10.4) EOM mode and PowerShell 5.1 compatibility:** Restored full EOM mode (`-UseEOM`) functionality with sequential partition processing for PowerShell 5.1 environments. Added clear validation messaging for PS 5.1 users when Graph API mode is attempted (which requires PS 7+), improved cleanup handling to suppress irrelevant Graph disconnect messages in EOM mode, and ensured UTF-8 BOM encoding for PS 5.1 parser compatibility.

- **(v1.10.4) International locale date parsing:** Fixed date parsing errors for UK and other non-US locale users where US-format dates returned by the Purview API (M/d/yyyy) caused "String was not recognized as a valid DateTime" errors. All date parsing locations now use `InvariantCulture` to correctly interpret Purview API responses regardless of system locale.

- **(v1.10.4) Memory exhaustion during resume:** Fixed memory exhaustion during `-Resume` operations with large datasets (millions of records) by implementing streaming merge that processes JSONL incremental files directly to CSV without loading all records into memory. Also fixed divide-by-zero errors and timestamp consistency issues in resume mode.

- **(v1.10.4) Excel export performance:** Fixed Excel workbook export (`-ExportWorkbook`) hanging indefinitely for large datasets by replacing cell-by-cell processing with DataTable bulk insert via `Send-SQLDataToExcel`. A 35K row × 194 column dataset that previously took hours now completes in seconds. Also fixed CSV path extension issues when combining checkpointing with Excel export, and added retry logic for temp file cleanup.

- **(v1.10.4) Resume mode reliability:** Fixed multiple resume-related issues including: header-only CSV overwriting completed exports when all partitions were already done; `-ExplodeArrays` parameter validation with live API mode; activity breakdown showing "Exported: 0 rows" in streaming merge mode; and explosion modes with all partitions completed from a prior run.

- **(v1.10.5) AppRegistration token refresh failure:** Fixed "Parameter set cannot be resolved using the specified named parameters" error during automatic token refresh in long-running AppRegistration operations. The `Invoke-TokenRefresh` function had the same parameter set conflict fixed in v1.10.2 for initial authentication—passing `-ClientId` alongside `-ClientSecretCredential` when the Graph SDK expects ClientId embedded only in the PSCredential.

- **(v1.10.6) AppRegistration token reliability for long-running exports:** Fixed multiple issues causing 401 authentication cascades during exports exceeding 60 minutes with `-Auth AppRegistration`. ThreadJob parallel partitions now build fresh headers from the shared auth state for every API call (12 locations fixed), token refresh logic now correctly uses AppRegistration credentials instead of defaulting to interactive WebLogin, and proactive token refresh now runs periodically every 30 minutes throughout the export.

- **(v1.10.6) Partition error recovery and final reconciliation:** Fixed an issue where partitions encountering non-authentication errors were not being queued for retry, potentially resulting in missing data in the final export. Added a final reconciliation safety net before export that detects any incomplete partitions and retries them sequentially (up to 5 attempts). Error messages now accurately indicate that failed partitions will be retried automatically.

- **(v1.10.6) Query slot cleanup and fetch retry:** Failed partitions now clean up their server-side query slots immediately, preventing orphaned queries from filling all 10 concurrent slots and blocking subsequent queries. Also added retry logic for record fetch failures (3 attempts, 30-second delays) to preserve costly server-side query preparation work before deleting the query.

- **(v1.10.6) Zero-record run cleanup:** Fixed `_PARTIAL` suffix remaining on output CSV and log filenames when all partitions completed successfully but returned 0 records. Checkpoint files are now properly cleaned up on zero-record runs.

- **(v1.10.6) Log message completeness:** Fixed missing and duplicate "Query succeeded" messages in the log file. All three ThreadJob output processing code paths now reliably emit exactly one success message per partition.

- **(v1.10.7) Enterprise query resilience and retry hardening:** Fixed multiple issues causing queries to fail prematurely on large tenants. The 429 throttle retry counter is now properly incremented (previously stuck at 0, causing infinite retry loops). HTTP 401 Unauthorized errors are now handled in all query phases (CREATE, POLL, FETCH) with automatic token refresh — previously, 401 in the POLL or FETCH phase immediately killed the partition with no recovery attempt. All 5xx server errors (not just 502/503/504) are now treated as transient and eligible for adaptive backoff retry. All artificial poll timeouts have been removed — the poll loop now runs until Purview responds or the user cancels, preventing premature termination of valid queries still processing server-side. Retry passes now use reduced concurrency (capped at 3) to lower sustained 504 pressure during recovery.

- **(v1.10.7) Authentication recovery and token propagation:** Fixed a critical bug where refreshed authentication tokens were not propagated to active thread jobs after machine sleep or suspension, causing all thread jobs to continue using expired tokens and return 0 records with no error indication. Token refresh now validates that newly acquired tokens have more than 2 minutes remaining, preventing MSAL's in-memory cache from silently returning stale or already-expired tokens. Added automatic `Disconnect-MgGraph` before authentication to clear any pre-existing Graph sessions that could silently reuse expired or wrong-account cached tokens. When a run completes with 0 records and authentication recovery occurred during the run, a prominent warning now advises the user to check for auth-related issues.

- **(v1.10.7) Data integrity and loss prevention:** Added multiple safety layers to prevent silent data loss in long-running exports. ThreadJob error detection now correctly reads error streams from `Start-ThreadJob` objects (previously checked wrong API, missing all thread errors). Partition completion now requires JSONL data files to exist on disk — partitions that completed without saving data are automatically re-marked as Failed and retried. Pre-merge validation compares JSONL file count against expected partition count and renames output to `_PARTIAL` when partitions are missing. Streaming merge is now scoped to the current run's files only, preventing stale files from prior runs from corrupting output with unrelated records. JSONL files are deduplicated per partition during merge, keeping only the largest file to prevent duplicate records from retry attempts. Invalid "empty QueryId + 0 records" completions are now detected and retried instead of being silently counted as successful. A zero-record recovery safety net re-fetches data directly from Purview when all processing completes with 0 records despite valid server-side queries.

- **(v1.10.7) Memory management and performance:** Thread jobs now flush records to disk after each API page instead of accumulating all records in memory throughout pagination — per-thread peak memory is bounded to a single API page (~1,000 records) regardless of partition size, resolving out-of-memory crashes on servers processing large partitions across concurrent threads (previously 15–22 GB combined working set). In memory-flush mode, thread jobs persist JSONL data directly and return lightweight metadata to the main thread, eliminating large object transfers via `Receive-Job`. The streaming merge function now uses `System.IO.StreamReader` instead of `Get-Content | ForEach-Object` for ~5–10× throughput improvement on large merges. Fixed an O(n) iteration growth bug in the monitoring loop caused by `Receive-Job -Keep` re-delivering complete output history on every poll cycle, which caused STATUS intervals to drift from 2 minutes to 10+ minutes on multi-hour runs.

- **(v1.10.7) CSV output schema alignment:** Non-exploded CSV output now matches Purview UI manual export schema: added the missing `UserIds` top-level column, renamed `Operation` → `Operations` (plural), and removed `AssociatedAdminUnits`/`AssociatedAdminUnitsNames` columns that do not exist in Purview UI exports. Column order is `RecordId, CreationDate, UserIds, RecordType, Operations, AuditData`. Exploded CSV output now uses a fixed 153-column schema matching the Power BI M code `#"Changed Type"` step exactly, replacing the previous dynamic schema that produced variable column count and order. Both Copilot and non-Copilot record types, across live and replay paths, now produce a consistent 153-column layout. **Breaking:** Non-exploded output column `Operation` is now `Operations` (plural); `AssociatedAdminUnits` and `AssociatedAdminUnitsNames` are removed from non-exploded output (still available in exploded output and in the `AuditData` JSON column).

- **(v1.10.7) Console monitoring and STATUS improvements:** Suppressed terminal flooding from ThreadJob output streams. Added an "EXTREME VOLUME WARNING" for queries exceeding 60 days with >10 activity types or >120 partitions, recommending AppRegistration auth and `-Resume`. Added `-StatusIntervalSeconds` parameter (range 30–600, default 60) to control STATUS update frequency during polling. STATUS lines now display per-partition page counts (e.g., `| Pages P1:200pg P2:340pg`) for real-time visibility into active partition progress. Resume-mode STATUS lines now correctly reflect total partition counts including prior-run completions. Pipeline Summary counters now use actual merge data instead of filename-derived estimates, and duplicate removal counts are shown when applicable. Enterprise Processing Summary "Records from prior run" now uses checkpoint-stored exact counts instead of inflated filename-scan estimates.

- **(v1.10.7) M365 Usage Bundle — `UserLoggedIn` removed:** Removed `UserLoggedIn` from the `-IncludeM365Usage` activity bundle. On large tenants, `UserLoggedIn` generates extremely high record volumes (often orders of magnitude more than all other M365 usage activities combined), significantly increasing query time and data size without contributing to Copilot ROI or productivity analytics. The activity type remains available for explicit queries via `-ActivityTypes 'UserLoggedIn'`.

- **(v1.10.7) Checkpoint log file rename in split mode:** Fixed `_PARTIAL` suffix remaining on the log file after a fully successful export when CSV split mode (`-SplitByActivityType` or `-SplitByRecordType`) is active. The fallback rename is guarded to preserve `_PARTIAL` on genuinely interrupted runs for Resume mode detection.

---

## Known Considerations

- **Output file count:** The M365 usage bundle includes many activity types. Without `-CombineOutput` or `-ExportWorkbook`, this creates one file per activity type. The new multi-output warning helps users avoid this unintentionally.
- **Record type filter names:** Graph expects literal record type strings as documented by Microsoft. Incorrect casing or values lead to empty responses.
- **EOM mode limitations:** The M365 usage bundle, CopilotInteraction control switches, and telemetry export are Graph API mode only.

---

## Action Items for Administrators

1. **Evaluate M365 usage scenarios:** If you need productivity baseline data for Copilot ROI analysis, consider adopting `-IncludeM365Usage` with `-CombineOutput`.
2. **Review automation scripts:** Add `-Force` to scheduled jobs that should not prompt for user input.
3. **Consider telemetry exports:** For large date ranges or troubleshooting slow queries, add `-IncludeTelemetry` to capture partition-level performance data.
4. **Leverage parallel explosion:** For large datasets (100K+ records) with `-ExplodeArrays` or `-ExplodeDeep`, ensure you're using PowerShell 7+ to benefit from automatic parallel explosion processing. Use `-ExplosionThreads` to tune thread count if needed.

---

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com) with any feedback.*
