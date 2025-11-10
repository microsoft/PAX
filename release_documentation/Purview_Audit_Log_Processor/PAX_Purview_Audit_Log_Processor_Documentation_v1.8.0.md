# Portable Audit eXporter (PAX) - <br/>Purview Audit Log Processor

> **📥 Quick Start:** Download the script → [`PAX_Purview_Audit_Log_Processor_v1.8.0.ps1`](https://github.com/microsoft/PAX/releases/download/purview-v1.8.0/PAX_Purview_Audit_Log_Processor_v1.8.0.ps1)
>
> **📋 Release Notes:** See what's new → [v1.8.0 Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.8.0.md) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Purview_Audit_Log_Processor)
>
> **📜 Previous Script Versions:** [All Purview Releases](https://github.com/microsoft/PAX/releases?q=purview-&expanded=true)
>
> **📚 Documentation Archive:** [v1.8.0 MD](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.8.0.md) | [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Purview_Audit_Log_Processor)

**Script:** `PAX_Purview_Audit_Log_Processor_v1.8.0.ps1`  
**Version:** 1.8.0  
**Audience:** IT admins, security/compliance analysts, BI/data teams  
**Runtime:** PowerShell 5.1 (compatible) / PowerShell 7+ (recommended)  
**License:** MIT

---

<details>
<summary>⚠️ Important Usage & Compliance Disclaimer</summary>

**Please note:**

While this tool helps customers better understand their AI usage data, Microsoft has no visibility into the data that customers input into this script/tool, nor does Microsoft have any control over how customers will use this script/tool in their environment.

Customers are solely responsible for ensuring that their use of the script/tool complies with all applicable laws and regulations, including those related to data privacy and security.

Microsoft disclaims any and all liability arising from or related to customers' use of the script/tool.

**Experimental Script Notice:**

This is an experimental script. On occasion, you may notice small deviations from metrics in the official Copilot and Agent Dashboards. We will continue to iterate based on your feedback. Currently available in English only.

</details>

---

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Use Cases](#use-cases)
4. [Prerequisites](#prerequisites)
5. [Installation & Setup](#installation--setup)
6. [Parameters Reference](#parameters-reference)
7. [Authentication Methods](#authentication-methods)
8. [Usage Examples](#usage-examples)
9. [Agent Filtering](#agent-filtering)
10. [User and Group Filtering](#user-and-group-filtering)
11. [Prompt and Response Filtering](#prompt-and-response-filtering)
12. [Combining Filters](#combining-filters)
13. [DSPM for AI](#dspm-for-ai)
14. [Excel Export](#excel-export)
15. [Incremental Data Collection (AppendFile)](#incremental-data-collection-appendfile)
16. [Output Files & Schema](#output-files--schema)
17. [Activity Types Reference](#activity-types-reference)
18. [Advanced Features](#advanced-features)
19. [Performance Tuning](#performance-tuning)
20. [Troubleshooting & FAQ](#troubleshooting--faq)
21. [Known Limitations](#known-limitations)
22. [Security & Compliance](#security--compliance)

---

## Overview

<details open>
<summary>What It Does</summary>

The **Portable Audit eXporter (PAX)** is an enterprise-grade PowerShell script that exports Microsoft Purview Unified Audit Log events, with specialized support for Microsoft 365 Copilot activities and related operations. It transforms raw audit data into analysis-ready CSV or Excel files with enriched metadata, intelligent query optimization, and flexible schema options.

**Core Capabilities:**

- Retrieves audit events from Microsoft 365 Unified Audit Log via **Graph API (default)** or **EOM mode** (`-UseEOM`)
- Exports to structured CSV or Excel (.xlsx) with optional array explosion and deep JSON flattening
- Includes enriched usage & ROI fields (tokens, models, latency, acceptance metrics)
- Supports both live querying and offline replay/transformation of previously exported data
- Implements adaptive time slicing to navigate service limits intelligently
- Provides detailed logging of all operations, warnings, and performance metrics
- Automatically handles module installation and authentication (ExchangeOnlineManagement for EOM mode)
- **Graph API mode (default):** Supports Entra ID user enrichment + M365 Copilot (MAC) licensing via `-IncludeUserInfo` and `-OnlyUserInfo`
- **EOM mode (`-UseEOM`):** Supports server-side group expansion via `-GroupNames` and 10K limit detection

**Execution Modes:**

1. **Standard Mode** - One row per audit record (raw JSON preserved in `AuditData` column)
2. **Array Explosion Mode** (`-ExplodeArrays`) - Canonical Purview 35-column schema with array elements expanded
3. **Deep Flatten Mode** (`-ExplodeDeep`) - 35-column base schema + fully flattened `CopilotEventData.*` columns
4. **Offline Replay Mode** (`-RAWInputCSV`) - Re-process previously exported raw audit CSV files without querying the service
5. **Agent Filtering Mode** (`-AgentsOnly` or `-AgentId` or `-ExcludeAgents`) - Filter for records based on Copilot agent presence (works with live queries and replay mode)
6. **Prompt and Response Filtering Mode** (`-PromptFilter`) - Filter Copilot conversation turns by isPrompt property to isolate prompts, responses, or both

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Key Features

<details>
<summary>Intelligent Query Management</summary>

- **Adaptive Block Sizing:** Automatically adjusts time window sizes based on data density
- **10K Limit Detection (EOM Mode Only):** Identifies when Microsoft 365 service cap is reached and recommends mitigation (requires `-UseEOM`)
- **Automatic Subdivision:** Binary/aggressive splitting of dense time periods to maximize completeness
- **Throttle Resilience:** Exponential backoff with jitter for retry operations
- **Volume Classification:** Smart batching based on activity type (High/Medium/Low volume)

</details>

<details>
<summary>Data Processing & Output</summary>

- **Purview Schema Compliance:** Matches Microsoft Purview's canonical exploded schema structure
- **Deep JSON Flattening:** Optional recursive flattening of nested `CopilotEventData` structures
- **Agent Filtering:** Filter records by specific AgentId values or any agent-related activity
- **User Filtering:** Filter by user emails via `-UserIds` parameter (server-side with `-UseEOM`, client-side in Graph API mode)
- **Group Filtering (EOM Mode Only):** Server-side group expansion to members via `-GroupNames` parameter (requires `-UseEOM`)
- **Entra ID Enrichment + M365 Copilot Licensing (Graph API Mode Only):** Enrich audit data with Entra user attributes and M365 Copilot (MAC) license information via `-IncludeUserInfo` (default mode, not compatible with `-UseEOM`)
- **User-Only Export (Graph API Mode Only):** Export only Entra ID user data and M365 Copilot licensing without audit records via `-OnlyUserInfo` (requires `-IncludeUserInfo`, not compatible with `-UseEOM`)
- **Flexible Export Formats:** CSV (default) or Excel (.xlsx) with professional formatting
- **Streaming Export:** Memory-efficient chunked data writing for large datasets
- **UTF-8 Encoding:** Consistent UTF-8 (no BOM) output for CSV files
- **Header Stability:** Always writes file headers even when zero records match (ensures schema consistency)

</details>

<details>
<summary>Performance Optimization</summary>

- **Parallel Execution (PS7+):** Concurrent processing of multiple activity types with controlled throttling
- **Learned Block Sizes:** Per-activity and global adaptive sizing based on observed densities
- **Fast Data Writer:** Direct `StreamWriter` usage for CSV; ImportExcel module for Excel exports
- **Schema Sampling:** Configurable initial sampling to optimize column discovery vs. memory usage

</details>

<details>
<summary>Operational Excellence</summary>

- **Real-Time Progress Tracking:** Live status updates across Query/Explosion/Export phases with percentage completion
- **CSV & Excel Export:** Native support for both CSV files and Excel workbooks with professional formatting
- **Detailed Logging:** Comprehensive log file with parameters, decisions, warnings, and metrics
- **Automated Setup:** Graph API mode (default) requires no modules; EOM mode auto-installs ExchangeOnlineManagement if needed
- **Offline Replay:** Transform previously exported raw CSVs without service connection

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Use Cases

<details>
<summary>Adoption & Usage Analytics</summary>

- Track Microsoft 365 Copilot adoption across your organization
- Measure user engagement with AI features (interactions, token consumption, model usage)
- Identify power users and underutilized licenses
- Calculate ROI metrics based on time saved and acceptance rates

</details>

<details>
<summary>Compliance & Governance</summary>

- Audit Copilot interactions for regulatory compliance requirements
- Monitor data access patterns and sensitivity indicators
- Track plugin usage and custom GPT deployment
- Generate audit trails for security reviews
- Filter and analyze specific Copilot Studio declarative agent activity

</details>

<details>
<summary>Performance & Capacity Planning</summary>

- Track Copilot usage patterns and peak activity periods
- Analyze model names and app host distribution across your tenant
- Optimize script performance with adaptive block sizing for your tenant's data density
- Identify query throttling patterns during high-volume periods

**Note:** Advanced metrics like response latencies and token consumption require `-ExplodeDeep` mode to extract nested CopilotEventData fields.

</details>

<details>
<summary>Data Integration & BI</summary>

- Export enriched data to Power BI, Azure Synapse, or data warehouses
- Join audit data with licensing information for coverage analysis
- Build custom dashboards with wide-schema flattened data
- Maintain historical archives with consistent schema over time

</details>

<details>
<summary>Development & Testing</summary>

- Offline replay mode for reproducible transformations
- Test schema changes against synthetic or sanitized datasets
- Validate data pipelines without querying production audit logs
- Develop downstream analytics without live tenant access

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Prerequisites

<details>
<summary>📋 View Prerequisites (Click to Expand)</summary>

| Requirement                 | Details                                 | Notes                                                        |
| --------------------------- | --------------------------------------- | ------------------------------------------------------------ |
| **PowerShell**              | 5.1 or 7+                               | 7+ strongly recommended for parallel execution and UTF-8     |
| **Unified Audit Logging**   | Enabled in tenant                       | Verify in Microsoft Purview compliance portal                |
| **Permissions**             | View-Only Audit Logs or Audit Logs role | Least privilege: Use read-only audit role. Graph API permissions (User.Read.All, Organization.Read.All) required for Entra enrichment + M365 Copilot (MAC) licensing (`-IncludeUserInfo`). Standard audit roles sufficient for DSPM activity types. |
| **Network Access**          | Microsoft 365 endpoints                 | Ensure firewall allows connections to Microsoft Graph and Exchange Online endpoints |
| **Execution Policy**        | Bypass or RemoteSigned                  | See [Authentication Methods](#authentication-methods)        |

**Note:** Graph API mode (default) requires no PowerShell module installation. EOM mode (`-UseEOM`) automatically handles ExchangeOnlineManagement module detection and installation if needed.

<details>
<summary>Permission Details</summary>

**Minimum RBAC Requirements:**

**Standard Audit Log Access:**
- **View-Only Audit Logs** role (read-only, recommended for production)
- **Audit Logs** role (if write operations needed elsewhere)
- Member of appropriate role groups in Microsoft Purview compliance portal

**DSPM for AI Access:**
- Same roles as standard audit access (View-Only Audit Logs or Audit Logs)
- No additional permissions required for DSPM activity types (`ConnectedAIAppInteraction`, `AIInteraction`, `AIAppInteraction`)

**Entra ID User Enrichment + M365 Copilot Licensing (Optional - Graph API Mode Only):**
- **User.Read.All** (read all users' basic profiles and license assignments via Microsoft Graph)
- **Organization.Read.All** (read organization information)
- Required only when using `-IncludeUserInfo` or `-OnlyUserInfo` parameters
- Provides access to both Entra user data AND M365 Copilot (MAC) license information
- License data retrieved from Microsoft Graph License APIs using User.Read.All scope
- Not applicable in EOM mode (`-UseEOM`)

</details>

<details>
<summary>Why PowerShell 7+?</summary>

| Feature              | PowerShell 5.1                | PowerShell 7+                  |
| -------------------- | ----------------------------- | ------------------------------ |
| Parallel Execution   | ❌ Not Available              | ✅ `ForEach-Object -Parallel`  |
| UTF-8 Default        | ❌ Requires explicit encoding | ✅ Native UTF-8                |
| Performance          | Baseline                      | 🚀 30-50% faster JSON/pipeline |
| TLS/Cipher Support   | Legacy protocols              | ✅ Modern TLS 1.3              |
| Cross-Platform       | ❌ Windows only               | ✅ Windows/macOS/Linux         |
| Side-by-Side Install | N/A                           | ✅ Does not replace PS 5.1     |

**Download PowerShell 7:** https://aka.ms/powershell

</details>

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Installation & Setup

<details>
<summary>Download the Script</summary>
 
- **Script:** [PAX_Purview_Audit_Log_Processor_v1.8.0.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.8.0/PAX_Purview_Audit_Log_Processor_v1.8.0.ps1)
- **Release Notes:** [v1.8.0](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.8.0.md)

Save the downloaded script to a working directory (e.g., `C:\Scripts\PAX\`).

</details>

### First Run (Quick Start)

<details>
<summary>💻 Show Quick Start Commands</summary>

```powershell
# PowerShell 7+ (recommended) - Graph API Mode (Default)
pwsh -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# Windows PowerShell 5.1 - Graph API Mode (Default)
powershell -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

**What Happens:**

1. Script connects to Microsoft Graph Security API (default mode in v1.8.0+)
2. Interactive browser sign-in prompt (unless `-Auth` specified)
3. Queries Unified Audit Log for the specified date range
4. Exports to auto-generated filename in `C:\Temp\` (default location, filename varies by activity types and parameters)
5. Creates matching `.log` file with detailed execution metrics

**Note:** For legacy Exchange Online Management (EOM) mode, add `-UseEOM` parameter. Graph API mode is recommended for better performance and Entra ID enrichment support.

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Parameters Reference

<details>
<summary>📋 View All Parameters (Click to Expand)</summary>

### Date & Time Parameters

#### `-StartDate` (string)

**Purpose:** UTC start date (inclusive) for audit log query or replay filter  
**Format:** `yyyy-MM-dd` (e.g., `2025-10-01`)  
**Default (Live Mode):** Previous full UTC day if both dates omitted  
**Default (Replay Mode):** No filter applied if omitted  
**Example:** `-StartDate 2025-10-01`

#### `-EndDate` (string)

**Purpose:** UTC end date (exclusive) for audit log query or replay filter  
**Format:** `yyyy-MM-dd` (e.g., `2025-10-02`)  
**Default (Live Mode):** Previous full UTC day + 1 if both dates omitted  
**Default (Replay Mode):** No filter applied if omitted  
**Example:** `-EndDate 2025-10-02`

**Date Behavior:**

- **Live mode:** If both dates omitted, defaults to previous full UTC day (midnight to midnight)
- **Live mode:** Must specify both or neither (partial specification rejected)
- **Replay mode:** Both dates optional; act as filters on `CreationDate` column
- **Time zone:** All dates interpreted as UTC; convert local times before invocation

---

### Output & File Parameters

#### `-OutputPath` (string)

**Purpose:** Directory path where output files will be created with auto-generated timestamped filenames  
**Default:** `C:\Temp\`
**Auto-Generated Filenames:** Script creates descriptive filenames based on:
- **Activity types** being exported
- **Export mode** (CSV vs Excel, combined vs separate)
- **Current timestamp** (yyyyMMdd_HHmmss format)

**Examples of Auto-Generated Filenames:**
- `Purview_CopilotInteraction_Export_20251110_143022.csv`
- `Purview_Audit_CombinedUsageActivity_20251110_143022.csv`
- `Purview_MultiTab_Export_20251110_143022.xlsx`
- `Purview_DSPM_Export_20251110_143022.csv` (with `-IncludeDSPMForAI`)

**Use When:** Specifying custom output directory location  
**Example:** `-OutputPath "D:\AuditData\2025\\"` → Uses `-OutputPath` directory
- **Full path:** `-AppendFile "C:\Data\\" -OutputPath "C:\Reports\"

# Append to CSV with full path
-AppendFile "C:\Data\Audit\\\" -ExportWorkbook -CombineOutput -OutputPath "C:\Reports\\" -ActivityTypes CopilotInteraction
```

---

### Authentication Parameters

#### `-Auth` (string)

**Purpose:** Authentication method for Exchange Online connection  
**Valid Values:** `WebLogin`, `DeviceCode`, `Credential`, `Silent`  
**Default:** `WebLogin`  
**Use When:** Automating scripts, using headless terminals, or SSO scenarios  
**Examples:**

- `-Auth WebLogin` - Interactive browser sign-in (default)
- `-Auth DeviceCode` - Device code flow for headless/remote sessions
- `-Auth Credential` - Prompt for username/password (stored in memory only)
- `-Auth Silent` - Attempt cached token (fails if no valid token)

**Not applicable in replay mode** (authentication skipped when using `-RAWInputCSV`)

---

### Query Behavior Parameters

#### `-BlockHours` (double)

**Purpose:** Initial time window size (hours) for each audit query chunk  
**Range:** `0.016667` to `24.0` (1 minute to 24 hours)  
**Default:** `0.5` (30 minutes)  
**Use When:**

- Frequently hitting 10K limit (reduce to 0.25 or lower)
- Sparse historical data (increase to 2-8 hours for faster processing)
- Fine-tuning for tenant-specific data density

**Examples:**

- `-BlockHours 0.25` - Dense periods, many records
- `-BlockHours 4.0` - Sparse backfills, low activity

**Notes:** Script learns optimal sizes during execution; this is just the starting point

#### `-ResultSize` (int)

**Purpose:** Target number of records to retrieve per activity per time window  
**Range:** `1` to `10000`  
**Default:** `10000`  
**Use When:**

- Managing memory usage (lower values = smaller batches)
- Testing with small samples
- Avoiding service throttling (reduce to 2500-5000)

**Example:** `-ResultSize 5000`  
**Notes:** Actual results may be less; this is the requested maximum

#### `-PacingMs` (int)

**Purpose:** Delay (milliseconds) between paginated API calls  
**Range:** `0` to `10000`  
**Default:** `0` (no artificial delay)  
**Use When:**

- Experiencing frequent throttling errors
- Running during peak tenant usage
- Spreading load over time for politeness

**Examples:**

- `-PacingMs 250` - Moderate pacing
- `-PacingMs 500` - Conservative pacing

**Notes:** Increases total execution time proportionally

#### `-ActivityTypes` (string[])

**Purpose:** Array of audit log operation names to retrieve  
**Default:** `@('CopilotInteraction')`  
**Use When:**

- Querying multiple activity types in one run
- Analyzing cross-functional behaviors (Teams + Copilot)
- Comparative analysis across services

**Examples:**

- Single: `-ActivityTypes CopilotInteraction`
- Multiple: `-ActivityTypes CopilotInteraction,MessageSent,FileAccessed`
- Custom: `-ActivityTypes @('MeetingDetail','SearchQueryPerformed')`

**Notes:** See [Activity Types Reference](#activity-types-reference) for common operations

---

#### `-AgentId` (string[])

**Purpose:** Filter audit records to include only those with specific AgentId value(s)  
**Default:** Not set (no agent filtering)  
**Use When:**

- Analyzing specific Copilot Studio declarative agents
- Tracking usage of particular agent implementations
- Filtering for known AgentId patterns

**Examples:**

- Single: `-AgentId "CopilotStudio.Declarative.T_4e671777-fa6c-601a-b416-df08b6ae4c14.03dc0b8b-a75a-4b77-86d7-98185a176d1b"`
- Multiple: `-AgentId "SYSTEM_CreateGPT.declarativeCopilot","CopilotStudio.Declarative.T_..."`

**Notes:** 
- Works in both live query and replay modes
- AgentId is a top-level field in AuditData JSON
- Takes precedence if both `-AgentId` and `-AgentsOnly` are specified

---

#### `-AgentsOnly` (switch)

**Purpose:** Filter audit records to include only those with any AgentId present  
**Default:** Off (no agent filtering)  
**Use When:**

- Analyzing all agent-related activity regardless of specific agent
- Identifying records that involve Copilot Studio agents
- Filtering out non-agent Copilot interactions

**Example:** `-AgentsOnly`

**Notes:**
- Works in both live query and replay modes
- More inclusive than `-AgentId` (includes any record with AgentId field populated)
- Combined with `-ActivityTypes` for refined filtering

---

#### `-ExcludeAgents` (switch)

**Purpose:** Filter audit records to EXCLUDE those with AgentId present (inverse of `-AgentsOnly`)  
**Default:** Off (no agent filtering)  
**Use When:**

- Analyzing non-agent Copilot interactions only
- Removing agent activity from analysis
- Comparing agent vs non-agent usage patterns

**Example:** `-ExcludeAgents`

**Notes:**
- Works in both live query and replay modes
- Mutually exclusive with `-AgentId` and `-AgentsOnly`
- Filters at record level during parsing phase

---

#### `-UserIds` (string[])

**Purpose:** Filter audit records to include only those from specific user(s)  
**Default:** Not set (no user filtering)  
**Mode Compatibility:**
- **Graph API Mode (Default):** Client-side filtering after retrieval (filters all retrieved records)
- **EOM Mode (`-UseEOM`):** Server-side filtering via `Search-UnifiedAuditLog -UserIds` (highly efficient)
- **Replay Mode:** Client-side filtering by parsing `UserId` from AuditData JSON

**Use When:**

- Investigating specific user's Copilot activity
- Security reviews or compliance audits for individual accounts
- Troubleshooting user-reported issues
- Analyzing power users or early adopters
- Post-processing existing exports (replay mode)

**Examples:**

- Single: `-UserIds "john.doe@contoso.com"`
- Multiple: `-UserIds "john.doe@contoso.com","jane.smith@contoso.com","bob.jones@contoso.com"`
- Array: `-UserIds @("user1@contoso.com", "user2@contoso.com")`

**Notes:** 
- User emails are case-insensitive
- Can be combined with `-GroupNames` (users are merged and deduplicated)
- Works with all other filters (`-AgentsOnly`, `-AgentId`, `-ExcludeAgents`, `-PromptFilter`)
- **Performance:** Server-side filtering (EOM mode) is more efficient for large datasets; Graph API mode retrieves all records then filters client-side
- Client-side filtering processes ~5,000 records/second

---

#### `-GroupNames` (string[])

**Purpose:** Filter audit records to include only those from members of specific distribution group(s)  
**Default:** Not set (no group filtering)  
**Mode Compatibility:**
- **⚠️ EOM Mode Only:** Requires `-UseEOM` parameter (NOT compatible with default Graph API mode)
- **Live Mode:** Expands groups to member emails, then filters server-side (efficient)
- **Replay Mode:** ⚠️ **BLOCKED** - Group expansion requires Exchange Online authentication

**Use When:**

- Analyzing department-wide or team-level Copilot adoption (EOM live mode only)
- Tracking usage across organizational units
- Compliance audits for specific business groups
- ROI analysis by functional group

**Examples:**

- Single: `-UseEOM -GroupNames "Engineering-Team@contoso.com"`
- Multiple: `-UseEOM -GroupNames "Sales@contoso.com","Marketing@contoso.com"`
- Array: `-UseEOM -GroupNames @("Group1@contoso.com", "Group2@contoso.com")`

**Notes:** 
- **Requires `-UseEOM`** to enable EOM mode
- Requires Exchange Online authentication for group expansion
- Uses `Get-DistributionGroupMember` to expand groups to member emails
- Expansion adds ~2-5 seconds per group (one-time cost)
- Can be combined with `-UserIds` (users are merged and deduplicated)
- Works with all other filters (`-AgentsOnly`, `-AgentId`, `-ExcludeAgents`, `-PromptFilter`)
- **Not compatible with Graph API mode (default)** - use `-UseEOM` first
- **Replay mode:** Script will display error and exit if `-GroupNames` used

---

#### `-PromptFilter` (string)

**Purpose:** Filter Copilot conversation turns by `Message_isPrompt` property to isolate prompts, responses, or both  
**Default:** Not set (no prompt/response filtering)  
**Valid Values:** `Prompt`, `Response`, `Both`, `Null`  
**Use When:**

- **Prompt**: Analyzing user input patterns, query types, intent analysis
- **Response**: Extracting response content for analysis, measuring latency, tracking acceptance rates (combine with Prompt data via ThreadId for quality evaluation)
- **Both**: Full conversation analysis with defined isPrompt values
- **Null**: Debugging records with malformed or missing isPrompt properties

**Examples:**
- `-PromptFilter Prompt` - Only conversation turns where Message_isPrompt = True
- `-PromptFilter Response` - Only conversation turns where Message_isPrompt = False
- `-PromptFilter Both` - Conversation turns with either True or False (excludes nulls)
- `-PromptFilter Null` - Conversation turns with null/undefined isPrompt values

**Notes:**
- Works in both live query and replay modes
- Uses two-stage filtering: pre-filter records, then filter conversation turns during explosion
- Can be combined with `-AgentsOnly`, `-ExcludeAgents`, or `-AgentId`
- Provides detailed metrics in summary (record/conversation retention, type breakdown)
- Stage 1 reduces records before explosion for performance
- Stage 2 ensures clean output with no blank Message_isPrompt values

---

### Data Processing Parameters

#### `-ExplodeArrays` (switch)

**Purpose:** Enable Purview canonical 35-column exploded schema (array elements → rows)  
**Default:** Off (standard 1:1 row mode)  
**Use When:**

- Need one row per array element for pivoting
- Matching Microsoft Purview export format
- Preparing for relational BI tools

**Example:** `-ExplodeArrays`  
**Notes:** Forced ON automatically in replay mode

#### `-ExplodeDeep` (switch)

**Purpose:** Enable deep flattening (35-column base + all `CopilotEventData.*` columns)  
**Default:** Off  
**Use When:**

- Maximum data extraction for BI/ML pipelines
- Need every nested field as a separate column
- Building wide-schema data warehouses

**Example:** `-ExplodeDeep`  
**Notes:** Significantly increases CSV width; test with short date range first

---

### Offline Replay Parameters

#### `-RAWInputCSV` (string)

**Purpose:** Path to previously exported raw Purview audit CSV for offline transformation  
**Default:** Not set (live query mode)  
**Use When:**

- Re-processing raw exports with different explosion settings
- Development/testing without live tenant access
- Reproducible transformations for auditing

**Example:** `-RAWInputCSV "C:\PreviousExports\\"`

---

### Parallel Execution Parameters (PowerShell 7+ only)

#### `-ParallelMode` (string)

**Purpose:** Control parallel execution of multiple activity types  
**Valid Values:** `Off`, `On`, `Auto`  
**Default:** `Off`  
**Use When:**

- Processing multiple high-volume activity types
- Maximizing throughput on multi-core systems
- Need `Auto` heuristic to decide based on activity count

**Examples:**

- `-ParallelMode Auto` - Let script decide based on activity count and volume
- `-ParallelMode On` - Force parallel execution
- `-ParallelMode Off` - Sequential processing (PS 5.1 compatible)

#### `-MaxConcurrency` (int)

**Purpose:** Controls concurrent query/partition execution for both EOM and Graph API modes  
**Range:** `1` to `10`  
**Default:** `10`  
**Use When:**
- Fine-tuning parallel execution to avoid throttling
- **EOM mode:** Limits concurrent serial queries
- **Graph API mode:** Limits concurrent partition execution

**Example:** `-MaxConcurrency 8`

**Notes:** 
- Replaced the previous `MaxActivePartitions` parameter (v1.7.4 and earlier)
- **Maximum enforced by Microsoft Purview:** 10 concurrent search jobs per user account (platform limitation)
- Default set to 10 to maximize throughput within platform limits
- Works consistently across both execution modes

#### `-MaxParallelGroups` (int)

**Purpose:** Maximum number of activity groups to process concurrently  
**Range:** `1` to `5`  
**Default:** `3`  
**Use When:** Limiting total concurrent operations  
**Example:** `-MaxParallelGroups 2`

---

### Advanced Tuning Parameters

#### `-StreamingSchemaSample` (int)

**Purpose:** Number of initial records to sample for schema discovery  
**Range:** `100` to `10000`  
**Default:** `2000`  
**Use When:**

- Wide schemas need more samples to discover all columns
- Narrow schemas can use smaller samples for faster processing

**Example:** `-StreamingSchemaSample 5000`

#### `-StreamingChunkSize` (int)

**Purpose:** Number of records to write per CSV flush operation  
**Range:** `100` to `20000`  
**Default:** `5000`  
**Use When:**

- Managing memory usage (lower = more frequent flushes)
- Optimizing write performance (higher = fewer I/O operations)

**Example:** `-StreamingChunkSize 10000`

#### `-ExportProgressInterval` (int)

**Purpose:** Row interval for export progress updates  
**Range:** `1` to `10000`  
**Default:** `10`  
**Use When:** Need more granular progress updates  
**Example:** `-ExportProgressInterval 5`

#### `-LowLatencyMs` (int)

**Purpose:** Threshold (milliseconds) under which recent interactions are considered low latency for adaptive concurrency heuristics.  
**Default:** `20000`  
**Use When:** Adjusting sensitivity of concurrency scaling in very fast or slower tenant conditions.  
**Notes:** Lower = stricter definition of "low latency" (slower growth); higher = more aggressive scaling.  
**Example:** `-LowLatencyMs 15000`

#### `-ThroughputDropPct` (int)

**Purpose:** Percentage drop from recent peak throughput (records/sec) that triggers damping of concurrency growth.  
**Default:** `15`  
**Use When:** Reducing false positives (raise value) or increasing responsiveness to regressions (lower value).  
**Example:** `-ThroughputDropPct 20`

#### `-AdaptiveConcurrencyCeiling` (int)

**Purpose:** Safety ceiling on adaptive concurrency regardless of `-MaxConcurrency`.  
**Default:** `6`  
**Use When:** Constraining dynamic scaling even if hardware could support more.  
**Notes:** Effective concurrency never exceeds min(`-MaxConcurrency`, `-AdaptiveConcurrencyCeiling`).  
**Example:** `-AdaptiveConcurrencyCeiling 8`

---

### Observability & Completeness Parameters

#### `-EmitMetricsJson` (switch)

**Purpose:** Emit a structured JSON metrics file summarizing the export session (query windows, explosion counts, timings, exit code)  
**Default:** Off  
**Use When:**

- Need machine-readable telemetry for automation / dashboards
- Comparing completeness across sequential runs
- Integrating with pipeline gating (exit code + metrics state)

**Example:** `-EmitMetricsJson`

**Notes:**

- File name automatically includes timestamp unless `-MetricsPath` supplied with custom name
- Emitted exactly once (even in parallel mode) after final aggregation
- Safe to re-run; new timestamped file created for each execution

#### `-MetricsPath` (string)

**Purpose:** Override default metrics output path and filename  
**Default:** Auto-generated path alongside CSV  
**Use When:** Centralizing metrics, piping to monitoring folder, or storing outside restricted data zone  
**Example:** `-EmitMetricsJson -MetricsPath "C:\Exports\Telemetry\purview_run_20251026.json"`  
**Notes:** Ignored unless `-EmitMetricsJson` is also specified

#### `-AutoCompleteness` (switch)

**Purpose:** Recursively subdivide any time windows that still hit the 10K service limit after the initial pass until below limit or safety thresholds reached  
**Default:** Off  
**Use When:** First run (without this switch) exits with code 10 (incomplete) and logs saturated windows  
**Example Workflow:**

1. Initial run: `pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-25 -EndDate 2025-10-25 -EmitMetricsJson`
2. If exit code = 10 → re-run: `pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-25 -EndDate 2025-10-25 -AutoCompleteness -EmitMetricsJson`

**Notes:**

- Honors minimum window size & max recursion depth to prevent pathological slicing
- Stops early once all previously saturated windows resolve (<10K)
- Exit codes: 0 (success), 10 (incomplete if not invoked), 20 (circuit breaker)
- Prefer narrowing `-BlockHours` first for multi-day very high volume ranges

---

### Dual-Mode & Enrichment Parameters

#### `-UseEOM` (switch)

**Purpose:** Use Exchange Online Management (EOM) module for audit log retrieval instead of Microsoft Graph API  
**Default:** Off (uses Graph API by default in v1.8.0+)  
**Use When:**

- Legacy compatibility required
- Graph API permissions unavailable
- Troubleshooting Graph API connectivity issues

**Example:** `-UseEOM`

**Notes:**

- **Graph API is now the default** in version 1.8.0
- EOM mode does NOT support `-IncludeUserInfo` (Entra enrichment requires Graph API)
- `-GroupNames` filtering requires EOM mode (Graph API does not support server-side group filtering)
- For most scenarios, Graph API provides better performance and features

#### `-IncludeUserInfo` (switch)

**Purpose:** Enrich audit data with Entra ID user attributes and Microsoft 365 license information (extended schema)  
**Default:** Off (audit data only)  
**Use When:**

- Need user department, job title, manager, license assignments, or account status
- Analyzing adoption by organizational structure
- Compliance reporting requiring user demographics
- License tracking and M365 Copilot entitlement analysis

**Example:** `-IncludeUserInfo`

**Requirements:**

- **Graph API Mode:** NOT compatible with `-UseEOM` (requires Graph API)
- **Permissions:** User.Read.All (includes user profiles and license data), Organization.Read.All (least privilege)
- **Output:** Adds `EntraUsers_MAClicensing_<timestamp>.csv` file (CSV mode) or `EntraUsers_MAClicensing` tab (Excel mode)

**Schema:** Comprehensive schema including UserPrincipalName, DisplayName, Department, JobTitle, Manager, AssignedLicenses (all M365 licenses), HasCopilotLicense (boolean), CopilotLicenseSkus (detected SKUs), AccountEnabled, and more

**Notes:**

- One-time Graph API call per unique user in audit dataset
- Minimal performance impact (<5 seconds for typical datasets)
- User data cached for session duration
- **License data:** Retrieved via User.Read.All scope from Microsoft Graph - includes all assigned licenses
- **License detection:** Automatically identifies M365 Copilot entitlements from AssignedLicenses using SKU pattern matching (O365_PREMIUM, M365_F1_COMM, etc.)

#### `-OnlyUserInfo` (switch)

**Purpose:** Export ONLY Entra ID user directory and Microsoft 365 license data (skips all audit log queries)  
**Default:** Off (standard audit log mode)  
**Use When:**

- Need rapid license compliance snapshots without audit data
- Periodic user directory exports for tracking M365 Copilot license assignments
- Standalone Entra data for cross-referencing with other systems
- Monthly/quarterly license auditing without audit log overhead

**Example:** `-OnlyUserInfo`

**Behavior:**

- Authenticates to Microsoft Graph
- Fetches all Entra users and Microsoft 365 license assignments via Graph API
- Exports standalone `EntraUsers_MAClicensing_<timestamp>.csv` (or Excel with single tab)
- **Skips all audit log queries** (completes in 5-15 seconds vs. minutes/hours)
- Automatically enables `-IncludeUserInfo` internally

**Requirements:**

- **Graph API Mode:** NOT compatible with `-UseEOM` (requires Graph API)
- **Permissions:** User.Read.All (includes user profiles and license data), Organization.Read.All
- **Output:** Single file containing 37 columns of user + license data

**Compatible Parameters:**

- `-OutputPath` (specify output directory)
- `-Auth` (choose authentication method: WebLogin, DeviceCode, etc.)
- `-ExportWorkbook` (export to Excel instead of CSV)

**Note:** `-AppendFile` is NOT compatible with `-OnlyUserInfo` since EntraUsers data represents point-in-time snapshots, not time-based activity that should be appended.

**Incompatible Parameters (automatically blocked):**

All audit-related parameters are incompatible and will trigger validation errors:

- **Date Filtering:** StartDate, EndDate
- **Activity Types:** ActivityTypes, IncludeDSPMForAI, ExcludeCopilotInteraction
- **User/Agent Filtering:** UserIds, GroupNames, AgentId, AgentsOnly, ExcludeAgents, PromptFilter
- **Processing Modes:** ExplodeArrays, ExplodeDeep, RAWInputCSV
- **Query Tuning:** BlockHours, PartitionHours, MaxPartitions, ResultSize, PacingMs, AutoCompleteness
- **Parallelization:** ParallelMode, MaxParallelGroups, MaxConcurrency, EnableParallel
- **EOM Mode:** UseEOM

**Use Cases:**

1. **License Compliance:** Monthly snapshots to track M365 Copilot license assignments over time
2. **Adoption Planning:** Identify licensed vs. unlicensed users before detailed usage analysis
3. **User Directory Exports:** Standalone Entra data for HR/IT system integration
4. **Rapid Licensing Audits:** Quick compliance checks without audit log overhead

**Performance:**

- Execution time: 5-15 seconds (vs. minutes/hours for audit queries)
- Network traffic: Minimal (only user directory + license API calls, no audit queries)

**Examples:**

```powershell
# Basic user-only export (CSV)
.\PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -OnlyUserInfo

# Export to Excel workbook
.\PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -OnlyUserInfo -ExportWorkbook

# Custom output directory
.\PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -OnlyUserInfo -OutputPath "D:\LicenseAudits\"

# Device code auth for automation/headless scenarios
.\\" -StartDate 2025-10-03 -EndDate 2025-10-04`

**CSV Mode Behavior:**

- **File Selection:**
  - With full path: Uses exact file path (e.g., `"C:\Data\\"`)
  - With filename only: Searches in `-OutputPath` directory (default: `.\output\`)
  - Without `-AppendFile`: Creates new timestamped file
- **Header Validation:**
  - Compares new data headers against existing CSV headers
  - Validates exact match (case-sensitive column names and order)
  - **Mismatch Behavior:** Script exits with error showing missing/extra columns
- **Append Operation:**
  - Opens existing file in append mode
  - Writes new rows starting immediately after last existing row
  - No duplicate header row written
- **No `-ExportWorkbook` required** for CSV append mode

**Excel Mode Behavior:**

- **File Selection:**
  - With full path: Uses exact file path (e.g., `"C:\Reports\\"`)
  - With filename only: Searches for file in `-OutputPath` directory (default: `.\output\`)
  - Without `-AppendFile`: Creates new timestamped workbook
- **Header Validation:**
  - Compares new data headers against each existing tab
  - **Matching Headers:** Appends new rows to existing tabs
  - **Mismatched Headers:** Creates timestamped duplicate tabs (preserves both datasets, safe mode)
- **Multi-Tab Mode:**
  - Appends to each activity type tab separately (e.g., `CopilotInteraction`, `ConnectedAIAppInteraction`)
  - Handles DSPM naming variations automatically
- **Combined Mode:**
  - Appends to single combined activity tab
  - EntraUsers tab handled separately if present
- **Requires `-ExportWorkbook` parameter**

**File Path Priority Logic:**

When both `-AppendFile` and `-OutputPath` are specified:
- **Full path in `-AppendFile`:** Takes complete precedence (e.g., `"C:\Data\\" -OutputPath "C:\Data"`)
- **Conflict scenario:** If `-AppendFile` contains directory that differs from `-OutputPath`, script warns and uses `-AppendFile` path
- **Best Practice:** Use `-AppendFile` with full path for explicit control, or filename only with `-OutputPath`

**Error Scenarios:**

- **CSV header mismatch:** Script exits with detailed diff showing missing columns (in CSV but not new) and extra columns (in new but not CSV)
- **File not found:** Script exits with error message. Create initial file first by running without `-AppendFile`
- **Excel without `-ExportWorkbook`:** Script exits with error: "Excel append requires -ExportWorkbook parameter"
- **EntraUsers mode restriction:** Script exits if `-IncludeUserInfo` or `-OnlyUserInfo` used with `-AppendFile` (EntraUsers data represents point-in-time snapshots, not time-based activity)
- **RAWInputCSV conflicts:** If incompatible parameters specified, script exits listing conflicts (see `-RAWInputCSV` documentation)

**Offline Replay Mode (`-RAWInputCSV`):**

- `-AppendFile` is **fully compatible** with offline replay mode
- Use case: Incrementally filter/transform a large raw audit CSV into multiple processed outputs
- Example: First run exports agents only, second run appends non-agent records to same file
- All CSV and Excel append behaviors apply identically in replay mode

**Notes:**

- **Safe mode operation:** Never overwrites existing data in-place
- **CSV:** Header mismatch = hard stop (prevents schema corruption)
- **Excel:** Header mismatch = new timestamped tab (preserves both schemas)

#### `-CombineOutput` (switch)

**Purpose:** Combine all activity types into single output file/tab  
**Default:** Off (creates separate files per activity type for CSV; separate tabs for Excel)  
**Use When:** Need consolidated single-file output for ingestion pipelines or simplified analysis  
**Applies to:** Both CSV and Excel export modes  
**Example:** `-CombineOutput` (for CSV) or `-ExportWorkbook -CombineOutput` (for Excel)

**Behavior:**

**Without `-CombineOutput` (Default):**
- **CSV Mode:** Creates separate CSV file per activity type (e.g., `CopilotInteraction_<timestamp>.csv`, `ConnectedAIAppInteraction_<timestamp>.csv`)
- **Excel Mode:** Creates multi-tab workbook (one tab per activity type, e.g., `CopilotInteraction`, `ConnectedAIAppInteraction`)

**With `-CombineOutput` switch:**
- **CSV Mode:** Merges all activity types into single file: `Purview_Audit_CombinedUsageActivity_<timestamp>.csv` (with `Operation` column identifying type)
- **Excel Mode:** Creates single-tab workbook with all activity types in one sheet: `Purview_Audit_CombinedUsageActivity_<timestamp>.xlsx`

**Use Cases:**

- **Ingestion Pipelines:** Single combined file simplifies automated ingestion workflows
- **Cross-Activity Analysis:** Easier correlation across activity types in single dataset
- **Simplified Distribution:** Single file for stakeholder sharing instead of multiple files/tabs

**Notes:**

- EntraUsers data always exported separately (not merged with activity data)
- Can be combined with `-AppendFile` for incremental single-tab Excel builds
- Separate files (default) enable parallel processing and activity-specific analysis

---

### Helper Parameters

#### `-Help` (switch)

**Purpose:** Display built-in help documentation  
**Example:** `./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -Help`  
**Use When:** Quick reference without opening documentation

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Authentication Methods

**Starting in version 1.8.0**, the script uses **Microsoft Graph API by default** for audit log retrieval, providing enhanced performance and feature support including Entra ID enrichment and M365 Copilot (MAC) licensing.

**Dual-Mode Architecture:**

- **Graph API Mode (Default):** Modern API with support for `-IncludeUserInfo` (Entra + MAC licensing), better performance, and unified Microsoft 365 access
- **EOM Mode (`-UseEOM`):** Legacy Exchange Online Management module for compatibility scenarios

**Feature Comparison:**

| Feature | Graph API (Default) | EOM Mode (`-UseEOM`) |
|---------|-------------------|---------------------|
| **Entra ID Enrichment + MAC Licensing** (`-IncludeUserInfo`) | ✅ Supported | ❌ Not supported |
| **Server-Side Group Filtering** (`-GroupNames`) | ❌ Not supported | ✅ Supported |
| **Performance** | Better (modern API) | Good (mature module) |
| **Authentication Methods** | All four methods | All four methods |
| **Default in v1.8.0+** | ✅ Yes | Use `-UseEOM` to enable |

**Recommendation:** Use Graph API mode (default) unless you require `-GroupNames` filtering or have legacy constraints.

---

The script supports four authentication methods (available in both Graph API and EOM modes):

### 1. WebLogin (Default)

Interactive browser-based authentication. Best for ad-hoc queries and interactive sessions.

<details>
<summary>💻 Show WebLogin Example</summary>

```powershell
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -Auth WebLogin -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

### 2. DeviceCode

Device code flow for headless/remote sessions or terminals without browser access.

<details>
<summary>💻 Show DeviceCode Example</summary>

```powershell
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -Auth DeviceCode -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

### 3. Credential

Username/password prompt. Credentials stored in memory only during script execution.

<details>
<summary>💻 Show Credential Example</summary>

```powershell
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -Auth Credential -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

### 4. Silent

Attempts to use cached authentication token. Falls back to WebLogin if no valid token exists.

<details>
<summary>💻 Show Silent Example</summary>

```powershell
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -Auth Silent -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Usage Examples

### Basic Queries

<details>
<summary>💻 Show Basic Query Examples</summary>

```powershell
# Standard mode - previous day (auto-default)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1

# Specific date range
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# Custom output directory
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputPath "C:\AuditData\"

# Multiple activity types
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -ActivityTypes CopilotInteraction,MessageSent,FileAccessed
```
### Metrics & Completeness Examples

<details>
<summary>💻 Show Metrics & Completeness Examples</summary>

```powershell
# Emit metrics JSON (default path derived from output directory, includes timestamp)
pwsh -File ./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-05 -EndDate 2025-10-05 -EmitMetricsJson -OutputPath C:\Exports\

# Emit metrics JSON to custom path
pwsh -File ./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-05 -EndDate 2025-10-05 -EmitMetricsJson -MetricsPath C:\Exports\Telemetry\purview_metrics_20251005.json -OutputPath C:\Exports\

# AutoCompleteness remediation (two-run workflow)
# First run (no AutoCompleteness) – may exit with code 10 if saturated windows remain
pwsh -File ./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-07 -EndDate 2025-10-07 -EmitMetricsJson -OutputPath C:\Exports\
# Second run resolves remaining windows
pwsh -File ./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-07 -EndDate 2025-10-07 -AutoCompleteness -EmitMetricsJson -OutputPath C:\Exports\

# Treat exit codes in automation (PowerShell example)
pwsh -File ./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-07 -EndDate 2025-10-07 -EmitMetricsJson
if ($LASTEXITCODE -eq 10) { Write-Host 'Incomplete export detected – re-run with -AutoCompleteness' -ForegroundColor Yellow }
elseif ($LASTEXITCODE -eq 20) { Write-Host 'Circuit breaker tripped – investigate throttling or reduce concurrency' -ForegroundColor Red }
```

</details>


</details>

### Exploded Schema Queries

<details>
<summary>💻 Show Exploded Schema Examples</summary>

```powershell
# Array explosion (35-column Purview schema)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02

# Deep flatten (maximum column extraction)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

### Performance Tuning

<details>
<summary>💻 Show Performance Tuning Examples</summary>

```powershell
# Reduce block size for dense data (hitting 10K limit)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -BlockHours 0.25 -StartDate 2025-10-01 -EndDate 2025-10-01

# Increase block size for sparse historical data
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -BlockHours 4.0 -StartDate 2025-09-01 -EndDate 2025-09-07

# Add pacing to reduce throttling
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -PacingMs 250 -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

### Parallel Execution (PowerShell 7+ only)

<details>
<summary>💻 Show Parallel Execution Examples</summary>

```powershell
# Auto-detect parallel benefit
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -ParallelMode Auto -ActivityTypes CopilotInteraction,MessageSent,FileAccessed

# Force parallel with custom concurrency
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -ParallelMode On -MaxConcurrency 4 -MaxParallelGroups 2 -ActivityTypes CopilotInteraction,MessageSent,FileAccessed
```

</details>

### Offline Replay

<details>
<summary>💻 Show Offline Replay Examples</summary>

```powershell
# Basic replay (forced explosion) - creates timestamped output file
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -RAWInputCSV "C:\PreviousExports\\" -OutputPath "C:\AuditData\"

# Replay with deep flatten and date filtering
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -RAWInputCSV "C:\PreviousExports\\" -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputPath "C:\AuditData\"

# Replay with activity filtering
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -RAWInputCSV "C:\PreviousExports\\" -ActivityTypes CopilotInteraction -OutputPath "C:\AuditData\"

# Replay with agent filtering (any agent)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -RAWInputCSV "C:\PreviousExports\\" -AgentsOnly -OutputPath "C:\AuditData\"


# Replay with specific agent ID
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -RAWInputCSV "C:\PreviousExports\\" -AgentId "CopilotStudio.Declarative.T_4e671777-fa6c-601a-b416-df08b6ae4c14.03dc0b8b-a75a-4b77-86d7-98185a176d1b" -OutputPath "C:\AuditData\\"
```

</details>

### Agent Filtering (Live & Replay)

<details>
<summary>💻 Show Agent Filtering Examples</summary>

```powershell
# Filter for any agent-related records (live query)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -AgentsOnly -StartDate 2025-10-01 -EndDate 2025-10-02

# Filter for specific agent ID(s)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -AgentId "SYSTEM_CreateGPT.declarativeCopilot" -StartDate 2025-10-01 -EndDate 2025-10-02

# Multiple agent IDs with deep flatten
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -ExplodeDeep -AgentId "SYSTEM_CreateGPT.declarativeCopilot","CopilotStudio.Declarative.T_..." -StartDate 2025-10-01 -EndDate 2025-10-02

# Agent filtering in replay mode
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -RAWInputCSV "C:\PreviousExports\\" -AgentsOnly -OutputPath "C:\AuditData\\"
```

</details>

### Entra ID Enrichment & Dual-Mode

<details>
<summary>💻 Show Entra Enrichment & EOM Mode Examples</summary>

```powershell
# Enrich with Entra ID user data (Graph API mode - default)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeUserInfo `
	-OutputPath "C:\Exports\\"
# Output: CopilotInteraction_<timestamp>.csv + EntraUsers_MAClicensing_<timestamp>.csv

# Entra enrichment with Excel export (embedded tab)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeUserInfo `
	-ExportWorkbook `
	-CombineOutput
# Output: Purview_Audit_CombinedUsageActivity_EntraUsers_MAClicensing_<timestamp>.xlsx (with EntraUsers_MAClicensing tab)

# Use EOM mode for GroupNames filtering (legacy mode)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UseEOM `
	-GroupNames "Sales Team","Marketing Team" `
	-OutputPath "C:\Exports\\"

# Increase network resilience timeout (for unstable connections)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-MaxNetworkOutageMinutes 60 `
	-OutputPath "C:\Exports\\"
```

</details>

### Authentication Variations

<details>
<summary>💻 Show Authentication Examples</summary>

```powershell
# Device code for headless session
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -Auth DeviceCode -StartDate 2025-10-01 -EndDate 2025-10-02

# Credential prompt
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -Auth Credential -StartDate 2025-10-01 -EndDate 2025-10-02

# Silent (cached token)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -Auth Silent -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Agent Filtering

<details>
<summary>🤖 View Agent Filtering Guide (Click to Expand)</summary>

### Overview

Agent Filtering enables targeted extraction of Copilot agent-specific audit records from your audit logs. This feature is essential for enterprises analyzing AI agent usage, ROI metrics, and compliance requirements specific to Copilot agents and declarative agents.

**Why Use Agent Filtering?**

- **Performance**: Process only relevant records when you need agent-specific analysis (typical reduction: 99%+ of non-agent records filtered out)
- **Cost Efficiency**: Reduce data egress, storage, and processing costs by exporting only agent-related activities
- **Focused Analysis**: Streamline BI pipelines, Power BI dashboards, and ML models to analyze agent adoption, usage patterns, and ROI
- **Compliance**: Isolate agent interactions for regulatory audits, data governance, and security investigations
- **Multi-Agent Tracking**: Monitor specific declarative agents, custom agents, or Copilot Studio agents across your tenant

### When to Use Agent Filtering

**Use `-AgentsOnly`** when:
- You want all records that contain any AgentId (any Copilot agent activity)
- Building comprehensive agent usage dashboards
- Analyzing overall agent adoption across the organization
- Tracking all AI agent interactions for compliance

**Use `-AgentId`** when:
- You need records for specific agent(s) only (e.g., "CopilotStudio.Declarative.12345")
- Troubleshooting a particular custom or declarative agent
- Analyzing ROI/performance of specific agent deployments
- Auditing a specific agent's interactions for security review

### Agent Filtering Examples

<details>
<summary>💻 Show Detailed Agent Filtering Examples</summary>

```powershell
# Export ALL agent-related records from live query
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentsOnly `
	-OutputPath "C:\Exports\\"

# Filter for specific AgentId (single)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentId "CopilotStudio.Declarative.a1b2c3d4" `
	-OutputPath "C:\Exports\\"

# Filter for multiple specific AgentIds
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentId "CopilotStudio.Declarative.agent1","CopilotStudio.Declarative.agent2","CustomAgent.xyz" `
	-OutputPath "C:\Exports\\"

# Replay mode: Filter agents from previously exported data
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-RAWInputCSV "C:\Exports\\" `
	-AgentsOnly `
	-ExplodeDeep `
	-OutputPath "C:\Exports\\"

# Replay mode: Filter specific AgentId from previously exported data
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-RAWInputCSV "C:\Exports\\" `
	-AgentId "CopilotStudio.Declarative.a1b2c3d4" `
	-OutputPath "C:\Exports\\"

# Combine with deep explosion for maximum analysis detail
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentsOnly `
	-ExplodeDeep `
	-OutputPath "C:\Exports\\"
```

</details>

### How Agent Filtering Works

<details>
<summary>🔍 Show Technical Details</summary>

1. **Pre-Parsing Phase**:
   - In replay mode, JSON audit data is pre-parsed for all records
   - Enables fast filtering without repeated JSON parsing

2. **Agent Filtering Phase**:
   - Each record's `ParsedAuditData.AgentId` field is evaluated
   - `-AgentsOnly`: Includes any record where `AgentId` is present and non-empty
   - `-AgentId`: Includes records where `AgentId` matches one of the specified values (case-insensitive)
   - Non-matching records are excluded from output

3. **Output Generation**:
   - Only filtered records proceed to explosion/flattening
   - Summary includes pre/post filter counts and retention rate
   - Log file documents exact filter criteria applied

</details>

### Agent Filtering Performance

<details>
<summary>📊 Show Performance Metrics</summary>

**Live Query Mode:**
- Agent filtering occurs server-side via activity type selection
- Use standard Copilot activity types (CopilotInteraction, etc.)
- Agent switches apply additional post-retrieval filtering

**Replay Mode:**
- Processes up to ~5,000 records/second during filtering
- Progress bar shows pre-parsing and filtering phases separately
- Example: 367,796 records → 20,240 agent records in ~80 seconds total

**Memory Usage:**
- Low overhead: only filtered records remain in memory
- Safe for processing multi-million record datasets
- Ideal for post-processing large audit exports

</details>

### Agent Field Reference

The `AgentId` field appears in Copilot audit records and identifies the specific agent involved in the interaction:

**Common Agent Patterns:**
- `CopilotStudio.Declarative.<GUID>` - Declarative agents created in Copilot Studio
- `CustomAgent.<name>` - Custom-built agents
- Copilot-specific identifiers for built-in agents

**Output Columns:**
- `AgentId` - The unique agent identifier
- `AgentName` - Human-readable agent name (if available)
- `AppIdentity` - Application context for the agent
- Plus all standard Copilot usage fields

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## User and Group Filtering

<details>
<summary>👥 View User & Group Filtering Guide (Click to Expand)</summary>

### Overview

User and Group Filtering enables targeted extraction of audit records for specific users or distribution groups from your Purview audit logs. This feature is essential for investigating individual user activity, analyzing group adoption patterns, or conducting compliance audits for specific teams.

**Why Use User and Group Filtering?**

- **Efficiency**: In live mode, reduces data retrieved from Purview server-side; in replay mode, filters locally
- **User-Specific Investigations**: Track a specific user's Copilot interactions for security reviews, compliance audits, or support troubleshooting
- **Group Analysis**: Automatically expand distribution groups to monitor department-wide or team-level adoption
- **Performance**: Reduce processing time and data transfer by targeting specific users
- **Compliance**: Isolate user activity for regulatory audits, eDiscovery requests, or data governance

### Modes and Behavior

**User Filtering (`-UserIds`):**
- **Graph API Mode (Default):** Client-side filtering after retrieval (filters all retrieved records)
- **EOM Mode (`-UseEOM`):** Server-side filtering via `Search-UnifiedAuditLog -UserIds`
- **Replay Mode (`-RAWInputCSV`):** Client-side filtering from parsed AuditData JSON
- Available in all modes

**Group Filtering (`-GroupNames`):**
- **⚠️ EOM Mode Only:** Requires `-UseEOM` parameter
- Groups are expanded to member emails using `Get-DistributionGroupMember` before querying
- NOT supported in Graph API mode (default) or Replay mode
- Requires Exchange Online authentication for group expansion

### When to Use User/Group Filtering

**Use `-UserIds`** when:
- Investigating specific user(s) Copilot activity
- Conducting security reviews or compliance audits for individual accounts
- Troubleshooting user-reported issues
- Analyzing power users or early adopters
- Post-processing existing exports (replay mode)
- Works with both Graph API (default) and EOM mode

**Use `-GroupNames`** when:
- Analyzing department-wide or team-level adoption (**EOM mode only - requires `-UseEOM`**)
- Tracking Copilot usage across organizational units
- Compliance audits for specific business groups
- ROI analysis by functional group

### User and Group Filtering Examples

<details>
<summary>💻 Show User and Group Filtering Examples</summary>

```powershell
# Filter for a single user (live mode)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "john.doe@contoso.com" `
	-OutputPath "C:\Exports\\"

# Filter for multiple users (live mode)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "john.doe@contoso.com","jane.smith@contoso.com","bob.jones@contoso.com" `
	-OutputPath "C:\Exports\\"

# Filter for a distribution group (EOM mode only - requires -UseEOM)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UseEOM `
	-GroupNames "Engineering-Team@contoso.com" `
	-OutputPath "C:\Exports\\"

# Filter for multiple groups (EOM mode only - requires -UseEOM)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UseEOM `
	-GroupNames "Sales@contoso.com","Marketing@contoso.com" `
	-OutputPath "C:\Exports\\"

# Combine UserIds and GroupNames (EOM mode only - requires -UseEOM)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UseEOM `
	-UserIds "ceo@contoso.com","cfo@contoso.com" `
	-GroupNames "ExecutiveTeam@contoso.com" `
	-OutputPath "C:\Exports\\"

# Replay mode: Filter users from previously exported data
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-RAWInputCSV "C:\Exports\\" `
	-UserIds "john.doe@contoso.com","jane.smith@contoso.com" `
	-OutputPath "C:\Exports\\"

# Combine with agent filtering for targeted analysis
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "poweruser@contoso.com" `
	-AgentsOnly `
	-ExplodeDeep `
	-OutputPath "C:\Exports\\"
```

</details>

### How User and Group Filtering Works

<details>
<summary>🔍 Show Technical Details</summary>

**Live Mode Process:**

1. **Group Expansion** (if `-GroupNames` used):
   - Connects to Exchange Online using existing authentication
   - Calls `Get-DistributionGroupMember` for each group
   - Extracts `PrimarySmtpAddress` from each member
   - Combines with any `-UserIds` provided
   - Deduplicates final user list

2. **Server-Side Filtering**:
   - Passes expanded user list to `Search-UnifiedAuditLog -UserIds` parameter
   - Purview server filters records matching any UserIds
   - Only matching records are transmitted to client
   - Highly efficient: reduces network transfer and processing time

3. **Progress Tracking**:
   - Shows user/group expansion status
   - Displays target user count
   - Progress bar reflects retrieval and processing phases

**Replay Mode Process:**

1. **Pre-Parsing Phase**:
   - Parses AuditData JSON for all records
   - Extracts `UserId` field into `_ParsedAuditData` object
   - Enables fast filtering without repeated JSON parsing

2. **User Filtering Phase**:
   - Creates hashtable lookup of target users (case-insensitive)
   - Evaluates each record's `_ParsedAuditData.UserId`
   - Includes records where UserId matches target list
   - Non-matching records excluded from output

3. **Output Generation**:
   - Only filtered records proceed to explosion/flattening
   - Summary includes pre/post filter counts and retention rate
   - Log file documents exact filter criteria applied

</details>

### User and Group Filtering Performance

<details>
<summary>📊 Show Performance Metrics</summary>

**Live Query Mode (Server-Side):**
- Extremely efficient: filtering happens at Microsoft 365 Purview
- Only matching records transmitted over network
- No local processing overhead for non-matching records
- Group expansion adds ~2-5 seconds per group (one-time cost)
- **Recommended** when targeting specific users/groups

**Replay Mode (Client-Side):**
- Memory efficient: only filtered records retained
- Useful for post-processing large exports

</details>

### User Field Reference

The `UserId` field appears in all Copilot audit records and identifies the user who performed the activity:

**Format:**
- Typically: `user@domain.com` (User Principal Name or email)
- Case-insensitive matching

**Output Columns:**
- `UserId` - The user's email/UPN
- Plus all standard Copilot usage fields (Operation, ClientIP, AppName, etc.)

### Important Notes

- **Replay Mode Limitation**: `-GroupNames` parameter blocked in replay mode (displays error)
- **Authentication**: Group expansion requires Exchange Online authentication in live mode
- **Deduplication**: When combining `-UserIds` and `-GroupNames`, duplicates are automatically removed
- **Case Sensitivity**: User email matching is case-insensitive
- **Filter Combinations**: Can combine with `-AgentsOnly`, `-AgentId`, `-ExcludeAgents`, `-PromptFilter`

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Prompt and Response Filtering

<details>
<summary>💬 View Prompt & Response Filtering Guide (Click to Expand)</summary>

### Overview

Prompt and Response Filtering (`-PromptFilter`) enables targeted extraction of specific conversation turn types from Copilot audit logs based on the `Message_isPrompt` property. This feature is essential for analyzing prompt engineering, conversation patterns, and user interaction behaviors.

**Why Use PromptFilter?**

- **Prompt Analysis**: Isolate user prompts to analyze query patterns, intent, and demand
- **Response Analysis**: Extract Copilot responses for content analysis, latency measurement, and tracking acceptance rates (combine with prompts via ThreadId for full conversation context)
- **Conversation Segmentation**: Separate prompts from responses for training data or analysis pipelines
- **Data Reduction**: Reduce output size by 50%+ when only prompts or responses are needed
- **Performance**: Two-stage filtering optimizes processing (pre-filter records + conversation-level filtering during explosion)

### PromptFilter Options

| Option | Description | Message_isPrompt Value | Use Case |
|--------|-------------|------------------------|----------|
| `Prompt` | Only prompts (user inputs) | `True` | Analyze what users are asking |
| `Response` | Only responses (Copilot outputs) | `False` | Extract response content (combine with prompts via ThreadId for quality evaluation) |
| `Both` | Both prompts and responses | `True` or `False` | Full conversation analysis |
| `Null` | Conversation turns with no isPrompt value | `null` or empty | Debug malformed data |

### PromptFilter Examples

<details>
<summary>💻 Show PromptFilter Examples</summary>

```powershell
# Export only user prompts
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExplodeArrays `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Export only Copilot responses
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExplodeArrays `
	-PromptFilter Response `
	-OutputPath "C:\Exports\\"

# Combine with agent filtering: Agent prompts only
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExplodeArrays `
	-AgentsOnly `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Replay mode: Filter prompts from previous export
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-RAWInputCSV "C:\Exports\\" `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"
```

</details>

### How PromptFilter Works

<details>
<summary>🔍 Show Two-Stage Filtering Technical Details</summary>

**Two-Stage Filtering for Optimal Performance:**

1. **Stage 1 (Record-level Filter)**: Filters entire audit records BEFORE explosion
   - **Always applies** when PromptFilter is used
   - Analyzes each record's Messages array (conversation turns)
   - Categorizes records: Mixed (prompts+responses), Prompt-only, Response-only, No conversation data
   - Filters out records without matching conversation turns
   - Typical reduction: 10-15% of records filtered before explosion
   - In non-explosion mode (live query without explosion switches), this is the only filtering stage

2. **Stage 2 (Conversation-level Filter)**: Filters individual prompts/responses DURING explosion
   - **Only applies during explosion** (when using `-ExplodeArrays`, `-ExplodeDeep`, or `-RAWInputCSV` replay mode)
   - Filters individual conversation turns (prompts/responses) within each record
   - Only outputs rows for conversation turns matching the filter
   - Prevents blank `Message_isPrompt` values in output
   - Not used in standard 1:1 mode (live query without explosion switches)

**PromptFilter Behavior by Option:**

- **Prompt**: Stage 1 keeps records with at least one prompt; Stage 2 (if explosion enabled) outputs only prompt conversation turns
- **Response**: Stage 1 keeps records with at least one response; Stage 2 (if explosion enabled) outputs only response conversation turns
- **Both**: Stage 1 keeps records with at least one conversation turn having explicit isPrompt value; Stage 2 (if explosion enabled) outputs conversation turns with defined isPrompt values
- **Null**: Stage 1 keeps records with null isPrompt conversation turns; Stage 2 (if explosion enabled) outputs only conversation turns with null isPrompt

</details>

### PromptFilter + Agent Filtering Combination

<details>
<summary>💻 Show PromptFilter + Agent Examples</summary>

```powershell
# Agent interactions only, prompts only
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExplodeArrays `
	-AgentsOnly `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Non-agent interactions only, prompts only
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExplodeArrays `
	-ExcludeAgents `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"
```

</details>

### Performance Metrics

<details>
<summary>📊 Show PromptFilter Performance Metrics</summary>

The script provides detailed PromptFilter metrics in the summary:

- **Record-level**: Records before/after filter, retention rate
- **Record type breakdown**: Mixed, Prompt-only, Response-only, No conversation data (with percentages)
- **Conversation-level**: Conversation turns before/after filter, retention rate
- **Processing time**: Stage 1 pre-filter execution time

</details>

### Output Schema

When using PromptFilter with `-ExplodeArrays` or `-ExplodeDeep`, the `Message_isPrompt` column will contain:

- **PromptFilter=Prompt**: All rows have `Message_isPrompt = True`
- **PromptFilter=Response**: All rows have `Message_isPrompt = False`
- **PromptFilter=Both**: Mix of `True` and `False` values
- **PromptFilter=Null**: All rows have blank `Message_isPrompt` values

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Combining Filters

<details>
<summary>🔗 View Combined Filtering Guide (Click to Expand)</summary>

### Overview

All filtering switches (`-UserIds`, `-GroupNames`, `-AgentsOnly`, `-AgentId`, `-ExcludeAgents`, `-PromptFilter`) can be combined for highly targeted data extraction. This enables powerful use cases like analyzing specific users' interactions with agents, or isolating conversation patterns for specific teams.

**Filter Application Order:**

Filters are applied in a consistent sequence across both live and replay modes:

**BOTH MODES (Live & Replay):**
1. **User/Group Filtering** - Server-side in EOM mode (via `Search-UnifiedAuditLog -UserIds`), client-side in Graph API mode and replay mode (parsing UserId from JSON)
2. **Agent Filtering** - Filters by agent presence or specific agent IDs (AgentsOnly, AgentId, ExcludeAgents)
3. **Prompt Filtering** - Filters conversation turns by isPrompt property during explosion

**Performance Note:** User/Group filtering performance varies by mode. EOM mode (`-UseEOM`) offers server-side filtering which is highly efficient. Graph API mode (default) and replay mode use client-side filtering, which retrieves all records first then filters.

### Two-Filter Combinations

#### User + Agent Filtering

**Use Case:** Analyze specific user(s) interactions with Copilot agents

**Example Scenario:** "Show me all agent usage by our power users"

<details>
<summary>💻 Show User + Agent Filtering Examples</summary>

```powershell
# Single power user with any agents
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "poweruser@contoso.com" `
	-AgentsOnly `
	-OutputPath "C:\Exports\\"

# Executive team with specific declarative agent
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-GroupNames "Executive Team" `
	-AgentId "CopilotStudio.Declarative.ExecutiveAssistant" `
	-OutputPath "C:\Exports\\"
```

</details>

**Benefits:**
- Server-side user filtering reduces data transfer (live mode)
- Agent filter removes non-agent interactions
- Focused dataset for agent adoption analysis per user/team

---

#### User + PromptFilter

**Use Case:** Focus on conversation patterns (prompts/responses) for specific users

**Example Scenario:** "Show me only the questions asked by the sales team"

<details>
<summary>💻 Show User + PromptFilter Examples</summary>

```powershell
# Sales team prompts only (removes responses and resource-only rows)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-GroupNames "Sales Team" `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Individual user's full conversations (prompts + responses, no resource rows)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "analyst@contoso.com" `
	-PromptFilter Both `
	-OutputPath "C:\Exports\\"
```

</details>

**Benefits:**
- Removes resource-only explosion rows (cleaner message-focused dataset)
- Typical reduction: 15-20% smaller file when using `PromptFilter Both`
- Ideal for conversation analysis, prompt engineering studies, token usage

---

#### Agent + PromptFilter

**Use Case:** Analyze agent conversation quality and prompt engineering effectiveness

**Example Scenario:** "Show me all prompts sent to our custom sales agent"

<details>
<summary>💻 Show Agent + PromptFilter Examples</summary>

```powershell
# All prompts sent to a specific agent
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentId "CopilotStudio.Declarative.SalesAssistant" `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Agent responses only (for quality/latency analysis)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentsOnly `
	-PromptFilter Response `
	-OutputPath "C:\Exports\\"
```

</details>

**Benefits:**
- Focus on agent-specific conversation patterns
- Analyze prompt engineering effectiveness per agent
- Measure agent response quality and latency

---

### Three-Filter Combination

#### User + Agent + PromptFilter

**Use Case:** Deep-dive conversation analysis for specific users with specific agents

**Example Scenario:** "Show me all questions the marketing team asked our content creation agent"

<details>
<summary>💻 Show Three-Filter Combination Examples</summary>

```powershell
# Marketing team prompts to content agent
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-GroupNames "Marketing Team" `
	-AgentId "ContentCreation.Agent" `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Executive team's full conversations with all agents
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-GroupNames "Executive Leadership" `
	-AgentsOnly `
	-PromptFilter Both `
	-ExplodeDeep `
	-OutputPath "C:\Exports\\"
```

</details>

**Benefits:**
- **Maximum precision:** Combines server-side user filtering, agent filtering, and conversation turn filtering
- **Optimal performance:** Server-side reduces data transfer (live mode)
- **Clean dataset:** Only relevant conversation turns for the targeted user/agent combination
- **Typical reduction:** 95%+ of original data filtered out for highly focused analysis

---

### Replay Mode Combinations

All filter combinations work in replay mode **except `-GroupNames`** (requires authentication).

<details>
<summary>💻 Show Replay Mode Combination Examples</summary>

```powershell
# Replay: User + Agent + PromptFilter
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-RAWInputCSV "C:\Exports\\" `
	-UserIds "poweruser@contoso.com","analyst@contoso.com" `
	-AgentsOnly `
	-PromptFilter Both `
	-OutputPath "C:\Exports\\"

# Replay: User + PromptFilter (client-side user filtering from JSON)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-RAWInputCSV "C:\Exports\\" `
	-UserIds "exec@contoso.com" `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"
```

</details>

**Note:** Use `-UserIds` with explicit email addresses instead of `-GroupNames` in replay mode.

---

### Common Use Cases

<details>
<summary>📊 Show Use Case → Filter Combinations Table</summary>

| Use Case | Filters | Example Output |
|----------|---------|----------------|
| **Power user agent adoption** | User + Agent | All agent interactions for specific power users |
| **Team prompt analysis** | Group + PromptFilter | All questions asked by a department |
| **Agent quality review** | Agent + PromptFilter | Prompts and responses for a specific agent |
| **User conversation focus** | User + PromptFilter | Clean message dataset without resource rows |
| **Targeted deep-dive** | User + Agent + PromptFilter | Specific users' questions to specific agents |
| **Executive summary** | Group + Agent + PromptFilter | Leadership team's agent conversations |

</details>

### Performance Tips

- **EOM Mode (`-UseEOM`):** User/group filtering is server-side (highly efficient) - best for large datasets when filtering by users
- **Graph API Mode (Default):** User filtering is client-side - retrieves all records then filters; consider EOM mode for user-specific queries
- **Replay Mode:** All filtering is client-side - expect longer processing times
- **PromptFilter Impact:** Reduces output rows by 15-20% when using `Both` (removes resource-only rows)
- **Three-Filter Combo:** Can reduce final output by 95%+ for highly targeted analysis

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## DSPM for AI

<details>
<summary>🔐 View DSPM for AI Guide (Click to Expand)</summary>

### Overview

**Data Security Posture Management (DSPM) for AI** enables comprehensive monitoring of AI application interactions across your Microsoft 365 environment. Version 1.8.0 introduces dedicated switches to capture DSPM-specific audit data for governance, compliance, and security analysis.

**What is DSPM for AI?**

DSPM for AI provides visibility into:
- Connected AI application interactions (Microsoft 365 Copilot integrations)
- Team Copilot interactions (collaborative AI scenarios)
- Third-party AI application interactions (external AI services)
- Prompt and response content analysis (with elevated permissions)

**Permission Requirements:**

- **DSPM Activity Types:** Standard audit log permissions (View-Only Audit Logs or Audit Logs role) - **no additional permissions required**
- **Cost:** PAYG billing applies only to third-party AI app records in `AIAppInteraction` activity type

**Key Use Cases:**

- **Compliance Monitoring:** Track AI usage for regulatory requirements (GDPR, HIPAA, SOX)
- **Security Analysis:** Identify potentially risky AI interactions or data exposures
- **Governance Reporting:** Demonstrate AI usage controls to auditors and stakeholders
- **Data Flow Mapping:** Understand how data moves between your organization and AI services
- **Risk Assessment:** Identify which AI applications access sensitive data

---

### DSPM Activity Types

#### MIXED FREE/PAYG Tier Activities

The following activity types include both FREE and PAYG records depending on the source:

**ConnectedAIAppInteraction**
- Microsoft 365 Copilot integrations with external AI services
- Copilot extensibility interactions
- AI plugins and connectors within M365 ecosystem
- **FREE:** Microsoft AI apps/agents
- **PAYG:** Third-party AI apps/agents
- **Enabled by:** `-IncludeDSPMForAI`

**AIInteraction**
- AI interactions (currently Microsoft platforms only)
- Microsoft AI service interactions
- **FREE:** Microsoft AI apps/agents
- **PAYG:** Third-party AI apps/agents (if applicable)
- **Enabled by:** `-IncludeDSPMForAI`

#### PAYG (Pay-As-You-Go) Tier Activities

The following activity type requires extended audit retention and incurs usage-based billing:

**AIAppInteraction**
- Third-party AI application interactions
- External AI service connections outside M365 ecosystem
- Non-Microsoft AI platforms and tools
- **PAYG only:** Third-party AI apps/agents via network DLP
- **Enabled by:** `-IncludeDSPMForAI`
- **Cost:** Approximately $0.0132 per 1,000 records (subject to change, verify current pricing)
- **Billing Alert:** Script displays information about potential PAYG costs before proceeding

---

### DSPM Parameters Deep Dive

#### `-IncludeDSPMForAI` (MIXED FREE/PAYG Tier)

**Behavior:**
- Adds `ConnectedAIAppInteraction`, `AIInteraction`, and `AIAppInteraction` to your activity types list
- **Additive logic:** Does NOT replace existing `-ActivityTypes`, adds to them
- Output files automatically include `DSPM` in filename
- **Billing:** MIXED FREE/PAYG for `ConnectedAIAppInteraction` and `AIInteraction`; PAYG only for `AIAppInteraction`
- **PAYG billing only applies to third-party AI apps/agents, never to Microsoft AI apps/agents**

**Example:**

<details>
<summary>💻 Show DSPM for AI Examples</summary>

```powershell
# Basic DSPM for AI (includes all 3 activity types)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeDSPMForAI

# DSPM with existing activity types (additive)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ActivityTypes MessageSent,FileAccessed `
	-IncludeDSPMForAI
# Result: MessageSent + FileAccessed + ConnectedAIAppInteraction
```

</details>

---

#### `-DSPMOutputMode`

**Valid Values:** `Combined` (default), `Separate`

**Combined Mode (Default):**
- All activity types exported to single output file
- Filename includes `DSPM` identifier: `Purview_DSPM_Export_20251030_143022.csv`

**Separate Mode:**
- DSPM activity types exported to dedicated `*_DSPM_*.csv` file
- Standard activity types exported to separate file without `DSPM` identifier
- Useful for compliance workflows requiring isolated DSPM data

<details>
<summary>💻 Show DSPMOutputMode Examples</summary>

```powershell
# Combined mode (default)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeDSPMForAI
# Output: Purview_DSPM_Export_20251030_143022.csv (all activities)

# Separate mode
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ActivityTypes MessageSent,FileAccessed `
	-IncludeDSPMForAI `
	-DSPMOutputMode Separate
# Output 1: Purview_DSPM_Export_20251030_143022.csv (DSPM activities only)
# Output 2: Purview_Export_20251030_143022.csv (standard activities only)
```

</details>

---

### File Naming with DSPM

**Automatic DSPM Detection:**

The script automatically detects when DSPM parameters are active and adjusts file naming:

| Scenario | Output Filename Pattern |
|----------|------------------------|
| Standard query (no DSPM) | `Purview_Export_20251030_143022.csv` or `.xlsx` |
| DSPM parameters enabled | `Purview_DSPM_Export_20251030_143022.csv` or `.xlsx` |

**Detection Logic:**

Script considers DSPM active when:
- `-IncludeDSPMForAI` is specified

---

### Advanced DSPM Scenarios

#### Comprehensive DSPM Audit

<details>
<summary>💻 Show Comprehensive DSPM Example</summary>

```powershell
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeDSPMForAI `
	-Force `
	-ExplodeDeep
# Result: All DSPM activities (ConnectedAIAppInteraction, AIInteraction, AIAppInteraction) with deep schema expansion
```

</details>

#### DSPM with User Filtering

<details>
<summary>💻 Show DSPM + User Filtering Example</summary>

```powershell
# Audit specific user's AI interactions
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "executive@contoso.com" `
	-IncludeDSPMForAI

# Audit executive team's DSPM AI usage
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-GroupNames "Executive Team" `
	-IncludeDSPMForAI `
	-Force `
	-ExcludeCopilotInteraction
```

</details>

#### DSPM with Excel Export

<details>
<summary>💻 Show DSPM + Excel Example</summary>

```powershell
# DSPM data in Excel workbook
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeDSPMForAI `
	-Force `
	-ExportWorkbook
# Output: Purview_DSPM_Export_20251030_143022.xlsx
# Tabs: ConnectedAIAppInteraction, AIInteraction, AIAppInteraction, CopilotInteraction
```

</details>

---

### DSPM Best Practices

**Cost Management:**
- Start with `-IncludeDSPMForAI` to understand data volumes across all three activity types
- Test queries with narrow date ranges first
- Use `-Force` in automation to avoid interactive prompts
- Monitor actual costs through Microsoft billing portal
- PAYG billing only applies to third-party AI app audit records

**Compliance Workflows:**
- Use `-DSPMOutputMode Separate` to isolate DSPM data for auditors
- Combine with `-ExcludeCopilotInteraction` for pure DSPM datasets

**Performance:**
- DSPM activity types query the same API as standard activities
- No performance penalty for enabling DSPM switches
- Use standard performance tuning parameters (`-BlockHours`, `-PacingMs`) as needed

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Excel Export

<details>
<summary>📊 View Excel Export Guide (Click to Expand)</summary>

### Overview

**Excel Export** functionality in version 1.8.0 enables direct export to `.xlsx` format with professional formatting, making audit data immediately consumable by business stakeholders, executives, and reporting tools.

**Why Excel Export?**

- **Business-Ready Format:** No CSV-to-Excel conversion needed
- **Professional Formatting:** Auto-sized columns, frozen headers, bold titles
- **Multi-Tab Organization:** Separate tabs per activity type for easy navigation
- **Incremental Builds:** Append new data to existing workbooks across multiple runs
- **Safer Number Handling:** Prevents Excel's auto-conversion of IDs to scientific notation
- **Stakeholder Distribution:** Share formatted reports directly with non-technical audiences

**Prerequisites:**

- **ImportExcel Module:** PowerShell module for Excel file manipulation
- **Auto-Installation:** Script automatically installs module if missing (requires PowerShell Gallery access)
- **No Excel Required:** Does NOT require Microsoft Excel to be installed on the machine

---

### Export Modes

#### Multi-Tab Mode (Default)

**Behavior:**
- Creates one tab per activity type
- Tab names match activity type: `CopilotInteraction`, `MessageSent`, `FileAccessed`
- Default mode when `-ExportWorkbook` is specified without `-CombineOutput`

**File Naming:**
- Standard: `Purview_Export_<timestamp>.xlsx`
- With DSPM (`-IncludeDSPMForAI`): `Purview_DSPM_Export_<timestamp>.xlsx`

**Use Cases:**
- Multi-activity queries where separate analysis per type is needed
- Reporting to different teams (each team gets their relevant tab)
- Easier filtering and pivot tables per activity type

<details>
<summary>💻 Show Multi-Tab Mode Examples</summary>

```powershell
# Basic multi-tab export (default)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExportWorkbook
# Output: Purview_Export_20251030_143022.xlsx
# Tabs: CopilotInteraction

# Multi-activity multi-tab export
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ActivityTypes CopilotInteraction,MessageSent,FileAccessed `
	-ExportWorkbook
# Output: Purview_Export_20251030_143022.xlsx
# Tabs: CopilotInteraction, MessageSent, FileAccessed

# DSPM multi-tab export
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeDSPMForAI `
	-ExportWorkbook
# Output: Purview_DSPM_Export_20251030_143022.xlsx
# Tabs: CopilotInteraction, ConnectedAIAppInteraction,AIInteraction, AIAppInteraction
```

</details>

---

#### Combined Mode (Single Tab)

**Behavior:**
- All activity types combined into single tab
- Tab name: `Combined_Purview_Data` or `Combined_Purview_DSPM_Data` (with DSPM)
- Enabled by adding `-CombineOutput` parameter

**File Naming:**
- Standard: `Purview_Audit_CombinedUsageActivity_<timestamp>.xlsx`
- With Entra enrichment (`-IncludeUserInfo`): `Purview_Audit_CombinedUsageActivity_EntraUsers_MAClicensing_<timestamp>.xlsx`
- Tab name: `CombinedUsageActivity` (with `EntraUsers_MAClicensing` tab if `-IncludeUserInfo` used)

**Use Cases:**
- Single activity type queries (no benefit to multiple tabs)
- Cross-activity analysis where combined dataset is preferred
- Smaller exports where tab organization isn't needed

<details>
<summary>💻 Show Combined Mode Examples</summary>

```powershell
# Single-tab export (combined mode)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExportWorkbook `
	-CombineOutput
# Output: Purview_Audit_CombinedUsageActivity_<timestamp>.xlsx
# Tab: CombinedUsageActivity

# DSPM combined export
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeDSPMForAI `
	-ExportWorkbook `
	-CombineOutput
# Output: Purview_Audit_CombinedUsageActivity_<timestamp>.xlsx
# Tab: CombinedUsageActivity (DSPM activity types included)
```

</details>

---

### Excel Formatting Features

Every Excel export includes professional formatting:

| Feature | Behavior | Benefit |
|---------|----------|---------|
| **AutoSize** | Columns auto-sized to content width | Readable without manual resizing |
| **FreezeTopRow** | First row frozen during scroll | Headers always visible |
| **BoldTopRow** | Header row in bold font | Clear visual separation |
| **NoNumberConversion** | All columns treated as text (`@` format) | Prevents ID corruption (e.g., GUIDs) |

**Number Conversion Prevention:**

Excel's default behavior converts values like `1E10` or `00123` to scientific notation or removes leading zeros. The script applies text formatting (`'*'` = all columns) to prevent this, ensuring data integrity for:
- User IDs
- Session IDs
- Agent IDs (GUIDs)
- Timestamps
- Any numeric-looking text fields

---

### ImportExcel Module Management

**Auto-Installation:**

If `ImportExcel` module not found, script:
1. Displays module information and purpose
2. Prompts for installation confirmation
3. Installs from PowerShell Gallery (requires internet)
4. Imports module automatically

**Manual Installation:**

```powershell
# Install ImportExcel module manually
Install-Module -Name ImportExcel -Scope CurrentUser -Force

# Verify installation
Get-Module -Name ImportExcel -ListAvailable
```

**Fallback Behavior:**

If installation fails or is declined:
- Script falls back to CSV export
- Displays warning message
- Continues execution with CSV output

---

### Advanced Excel Scenarios

#### Incremental Weekly Reports

<details>
<summary>💻 Show Incremental Report Example</summary>

```powershell
# Monday: Week 1 initial export
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-06 `
	-EndDate 2025-10-13 `
	-ExportWorkbook `
	-OutputPath "C:\Reports\\"

# Monday: Week 2 append
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-13 `
	-EndDate 2025-10-20 `
	-ExportWorkbook `
	-AppendFile `
	-OutputPath "C:\Reports\\"

# Result: Single workbook with 2 weeks of data
```

</details>

#### DSPM Excel Reports

<details>
<summary>💻 Show DSPM Excel Example</summary>

```powershell
# Comprehensive DSPM report with Excel
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeDSPMForAI `
	-IncludeThirdPartyAI `
	-Force `
	-ExportWorkbook `
	-ExplodeDeep
# Output: Purview_DSPM_Export_20251030_143022.xlsx
# Tabs: CopilotInteraction, ConnectedAIAppInteraction, AIInteraction, AIAppInteraction
# Formatting: All tabs have frozen headers, bold titles, auto-sized columns
```

</details>

#### Multi-Activity Excel with Filtering

<details>
<summary>💻 Show Filtered Excel Example</summary>

```powershell
# Executive team activity across multiple types
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-GroupNames "Executive Team" `
	-ActivityTypes CopilotInteraction,MessageSent,FileAccessed `
	-ExportWorkbook `
	-UseEOM
# Output: Purview_Export_20251030_143022.xlsx
# Tabs: CopilotInteraction (execs only), MessageSent (execs only), FileAccessed (execs only)
```

</details>

---

### Excel Export Best Practices

**Performance:**
- Excel export adds minimal overhead (post-processing CSV → Excel conversion)
- Use same performance tuning parameters as CSV mode
- Large exports (>100K rows) may take slightly longer due to Excel formatting

**File Management:**
- Use descriptive `-AppendFile` names with consistent naming conventions
- Consider date-based folder structure for long-term archival

**Schema Consistency:**
- Use consistent parameters across AppendFile runs
- Avoid mixing `-ExplodeArrays` and `-ExplodeDeep` in same workbook
- Schema mismatches create timestamped duplicate tabs (safe but increases file size)

**Automation:**
- Excel export works seamlessly in scheduled tasks
- No Microsoft Excel installation required on server
- ImportExcel module installation may require one-time interactive approval

**Distribution:**
- Excel workbooks are business-ready for sharing
- No post-processing needed for stakeholder reports
- Consider file size limits for email distribution (>25 MB may require file share)

---

### File Naming Convention Reference

**Complete naming patterns for all output scenarios:**

| Export Mode | Parameters | Output File Name | Additional Files |
|-------------|-----------|------------------|------------------|
| **Excel Multi-Tab** | `-ExportWorkbook` | `Purview_Export_<timestamp>.xlsx` | — |
| **Excel Multi-Tab (DSPM)** | `-ExportWorkbook -IncludeDSPMForAI` | `Purview_DSPM_Export_<timestamp>.xlsx` | — |
| **Excel Combined** | `-ExportWorkbook -CombineOutput` | `Purview_Audit_CombinedUsageActivity_<timestamp>.xlsx` | — |
| **Excel Combined + Entra** | `-ExportWorkbook -CombineOutput -IncludeUserInfo` | `Purview_Audit_CombinedUsageActivity_<timestamp>.xlsx` | `EntraUsers_MAClicensing` tab embedded |
| **CSV Multi-File** | (default, no `-CombineOutput`) | `<ActivityType>_<timestamp>.csv` (per activity) | `EntraUsers_MAClicensing_<timestamp>.csv` (if `-IncludeUserInfo`) |
| **CSV Combined** | `-CombineOutput` | `Purview_Audit_CombinedUsageActivity_<timestamp>.csv` | `EntraUsers_MAClicensing_<timestamp>.csv` (if `-IncludeUserInfo`) |

**Timestamp Format:** `YYYYMMDD_HHMMSS` (e.g., `20251107_143022`)

**EntraUsers File Behavior:**
- **CSV Mode:** Always separate file `EntraUsers_MAClicensing_<timestamp>.csv` when `-IncludeUserInfo` used
- **Excel Mode:** Embedded as `EntraUsers_MAClicensing` tab in workbook when `-IncludeUserInfo` used (no separate file)
- **Graph API Requirement:** `-IncludeUserInfo` requires Graph API mode (not compatible with `-UseEOM`)

**Query Names in Purview:**

When the script creates queries in Microsoft Purview (parallel mode), they appear with descriptive names:
- **Format:** `PAX_Query_<StartDate>_<StartTime>-<EndDate>_<EndTime>_PartX/Total`
- **Example:** `PAX_Query_20241101_0000-20241101_0100_Part27/134`

This naming convention helps you:
- Find queries in the Purview audit log search interface
- Track query status and completion
- Correlate script output with Purview UI for troubleshooting

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Incremental Data Collection (AppendFile)

<details open>
<summary>Overview</summary>

The **`-AppendFile` parameter** enables incremental dataset building across multiple script executions. This enterprise-critical feature allows organizations to:

- **Build continuous audit trails** spanning weeks or months without recreating entire datasets
- **Combine multiple time periods** into single comprehensive reports
- **Transform and append offline data** using replay mode (`-RAWInputCSV`)
- **Maintain consistent naming** for scheduled reports and automation workflows

**Key Benefits:**
- **Zero data loss:** Safe header validation prevents schema conflicts
- **Flexible workflows:** Works with CSV and Excel, live queries and offline replay
- **Enterprise-ready:** Supports large-scale audit collection strategies used by Fortune 500 organizations
- **Time-saving:** Eliminates manual copy/paste operations across multiple exports

</details>

---

### How AppendFile Works

#### CSV Append Mode

**Process:**
1. **File Resolution:** Uses `-AppendFile` path (full path or relative filename in `-OutputPath` directory)
2. **Pre-Flight Check:** Validates file exists and is accessible (file lock detection, permission checks)
3. **Header Validation:** Reads first row of existing CSV and compares against new data headers
4. **Exact Match Required:** Column names must match exactly (case-sensitive, same order)
5. **Mismatch Handling:** Script exits with error showing detailed diff (missing columns, extra columns, order differences)
6. **Append Operation:** Opens file in append mode, writes new rows without duplicate header

**Safety Features:**
- **Never overwrites:** Exits cleanly if headers don't match (prevents data corruption)
- **Detailed diagnostics:** Shows exact column differences when validation fails
- **File lock detection:** Identifies if file is open in Excel or another process

#### Excel Append Mode

**Process:**
1. **File Resolution:** Locates existing workbook by `-AppendFile` path (full path or filename in `-OutputPath`)
2. **Pre-Flight Check:** Validates file accessibility and Excel format integrity
3. **Sheet Discovery:** Reads all existing worksheet names
4. **Header Validation:** Compares new data headers against each existing tab's first row
5. **Matching Headers → Direct Append:** Appends rows to existing tabs (e.g., adds Day 2 data to existing `CopilotInteraction` tab)
6. **Mismatched Headers → Safe Mode:** Creates timestamped duplicate tabs to preserve both datasets

**Safety Features:**
- **Never overwrites:** Mismatched schemas create new timestamped tabs (preserves original data)
- **Multi-tab intelligence:** Handles multiple activity types independently
- **DSPM naming awareness:** Recognizes tab naming variations (`CopilotInteraction` vs `DSPM_CopilotInteraction`)
- **Encrypted file guidance:** Provides specific troubleshooting for OneDrive/sensitivity labeled files

**Schema Mismatch Example:**
```
Existing tab: CopilotInteraction (10 columns, no deep explosion)
New data: CopilotInteraction (25 columns, with -ExplodeDeep)
Result: 
  - Original tab "CopilotInteraction" preserved
  - New tab "CopilotInteraction_20251110_143022" created with new schema
```

---

### File Path Resolution

| Scenario | `-AppendFile` Value | `-OutputPath` Value | Final Path Used |
|----------|---------------------|---------------------|-----------------|
| **Full path** | `"C:\Data\Report.xlsx"` | (any value) | `C:\Data\Report.xlsx` |
| **Filename only** | `"Report.xlsx"` | `"C:\Data"` | `C:\Data\Report.xlsx` |
| **Filename + default** | `"Report.xlsx"` | (not specified) | `.\output\Report.xlsx` |
| **Conflicting paths** | `"C:\Data\Report.xlsx"` | `"C:\Other"` | `C:\Data\Report.xlsx` (warns about conflict) |

**Recommendation:** Use full paths in automation scripts for explicit control; use filename-only in interactive workflows with `-OutputPath`.

---

### Restrictions & Requirements

**Cannot Be Used With:**
- **`-IncludeUserInfo`:** EntraUsers data represents point-in-time snapshots, not time-based activity suitable for appending
- **`-OnlyUserInfo`:** Same reason (EntraUsers mode outputs user snapshots, not audit events)

**Requires:**
- **Single-file output:** Must use one of:
  - `-ExportWorkbook` (Excel mode - multiple tabs OK, but single workbook)
  - `-CombineOutput` (CSV combined mode)
  - Single activity type (e.g., `-ActivityTypes CopilotInteraction` only)
- **File must exist:** Run once without `-AppendFile` to create initial file, then use `-AppendFile` for subsequent runs

**Works With:**
- **Live query mode:** Append new date ranges to existing files
- **Offline replay mode:** `-RAWInputCSV` + `-AppendFile` for incremental transformations
- **All filtering options:** Agent, user, group, prompt filtering fully compatible
- **Schema variations:** Different explosion modes (creates new tabs in Excel; errors in CSV)

---

### Enterprise Use Cases

<details>
<summary>💼 Continuous Audit Collection</summary>

**Scenario:** Security team needs 90-day rolling audit dataset updated daily

```powershell
# Initial export (Day 1)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate (Get-Date).AddDays(-1) `
	-EndDate (Get-Date) `
	-ExportWorkbook `
	-CombineOutput `
	-OutputPath "C:\AuditArchive"
# Creates: Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx

# Daily append (scheduled task)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate (Get-Date).AddDays(-1) `
	-EndDate (Get-Date) `
	-ExportWorkbook `
	-CombineOutput `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx" `
	-OutputPath "C:\AuditArchive"
```

**Benefits:**
- Single workbook contains entire 90-day history
- No manual consolidation required
- Consistent naming for downstream tools (Power BI, etc.)

</details>

<details>
<summary>💼 Multi-Phase Data Transformation</summary>

**Scenario:** Initial export without deep explosion, then incremental replay with `-ExplodeDeep` for specific date ranges

```powershell
# Phase 1: Fast export (no explosion)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-31 `
	-ExportWorkbook `
	-CombineOutput

# Phase 2: Offline replay with deep explosion (specific week only)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-RAWInputCSV "C:\RawExports\Oct_Week2.csv" `
	-ExportWorkbook `
	-ExplodeDeep `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251101_143022.xlsx"
# Result: Original tab preserved, new "CombinedUsageActivity_20251110_152000" tab with deep schema
```

**Benefits:**
- Fast initial collection (no explosion overhead)
- Selective deep analysis only where needed
- Both schemas preserved in same workbook

</details>

<details>
<summary>💼 Multi-Tenant Consolidation</summary>

**Scenario:** MSP managing multiple customer tenants, consolidating audit data into single workbook per customer

```powershell
# Customer A - Tenant 1 (initial)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExportWorkbook `
	-CombineOutput `
	-OutputPath "C:\Customers\CustomerA"
# Creates: Purview_Audit_CombinedUsageActivity_20251110_143022.xlsx

# Customer A - Tenant 1 (append Week 2)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-08 `
	-EndDate 2025-10-09 `
	-ExportWorkbook `
	-CombineOutput `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_143022.xlsx" `
	-OutputPath "C:\Customers\CustomerA"
```

**Benefits:**
- Single workbook per customer (easy distribution)
- Consistent naming across customer base
- Simplified monthly reporting workflows

</details>

---

### Header Validation & Schema Management

#### When Headers Match

**CSV Mode:**
- Appends rows directly to existing file
- No duplicate header row added
- Seamless data continuation

**Excel Mode:**
- Appends rows to matching tabs
- Preserves existing formatting and frozen panes
- No visible indication of append boundary (continuous dataset)

#### When Headers Don't Match

**CSV Mode:**
```
ERROR: CSV header mismatch detected
  Existing file: C:\Data\Report.csv
  
  Missing from existing file (new columns):
    - PromptTokens
    - ResponseTokens
    
  Extra in existing file (removed columns):
    - OldColumnName
  
  To fix:
    1. Use consistent parameters across runs
    2. Create new file without -AppendFile
    3. Use offline replay to rebuild with matching schema
```

**Excel Mode:**
```
WARNING: Schema mismatch detected on tab 'CopilotInteraction'
  New data has different columns than existing tab
  Creating new tab: CopilotInteraction_20251110_143022
  Original tab preserved
```

#### Common Schema Mismatch Causes

| Cause | Solution |
|-------|----------|
| **Added `-ExplodeDeep`** | Use consistent explosion mode across runs OR accept timestamped duplicate tabs |
| **Changed activity types** | Maintain same `-ActivityTypes` list OR use multi-tab mode (activity type per tab) |
| **Added DSPM activities** | Include `-IncludeDSPMForAI` in all runs OR separate DSPM from standard exports |
| **Schema evolution** | Microsoft adds new fields to API response - accept new timestamped tab OR rebuild initial file |

---

### Troubleshooting AppendFile

#### File Access Errors

**Error:** `Cannot access file for reading`

**Common Causes:**
1. File open in Excel (exclusive lock)
2. OneDrive sync in progress
3. Insufficient permissions
4. Network path not accessible

**Solutions:**
```powershell
# Check if file is locked
Get-Process | Where-Object {$_.MainWindowTitle -like "*Report.xlsx*"}

# Copy to local folder
Copy-Item "C:\OneDrive\Reports\Report.xlsx" "C:\temp\Report.xlsx"
.\PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 ... -AppendFile "C:\temp\Report.xlsx"

# Verify permissions
Test-Path "C:\Data\Report.xlsx" -PathType Leaf
(Get-Acl "C:\Data\Report.xlsx").Access
```

#### Excel Structure Errors

**Error:** `Cannot read Excel workbook structure: The file is not a valid Package file`

**Common Causes:**
1. File has encryption/sensitivity labels applied
2. File corrupted
3. ImportExcel module can't parse file format

**Solutions:**
```powershell
# Remove encryption (open in Excel)
# File > Info > Protect Workbook > Remove encryption

# Copy to clean folder (removes some metadata)
Copy-Item "source.xlsx" "C:\temp\clean.xlsx"

# Verify Excel format
$excel = Import-Excel "C:\temp\clean.xlsx" -WorksheetName Sheet1 -StartRow 1 -EndRow 1
# Should return first row without errors
```

#### Pattern Matching Issues

**Issue:** Script doesn't find existing file when using pattern-based search

**Cause:** Filename doesn't match expected pattern

**Solution:** Use explicit full path instead of relying on pattern matching:
```powershell
# Instead of relying on pattern match
-AppendFile -OutputPath "C:\Data"

# Use explicit filename
-AppendFile "C:\Data\Purview_Export_20251030_143022.xlsx"
```

---

### AppendFile Examples

<details>
<summary>📅 Weekly Incremental Build</summary>

```powershell
# Week 1: Initial export
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-08 `
	-ExportWorkbook `
	-CombineOutput `
	-OutputPath "C:\Reports"
# Output: Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx

# Week 2: Append
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-08 `
	-EndDate 2025-10-15 `
	-ExportWorkbook `
	-CombineOutput `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx" `
	-OutputPath "C:\Reports"

# Week 3: Append
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-15 `
	-EndDate 2025-10-22 `
	-ExportWorkbook `
	-CombineOutput `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx" `
	-OutputPath "C:\Reports"

# Result: Single workbook with 3 weeks of continuous data
```

</details>

<details>
<summary>📊 CSV Append with Filtering</summary>

```powershell
# Initial: All users, Week 1
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-08 `
	-ActivityTypes CopilotInteraction `
	-CombineOutput `
	-OutputPath "C:\Data"
# Output: Purview_Audit_CombinedUsageActivity_20251110_080000.csv

# Append: All users, Week 2
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-08 `
	-EndDate 2025-10-15 `
	-ActivityTypes CopilotInteraction `
	-CombineOutput `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_080000.csv" `
	-OutputPath "C:\Data"

# Result: Single CSV with 2 weeks of CopilotInteraction events
```

</details>

<details>
<summary>🔄 Offline Replay Append</summary>

```powershell
# Initial: Transform October data
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-RAWInputCSV "C:\RawExports\October_Raw.csv" `
	-ExportWorkbook `
	-CombineOutput
# Output: Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx

# Append: Transform November data to same workbook
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-RAWInputCSV "C:\RawExports\November_Raw.csv" `
	-ExportWorkbook `
	-CombineOutput `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx"

# Result: Both months in single workbook, no live API calls
```

</details>

<details>
<summary>🏢 Enterprise Scheduled Task</summary>

```powershell
# Scheduled task: Daily at 2 AM
$taskName = "PAX_Daily_Append"
$scriptPath = "C:\Scripts\PAX_Purview_Audit_Log_Processor_v1.8.0.ps1"
$outputPath = "C:\AuditArchive"
$fileName = "Annual_Audit_2025.xlsx"

# Task action
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument @"
-NoProfile -Command "$scriptPath -StartDate (Get-Date).AddDays(-1) -EndDate (Get-Date) -ExportWorkbook -CombineOutput -AppendFile '$fileName' -OutputPath '$outputPath' -Silent"
"@

# Task trigger (daily 2 AM)
$trigger = New-ScheduledTaskTrigger -Daily -At 2am

# Register task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -User "DOMAIN\ServiceAccount" -Password (Read-Host -AsSecureString)

# Result: Single workbook automatically updated daily with previous 24h of data
```

</details>

---

### Best Practices

**Naming Strategy:**
- Use descriptive, date-based names: `Audit_2025_Q4.xlsx`
- Avoid spaces in filenames (simplifies automation)
- Include scope in name: `Executive_Team_Copilot_Usage_2025.xlsx`

**Schema Consistency:**
- Document parameters used for initial export
- Maintain same parameters for all append operations
- Test append on copy before production use

**File Management:**
- Keep backups before each append operation
- Monitor file size (Excel limit: 1,048,576 rows)
- Use compression for archived datasets (7-Zip, etc.)

**Error Handling:**
- Always check exit code in automation: `if ($LASTEXITCODE -ne 0) { Send-MailMessage ... }`
- Log append operations to separate file for audit trail
- Test file accessibility before starting long-running queries

**Performance:**
- Appending adds minimal overhead (< 5 seconds for header validation)
- Large Excel files (>500MB) may take longer to open/validate
- Consider CSV for extremely large datasets (faster append, smaller files)

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Output Files & Schema

<details>
<summary>📄 View Output Files & Schema Details (Click to Expand)</summary>

### Output Files

Every execution produces two files:

#### 1. Data Export File (CSV or Excel)

- **Location:** Specified by `-OutputPath` parameter (directory) or `-AppendFile` (specific filename/path)
- **Format Options:**
  - **CSV Mode (default):** UTF-8 without BOM, standard CSV with quoted fields, CRLF line endings (Windows) or LF (macOS/Linux)
  - **Excel Mode (`-ExportWorkbook`):** .xlsx format with multi-tab or combined layout, professional formatting (frozen headers, auto-sized columns, bold titles)
- **Header:** Always written (even when zero records match)
- **CSV Default:** Separate files per activity type (use `-CombineOutput` to merge into single file)
- **Excel Default:** Multi-tab workbook (one tab per activity type; use `-CombineOutput` for single combined tab)

**Excel File Naming Conventions:**

- **Combined Mode (with `-CombineOutput`):**
  - Standard and DSPM: `Purview_Audit_CombinedUsageActivity_<timestamp>.xlsx`
- **Multi-Tab Mode (default for Excel):**
  - Standard datasets: `Purview_Export_<timestamp>.xlsx`
  - DSPM datasets (`-IncludeDSPMForAI`): `Purview_DSPM_Export_<timestamp>.xlsx`

**CSV File Naming:**
- **Default (separate files per activity type):** `<ActivityTypeName>_<timestamp>.csv` (e.g., `CopilotInteraction_20251107_143022.csv`, `ConnectedAIAppInteraction_20251107_143022.csv`)
- **Combined mode (with `-CombineOutput`):** `Purview_Audit_CombinedUsageActivity_<timestamp>.csv`
- **Entra users file (when `-IncludeUserInfo` used):** `EntraUsers_MAClicensing_<timestamp>.csv` (always separate CSV, even in Excel mode unless embedded as tab)

#### 2. Log File (Execution Metrics)

- **Location:** Same directory as data file, extension replaced with `.log`
- **Contains:** 
  - Script parameters and version
  - Authentication method and connection details
  - Query plan and adaptive block sizing decisions
  - Progress updates and phase transitions
  - Warnings (10K limits, throttling, schema changes)
  - Final metrics (records processed, time elapsed, throughput)

### Schema Modes

#### Standard Mode (Default)

**One row per audit record.** AuditData preserved as JSON string in a single column.

**Column Count:** Variable (base audit fields + `AuditData` JSON column)

**Use When:** Need raw data for custom processing or minimal transformation

#### Exploded Mode (`-ExplodeArrays`)

**Purview canonical 35-column schema.** Array elements (Messages, AccessedResources, AISystemPlugins) expanded to separate rows.

**Column Count:** 35 base columns

**Base Columns (35):**
1. RecordId
2. CreationDate
3. RecordType
4. Operation
5. UserId
6. AssociatedAdminUnits
7. AssociatedAdminUnitsNames
8. AgentId
9. AgentName
10. AppIdentity
11. AppIdentity_DisplayName
12. AppIdentity_PublisherId
13. ApplicationName
14. CreationTime
15. ClientRegion
16. ClientIP
17. Audit_UserId
18. AppHost
19. ThreadId
20. Context_Id
21. Context_Type
22. Message_Id
23. Message_isPrompt
24. AccessedResource_Action
25. AccessedResource_PolicyDetails
26. AccessedResource_SiteUrl
27. AISystemPlugin_Id
28. AISystemPlugin_Name
29. ModelTransparencyDetails_ModelName
30. MessageIds
31. OrganizationId
32. Version
33. UserType
34. CopilotLogVersion
35. Workload

**Use When:** Need relational format for BI tools or matching Microsoft Purview exports

#### Deep Flatten Mode (`-ExplodeDeep`)

**35 base columns + all nested `CopilotEventData.*` columns.** Maximum data extraction with every nested field as a separate column.

**Column Count:** 35+ (dynamic based on data)

**Use When:** 
- Maximum data extraction for BI/ML pipelines
- Need every nested field accessible as a column
- Building wide-schema data warehouses

**Warning:** Significantly increases CSV width and processing time. Test with short date range first.

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Entra ID User Enrichment

<details>
<summary>👤 View Entra ID Enrichment Guide (Click to Expand)</summary>

### Overview

**Entra ID User Enrichment** (`-IncludeUserInfo`) extends audit data with organizational context by querying Microsoft Entra ID (formerly Azure AD) for user attributes. This feature enables adoption analysis, compliance reporting, and organizational insights beyond raw audit logs.

**Why Use User Enrichment?**

- **Organizational Analysis:** Analyze adoption by department, job title, manager, or office location
- **License Tracking:** Identify M365 Copilot license holders and correlate with usage patterns
- **Compliance Reporting:** Include user demographics (manager, account status, creation date) for audit trails
- **Executive Dashboards:** Visualize usage by business unit, geography, or reporting hierarchy
- **Data Enrichment:** Join audit data with HR systems using EmployeeId, Department, or Office location

**New in version 1.8.0:** Requires **Graph API mode** (default) - not compatible with `-UseEOM`

---

### Requirements

| Requirement | Details |
|-------------|---------|
| **Mode** | Graph API (default) - **NOT compatible with `-UseEOM`** |
| **Parameter** | `-IncludeUserInfo` switch |
| **Permissions** | `User.Read.All`, `Organization.Read.All` (least privilege Graph API scopes) |
| **Output** | CSV: Separate `EntraUsers_MAClicensing_<timestamp>.csv` file<br>Excel: Embedded `EntraUsers_MAClicensing` tab in workbook |
| **Performance** | Minimal impact: ~1-5 seconds for typical datasets (one-time batch query) |

---

### Output Schema

Comprehensive user profile data per user, automatically deduplicated by UserPrincipalName:

| Column Name | Description | Example |
|------------|-------------|---------|
| `UserPrincipalName` | Primary email/login | `user@contoso.com` |
| `DisplayName` | Full name | `Jane Smith` |
| `GivenName` | First name | `Jane` |
| `Surname` | Last name | `Smith` |
| `Mail` | Email address | `jane.smith@contoso.com` |
| `JobTitle` | Job title | `Senior Product Manager` |
| `Department` | Department name | `Product Management` |
| `OfficeLocation` | Office/location | `Seattle` |
| `City` | City | `Seattle` |
| `State` | State/province | `WA` |
| `Country` | Country | `United States` |
| `PostalCode` | Postal code | `98101` |
| `StreetAddress` | Street address | `123 Main St` |
| `UsageLocation` | License location | `US` |
| `EmployeeId` | Employee ID | `EMP12345` |
| `CompanyName` | Company name | `Contoso Corporation` |
| `Manager` | Manager UPN | `manager@contoso.com` |
| `ManagerDisplayName` | Manager name | `John Doe` |
| `AccountEnabled` | Account status | `True` or `False` |
| `UserType` | User type | `Member`, `Guest` |
| `CreationType` | Account creation | `Invitation`, `LocalAccount` |
| `CreatedDateTime` | Account created | `2023-01-15T08:30:00Z` |
| `LastSignInDateTime` | Last sign-in | `2025-11-06T14:22:00Z` |
| `AssignedLicenses` | All licenses (JSON array) | `[{...}, {...}]` |
| `HasCopilotLicense` | M365 Copilot license | `True` or `False` |
| `CopilotLicenseSkus` | Detected Copilot SKUs | `O365_PREMIUM` or empty |
| `LicenseCount` | Total licenses | `5` |
| ... (11 more extended attributes) | ... | ... |

**License Detection Logic:**

The script automatically detects Microsoft 365 Copilot licenses using SKU pattern matching:

- `SPE_E3_RPA1`, `SPE_E5_RPA1` - Copilot for Enterprise E3/E5
- `O365_PREMIUM`, `M365_F1_COMM`, `M365_F3_COMM` - Commercial licenses with Copilot entitlements
- Additional SKUs: `MICROSOFT_BUSINESS_CENTER`, `TEAMS_COMMERCIAL_TRIAL`, etc.

`HasCopilotLicense` column: `True` if any matching SKU detected, `False` otherwise

---

### Usage Examples

<details>
<summary>💻 Show Entra Enrichment Examples</summary>

```powershell
# Basic Entra enrichment (CSV mode)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeUserInfo
# Output: CopilotInteraction_<timestamp>.csv + EntraUsers_MAClicensing_<timestamp>.csv

# Entra enrichment with Excel (embedded tab)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeUserInfo `
	-ExportWorkbook `
	-CombineOutput
# Output: Purview_Audit_CombinedUsageActivity_EntraUsers_MAClicensing_<timestamp>.xlsx
# Tabs: CombinedUsageActivity, EntraUsers_MAClicensing

# Entra enrichment with DSPM activities
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeDSPMForAI `
	-IncludeUserInfo `
	-ExportWorkbook
# Output: Purview_DSPM_Export_<timestamp>.xlsx
# Tabs: CopilotInteraction, ConnectedAIAppInteraction, AIInteraction, AIAppInteraction, EntraUsers_MAClicensing

# Entra enrichment with exploded schema
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeUserInfo `
	-ExplodeArrays `
	-OutputPath "C:\Exports\\"
# Output: Copilot_Enriched_Exploded.csv + EntraUsers_MAClicensing_<timestamp>.csv
```

</details>

---

### Common Use Cases

#### 1. Adoption Analysis by Department

**Goal:** Identify which departments are using M365 Copilot most

**Workflow:**
1. Export with `-IncludeUserInfo`
2. Join audit data with EntraUsers on `UserId` = `UserPrincipalName`
3. Group by `Department` and count interactions

**Power Query/SQL:**
```sql
SELECT 
    e.Department,
    COUNT(a.RecordId) AS InteractionCount,
    COUNT(DISTINCT a.UserId) AS UniqueUsers
FROM AuditData a
INNER JOIN EntraUsers e ON a.UserId = e.UserPrincipalName
GROUP BY e.Department
ORDER BY InteractionCount DESC
```

---

#### 2. License Correlation Analysis

**Goal:** Compare Copilot usage between licensed and unlicensed users

**Workflow:**
1. Export with `-IncludeUserInfo`
2. Filter EntraUsers by `HasCopilotLicense`
3. Calculate usage metrics per cohort

**Use Case:** Identify license optimization opportunities (unused licenses, high-value unlicensed users)

---

#### 3. Manager-Level Reporting

**Goal:** Show Copilot adoption for each manager's direct reports

**Workflow:**
1. Export with `-IncludeUserInfo`
2. Join audit data with EntraUsers
3. Group by `Manager` and calculate team adoption rates

**Dashboard Insight:** Executive view showing team-level adoption across organizational hierarchy

---

#### 4. Geographic Distribution

**Goal:** Analyze Copilot usage by office location or country

**Workflow:**
1. Export with `-IncludeUserInfo`
2. Join on UserPrincipalName
3. Group by `OfficeLocation` or `Country`

**Use Case:** Regional rollout planning, data residency compliance, language-specific adoption patterns

---

### Performance & Best Practices

**Performance Characteristics:**

- **Batch Query:** Single Graph API call retrieves all users in tenant (one-time cost)
- **Caching:** User data cached in memory for session duration
- **Deduplication:** Automatic deduplication by UserPrincipalName (no duplicate user rows)
- **Typical Overhead:** 1-5 seconds for 1,000-50,000 user tenants

**Best Practices:**

1. **Use with Excel:** Embed EntraUsers tab for easy pivot tables and Power Query joins
2. **Cache Reuse:** Run multiple audit queries in same session to reuse cached user data
3. **Selective Filtering:** Use `-UserIds` or `-GroupNames` to reduce audit dataset size before enrichment
4. **License Auditing:** Export EntraUsers separately and audit `HasCopilotLicense` against actual license assignments

**Troubleshooting:**

- **Error: "Entra enrichment requires Graph API mode"** → Remove `-UseEOM` parameter
- **Error: "Insufficient privileges to complete the operation"** → Grant `User.Read.All` and `Organization.Read.All` Graph API permissions
- **Empty HasCopilotLicense:** Update SKU detection list in script if new Copilot SKUs released

---

### Limitations

| Limitation | Details | Workaround |
|------------|---------|------------|
| **Not compatible with `-UseEOM`** | Requires Graph API mode | Remove `-UseEOM` or skip `-IncludeUserInfo` |
| **Tenant-wide query** | Retrieves all users (no server-side filtering) | Use Graph API's `$filter` with custom script modifications |
| **Requires elevated permissions** | `User.Read.All` Graph scope needed | Request consent from Global Admin or Privileged Role Admin |
| **Guest user limitations** | Guest users may have limited attribute population | Expected behavior - guest profiles often sparse |
| **License SKU changes** | New Copilot SKUs require script updates | Monitor Microsoft licensing announcements |

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Activity Types Reference

<details>
<summary>📊 View Activity Types Reference (Click to Expand)</summary>

### Copilot & AI Activities

- `CopilotInteraction` - Microsoft 365 Copilot usage events (default activity type)
- `ConnectedAIAppInteraction` - Connected AI app interactions (MIXED FREE/PAYG - DSPM for AI)
- `AIInteraction` - AI interactions (MIXED FREE/PAYG - DSPM for AI, currently Microsoft platforms only)
- `AIAppInteraction` - Third-party AI app interactions (PAYG - DSPM for AI, ~$0.0132/1K records)

### Common High-Volume Activities

- `MessageSent` - Teams/Exchange message sending
- `FileAccessed` - SharePoint/OneDrive file access
- `MailItemsAccessed` - Email access events

### Common Medium-Volume Activities

- `MessageRead` - Message read receipts
- `FileModified` - File edit operations
- `MeetingDetail` - Teams meeting metadata
- `SearchQueryPerformed` - Search queries

### Common Low-Volume Activities

- `CreatePlugin` - Copilot plugin creation
- `UpdatePlugin` - Plugin modifications
- `DeletePlugin` - Plugin removal
- `EnablePlugin` / `DisablePlugin` - Plugin state changes

### Finding Available Activities

For a complete list of available Purview audit activities and operations, refer to the Microsoft Learn documentation:

**📚 [Audit log activities - Microsoft Purview](https://learn.microsoft.com/en-us/purview/audit-log-activities)**

This comprehensive reference includes all available operations across Microsoft 365 services, including SharePoint, Exchange, Teams, Copilot, and more.

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Advanced Features

<details>
<summary>⚙️ View Advanced Features (Click to Expand)</summary>

### Adaptive Block Sizing

The script automatically adjusts time window sizes based on observed data density:

- **Initial Block:** Starts with `-BlockHours` parameter (default 30 minutes)
- **Learning Phase:** Monitors record counts per window
- **Graph API Mode (Default):** Partitions time ranges for parallel async queries; adaptive sizing optimizes query distribution
- **EOM Mode (`-UseEOM`):** Automatic subdivision splits windows hitting the 10K service limit
- **Progressive Refinement:** Shrinks blocks for dense periods, expands for sparse periods
- **Per-Activity Learning:** Maintains separate learned block sizes for each activity type

**Mode Differences:**
- **Graph API:** Adaptive sizing focuses on optimal query parallelization and result distribution
- **EOM Mode:** Adaptive sizing primarily addresses the 10K result limit constraint

### Parallel Execution (PowerShell 7+)

When processing multiple activity types or large date ranges, parallel execution can significantly improve performance:

- **Auto Mode:** Script heuristically determines if parallel execution will benefit
- **Forced Mode:** Always use parallel execution regardless of activity count
- **Throttling Control:** Configurable concurrency limits to avoid overwhelming the API endpoints
- **Graph API Mode (Default):** Uses ThreadJobs to parallelize time-partitioned queries
- **EOM Mode (`-UseEOM`):** Group processing with activities classified by volume (High/Medium/Low)
- **Mode-Specific Behavior:** Graph API parallel execution creates async queries; EOM mode uses synchronous calls with throttling

### Adaptive Concurrency (v1.8.0)

New adaptive concurrency heuristics (v1.8.0) refine scaling decisions based on latency and throughput stability:
- Evaluates average latency against `-LowLatencyMs`
- Dampens scaling when throughput regression ≥ `-ThroughputDropPct` from recent peak
- Applies hard safety cap via `-AdaptiveConcurrencyCeiling` (in addition to `-MaxConcurrency`)
These parameters are optional—omit them to use defaults tuned for conservative, service-friendly growth.

### Automatic Query Retry & Recovery

The script includes built-in resilience for handling transient failures during parallel query execution:

**How It Works:**
- **Automatic Retries:** Up to 3 total attempts per partition (initial attempt + 2 retry passes)
- **Smart Cooldown:** 30-60 second pause between retry passes to allow service recovery
- **Partial Success:** Script continues with successfully retrieved data even if some partitions fail
- **Status Tracking:** Every partition monitored throughout execution to detect failures

**What You'll See:**

During execution, you'll see status messages for each partition:
```
[CREATED] [14:23:15] Partition 1/134 - Job created
[ATTEMPT] [14:23:15] Partition 1/134 - Starting query creation...
[SENT]    [14:23:17] Partition 1/134 - Query sent to Purview
```

If retries are needed:
```
[RETRY] Pass 2/3 - 5 partition(s) need retry
  Waiting 47 seconds before retry...
  ✓ Retry successful for Partition 12/134: 8,542 records
```

At the end of execution, you'll see a summary:
```
═══════════════════════════════════════════════════════════════
  QUERY SUBMISSION SUMMARY
═══════════════════════════════════════════════════════════════
  Total Partitions: 134
  ✓ Sent and Complete: 131
  ⚠ Sent but Incomplete: 2
  ✗ Never Sent: 1
═══════════════════════════════════════════════════════════════
```

**Finding Your Queries in Purview:**

All queries appear in the Purview audit log search interface with descriptive names:
- Format: `PAX_Query_<StartDate>_<StartTime>-<EndDate>_<EndTime>_PartX/Total`
- Example: `PAX_Query_20241101_0000-20241101_0100_Part27/134`

This naming helps you:
- Track query status in Purview UI
- Correlate terminal output with Purview searches
- Troubleshoot incomplete partitions using the QueryName shown in the summary

**When to Act:**

The script automatically handles most transient failures. However, if you see partitions listed as "Never Sent" or "Sent but Incomplete":
- Check the log file for detailed error messages
- Review the specific query in Purview UI using the QueryName
- Consider re-running with smaller partition sizes if issues persist

### Offline Replay Mode

Re-process previously exported raw audit CSV files without querying live APIs:

- **No Authentication Required:** Skip connection to Microsoft 365 services
- **Flexible Filtering:** Apply date, activity, and agent filters to existing data
- **Schema Transformation:** Convert raw exports to exploded or deep flatten schemas
- **Reproducible Analysis:** Test transformations against known datasets
- **Development Workflow:** Build pipelines without production access
- **Works with both modes:** Compatible with CSV exports from Graph API or EOM mode

### Progress Tracking System

Real-time progress updates across three phases:

**Display Format:**

```
PAX Purview Audit Log Processing
Status: Query: 45/100(45%) | Explosion: 12000/25000(48%) | Export: 0/1(0%) :: 42%
```

**Components:**

- **Overall percentage:** Composite progress across all phases
- **Phase detail:** Current/Total (percentage) for each active phase
- **Batch info:** Current batch number, estimated total, percentage range
- **Record range:** Shows which records currently processing (in batches)

### AutoCompleteness Recursive Strategy (EOM Mode)

**⚠️ Note:** AutoCompleteness primarily applies to EOM mode (`-UseEOM`) where the 10K result limit exists. Graph API (default) does not have this limitation.

When `-AutoCompleteness` is enabled in EOM mode, any time window still returning the 10K cap is subdivided again (binary split) until one of these conditions:

- Sub-window estimated total < 10,000 (safe to fully paginate)
- Minimum window duration reached (guardrail)
- Maximum recursion depth reached (prevents runaway micro-windows)

**Benefits:** Maximizes completeness without manual re-tuning of `-BlockHours` values. **Recommended flow:** Run without it first; if exit code 10 (incomplete), re-run with `-AutoCompleteness`.

**Operational Notes:**
- Tracks iteration count in metrics (`AutoCompletenessIterations`)
- Only subdivides saturated windows; unaffected windows are reused
- Produces fewer redundant API calls than blanket ultra-small initial windows
- **Graph API users:** This feature is less relevant as async queries handle large result sets automatically

### Metrics & Exit Codes

The script can emit a metrics JSON capturing execution telemetry and final state.

**Enable:** `-EmitMetricsJson` (optional `-MetricsPath`)

**JSON Includes (illustrative):**
```json
{
	"ScriptVersion": "1.8.0",
	"StartTimestampUtc": "2025-10-26T14:05:23Z",
	"EndTimestampUtc": "2025-10-26T14:07:11Z",
	"TotalWindows": 42,
	"SubdividedWindows": 6,
	"Hit10KLimitWindows": 2,
	"AutoCompletenessIterations": 1,
	"ExplodedRows": 25678,
	"ExplosionEvents": 1092,
	"ExplosionRowsFromEvents": 2345,
	"ExitCode": 0
}
```

**Exit Codes:**
| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success (complete) | Proceed with analytics |
| 10 | Incomplete - saturated windows remain (EOM mode) | Re-run with `-AutoCompleteness` or smaller `-BlockHours`, or switch to Graph API mode |
| 20 | Circuit breaker tripped | Investigate throttling / reduce concurrency / add pacing |

**Note:** Exit code 10 is primarily relevant to EOM mode due to the 10K result limit. Graph API mode rarely encounters this condition.

### Parallel Metrics Aggregation Behavior

In parallel mode, interim partitions suppress metrics emission. A single aggregated metrics JSON is written after all activity groups finish.

**Safeguards:**
- Internal `SkipMetrics` flag prevents duplicate writes
- Explosion counters reconciled post-join (no double counting)
- Atomic file write minimizes race conditions

**Tip:** If monitoring progress externally, tail the log file; metrics JSON only appears at end.

### Synthetic Replay Testing Guidance

Offline replay (`-RAWInputCSV`) enables deterministic transformation tests without live service calls.

**Use Cases:**
- Validate schema explosion behavior on known datasets
- Benchmark deep flatten memory impact safely
- Redact / sanitize before sharing sample exports

**Best Practices:**
- Maintain a curated set of raw CSV snapshots (high, medium, low volume)
- Pair replay runs with `-EmitMetricsJson` for longitudinal trend baselines
- Use narrow date filtering when deep flattening very wide synthetic payloads

**Not Supported in Replay:** Authentication, group expansion, adaptive block sizing (already materialized), parallel querying.

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Performance Tuning

<details>
<summary>⚡ View Performance Tuning Guide (Click to Expand)</summary>

### Hitting the 10K Service Limit (EOM Mode Only)

**⚠️ Note:** The 10K limit applies only to EOM mode (`-UseEOM`). Graph API (default) does not have this limitation.

**Symptoms (EOM Mode):**

- Log shows: `CRITICAL: 10K limit reached for time window <dates>`
- CSV may be incomplete for dense periods

**Immediate Action:**

<details>
<summary>💻 Show 10K Limit Fix Examples</summary>

```powershell
# Reduce block hours to 15 minutes or less
pwsh -ExecutionPolicy Bypass -File ./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
  -BlockHours 0.25 `
  -StartDate 2025-10-03 `
  -EndDate 2025-10-03
```

</details>

**Progressive Tuning (EOM Mode):**

1. Start: `-BlockHours 0.5` (30 min) → If still hitting: `0.25` (15 min)
2. If still saturated: `0.133333` (8 min) → `0.066667` (4 min)
3. Minimum: `0.016667` (1 min)

**Verification:**

- Check log for "Data retrieval completed without hitting limits"
- Compare record counts across runs
- Monitor `Hit10KLimit` flag in metrics section

**Note:** Graph API mode (default) automatically handles large result sets through async query pagination without the 10K limit constraint.

### Throttling & Rate Limiting

**Graph API Mode (Default):**
- Throttling handled automatically through async query system
- Queries execute server-side; retrieval uses standard Graph API pagination
- Adjust `-MaxConcurrency` if experiencing sustained throttling

**EOM Mode (`-UseEOM`):**
- Real-time query execution more susceptible to rate limits
- Use `-PacingMs` to add delays between API calls
- Reduce `-ResultSize` for smaller page sizes

**Symptoms:**

- Log shows: `WARNING: Throttling detected, backing off...`
- Frequent retry attempts
- Extended execution times

**Solutions:**

<details>
<summary>💻 Show Throttling Solutions</summary>

**EOM Mode (`-UseEOM`) - Add Pacing:**

```powershell
# Add inter-page pacing (250ms delay between API calls)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -UseEOM -PacingMs 250 -StartDate 2025-10-01 -EndDate 2025-10-02

# Reduce ResultSize to smaller batches
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -UseEOM -ResultSize 5000 -StartDate 2025-10-01 -EndDate 2025-10-02

# Combine both approaches
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -UseEOM -ResultSize 5000 -PacingMs 250 -StartDate 2025-10-01 -EndDate 2025-10-02
```

**Graph API Mode (Default) - Reduce Concurrency:**

```powershell
# Lower concurrent query limit
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -MaxConcurrency 5 -StartDate 2025-10-01 -EndDate 2025-10-02

# Conservative parallel settings
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -MaxConcurrency 3 -MaxParallelGroups 2 -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

### Memory Optimization

**For Deep Flatten with Wide Schemas:**

<details>
<summary>💻 Show Memory Optimization Examples</summary>

```powershell
# Increase schema sample, reduce chunk size
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -ExplodeDeep `
  -StreamingSchemaSample 5000 `
  -StreamingChunkSize 2000 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**For Narrow Schemas (Faster Processing):**

```powershell
# Reduce schema sample, increase chunk size
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -ExplodeArrays `
  -StreamingSchemaSample 1000 `
  -StreamingChunkSize 10000 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

</details>

### Parallel Execution Tuning

**Conservative Approach (Avoid Throttling):**

<details>
<summary>💻 Show Parallel Execution Examples</summary>

```powershell
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -ParallelMode On `
  -MaxConcurrency 2 `
  -MaxParallelGroups 2 `
  -ActivityTypes CopilotInteraction,MessageSent,FileAccessed
```

**Aggressive Approach (Maximum Throughput):**

```powershell
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -ParallelMode On `
  -MaxConcurrency 4 `
  -MaxParallelGroups 3 `
  -ActivityTypes CopilotInteraction,MessageSent,FileAccessed
```

</details>

### Adaptive Concurrency Guidance (v1.8.0)

If adaptive scaling appears too assertive in your environment, lower `-AdaptiveConcurrencyCeiling` or raise `-ThroughputDropPct`. If scaling is too conservative, raise `-AdaptiveConcurrencyCeiling` (but keep `-MaxConcurrency` equal or higher) or lower `-LowLatencyMs` only if your baseline latency is consistently very low.

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Troubleshooting & FAQ

<details>
<summary>❓ View Troubleshooting & FAQ (Click to Expand)</summary>

**Common Issues:**

- [Authentication Failures](#authentication-failures)
- [No Data Returned](#no-data-returned)
- [10K Limit Warnings](#10k-limit-warnings)
- [Memory Issues](#memory-issues)
- [Throttling Errors](#throttling-errors)

**Frequently Asked Questions:**

- [Does the script modify any data?](#q-does-the-script-modify-any-data)
- [What timezone are dates in?](#q-what-timezone-are-dates-in)
- [Can I filter by specific users or models at the source?](#q-can-i-filter-by-specific-users-or-models-at-the-source)
- [How deep does the script flatten JSON?](#q-how-deep-does-the-script-flatten-json)
- [Can I run this in an automated schedule?](#q-can-i-run-this-in-an-automated-schedule)
- [What if I need older audit logs?](#q-what-if-i-need-older-audit-logs)
- [Does the script work on macOS/Linux?](#q-does-the-script-work-on-macoslinux)
- [How do I handle very large date ranges?](#q-how-do-i-handle-very-large-date-ranges)
- [Can I customize the output schema?](#q-can-i-customize-the-output-schema)
- [What's the difference between `-ExplodeArrays` and `-ExplodeDeep`?](#q-whats-the-difference-between--explodearrays-and--explodedeep)
- [What happens if some queries fail?](#q-what-happens-if-some-queries-fail)

---

### Common Issues

#### Authentication Failures

**Problem:** "Unable to connect to Microsoft Graph" or "Unable to connect to Exchange Online"

**Solutions:**

**Graph API Mode (Default):**
- Verify you have AuditLog.Read.All permission (Application or Delegated)
- Verify you have Azure AD role: Compliance Administrator, Security Administrator, or Global Reader
- Check network connectivity to Microsoft Graph endpoints (`*.graph.microsoft.com`)
- Try different auth method: `-Auth DeviceCode` for headless sessions
- Clear cached credentials: Restart PowerShell session

**EOM Mode (`-UseEOM`):**
- Verify you have View-Only Audit Logs or Audit Logs role assigned
- Check network connectivity to Exchange Online endpoints (`*.protection.outlook.com`)
- ExchangeOnlineManagement module will auto-install if missing
- Try different auth method: `-Auth DeviceCode` for headless sessions

#### No Data Returned

**Problem:** CSV contains only header, no records

**Solutions:**

- Verify Unified Audit Logging is enabled in your tenant
- Check date range (dates are UTC, not local time)
- Confirm activity type spelling: `-ActivityTypes CopilotInteraction` (case-sensitive)
- Verify users have generated audit events in the date range
- Check audit log retention period (default 90 days)

#### 10K Limit Warnings (EOM Mode Only)

**Problem:** Log shows "CRITICAL: 10K limit reached"

**⚠️ Note:** This only applies to EOM mode (`-UseEOM`). Graph API (default) does not have this limitation.

**Solutions (EOM Mode):**

- Reduce `-BlockHours` parameter (try 0.25 or 0.133333)
- Run script multiple times with shorter date ranges
- Check adaptive subdivision is working (log should show automatic splits)
- Consider if data is genuinely dense (may need multiple runs)
- **Or switch to Graph API mode (default)** by removing `-UseEOM` parameter

#### Memory Issues

**Problem:** Script consumes excessive memory or crashes

**Solutions:**

- Reduce `-StreamingChunkSize` (try 2000 or 1000)
- Increase `-StreamingSchemaSample` to discover schema earlier (try 5000)
- Avoid `-ExplodeDeep` for initial runs (use `-ExplodeArrays` instead)
- Process shorter date ranges
- Close other applications to free memory

#### Throttling Errors

**Problem:** Frequent "Throttling detected" messages

**Solutions:**

- Add pacing: `-PacingMs 250` or `-PacingMs 500`
- Reduce ResultSize: `-ResultSize 5000`
- Run during off-peak hours
- Disable parallel mode if enabled
- Consider if tenant is under heavy load

---

### Frequently Asked Questions

#### Q: Does the script modify any data?

**A:** No. The script is read-only and only exports audit data. No modifications are made to audit logs or tenant configuration.

#### Q: What timezone are dates in?

**A:** All dates are interpreted as UTC. Output timestamps are also UTC in ISO 8601 format (`yyyy-MM-ddTHH:mm:ss.fffZ`).

#### Q: Can I filter by specific users or models at the source?

**A:** Depends on the mode:
- **Graph API Mode (Default):** Filtering happens client-side after retrieval. Use `-UserIds` to filter after data is retrieved.
- **EOM Mode (`-UseEOM`):** User filtering (`-UserIds`) is server-side via the API. Group filtering (`-GroupNames`) also available in EOM mode only.

For both modes, model/app filtering happens in post-processing or BI tools.

#### Q: How deep does the script flatten JSON?

**A:** Standard explode: 60 levels. Deep flatten: 120 levels. JSON serialization: 60 levels. These are constants in the script and can be adjusted if needed.

#### Q: Can I run this in an automated schedule?

**A:** Yes. Use `-Auth Silent` with cached credentials or `-Auth Credential` with saved credentials. Consider using Task Scheduler (Windows) or cron (macOS/Linux).

#### Q: What if I need older audit logs?

**A:** Audit retention depends on your tenant's licensing. E3/E5 licenses retain 90-365 days. Check Microsoft Purview compliance portal for your retention period.

#### Q: Does the script work on macOS/Linux?

**A:** Yes, with PowerShell 7+. Install PowerShell 7:
- **Graph API Mode (Default):** Works seamlessly with `Microsoft.Graph.Security` module (cross-platform)
- **EOM Mode (`-UseEOM`):** Requires ExchangeOnlineManagement module (cross-platform support)

Authentication methods: WebLogin or DeviceCode recommended for non-Windows platforms.

#### Q: How do I handle very large date ranges?

**A:** Break into smaller chunks (weekly or monthly), run separately, then:
- **CSV Mode:** Concatenate files manually or use `-AppendFile` with subsequent runs
- **Excel Mode:** Use `-ExportWorkbook` with `-AppendFile` to incrementally build a single workbook across multiple time periods

Use `-AppendFile` with a specific filename for incremental appending.

#### Q: Can I customize the output schema?

**A:** The 35-column base schema is fixed to match Purview standards. In `-ExplodeDeep` mode, additional columns are auto-discovered from nested data.

#### Q: What's the difference between `-ExplodeArrays` and `-ExplodeDeep`?

**A:** `-ExplodeArrays` creates 35 columns with array elements as separate rows. `-ExplodeDeep` adds all nested `CopilotEventData.*` fields as additional columns (wide schema).

#### Q: What happens if some queries fail?

**A:** The script includes automatic retry logic to handle transient failures:

- **Automatic Recovery:** Failed partitions are automatically retried up to 3 times with smart delays between attempts
- **Partial Success:** The script continues processing and exports data from successful partitions, even if some fail
- **Clear Summary:** At the end, you'll see a detailed report showing which partitions completed successfully and which failed
- **Easy Troubleshooting:** Failed queries include the query name (e.g., `PAX_Query_20241101_0000-20241101_0100_Part27/134`) so you can find them in Purview UI

Most transient issues (network hiccups, temporary service throttling) are resolved automatically. If you see persistent failures in the summary, check the log file for detailed error messages and consider re-running with smaller partition sizes (`-PartitionHours`).

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Known Limitations

<details>
<summary>⚠️ View Known Limitations (Click to Expand)</summary>

<details>
<summary>⚠️ Show Known Limitations Table</summary>

| Area                        | Limitation / Behavior                                                          | Mitigation / Guidance                                                                                        |
| --------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| Unified Audit 10K cap (EOM) | Each `Search-UnifiedAuditLog` window tops at 10,000 records (EOM mode only)    | Script auto-subdivides; if still saturated, re-run with smaller `-BlockHours` (≤30m) or use Graph API mode (default) |
| Row explosion cap           | Per original record explosion capped at 1,000 rows (`ExplosionTruncated` flag) | Investigate fan-out; consider narrower date, filter operations, or deep analysis separately                  |
| JSON / flatten depth        | JSON serialization depth fixed at 60; deep flatten recursion capped at 120     | Extremely deep structures beyond caps truncated; adjust constants if required                                |
| Memory usage                | Streaming, chunked export by default                                           | Tune with `-StreamingSchemaSample` / `-StreamingChunkSize`; shard by date for extreme spans                  |
| Replay mode                 | Non‑exploded mode disabled; always at least exploded schema                    | Use live mode if raw 1:1 row shape required                                                                  |
| Parallel mode               | Graph API: time-partitioned parallel queries; EOM: multi-activity sets only    | Graph API mode (default) provides better parallel performance for single activity types                      |
| Time zones                  | Dates interpreted as UTC; `yyyy-MM-dd` must be UTC                             | Convert local times to UTC prior to invocation to avoid DST drift                                            |
| Streaming export            | Always on (chunked)                                                            | Adjust sample/chunk sizes for schema width & memory balance                                                  |
| Group filtering             | Only available in EOM mode (`-UseEOM -GroupNames`)                              | Graph API mode does not support group-based filtering; export and filter client-side                         |

</details>

### Additional Notes

**Streaming Export Behavior:**

- Samples initial records (default 2000) to finalize column schema
- Writes header once, then processes rows in chunks (default 5000)
- Auto-adjusts chunk size based on column count (>250/500/750/1000 columns → smaller chunks)
- Boosts chunk size for narrow schemas (≤60 columns → up to 15K)
- New columns discovered after schema freeze are ignored (warning emitted)

**Fast CSV Writer:**

- Uses in-process UTF‑8 `StreamWriter` with manual escaping
- No repeated `Export-Csv` invocations
- Significantly faster for large exports (>300K rows)
- Transparent to user (no parameter required)

**Timestamp Normalization:**

- All timestamps output in UTC
- ISO 8601 format with millisecond precision: `yyyy-MM-ddTHH:mm:ss.fffZ`
- Eliminates locale ambiguity
- Simplifies downstream parsing

**Parallel Replay Explosion (PS 7+ only):**

- When replaying raw CSV with large record count
- Switches to controlled parallel explosion
- Dynamic throttle + batch resizing (targets ~0.8s–2.5s batches)
- Metrics emitted at completion

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Security & Compliance

<details>
<summary>🔒 View Security & Compliance Information (Click to Expand)</summary>

### Data Handling

- **Read-Only Operations:** Script never modifies audit logs or tenant configuration
- **Credential Security:** Authentication credentials never written to disk (memory only)
- **Audit Trail:** All operations logged with timestamps and parameters
- **No External Services:** No data transmitted to third-party services
- **Local Processing:** All data processing occurs on the execution machine

### Permissions & Least Privilege

**Graph API Mode (Default):**

- **API Permission:** AuditLog.Read.All (Application or Delegated)
- **Azure AD Role:** Compliance Administrator, Security Administrator, Security Reader, or Global Reader
- **Read-Only:** No write permissions required
- Create dedicated service account for automated runs
- Limit access to output files (contain sensitive audit data)

**EOM Mode (`-UseEOM`):**

- **Exchange Role:** View-Only Audit Logs or Audit Logs role
- **Read-Only:** No write permissions required
- Create dedicated service account for automated runs
- Limit access to output files (contain sensitive audit data)

**Not Required (Both Modes):**

- No Global Administrator rights needed
- No tenant configuration changes
- No write access to audit logs

### Compliance Considerations

- **Data Residency:** Export files remain on execution machine (control geography)
- **Retention:** Manage export file retention per organizational policies (CSV or Excel)
- **Encryption:** Consider encrypting output files for sensitive environments
- **Access Control:** Limit script execution to authorized personnel
- **Audit Review:** Regularly review log files for anomalies

### Security Best Practices

1. **Execution Policy:** Use `Bypass` or `RemoteSigned` (avoid `Unrestricted`)
2. **Script Verification:** Validate script hash before execution
3. **Credential Management:** Avoid storing passwords in scripts (use `-Auth Silent` or `-Auth DeviceCode`)
4. **Network Security:** Ensure TLS 1.2+ for API connections (Graph API and Exchange Online)
5. **Output Protection:** Store export files (CSV or Excel) in encrypted volumes or secure file shares
6. **Access Logging:** Enable filesystem auditing for output directories
7. **Module Security:** Use official modules from PowerShell Gallery (Microsoft.Graph.Security, ExchangeOnlineManagement)

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## License & Disclaimer

**License:** MIT License - see [LICENSE](./LICENSE) for full text

**Copyright:** © Microsoft Corporation

**Disclaimer:** This script is provided "AS IS" without warranties or official support. Validate fit for purpose before production use. Not endorsed or officially supported by Microsoft Product Groups. Community-driven maintenance model.

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Additional Resources

### Microsoft Documentation

- **[Microsoft Graph Security API](https://learn.microsoft.com/en-us/graph/api/resources/security-api-overview)** - Graph API security capabilities
- **[AuditLog resource type](https://learn.microsoft.com/en-us/graph/api/resources/auditlog)** - Graph API audit log documentation
- **[Microsoft Purview Audit (Premium)](https://learn.microsoft.com/en-us/purview/audit-premium)** - Overview of audit capabilities
- **[Audit log activities](https://learn.microsoft.com/en-us/purview/audit-log-activities)** - Complete list of auditable activities
- **[Search the audit log](https://learn.microsoft.com/en-us/purview/audit-log-search)** - Audit log search basics
- **[Exchange Online PowerShell](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell)** - Exchange Online module documentation (for EOM mode)

### Related Tools

- **[Power BI](https://powerbi.microsoft.com/)** - Visualize exported audit data
- **[Azure Synapse Analytics](https://azure.microsoft.com/en-us/products/synapse-analytics/)** - Data warehousing for large audit datasets
- **[Microsoft Sentinel](https://azure.microsoft.com/en-us/products/microsoft-sentinel/)** - SIEM integration for audit logs

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Support

For questions or issues, refer to the documentation:

- **Documentation v1.8.0 (Markdown):** [PAX_Purview_Audit_Log_Processor_Documentation_v1.8.0.md](https://github.com/microsoft/PAX/blob/main/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.8.0.md)

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com) with any feedback.*

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

© Microsoft Corporation — MIT Licensed


