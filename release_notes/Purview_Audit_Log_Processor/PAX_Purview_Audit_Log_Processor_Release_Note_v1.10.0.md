# Release Notes: v1.10.x

## Release Information

- **Version:** 1.10.x
- **Release Date:** 2026-04-25
- **Released By:** Microsoft Copilot Growth ROI Advisory Team (copilot-roi-advisory-team-gh@microsoft.com)

---

## Script Download & Support

Download the script below.  For questions or issues, refer to the documentation.

- **PAX Purview Audit Log Processor Script v1.10.9:** [PAX_Purview_Audit_Log_Processor_v1.10.9.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.10.9/PAX_Purview_Audit_Log_Processor_v1.10.9.ps1)
- **Documentation v1.10.x (Markdown):** [PAX_Purview_Audit_Log_Processor_Documentation_v1.10.x.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.10.0.md)

---

## Overview

> ⚠️ **Required Action for v1.10.9 (Microsoft Graph Permissions Enforcement — April 2026):** Microsoft introduced a new dedicated permission level for the Microsoft Graph audit query API (`/security/auditLog/queries`) and began enforcing it across all tenants in April, 2026. Going forward, the audit query endpoint requires the new `AuditLogsQuery.Read.All` permission (and the granular `AuditLogsQuery-*.Read.All` workload scopes for optional M365 usage per-service queries); the broader `AuditLog.Read.All` permission is no longer sufficient on its own. **All app registrations and admin-consented delegated scopes used with PAX must be updated to grant `AuditLogsQuery.Read.All`** before running v1.10.9 against the Graph API path. Without it, Microsoft's enforcement causes the endpoint to return 0 records for `CopilotInteraction` and other workload-agnostic record types. v1.10.9 aligns PAX with Microsoft's new permission model and also adopts least-privilege conditional scopes — see the **Microsoft Graph API Permissions Enforcement & Least-Privilege Hardening (v1.10.9)** section below for full details. EOM mode (`-UseEOM`) is unaffected.

Version 1.10.x introduces two major capabilities: the **Microsoft 365 Usage Bundle** and **Checkpoint & Resume** for long-running exports.

The **Microsoft 365 Usage Bundle** (`-IncludeM365Usage`) is a single-switch activation that captures productivity activity across Outlook, Teams, SharePoint, OneDrive, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, and PowerApps alongside Copilot data. This enables organizations to correlate Copilot adoption with broader Microsoft 365 usage patterns for ROI analysis and productivity benchmarking.

**Checkpoint & Resume** (`-Resume`) enables recovery from interrupted exports—a critical capability for multi-hour queries spanning large date ranges. PAX automatically saves progress after each partition completes, allowing seamless resumption after token expiry, network interruptions, or system restarts. Combined with intelligent token refresh (silent refresh attempts before prompting, proactive refresh for AppRegistration), this ensures reliable completion of even the longest exports.

Additional enhancements include **memory management** (`-MaxMemoryMB`) to prevent out-of-memory crashes on large exports by streaming records through JSONL files instead of accumulating them in memory, **parallel explosion processing** (`-ExplosionThreads`) for faster post-retrieval performance on PS7+, **automatic 1M record limit detection** for Graph API queries (with BlockHours auto-subdivision), new CopilotInteraction control switches, an execution telemetry export option, improved automation support with the `-Force` parameter, and UX safeguards when many output files or tabs are expected.

---

## What's New

### Microsoft Graph API Permissions Enforcement & Least-Privilege Hardening (v1.10.9)

| Area | Details |
| --- | --- |
| **What changed** | Microsoft introduced a new dedicated permission level for the Microsoft Graph audit query API (`/security/auditLog/queries`) and began enforcing it across all tenants in April, 2026. The audit query endpoint now requires its own `AuditLogsQuery.Read.All` (umbrella) permission — plus the granular `AuditLogsQuery-*.Read.All` per-workload scopes for service-scoped queries — instead of the broader `AuditLog.Read.All` permission previously used by all tooling that called this endpoint. |
| **Tenant impact** | Calls to the audit query endpoint authenticated with only the legacy `AuditLog.Read.All` permission still receive a `succeeded` query status under Microsoft's enforcement, but the endpoint returns **zero records** for record types not covered by a granular `AuditLogsQuery-*.Read.All` workload scope (most notably `CopilotInteraction`). This is a Microsoft platform-level change and applies to every tenant; it is not specific to PAX. |
| **New permission to grant** | `AuditLogsQuery-*.Read.All` is the new umbrella permission set that authorizes the caller to retrieve all CopilotInteraction and M365 usage record types via the audit query endpoint. PAX v1.10.9 has been validated against an isolated app registration holding only this permission and successfully retrieves all expected record types under Microsoft's new enforcement. |
| **Customer action required** | Update existing PAX app registrations and admin-consented delegated scopes to add the `AuditLogsQuery-*.Read.All` permission family (Microsoft Graph, Application permission) and grant admin consent. After consent, no further changes are needed — the script will request the updated scope set automatically on next run. |
| **Interim workaround** | Runs can use `-UseEOM` to bypass the Graph API path while consent is in flight. EOM mode uses Exchange Online RBAC and is unaffected by Microsoft's Graph permission enforcement change. |

#### Least-Privilege Conditional Scope Request Set

| Scope | Conditional on |
|---|---|
| `AuditLogsQuery.Read.All` (umbrella) | `-not $OnlyUserInfo` |
| `AuditLogsQuery-Exchange.Read.All` | `-IncludeM365Usage` |
| `AuditLogsQuery-OneDrive.Read.All` | `-IncludeM365Usage` |
| `AuditLogsQuery-SharePoint.Read.All` | `-IncludeM365Usage` |
| `User.Read.All` | `-IncludeUserInfo`, `-OnlyUserInfo`, or `-GroupNames` |
| `Organization.Read.All` | `-IncludeUserInfo` or `-OnlyUserInfo` |
| `GroupMember.Read.All` | `-GroupNames` |


#### UX Updates

- **Connection banner filtering:** The "Successfully connected to Microsoft Graph" banner now displays only scopes present in `$RequiredScopes` — extra scopes carried by the token from prior `Connect-MgGraph` sessions or other tooling are no longer printed.
- **Query Mode permissions banner:** The startup `QUERY MODE: Microsoft Graph Security API` banner now renders each scope in **Yellow** when actively requested for the run and **DarkGray** when not, with a legend at the top. Sub-blocks for M365 usage, Entra directory enrichment, and group expansion show exactly which scopes a given invocation requires.
- **403/Forbidden diagnostics:** Recommends `GroupMember.Read.All` first, with `Group.Read.All` / `Directory.Read.All` listed as higher-privilege fallbacks. Authentication failure messages now reference `AuditLogsQuery.Read.All` throughout.
- **Diagnostic logging:** A new `Graph scopes requested: <list>` log line is written on each connect for post-mortem traceability of exactly which scopes were sent.

#### Customer Impact Summary

- Baseline `-StartDate / -EndDate` Graph runs now request **only** `AuditLogsQuery.Read.All`.
- `-OnlyUserInfo` runs no longer request audit query scopes they never use.
- `-IncludeUserInfo` / `-OnlyUserInfo` users no longer have a silent permission gap on `/users` (previously needed external consent for `User.Read.All`).
- `-GroupNames` users no longer have a silent permission gap on `/groups` and now request least-privilege `GroupMember.Read.All` instead of `Group.Read.All`.
- **EOM mode (`-UseEOM`) is unaffected** — uses Exchange Online RBAC, not Graph scopes.

---

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

- **(v1.10.8) Purview date-range bleed — client-side trimming:** Added client-side date-range trimming to eliminate records that bleed past the requested `EndDate` boundary by up to ~10 hours (a known Purview API behavior affecting ~3–5% of returned records). Output CSV is now guaranteed to contain only records within the user-specified `[StartDate, EndDate)` range. Timezone-safe boundary parsing uses `SpecifyKind(..., Utc)` to prevent local timezone offsets from shifting UTC midnight boundaries. Trimmed record count is reported in the Pipeline Summary for operator visibility.

- **(v1.10.8) M365 Usage Bundle — noisy operations removed:** Removed six high-volume, low-signal operations from the `-IncludeM365Usage` bundle: `MailboxLogin`, `SharingSet`, `AddedToSecureLink`, `SecureLinkUsed`, `NewInboxRule`, and `UpdateInboxRules`. Bundle size reduced from ~121 to ~117 curated operation types. All removed operations remain available for explicit queries via `-ActivityTypes`.

- **(v1.10.9) Entra Users CSV column naming alignment (breaking):** Renamed five Entra Users CSV columns from PascalCase to camelCase to match Microsoft Graph API property naming exactly: `DisplayName` → `displayName`, `Email` → `mail`, `JobTitle` → `jobTitle`, `Country` → `country`, `HasLicense` → `hasLicense`. Total column count remains 47. Output now matches the column names expected by the M365 Usage Analysis Dashboard and AI-in-One Power BI templates without requiring rename steps in M code. **Breaking:** Downstream consumers referencing the old PascalCase names must be updated.

- **(v1.10.9) Time-zone-dependent record loss in streaming merge:** Fixed a bug where `CreationDate` lost its `Z` suffix during the JSONL round-trip in worker page-flushes (always the case in v1.10.9 with `$memoryFlushEnabled=true`). Downstream parsing returned `Kind=Unspecified`, and `.ToUniversalTime()` then treated the value as local time — shifting UTC records by `[local-UTC-offset]` hours and trimming everything past the `TrimEndDateUTC` boundary. In a UTC-5 (EST) tenant pulling a single day, all activity authored after 19:00 UTC was silently dropped, often producing 0 exported records despite valid retrievals. The worker normalizer now parses with `AssumeUniversal | AdjustToUniversal`, producing `Kind=Utc` so JSONL serialization preserves the `Z`. Existing `.pax_incremental` JSONL files written by earlier v1.10.9 builds must be deleted and the run re-executed.

- **(v1.10.9) Circuit breaker cascading partition loss in sequential mode:** Fixed a bug where tripping the circuit breaker on one partition caused every remaining sequential partition to immediately `break` with 0 records (because the cooldown had not yet elapsed when the next partition's first iteration checked the flag). A single transient outage could silently skip 5–6 partitions (40–60% of the requested date range). The sequential `foreach` loop now waits out the remaining cooldown and resets the breaker before each partition. Affects EOM mode and any other sequential processing path; parallel mode was not affected.

- **(v1.10.9) 404 handling in ThreadJob status poll & dead QueryId reuse:** Added 404 detection in the ThreadJob status poll catch block that previously fell through to the generic error handler with no diagnostic context. A new `[QUERY-GONE]` log tag is emitted with the dead QueryId on detection. Combined with this, the main retry loop now inspects each partition's `LastError` before deciding whether to reuse `$existingQueryId` — when the prior failure matches `QUERY-GONE` / `404.*Not Found`, the dead QueryId is cleared and the retry CREATEs a fresh query. Previously every retry pass polled the same dead query and got the same 404, exhausting all retry passes with 0 records.

- **(v1.10.9) Single-partition Graph API runs forced sequential path:** Fixed an activation gate that bypassed the parallel ThreadJob pipeline whenever a Graph API run had only one partition (e.g., a one-day query at the default 24-hour `PartitionHours`). The sequential path lacked the v1.10.8/v1.10.9 reliability fixes (worker-flush recovery, page-flush memory management, JSONL incremental persistence wiring). The `($degree -gt 1)` requirement is now scoped to EOM mode only — Graph API runs always take the parallel ThreadJob path regardless of partition count. Sequential is now reserved exclusively for `-UseEOM`.

- **(v1.10.9) False data-loss warning on zero-record partitions:** Fixed the streaming-merge JSONL-file-count validation to cross-reference each "missing" partition against its `RecordCount`. Partitions that legitimately returned 0 records (and therefore produced no JSONL file) no longer trigger spurious `[DATA-LOSS]` warnings or `_PARTIAL` filename suffixes. The flag is now only raised when a partition with retrieved records has no corresponding JSONL file.

- **(v1.10.9) Double `_PARTIAL` suffix on output CSV:** Fixed an output filename bug where the streaming-merge data-loss code re-appended `_PARTIAL` to a basename that already contained the suffix from checkpoint initialization, producing `filename_PARTIAL_PARTIAL.csv`. A regex guard now ensures the suffix is only added if not already present.

- **(v1.10.9) Network retry recovery logging in ThreadJobs:** Added explicit `[NETWORK] ... Recovered after network error (Xs outage)` log lines at the two ThreadJob retry code paths (query creation POST, page-level fetch GET) that previously logged only the failure but never the successful recovery. Log files now provide full round-trip visibility for every transient 502/503/504 error: initial failure, retry attempts, and successful recovery with total outage duration. No behavioral changes — logging only.

- **(v1.10.9) Log-quality fixes from run-log review:** Token expiry log now includes the date (`yyyy-MM-dd HH:mm:ss UTC`) instead of time-only. The parallel-launch log line now displays `partitions={N}, MaxConcurrency={N}, effective={N}` so the `[Math]::Min` derivation is visible (previously a single-partition run with `-MaxConcurrency 10` looked like throttling). The redundant duplicate EntraUsers CSV emission in `csvSeparateMode + IncludeUserInfo` runs is now skipped, and the split-block emission is reordered above the combined-CSV cleanup so log entries appear in the correct file-creation order. The closing `===` divider for the `-AppendFile` validation block is now scoped inside the `if ($AppendFile)` branch so it no longer fires on runs that don't use the parameter.

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
