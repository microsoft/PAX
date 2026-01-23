# Release Notes: v1.10.0

## Release Information

- **Version:** 1.10.0
- **Release Date:** 2026-01-22
- **Released By:** Microsoft Copilot Growth ROI Advisory Team (copilot-roi-advisory-team-gh@microsoft.com)

---

## Script Download & Support

Download the script below.  For questions or issues, refer to the documentation.

- **PAX Purview Audit Log Processor Script v1.10.0:** [PAX_Purview_Audit_Log_Processor_v1.10.0.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.10.0/PAX_Purview_Audit_Log_Processor_v1.10.0.ps1)
- **Documentation v1.10.0 (Markdown):** [PAX_Purview_Audit_Log_Processor_Documentation_v1.10.0.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.10.0.md)

---

## Overview

Version 1.10.0 introduces two major capabilities: the **Microsoft 365 Usage Bundle** and **Checkpoint & Resume** for long-running exports.

The **Microsoft 365 Usage Bundle** (`-IncludeM365Usage`) is a single-switch activation that captures productivity activity across Outlook, Teams, SharePoint, OneDrive, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, and PowerApps alongside Copilot data. This enables organizations to correlate Copilot adoption with broader Microsoft 365 usage patterns for ROI analysis and productivity benchmarking.

**Checkpoint & Resume** (`-Resume`) enables recovery from interrupted exports—a critical capability for multi-hour queries spanning large date ranges. PAX automatically saves progress after each partition completes, allowing seamless resumption after token expiry, network interruptions, or system restarts. Combined with intelligent token refresh (silent refresh attempts before prompting, proactive refresh for AppRegistration), this ensures reliable completion of even the longest exports.

Additional enhancements include **parallel explosion processing** (`-ExplosionThreads`) for faster post-retrieval performance on PS7+, **automatic 1M record limit detection** for Graph API queries (with BlockHours auto-subdivision), new CopilotInteraction control switches, an execution telemetry export option, improved automation support with the `-Force` parameter, and UX safeguards when many output files or tabs are expected.

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
| **Authentication** | UserLoggedIn |
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

## Bug Fixes

- **Activity Type Breakdown metrics:** Fixed an issue where "Retrieved" counts showed 0 in the Activity Type Breakdown and Pipeline Summary sections. Per-activity retrieved counts now display correctly in all code paths.

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
