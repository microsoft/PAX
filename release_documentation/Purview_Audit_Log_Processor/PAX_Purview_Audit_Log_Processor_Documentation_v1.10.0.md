# Portable Audit eXporter (PAX) - <br/>Purview Audit Log Processor

> **📥 Quick Start:** Download the script → [`PAX_Purview_Audit_Log_Processor_v1.10.3.ps1`](https://github.com/microsoft/PAX/releases/download/purview-v1.10.3/PAX_Purview_Audit_Log_Processor_v1.10.3.ps1)
>
> **📋 Release Notes:** See what's new → [v1.10.x Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.10.0.md) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Purview_Audit_Log_Processor)
>
> **📜 Previous Script Versions:** [All Purview Releases](https://github.com/microsoft/PAX/releases?q=purview-&expanded=true)
>
> **📚 Documentation Archive:** [v1.10.x Documentation](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.10.0.md) | [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Purview_Audit_Log_Processor)

**Script:** `PAX_Purview_Audit_Log_Processor_v1.10.3.ps1`  
**Documentation Version:** 1.10.x  
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
15. [Incremental Data Collection](#incremental-data-collection-appendfile)
16. [Checkpoint & Resume](#checkpoint--resume)
17. [Output Files & Schema](#output-files--schema)
18. [Activity Types Reference](#activity-types-reference)
19. [Record & Service Filters](#record--service-filters)
20. [Microsoft 365 Usage Bundle](#microsoft-365-usage-bundle)
21. [Advanced Features](#advanced-features)
22. [Performance Tuning](#performance-tuning)
23. [Troubleshooting & FAQ](#troubleshooting--faq)
24. [Known Limitations](#known-limitations)
25. [Security & Compliance](#security--compliance)

---

## Overview

<details open>
<summary>What It Does</summary>

The **Portable Audit eXporter (PAX)** is an enterprise-grade PowerShell script that exports Microsoft Purview Unified Audit Log events, with specialized support for Microsoft 365 Copilot activities and related operations. It extends Graph-based retrieval so you can capture classic Microsoft 365 app usage (Word, Excel, PowerPoint, OneNote, Loop, SharePoint, OneDrive, Teams files) in the same run—without falling back to ExchangeOnlineManagement—alongside Copilot telemetry. It transforms raw audit data into analysis-ready CSV or Excel files with enriched metadata, intelligent query optimization, and flexible schema options.

**Core Capabilities:**

- Retrieves audit events from Microsoft 365 Unified Audit Log via **Graph API (default)** or **EOM mode** (`-UseEOM`)
- **Graph API filter passthrough:** Optional `-RecordTypes` / `-ServiceTypes` switches target documented Purview workloads (SharePoint, OneDrive, and future additions) so non-Copilot office app activity returns alongside Copilot operations
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

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Key Features

<details>
<summary>Intelligent Query Management</summary>

- **Adaptive Block Sizing:** Automatically adjusts time window sizes based on data density
- **10K Limit Detection (EOM Mode Only):** Identifies when Microsoft 365 service cap is reached and recommends mitigation (requires `-UseEOM`)
- **1M Limit Detection (Graph API Mode):** Identifies when Graph API's 1,000,000 record per-query limit is reached and auto-subdivides time windows
- **Automatic Subdivision:** Binary/aggressive splitting of dense time periods to maximize completeness
- **Throttle Resilience:** Exponential backoff with jitter for retry operations
- **Volume Classification:** Smart batching based on activity type (High/Medium/Low volume)

</details>

<details>
<summary>Data Processing & Output</summary>

- **Purview Schema Compliance:** Matches Microsoft Purview's canonical exploded schema structure
- **Deep JSON Flattening:** Optional recursive flattening of nested `CopilotEventData` structures
- **Microsoft 365 Usage Bundle:** Single-switch activation (`-IncludeM365Usage`) captures activity types across Outlook, Teams, SharePoint, OneDrive, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, and PowerApps alongside Copilot data
- **Agent Filtering:** Filter records by specific AgentId values or any agent-related activity
- **Record & Service Filters (Graph):** Use `-RecordTypes` / `-ServiceTypes` to retrieve Microsoft 365 app usage workloads (SharePoint, OneDrive, Loop, Files in Teams) without leaving Graph mode
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

- **Parallel Query Execution (PS7+):** Concurrent processing of multiple activity types with controlled throttling
- **Parallel Explosion Processing (PS7+):** Multi-threaded array/conversation explosion using job queue architecture (`-ExplosionThreads`)
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
- Analyze Word, Excel, PowerPoint, OneNote, and Loop document activity by pairing `-ActivityTypes` (e.g., `FileAccessed`, `FilePreviewed`) with `-RecordTypes`/`-ServiceTypes` to capture SharePoint and OneDrive workloads alongside Copilot usage

</details>

<details>
<summary>Microsoft 365 Usage Analytics</summary>

- **Copilot ROI Analysis:** Use `-IncludeM365Usage` to compare user productivity patterns before and after Copilot deployment
- **Cross-Workload Correlation:** Analyze how Copilot usage relates to email (Outlook), collaboration (Teams), and document activity (SharePoint/OneDrive)
- **Adoption Dashboards:** Build comprehensive views spanning activity types across the M365 suite with a single switch
- **Behavioral Insights:** Identify if Copilot changes workflow patterns (more files accessed? fewer emails sent? different collaboration behaviors?)
- **Baseline Establishment:** Use `-IncludeM365Usage -ExcludeCopilotInteraction` to capture pre-Copilot productivity baselines

</details>

<details>
<summary>Compliance & Governance</summary>

- Audit Copilot interactions for regulatory compliance requirements
- Monitor data access patterns and sensitivity indicators
- Track plugin usage and custom GPT deployment
- Generate audit trails for security reviews
- Filter and analyze specific Copilot Studio declarative agent activity
- Expand investigations to include Microsoft 365 productivity apps—SharePoint, OneDrive, and Files in Teams—by applying record/service filters for document operations such as `FileModified` or `FileDownloaded`

</details>

<details>
<summary>Performance & Capacity Planning</summary>

- Track Copilot usage patterns and peak activity periods
- Evaluate load across Office workloads by monitoring file operations returned through `-RecordTypes` / `-ServiceTypes`
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
- Blend Copilot telemetry with Microsoft 365 app usage metrics (SharePoint/OneDrive document interactions, Teams file usage) by leveraging record/service filters before loading into BI platforms

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
| **Graph API Permissions**   | See [Permission Details](#permission-details) below | Required for Graph API mode (default). Consented during interactive sign-in or pre-configured for app registrations. |
| **Audit Role**              | Purview Audit Reader (or higher) | Required for delegated authentication. The Exchange audit backend enforces this role. Not required for app-only (`-Auth AppRegistration`). |
| **Network Access**          | Microsoft 365 endpoints                 | Ensure firewall allows connections to Microsoft Graph and Exchange Online endpoints |
| **Execution Policy**        | Bypass or RemoteSigned                  | See [Authentication Methods](#authentication-methods)        |

**Note:** Graph API mode (default) requires no PowerShell module installation. EOM mode (`-UseEOM`) automatically handles ExchangeOnlineManagement module detection and installation if needed.

<details>
<summary>Permission Details</summary>

**Permissions by Execution Mode:**

| Permission | Purpose | Graph API (Delegated) | Graph API (AppRegistration) | ExchangeOnlineManagement (EOM) |
|------------|---------|:---------------------:|:---------------------------:|:------------------------------:|
| **Graph: AuditLog.Read.All** | General audit log access | ✅ Yes | ✅ Yes | — N/A |
| **Graph: ThreatIntelligence.Read.All** | Required for GET operations (query status checks) | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-Entra.Read.All** | Entra ID (Azure AD) audit logs | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-Exchange.Read.All** | Exchange Online audit logs | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-OneDrive.Read.All** | OneDrive audit logs | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-SharePoint.Read.All** | SharePoint Online audit logs | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Organization.Read.All** | Tenant/organization context, license metadata | ✅ Yes | ✅ Yes | — N/A |
| **Graph: User.Read.All** | Entra user directory, MAC licensing (optional) | ✅ Yes | ✅ Yes | — N/A |
| **Purview Audit Reader** | Backend audit enforcement | ✅ Yes | ❌ No | ✅ Yes |

> **📚 Reference:** [Microsoft Graph Audit Log Query Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditcoreroot-post-auditlogqueries#permissions) | [Get auditLogQuery Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditlogquery-get#permissions)

**Audit Role Requirement and Enforcement Behavior:**

Access to audit data via Microsoft Graph is governed by the same underlying audit authorization used by Microsoft Purview and Exchange Online.

Users running the script with **delegated authentication** must be assigned the **Purview Audit Reader** role (read-only) so that the Exchange audit service recognizes them as authorized to perform audit searches.

When using **application-only authentication** (`-Auth AppRegistration`), audit authorization is evaluated solely against the app's Microsoft Graph permissions, and no user-level audit role is required.

> **⚠️ Troubleshooting: "User is not authorized" or 403 Errors**  
> If the script fails with an error message containing `"User is not authorized for the RBAC roles"` or returns a `403 Forbidden` response during audit queries, this typically indicates a stale role assignment. The Purview Audit Reader role may appear correctly assigned in the Purview portal, but the Exchange audit backend no longer recognizes it.  
> **Fix:** Remove and re-assign the **Purview Audit Reader** role to the user. This refreshes the Exchange audit authorization mapping. No new permissions are required.

**DSPM for AI Access:**
- Same permissions as standard audit access (see table above)
- No additional permissions required for DSPM activity types (`ConnectedAIAppInteraction`, `AIInteraction`, `AIAppInteraction`)

**Entra ID User Enrichment + M365 Copilot Licensing (Optional Feature - Graph API Mode Only):**
- Uses the **User.Read.All** and **Organization.Read.All** permissions (already required for Graph API mode)
- Enabled via `-IncludeUserInfo` or `-OnlyUserInfo` parameters
- Provides access to Entra user attributes AND M365 Copilot (MAC) license information
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
<summary>Show Installation & Setup steps</summary>

### Download the Script

- **Script:** [PAX_Purview_Audit_Log_Processor_v1.10.3.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.10.3/PAX_Purview_Audit_Log_Processor_v1.10.3.ps1)
- **Release Notes:** [v1.10.X](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.10.0.md)

Save the downloaded script to a working directory (e.g., `C:\Scripts\PAX\`).

### First Run (Quick Start)

<details>
<summary>💻 Show Quick Start Commands</summary>

```powershell
# PowerShell 7+ (recommended) - Graph API Mode (Default)
pwsh -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# Windows PowerShell 5.1 - Graph API Mode (Default)
powershell -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

**What Happens:**

1. Script connects to Microsoft Graph Security API
2. Interactive browser sign-in prompt (unless `-Auth` specified)
3. Queries Unified Audit Log for the specified date range
4. Exports to auto-generated filename in `C:\Temp\` (default location, filename varies by activity types and parameters)
5. Creates matching `.log` file with detailed execution metrics

**Note:** For legacy ExchangeOnlineManagement (EOM) mode, add `-UseEOM` parameter. Graph API mode is recommended for better performance and Entra ID enrichment support.

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Parameters Reference

<details>
<summary>📋 Show All Parameters</summary>

**Quick Navigation:**
- [Date & Time Parameters](#date--time-parameters)
- [Output & File Parameters](#output--file-parameters)
- [Authentication Parameters](#authentication-parameters)
- [Query Behavior Parameters](#query-behavior-parameters)
- [CopilotInteraction Control Parameters](#copilotinteraction-control-parameters)
- [Microsoft 365 Usage Parameters](#microsoft-365-usage-parameters)
- [Data Processing Parameters](#data-processing-parameters)
- [Offline Replay Parameters](#offline-replay-parameters)
- [Parallel Execution Parameters](#parallel-execution-parameters-powershell-7-only)
- [Advanced Tuning Parameters](#advanced-tuning-parameters)
- [Observability & Completeness Parameters](#observability--completeness-parameters)
- [Resilience & Recovery Parameters](#resilience--recovery-parameters)
- [Dual-Mode & Enrichment Parameters](#dual-mode--enrichment-parameters)
- [Helper Parameters](#helper-parameters)

---

### Date & Time Parameters

#### `-StartDate` (string)

**Purpose:** UTC start date (inclusive) for audit log query or replay filter  
**Format:** `yyyy-MM-dd` (e.g., `2025-10-01`)  
**Default (Live Mode):** Previous full UTC day if both dates omitted  
**Default (Replay Mode):** No filter applied if omitted  
**Example:** `-StartDate 2025-10-01`

---

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
**Example:** `-OutputPath "D:\AuditData\2025\\"`

---

#### `-AppendFile` (string)

**Purpose:** Append new audit records to an existing output file (CSV or Excel) instead of creating new timestamped files  
**Default:** Not set (creates new timestamped files)  
**Use When:**

- Building continuous audit trails spanning multiple time periods
- Incremental dataset updates for scheduled exports
- Combining offline replay transformations into single output

**Examples:**

- Filename only: `-AppendFile "Report.xlsx"` (uses `-OutputPath` directory)
- Full path: `-AppendFile "C:\Data\\"`

**Notes:**

- See [Incremental Data Collection](#incremental-data-collection-appendfile) section for complete documentation
- Validates header compatibility before appending
- Works with both live query and offline replay modes
- NOT compatible with `-IncludeUserInfo` or `-OnlyUserInfo`

---

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

### Authentication Parameters

#### `-Auth` (string)

**Purpose:** Authentication method for connecting to Microsoft services  
Select the authentication flow that matches your environment (interactive, semi-interactive, or fully unattended). Detailed descriptions and examples for every supported method—including AppRegistration—are available in the [Authentication Methods](#authentication-methods) section.

> **Automation note:** For unattended service principal runs, configure an Entra AD app registration with Microsoft Graph application permissions and use `-Auth AppRegistration` together with `-TenantId`, `-ClientId`, and either `-ClientSecret` or the certificate parameters documented below.

**Valid Values:**  
`WebLogin`, `DeviceCode`, `Credential`, `Silent`, `AppRegistration`

**Default:**  
`WebLogin`

**Use When:**  
Automating scripts, using headless terminals, or SSO scenarios

**Examples:**

- `-Auth WebLogin` – Interactive browser sign-in (default)
- `-Auth DeviceCode` – Device code flow for headless/remote sessions
- `-Auth Credential` – Prompt for username/password (stored in memory only)
- `-Auth Silent` – Attempt cached token (fails if no valid token)
- `-Auth AppRegistration` – Service principal using app registration credentials (see parameters below)

**Notes:**

- Available in both Graph API and EOM modes, except `AppRegistration` (Graph mode only)
- See [Authentication Methods](#authentication-methods) section for detailed guidance
- Not applicable in replay mode (authentication skipped when using `-RAWInputCSV`)

---

#### `-TenantId` (string)

**Purpose:** Entra AD tenant ID (GUID) used when authenticating with `-Auth AppRegistration`  
**Default:** Not set  
**Use When:** Calling the script with service principal credentials  
**Example:** `-Auth AppRegistration -TenantId "00000000-0000-0000-0000-000000000000"`

---

#### `-ClientId` (string)

**Purpose:** Client (application) ID of the Entra AD app registration for `-Auth AppRegistration`  
**Default:** Not set  
**Example:** `-ClientId "11111111-1111-1111-1111-111111111111"`

---

#### `-ClientSecret` (string / secure string)

**Purpose:** Client secret value for service principal authentication  
**Default:** Not set  
**Use When:** Supplying an app secret (convert to a secure string before passing if desired)  
**Example:** `-ClientSecret (ConvertTo-SecureString "<secret>" -AsPlainText -Force)`

---

#### `-ClientCertificateThumbprint` (string)

**Purpose:** Thumbprint of a certificate in the CurrentUser or LocalMachine `My` store for app registration auth  
**Default:** Not set  
**Example:** `-ClientCertificateThumbprint "0123ABCD0123ABCD0123ABCD0123ABCD0123ABCD"`

---

#### `-ClientCertificateStoreLocation` (string)

**Purpose:** Store location used with `-ClientCertificateThumbprint`  
**Valid Values:** `CurrentUser` (default), `LocalMachine`

---

#### `-ClientCertificatePath` (string)

**Purpose:** Path to a PFX file containing the certificate for app registration authentication  
**Default:** Not set  
**Example:** `-ClientCertificatePath "C:\Secrets\PurviewAppCert.pfx"`

---

#### `-ClientCertificatePassword` (secure string)

**Purpose:** Password for the PFX file specified in `-ClientCertificatePath`  
**Default:** Not set  
**Example:** `-ClientCertificatePassword (ConvertTo-SecureString "<pfx-password>" -AsPlainText -Force)`

---

### Query Behavior Parameters

#### `-BlockHours` (double)

**Purpose:** Initial time window size (hours) for each audit query chunk  
**Range:** `0.016667` to `24.0` (1 minute to 24 hours)  
**Default:** `0.5` (30 minutes)  
**Use When:**

- Frequently hitting 10K limit in EOM mode (reduce to 0.25 or lower)
- Frequently hitting 1M limit in Graph API mode for very high-volume tenants (reduce to 0.25 or lower)
- Sparse historical data (increase to 2-8 hours for faster processing)
- Fine-tuning for tenant-specific data density

**Examples:**

- `-BlockHours 0.25` - Dense periods, many records
- `-BlockHours 4.0` - Sparse backfills, low activity

**Notes:** Script learns optimal sizes during execution; this is just the starting point

---

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

---

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

---

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

#### `-RecordTypes` (string[])

**Purpose:** Supplies Microsoft Graph record type identifiers to accompany `-ActivityTypes` when the backend requires explicit `recordTypeFilters` (for example, SharePoint/OneDrive file operations).  
**Default:** Not set (script submits only `operationFilters`).  
**Mode Compatibility:** Graph API mode (default) only; ignored in EOM mode (`-UseEOM`) and offline replay.  
**Use When:**

- Retrieving Microsoft 365 app usage (Word, Excel, PowerPoint, OneNote, Loop) that maps to SharePoint or OneDrive operations
- Targeting legacy operations that require both operation and record type filters to return data (for example, `FilePreviewed`)

**Examples:**

- Single: `-RecordTypes sharePointFileOperation`
- Multiple: `-RecordTypes sharePointFileOperation,onedriveFileOperation`

**Notes:**

- Values are trimmed and deduplicated automatically; empty strings are removed
- Refer to Microsoft Learn for the [record type and service guidance](https://learn.microsoft.com/en-us/purview/audit-log-activities) when locating canonical names
- Incompatible with `-OnlyUserInfo` (audit retrieval disabled in that mode)
- **When `-IncludeM365Usage` is active:** Your specified record types are merged with the bundle's 14 record types (ExchangeAdmin, ExchangeItem, ExchangeMailbox, SharePointFileOperation, SharePointSharingOperation, SharePoint, OneDrive, MicrosoftTeams, OfficeNative, MicrosoftForms, MicrosoftStream, PlannerPlan, PlannerTask, PowerAppsApp). The union is deduplicated automatically.

---

#### `-ServiceTypes` (string[])

**Purpose:** Supplies Microsoft Graph workload/service names to populate the `serviceFilter` field alongside optional record type filters.  
**Default:** Not set (script omits `serviceFilter`).  
**Mode Compatibility:** Graph API mode (default) only; ignored in EOM mode (`-UseEOM`) and offline replay.  
**Use When:**

- Need to point Microsoft Graph toward SharePoint/OneDrive workloads for document activity exports
- Running multi-service comparisons (for example, SharePoint vs. OneDrive) in a single Graph execution

**Examples:**

- Single: `-ServiceTypes SharePoint`
- Multiple: `-ServiceTypes SharePoint,OneDrive`

**Notes:**

- When multiple services are provided, the script submits the array directly; Graph may scope results per service depending on backend rules
- Combine with `-RecordTypes` for the most reliable results when targeting non-Copilot workloads
- Automatically ignored when `-OnlyUserInfo` is supplied
- **When `-IncludeM365Usage` is active:** This parameter is silently ignored and set to `$null` internally. The M365 usage bundle uses record type filtering exclusively (not service filtering) for single-pass query efficiency.

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

### CopilotInteraction Control Parameters

#### `-IncludeCopilotInteraction` (switch)

**Purpose:** Explicitly add CopilotInteraction to the activity list even when providing a custom `-ActivityTypes` array  
**Default:** Off  
**Use When:**

- Combining Copilot telemetry with targeted classic workloads without redefining defaults
- Ensuring CopilotInteraction is included regardless of other activity type selections
- Building mixed exports that include both Copilot and non-Copilot activities

**Example:** `-ActivityTypes FileAccessed,MessageSent -IncludeCopilotInteraction`

**Notes:**
- Additive behavior—does not replace existing activity types
- Works in both live query and replay modes
- If CopilotInteraction is already in the list, no duplicate is added

---

#### `-ExcludeCopilotInteraction` (switch)

**Purpose:** Explicitly remove CopilotInteraction from the final activity list  
**Default:** Off  
**Use When:**

- Using `-IncludeM365Usage` but only want non-AI collaboration signals
- Querying DSPM activity types without M365 Copilot data
- Building exports focused purely on classic M365 workloads

**Examples:**

- `-IncludeM365Usage -ExcludeCopilotInteraction` — Full M365 usage bundle WITHOUT CopilotInteraction
- `-IncludeDSPMForAI -ExcludeCopilotInteraction` — DSPM activity types only

**Notes:**
- Overrides default auto-inclusion of CopilotInteraction
- Removes CopilotInteraction from bundles that include it (like `-IncludeM365Usage`)
- **Conflict Detection:** If used with `-IncludeCopilotInteraction` or explicit CopilotInteraction in `-ActivityTypes`, the script prompts for resolution (or honors `-Force` to exclude)
- Works in both live query and replay modes

---

### Microsoft 365 Usage Parameters

#### `-IncludeM365Usage` (switch)

**Purpose:** Single-switch activation of a curated Microsoft 365 usage bundle spanning Outlook (Exchange), SharePoint, OneDrive, Teams, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, PowerApps, and Copilot  
**Default:** Off  
**Use When:**

- Correlating Copilot usage with actual user productivity patterns
- Building adoption dashboards comparing activity before/after Copilot rollout
- Tracking collaboration patterns alongside AI assistance
- Measuring ROI by comparing activity volumes across M365 workloads
- Understanding if Copilot changes user workflows (more files accessed? fewer emails sent?)

**Activity Types Included:**

| Category | Operations |
|----------|------------|
| Authentication | UserLoggedIn |
| Outlook (Exchange) | MailboxLogin, MailItemsAccessed, Send, SendOnBehalf, SoftDelete, HardDelete, MoveToDeletedItems, CopyToFolder |
| SharePoint/OneDrive (Files) | FileAccessed, FileDownloaded, FileUploaded, FileModified, FileDeleted, FileMoved, FileCheckedIn, FileCheckedOut, FileRecycled, FileRestored, FileVersionsAllDeleted |
| SharePoint/OneDrive (Sharing) | SharingSet, SharingInvitationCreated, SharingInvitationAccepted, SharedLinkCreated, SharingRevoked, AddedToSecureLink, RemovedFromSecureLink, SecureLinkUsed |
| Groups | AddMemberToUnifiedGroup, RemoveMemberFromUnifiedGroup |
| Teams (Team/Channel) | TeamCreated, TeamDeleted, TeamArchived, TeamSettingChanged, TeamMemberAdded, TeamMemberRemoved, MemberAdded, MemberRemoved, MemberRoleChanged, ChannelAdded, ChannelDeleted, ChannelSettingChanged, ChannelOwnerResponded, ChannelMessageSent, ChannelMessageDeleted, BotAddedToTeam, BotRemovedFromTeam, TabAdded, TabRemoved, TabUpdated, ConnectorAdded, ConnectorRemoved, ConnectorUpdated |
| Teams (Chat/Messaging) | TeamsSessionStarted, ChatCreated, ChatRetrieved, ChatUpdated, MessageSent, MessageRead, MessageDeleted, MessageUpdated, MessagesListed, MessageCreation, MessageCreatedHasLink, MessageEditedHasLink, MessageHostedContentRead, MessageHostedContentsListed, SensitiveContentShared |
| Teams (Meetings) | MeetingCreated, MeetingUpdated, MeetingDeleted, MeetingStarted, MeetingEnded, MeetingParticipantJoined, MeetingParticipantLeft, MeetingParticipantRoleChanged, MeetingRecordingStarted, MeetingRecordingEnded, MeetingDetail, MeetingParticipantDetail, LiveNotesUpdate, AINotesUpdate, RecordingExported, TranscriptsExported |
| Teams (Apps/Approvals) | AppInstalled, AppUpgraded, AppUninstalled, CreatedApproval, ApprovedRequest, RejectedApprovalRequest, CanceledApprovalRequest |
| Word, Excel, PowerPoint, OneNote | Create, Edit, Open, Save, Print |
| Forms | CreateForm, EditForm, DeleteForm, ViewForm, CreateResponse, SubmitResponse, ViewResponse, DeleteResponse |
| Stream | StreamModified, StreamViewed, StreamDeleted, StreamDownloaded |
| Planner | PlanCreated, PlanDeleted, PlanModified, TaskCreated, TaskDeleted, TaskModified, TaskAssigned, TaskCompleted |
| PowerApps | LaunchedApp, CreatedApp, EditedApp, DeletedApp, PublishedApp |
| Copilot | CopilotInteraction |

**Record Types Included:**  
ExchangeAdmin, ExchangeItem, ExchangeMailbox, SharePointFileOperation, SharePointSharingOperation, SharePoint, OneDrive, MicrosoftTeams, OfficeNative, MicrosoftForms, MicrosoftStream, PlannerPlan, PlannerTask, PowerAppsApp

**Examples:**

- `-IncludeM365Usage` — Full M365 usage bundle including CopilotInteraction
- `-IncludeM365Usage -ExcludeCopilotInteraction` — M365 collaboration data WITHOUT Copilot signals
- `-IncludeM365Usage -CombineOutput` — Single combined output file with all activity types

**Important Behaviors:**

- **CopilotInteraction included by default:** Use `-ExcludeCopilotInteraction` to remove it from the bundle
- **ServiceTypes automatically set to NULL:** The bundle queries all workloads in a single API pass for efficiency; any `-ServiceTypes` value you provide is silently ignored
- **RecordTypes merged:** If you also specify `-RecordTypes`, your values are merged with the bundle's record types
- **Additive with -ActivityTypes:** If you specify both, the bundle operations are added to your custom list

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

---

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

---

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

---

#### `-MaxParallelGroups` (int)

**Purpose:** Maximum number of activity groups to process concurrently  
**Range:** `1` to `5`  
**Default:** `3`  
**Use When:** Limiting total concurrent operations  
**Example:** `-MaxParallelGroups 2`

---

#### `-ExplosionThreads` (int)

**Purpose:** Control parallel thread count for array/conversation explosion processing  
**Range:** `0` to `8`  
**Default:** `0` (auto-detect based on CPU cores)  
**Mode Compatibility:** PowerShell 7+ only; falls back to serial on PS 5.1  
**Use When:**

- Processing large datasets with `-ExplodeArrays` or `-ExplodeDeep`
- Optimizing explosion throughput on multi-core systems
- Need explicit control over thread utilization

**Value Behaviors:**

| Value | Behavior |
|-------|----------|
| `0` | Auto-detect: Uses 2-8 threads based on CPU core count |
| `1` | Force serial processing (single-threaded) |
| `2-8` | Use exactly N threads for parallel explosion (capped at 8 for stability) |

**Examples:**

- `-ExplosionThreads 0` - Auto-detect optimal thread count (default, recommended)
- `-ExplosionThreads 1` - Force serial explosion (debugging, compatibility)
- `-ExplosionThreads 8` - Use maximum 8 threads for high-core systems

**Notes:**

- Uses `Start-ThreadJob` with job queue architecture for optimal load balancing
- Processes records in ~1000-record chunks with N concurrent workers
- **Full schema discovery:** Parallel mode scans ALL rows for 100% column coverage (serial mode uses sampling via `-StreamingSchemaSample`)
- Output is identical to serial mode (same columns, data, row count; only row order may differ)
- Works with both live query and offline replay modes
- Checkpoint files store `explosionThreads` for resume consistency
- Serial fallback automatic on PowerShell 5.1 or when `-ExplosionThreads 1` specified

---

### Advanced Tuning Parameters

#### `-StreamingSchemaSample` (int)

**Purpose:** Number of initial records to sample for schema discovery (serial mode only)  
**Range:** `100` to `10000`  
**Default:** `5000`  
**Use When:**

- Wide schemas need more samples to discover all columns
- Narrow schemas can use smaller samples for faster processing

**Note:** In parallel mode (PS7+), this parameter is ignored—PAX performs a full scan of ALL rows for 100% column coverage.

**Example:** `-StreamingSchemaSample 5000`

---

#### `-StreamingChunkSize` (int)

**Purpose:** Number of records to write per CSV flush operation  
**Range:** `100` to `20000`  
**Default:** `5000`  
**Use When:**

- Managing memory usage (lower = more frequent flushes)
- Optimizing write performance (higher = fewer I/O operations)

**Example:** `-StreamingChunkSize 10000`

---

#### `-ExportProgressInterval` (int)

**Purpose:** Row interval for export progress updates  
**Range:** `1` to `10000`  
**Default:** `10`  
**Use When:** Need more granular progress updates  
**Example:** `-ExportProgressInterval 5`

---

#### `-LowLatencyMs` (int)

**Purpose:** Threshold (milliseconds) under which recent interactions are considered low latency for adaptive concurrency heuristics.  
**Default:** `20000`  
**Use When:** Adjusting sensitivity of concurrency scaling in very fast or slower tenant conditions.  
**Notes:** Lower = stricter definition of "low latency" (slower growth); higher = more aggressive scaling.  
**Example:** `-LowLatencyMs 15000`

---

#### `-ThroughputDropPct` (int)

**Purpose:** Percentage drop from recent peak throughput (records/sec) that triggers damping of concurrency growth.  
**Default:** `15`  
**Use When:** Reducing false positives (raise value) or increasing responsiveness to regressions (lower value).  
**Example:** `-ThroughputDropPct 20`

---

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

---

#### `-MetricsPath` (string)

**Purpose:** Override default metrics output path and filename  
**Default:** Auto-generated path alongside CSV  
**Use When:** Centralizing metrics, piping to monitoring folder, or storing outside restricted data zone  
**Example:** `-EmitMetricsJson -MetricsPath "C:\Exports\Telemetry\purview_run_20251026.json"`  
**Notes:** Ignored unless `-EmitMetricsJson` is also specified

---

#### `-IncludeTelemetry` (switch)

**Purpose:** Export execution telemetry CSV alongside audit data for performance analysis  
**Default:** Off  
**Mode Compatibility:** Graph API mode only; not available in EOM mode (`-UseEOM`) or `-OnlyUserInfo` mode  
**Use When:**

- Analyzing query execution patterns and partition performance
- Identifying bottlenecks in large-scale exports
- Capacity planning and performance tuning
- Debugging slow or throttled queries

**Example:** `-IncludeTelemetry`

**Output:**

- Creates a separate CSV file: `<OutputFile>_telemetry_<timestamp>.csv`
- One row per partition containing timing and performance metrics
- Includes: partition ID, start/end times, record counts, duration, throughput

**Notes:**

- Always timestamped to prevent overwriting previous telemetry data
- Complements `-EmitMetricsJson` (JSON = session summary; telemetry CSV = partition-level detail)
- Useful for correlating performance with specific time windows or activity types

---

#### `-AutoCompleteness` (switch)

**Purpose:** Recursively subdivide any time windows that still hit the 10K service limit after the initial pass until below limit or safety thresholds reached  
**Default:** Off  
**Use When:** First run (without this switch) exits with code 10 (incomplete) and logs saturated windows  
**Example Workflow:**

1. Initial run: `pwsh -File .\PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-25 -EndDate 2025-10-25 -EmitMetricsJson`
2. If exit code = 10 → re-run: `pwsh -File .\PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-25 -EndDate 2025-10-25 -AutoCompleteness -EmitMetricsJson`

**Notes:**

- Honors minimum window size & max recursion depth to prevent pathological slicing
- Stops early once all previously saturated windows resolve (<10K)
- Exit codes: 0 (success), 10 (incomplete if not invoked), 20 (circuit breaker)
- Prefer narrowing `-BlockHours` first for multi-day very high volume ranges

---

### Resilience & Recovery Parameters

#### `-Resume` (string)

**Purpose:** Resume an interrupted operation from a checkpoint file  
**Default:** Not set  
**Use When:**

- Previous run was interrupted by token expiry (delegated auth modes)
- Network interruption caused early termination
- User chose "Quit and save progress" at token refresh prompt

**IMPORTANT: Resume mode is STANDALONE**

The `-Resume` switch restores ALL settings from the checkpoint file to ensure data consistency. You cannot specify other processing parameters with `-Resume`. This prevents schema mismatches (e.g., first half of data with explosion, second half without).

**Allowed with `-Resume`:**

| Parameter | Purpose |
|-----------|----------|
| `-Resume [path]` | Auto-discover checkpoint or use specific file |
| `-Force` | Use most recent checkpoint without prompting |
| `-Auth` | Override authentication method |
| `-TenantId` | Override tenant ID (for AppRegistration) |
| `-ClientId` | Override client ID (for AppRegistration) |
| `-ClientSecret` | Provide client secret (for AppRegistration) |
| `-ExplosionThreads` | Override thread count for parallel explosion (e.g., resuming on different hardware) |

**NOT Allowed with `-Resume`:**

Any other parameter (dates, activities, explosion settings, M365 bundles, etc.). These are all restored from checkpoint.

**Usage Patterns:**

| Pattern | Description |
|---------|-------------|
| `-Resume` | Auto-discover checkpoint in current directory/OutputPath |
| `-Resume "path\to\file.json"` | Use specific checkpoint file |
| `-Resume -Force` | Use most recent checkpoint without prompting |
| `-Resume -Auth DeviceCode` | Resume with different auth method |
| `-Resume -Auth AppRegistration -ClientId xxx -TenantId yyy` | Resume with AppRegistration (unattended) |

**Checkpoint Behavior:**

- **Created automatically** for all auth modes (WebLogin, DeviceCode, AppRegistration)
- **Enables resume** after Ctrl+C, network failures, token expiry, or any interruption
- **Location:** OutputPath directory as `.pax_checkpoint_<timestamp>.json`
- **Updated:** After each partition completes
- **Deleted:** Automatically on successful run completion
- **Stores ALL parameters:** Complete configuration snapshot for exact restoration

**Examples:**

```powershell
# Auto-discover checkpoint in current directory
.\PAX_Purview_Audit_Log_Processor.ps1 -Resume

# Resume from specific checkpoint file
.\PAX_Purview_Audit_Log_Processor.ps1 -Resume "C:\Temp\.pax_checkpoint_20251215_143022.json"

# Resume with Force (unattended - use most recent)
.\PAX_Purview_Audit_Log_Processor.ps1 -Resume -Force

# Resume with different auth method (e.g., switch to DeviceCode)
.\PAX_Purview_Audit_Log_Processor.ps1 -Resume -Auth DeviceCode

# Resume with AppRegistration for unattended completion
.\PAX_Purview_Audit_Log_Processor.ps1 -Resume -Auth AppRegistration -ClientId "xxx" -TenantId "yyy"
```

**What gets restored from checkpoint:**

| Category | Parameters |
|----------|------------|
| Date Range | StartDate, EndDate |
| Activity Filtering | ActivityTypes, RecordTypes, ServiceTypes, UserIds, GroupNames |
| Agent Filtering | AgentId, AgentsOnly, ExcludeAgents |
| Prompt Filtering | PromptFilter |
| Schema/Explosion | ExplodeArrays, ExplodeDeep, FlatDepth, StreamingSchemaSample, StreamingChunkSize |
| M365/User Info | IncludeM365Usage, IncludeUserInfo, IncludeDSPMForAI |
| Partitioning | BlockHours, PartitionHours, MaxPartitions |
| Output | OutputPath, ExportWorkbook, CombineOutput |
| Other | ResultSize, MaxConcurrency, AutoCompleteness, IncludeTelemetry |

**Notes:**

- Auth parameters can be overridden at resume time for flexibility
- ClientSecret is never stored in checkpoint (security)
- Incompatible with `-RAWInputCSV` (replay mode doesn't use checkpoints)

---

### Dual-Mode & Enrichment Parameters

#### `-UseEOM` (switch)

**Purpose:** Use ExchangeOnlineManagement (EOM) module for audit log retrieval instead of Microsoft Graph API  
**Default:** Off (uses Graph API by default)  
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

---

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

**Schema:** Comprehensive schema including UserPrincipalName, DisplayName, Email, Department, JobTitle, Manager, AssignedLicenses (semicolon-separated M365 licenses), HasLicense (boolean), AccountEnabled, and more

**Notes:**

- One-time Graph API call per unique user in audit dataset
- Minimal performance impact (<5 seconds for typical datasets)
- User data cached for session duration
- **License data:** Retrieved via User.Read.All scope from Microsoft Graph - includes all assigned licenses
- **License detection:** Automatically identifies M365 Copilot entitlements from AssignedLicenses using SKU pattern matching (O365_PREMIUM, M365_F1_COMM, etc.)
- **Power BI Templates:** When importing into Copilot ROI Analytics team Power BI templates, use the same PAX-generated EntraUsers file for both the "User/Org Data" and "Licensing Data" import prompts

---

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
5. **Power BI Templates:** Export user/org/licensing data for Copilot ROI Analytics team templates—use the same output file for both "User/Org Data" and "Licensing Data" import prompts

**Performance:**

- Execution time: 5-15 seconds (vs. minutes/hours for audit queries)
- Network traffic: Minimal (only user directory + license API calls, no audit queries)

**Examples:**

```powershell
# Basic user-only export (CSV)
.\PAX_Purview_Audit_Log_Processor.ps1 -OnlyUserInfo

# Export to Excel workbook
.\PAX_Purview_Audit_Log_Processor.ps1 -OnlyUserInfo -ExportWorkbook

# Custom output directory
.\PAX_Purview_Audit_Log_Processor.ps1 -OnlyUserInfo -OutputPath "D:\LicenseAudits\"

# Device code auth for automation/headless scenarios
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyUserInfo -Auth DeviceCode
```

---

### Helper Parameters

#### `-Help` (switch)

**Purpose:** Display built-in help documentation  
**Example:** `./PAX_Purview_Audit_Log_Processor.ps1 -Help`  
**Use When:** Quick reference without opening documentation

---

#### `-Force` (switch)

**Purpose:** Suppress interactive prompts and auto-resolve conflicts for unattended execution  
**Default:** Off (interactive prompts enabled)  
**Use When:**

- Running in automation, scheduled tasks, or CI/CD pipelines
- Avoiding billing confirmation prompts for DSPM activity types
- Auto-resolving parameter conflicts

**Example:** `-IncludeDSPMForAI -Force`

**Behaviors:**

- Skips DSPM/PAYG billing confirmation prompts
- Honors `-ExcludeCopilotInteraction` without prompting when conflicts detected
- Continues execution without user interaction for all warning scenarios
- Required for headless/non-interactive environments

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Authentication Methods

<details>
<summary>🔐 View Authentication Methods (click to expand)</summary>

The script uses **Microsoft Graph API by default** for audit log retrieval, providing enhanced performance and feature support including Entra ID enrichment and M365 Copilot (MAC) licensing.

**Dual-Mode Architecture:**

- **Graph API Mode (Default):** Modern API with support for `-IncludeUserInfo` (Entra + MAC licensing), better performance, and unified Microsoft 365 access
- **EOM Mode (`-UseEOM`):** Legacy ExchangeOnlineManagement module for compatibility scenarios

**Feature Comparison:**

| Feature | Graph API (Default) | EOM Mode (`-UseEOM`) |
|---------|-------------------|---------------------|
| **Entra ID Enrichment + MAC Licensing** (`-IncludeUserInfo`) | ✅ Supported | ❌ Not supported |
| **Server-Side Group Filtering** (`-GroupNames`) | ❌ Not supported | ✅ Supported |
| **Performance** | Better (modern API) | Good (mature module) |
| **Authentication Methods** | WebLogin, DeviceCode, Credential, Silent, AppRegistration* | WebLogin, DeviceCode, Credential, Silent |
| **Default** | ✅ Yes | Use `-UseEOM` to enable |

**Recommendation:** Use Graph API mode (default) unless you require `-GroupNames` filtering or have legacy constraints.

> **Important:** Graph API mode requires multiple permissions for the Microsoft Purview Audit Search API. See [Permission Details](#permission-details) in the Prerequisites section for the complete list. For delegated authentication (WebLogin, DeviceCode, Credential, Silent), users must also be assigned the **Purview Audit Reader** role (or higher) so that the Exchange audit backend recognizes them as authorized. Application-only authentication (`-Auth AppRegistration`) requires only Graph API permissions—no user-level audit role is needed.

**Required Permissions by Execution Mode:**

| Permission | Purpose | Graph API (Delegated) | Graph API (AppRegistration) | ExchangeOnlineManagement (EOM) |
|------------|---------|:---------------------:|:---------------------------:|:------------------------------:|
| **Graph: AuditLog.Read.All** | General audit log access | ✅ Yes | ✅ Yes | — N/A |
| **Graph: ThreatIntelligence.Read.All** | Required for GET operations (query status checks) | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-Entra.Read.All** | Entra ID (Azure AD) audit logs | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-Exchange.Read.All** | Exchange Online audit logs | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-OneDrive.Read.All** | OneDrive audit logs | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-SharePoint.Read.All** | SharePoint Online audit logs | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Organization.Read.All** | Tenant/organization context, license metadata | ✅ Yes | ✅ Yes | — N/A |
| **Graph: User.Read.All** | Entra user directory, MAC licensing (optional) | ✅ Yes | ✅ Yes | — N/A |
| **Purview Audit Reader** | Backend audit enforcement | ✅ Yes | ❌ No | ✅ Yes |

> **📚 Reference:** [Microsoft Graph Audit Log Query Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditcoreroot-post-auditlogqueries#permissions) | [Get auditLogQuery Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditlogquery-get#permissions)

> **⚠️ Troubleshooting: "User is not authorized" or 403 Errors**  
> If the script fails with an error message containing `"User is not authorized for the RBAC roles"` or returns a `403 Forbidden` response during audit queries, this typically indicates a stale role assignment. The Purview Audit Reader role may appear correctly assigned in the Purview portal, but the Exchange audit backend no longer recognizes it.  
> **Fix:** Remove and re-assign the **Purview Audit Reader** role to the user. This refreshes the Exchange audit authorization mapping. No new permissions are required.

---

*AppRegistration is available only in Graph API mode.*

---

The script supports five authentication methods:

- **WebLogin (Default):** Interactive browser sign-in for admins running the script manually.
- **DeviceCode:** Device-code flow when no browser is available (RDP, SSH, jump hosts).
- **Credential:** Prompts once for username/password and stores it in memory for the session.
- **Silent:** Reuses cached authentication tokens when available (falls back to WebLogin).
- **AppRegistration:** Non-interactive service principal credentials for automation pipelines (Graph mode only).

### Token Refresh Behavior

| Auth Method | Token Lifetime | Refresh Behavior | Long Query Support |
|-------------|---------------|------------------|-------------------|
| WebLogin | ~60-90 min | Silent attempt first, then prompt if needed | Checkpoint/Resume + Incremental saves |
| DeviceCode | ~60-90 min | Silent attempt first, then prompt if needed | Checkpoint/Resume + Incremental saves |
| AppRegistration | ~60-90 min | Proactive @ 45-50 min + Reactive on 401 | No checkpoint needed |
| Credential | Session | Manual re-auth if expired | Limited |
| Silent | Cached | Falls back to WebLogin if expired | Depends on fallback |

**Token Refresh Details:**
- **AppRegistration:** Proactively refreshes token at ~45-50 minutes (before expiry). Also handles 401 errors reactively as a backup. Fully automatic and silent.
- **Interactive (WebLogin/DeviceCode):** On 401 error, first attempts silent refresh using SDK's cached refresh token. Only prompts user if silent refresh fails.
- **403 Forbidden errors:** Indicate a permissions issue, NOT token expiry. Token refresh will not help—check `AuditLog.Read.All` consent and role assignments.

> 💡 **Recommendation:** For long-running queries, use `-Auth AppRegistration` with a service principal for automatic token refresh. For interactive modes (WebLogin/DeviceCode), the script attempts silent token refresh first and only prompts for re-authentication when necessary, with incremental saves ensuring no data loss.

---

**WebLogin (Default)**

Interactive browser-based authentication. Best for ad-hoc queries and interactive sessions.

- **Best for:** Tenant administrators running exploratory or one-off exports with full MFA support.
- **Prerequisites:** Browser access on the host machine, account with required audit permissions, ability to complete interactive MFA prompts.
- **Works in:** Graph API and EOM modes.
- **Automation suitability:** Not intended for automation (requires interactive browser every run).

> 💡 Tip: After a successful WebLogin session on a persistent workstation, you can usually reuse the cached token with `-Auth Silent` for subsequent runs.

<details>
<summary>💻 Show WebLogin Example</summary>

```powershell
./PAX_Purview_Audit_Log_Processor.ps1 -Auth WebLogin -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

<br />

**DeviceCode**

Device code flow for headless/remote sessions or terminals without browser access.

- **Best for:** Jump servers, headless Linux hosts, or when your browser is isolated from the execution environment.
- **Prerequisites:** Access to `https://microsoft.com/devicelogin` from any browser plus the ability to enter the generated device code.
- **Works in:** Graph API and EOM modes.
- **Automation suitability:** Semi-automated; still requires a human to approve each run unless combined with cached tokens (`-Auth Silent`).

> 💡 Tip: Kick off the script on the remote host, complete the device-code prompt once, then rerun future jobs with `-Auth Silent` to avoid repeating the flow.

<details>
<summary>💻 Show DeviceCode Example</summary>

```powershell
./PAX_Purview_Audit_Log_Processor.ps1 -Auth DeviceCode -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

<br />

**Credential**

Username/password prompt. Credentials stored in memory only during script execution.

- **Best for:** Dedicated service accounts that are exempt from MFA or use app passwords (e.g., lab/testing tenants).
- **Prerequisites:** Account with password-based sign-in allowed by tenant policy plus required audit/graph permissions.
- **Works in:** Graph API and EOM modes (fails if tenant enforces MFA without app passwords).
- **Automation suitability:** Short-term or emergency use only—prefer AppRegistration for long-term automation.

> ⚠️ Security note: Credentials gathered via the prompt remain in memory only during execution and are never written to disk, but they are still subject to tenant sign-in policies.

<details>
<summary>💻 Show Credential Example</summary>

```powershell
./PAX_Purview_Audit_Log_Processor.ps1 -Auth Credential -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

<br />

**AppRegistration (Graph mode only)**

Service principal authentication for automation, CI/CD, and headless batch jobs. Requires an Entra AD app registration with Microsoft Graph application permissions aligned with the script’s requirements.

- **Best for:** Fully unattended scheduling (Task Scheduler, Azure Automation, containers) and CI/CD pipelines.
- **Prerequisites:** App registration with Graph application permissions (e.g., `AuditLog.Read.All`, `Directory.Read.All`), admin consent, and either a client secret or certificate.
- **Works in:** Graph API mode only; automatically blocked when `-UseEOM` is supplied.
- **Automation suitability:** Purpose-built for automation with support for secrets, PFX certificates, or certificate thumbprints.

> 💡 Tip: Store secrets or certificate passwords in a secure vault (Azure Key Vault, Windows Credential Manager) and convert them to secure strings at runtime before passing to the script.

<details>
<summary>💻 Show AppRegistration Examples</summary>

```powershell
# Secret-based automation (secure string stored ahead of time)
$clientSecret = ConvertTo-SecureString "<client-secret>" -AsPlainText -Force
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth AppRegistration `
	-TenantId "<tenant-guid>" `
	-ClientId "<app-id>" `
	-ClientSecret $clientSecret `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02

# Certificate-based automation (PFX on disk)
$pfxPassword = ConvertTo-SecureString "<pfx-password>" -AsPlainText -Force
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth AppRegistration `
	-TenantId "<tenant-guid>" `
	-ClientId "<app-id>" `
	-ClientCertificatePath "C:\Certificates\PurviewAutomation.pfx" `
	-ClientCertificatePassword $pfxPassword `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02

# Certificate thumbprint (local cert store)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth AppRegistration `
	-TenantId "<tenant-guid>" `
	-ClientId "<app-id>" `
	-ClientCertificateThumbprint "<thumbprint>" `
	-ClientCertificateStoreLocation "CurrentUser" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02
```

</details>

<br />

**Silent**

Attempts to use cached authentication token. Falls back to WebLogin if no valid token exists.

- **Best for:** Repeat runs on the same host shortly after a successful WebLogin or DeviceCode session.
- **Prerequisites:** A previously cached token for the chosen authentication module (Graph API or EOM). Tokens expire per tenant policy.
- **Works in:** Graph API and EOM modes, matching the most recent interactive login type.
- **Automation suitability:** Useful for short-term automation on persistent machines; tokens expire or invalidate after password resets, consent changes, or policy updates.

> 🔄 Tip: If Silent fails, reauthenticate once with WebLogin or DeviceCode to refresh the cache, then retry the job with `-Auth Silent`.

<details>
<summary>💻 Show Silent Example</summary>

```powershell
./PAX_Purview_Audit_Log_Processor.ps1 -Auth Silent -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Usage Examples

<details>
<summary>📚 View Usage Examples (click to expand)</summary>

### Basic Queries

<details>
<summary>💻 Show Basic Query Examples</summary>

```powershell
# Standard mode - previous day (auto-default)
./PAX_Purview_Audit_Log_Processor.ps1

# Specific date range
./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# Custom output directory
./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputPath "C:\AuditData\"

# Multiple activity types
./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -ActivityTypes CopilotInteraction,MessageSent,FileAccessed
```

</details>

### Microsoft 365 App Usage

<details>
<summary>💻 Show App Usage Filter Examples</summary>

```powershell
# Word/Excel/PowerPoint activity via SharePoint/OneDrive
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-12-01 `
	-EndDate 2025-12-02 `
	-ActivityTypes FileAccessed,FilePreviewed `
	-RecordTypes sharePointFileOperation `
	-ServiceTypes SharePoint,OneDrive `
	-OutputPath "C:\Exports\"

# SharePoint-only pass (omit service filter to test record type alone)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-12-01 `
	-EndDate 2025-12-02 `
	-ActivityTypes FileModified `
	-RecordTypes sharePointFileOperation `
	-OutputPath "C:\Exports\"
```

**Tip:** Pull record type/workload names from the Microsoft Learn [audit log activities](https://learn.microsoft.com/en-us/purview/audit-log-activities) reference. The script logs submitted filters so you can validate backend acceptance.

</details>

### Metrics & Completeness Examples

<details>
<summary>💻 Show Metrics & Completeness Examples</summary>

```powershell
# Emit metrics JSON (default path derived from output directory, includes timestamp)
pwsh -File ./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-05 -EndDate 2025-10-05 -EmitMetricsJson -OutputPath C:\Exports\

# Emit metrics JSON to custom path
pwsh -File ./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-05 -EndDate 2025-10-05 -EmitMetricsJson -MetricsPath C:\Exports\Telemetry\purview_metrics_20251005.json -OutputPath C:\Exports\

# AutoCompleteness remediation (two-run workflow)
# First run (no AutoCompleteness) – may exit with code 10 if saturated windows remain
pwsh -File ./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-07 -EndDate 2025-10-07 -EmitMetricsJson -OutputPath C:\Exports\
# Second run resolves remaining windows
pwsh -File ./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-07 -EndDate 2025-10-07 -AutoCompleteness -EmitMetricsJson -OutputPath C:\Exports\

# Treat exit codes in automation (PowerShell example)
pwsh -File ./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-07 -EndDate 2025-10-07 -EmitMetricsJson
if ($LASTEXITCODE -eq 10) { Write-Host 'Incomplete export detected – re-run with -AutoCompleteness' -ForegroundColor Yellow }
elseif ($LASTEXITCODE -eq 20) { Write-Host 'Circuit breaker tripped – investigate throttling or reduce concurrency' -ForegroundColor Red }
```

</details>

### Exploded Schema Queries

<details>
<summary>💻 Show Exploded Schema Examples</summary>

```powershell
# Array explosion (35-column Purview schema)
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02

# Deep flatten (maximum column extraction)
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

### Performance Tuning

<details>
<summary>💻 Show Performance Tuning Examples</summary>

```powershell
# Reduce block size for dense data (hitting 10K limit)
./PAX_Purview_Audit_Log_Processor.ps1 -BlockHours 0.25 -StartDate 2025-10-01 -EndDate 2025-10-01

# Increase block size for sparse historical data
./PAX_Purview_Audit_Log_Processor.ps1 -BlockHours 4.0 -StartDate 2025-09-01 -EndDate 2025-09-07

# Add pacing to reduce throttling
./PAX_Purview_Audit_Log_Processor.ps1 -PacingMs 250 -StartDate 2025-10-01 -EndDate 2025-10-02

# Parallel explosion for large datasets (PS7+ only)
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeDeep -ExplosionThreads 8 -StartDate 2025-10-01 -EndDate 2025-10-31
```

</details>

### Parallel Execution (PowerShell 7+ only)

<details>
<summary>💻 Show Parallel Execution Examples</summary>

**Query Parallelism (Multiple Activity Types):**

```powershell
# Auto-detect parallel benefit
./PAX_Purview_Audit_Log_Processor.ps1 -ParallelMode Auto -ActivityTypes CopilotInteraction,MessageSent,FileAccessed

# Force parallel with custom concurrency
./PAX_Purview_Audit_Log_Processor.ps1 -ParallelMode On -MaxConcurrency 4 -MaxParallelGroups 2 -ActivityTypes CopilotInteraction,MessageSent,FileAccessed
```

**Explosion Parallelism (Array/Conversation Processing):**

```powershell
# Auto-detect explosion threads (default, recommended)
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeDeep -ExplosionThreads 0 -StartDate 2025-10-01 -EndDate 2025-10-08

# Explicit 8-thread explosion for large datasets
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeDeep -ExplosionThreads 8 -StartDate 2025-10-01 -EndDate 2025-10-31

# Force serial explosion (debugging or compatibility)
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeArrays -ExplosionThreads 1 -StartDate 2025-10-01 -EndDate 2025-10-02

# Combined: parallel queries + parallel explosion
./PAX_Purview_Audit_Log_Processor.ps1 -ParallelMode On -MaxConcurrency 4 -ExplodeDeep -ExplosionThreads 8 -ActivityTypes CopilotInteraction,ConnectedAIAppInteraction
```

</details>

### Offline Replay

<details>
<summary>💻 Show Offline Replay Examples</summary>

```powershell
# Basic replay (forced explosion) - creates timestamped output file
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\PreviousExports\\" -OutputPath "C:\AuditData\"

# Replay with deep flatten and date filtering
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\PreviousExports\\" -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputPath "C:\AuditData\"

# Replay with parallel explosion (PS7+ only, large datasets)
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\PreviousExports\\" -ExplodeDeep -ExplosionThreads 8 -OutputPath "C:\AuditData\"

# Replay with activity filtering
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\PreviousExports\\" -ActivityTypes CopilotInteraction -OutputPath "C:\AuditData\"

# Replay with agent filtering (any agent)
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\PreviousExports\\" -AgentsOnly -OutputPath "C:\AuditData\"


# Replay with specific agent ID
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\PreviousExports\\" -AgentId "CopilotStudio.Declarative.T_4e671777-fa6c-601a-b416-df08b6ae4c14.03dc0b8b-a75a-4b77-86d7-98185a176d1b" -OutputPath "C:\AuditData\\"
```

</details>

### Agent Filtering (Live & Replay)

<details>
<summary>💻 Show Agent Filtering Examples</summary>

```powershell
# Filter for any agent-related records (live query)
./PAX_Purview_Audit_Log_Processor.ps1 -AgentsOnly -StartDate 2025-10-01 -EndDate 2025-10-02

# Filter for specific agent ID(s)
./PAX_Purview_Audit_Log_Processor.ps1 -AgentId "SYSTEM_CreateGPT.declarativeCopilot" -StartDate 2025-10-01 -EndDate 2025-10-02

# Multiple agent IDs with deep flatten
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeDeep -AgentId "SYSTEM_CreateGPT.declarativeCopilot","CopilotStudio.Declarative.T_..." -StartDate 2025-10-01 -EndDate 2025-10-02

# Agent filtering in replay mode
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\PreviousExports\\" -AgentsOnly -OutputPath "C:\AuditData\\"
```

</details>

### Entra ID Enrichment & Dual-Mode

<details>
<summary>💻 Show Entra Enrichment & EOM Mode Examples</summary>

```powershell
# Enrich with Entra ID user data (Graph API mode - default)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeUserInfo `
	-OutputPath "C:\Exports\\"
# Output: CopilotInteraction_<timestamp>.csv + EntraUsers_MAClicensing_<timestamp>.csv

# Entra enrichment with Excel export (embedded tab)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeUserInfo `
	-ExportWorkbook `
	-CombineOutput
# Output: Purview_Audit_CombinedUsageActivity_EntraUsers_MAClicensing_<timestamp>.xlsx (with EntraUsers_MAClicensing tab)

# Use EOM mode for GroupNames filtering (legacy mode)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UseEOM `
	-GroupNames "Sales Team","Marketing Team" `
	-OutputPath "C:\Exports\\"

# Increase network resilience timeout (for unstable connections)
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 -Auth DeviceCode -StartDate 2025-10-01 -EndDate 2025-10-02

# Credential prompt
./PAX_Purview_Audit_Log_Processor.ps1 -Auth Credential -StartDate 2025-10-01 -EndDate 2025-10-02

# Silent (cached token)
./PAX_Purview_Audit_Log_Processor.ps1 -Auth Silent -StartDate 2025-10-01 -EndDate 2025-10-02

# AppRegistration (fully unattended)
$clientSecret = ConvertTo-SecureString "<client-secret>" -AsPlainText -Force
./PAX_Purview_Audit_Log_Processor.ps1 -Auth AppRegistration -TenantId "<tenant-guid>" -ClientId "<app-id>" -ClientSecret $clientSecret -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentsOnly `
	-OutputPath "C:\Exports\\"

# Filter for specific AgentId (single)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentId "CopilotStudio.Declarative.a1b2c3d4" `
	-OutputPath "C:\Exports\\"

# Filter for multiple specific AgentIds
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentId "CopilotStudio.Declarative.agent1","CopilotStudio.Declarative.agent2","CustomAgent.xyz" `
	-OutputPath "C:\Exports\\"

# Replay mode: Filter agents from previously exported data
./PAX_Purview_Audit_Log_Processor.ps1 `
	-RAWInputCSV "C:\Exports\\" `
	-AgentsOnly `
	-ExplodeDeep `
	-OutputPath "C:\Exports\\"

# Replay mode: Filter specific AgentId from previously exported data
./PAX_Purview_Audit_Log_Processor.ps1 `
	-RAWInputCSV "C:\Exports\\" `
	-AgentId "CopilotStudio.Declarative.a1b2c3d4" `
	-OutputPath "C:\Exports\\"

# Combine with deep explosion for maximum analysis detail
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "john.doe@contoso.com" `
	-OutputPath "C:\Exports\\"

# Filter for multiple users (live mode)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "john.doe@contoso.com","jane.smith@contoso.com","bob.jones@contoso.com" `
	-OutputPath "C:\Exports\\"

# Filter for a distribution group (EOM mode only - requires -UseEOM)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UseEOM `
	-GroupNames "Engineering-Team@contoso.com" `
	-OutputPath "C:\Exports\\"

# Filter for multiple groups (EOM mode only - requires -UseEOM)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UseEOM `
	-GroupNames "Sales@contoso.com","Marketing@contoso.com" `
	-OutputPath "C:\Exports\\"

# Combine UserIds and GroupNames (EOM mode only - requires -UseEOM)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UseEOM `
	-UserIds "ceo@contoso.com","cfo@contoso.com" `
	-GroupNames "ExecutiveTeam@contoso.com" `
	-OutputPath "C:\Exports\\"

# Replay mode: Filter users from previously exported data
./PAX_Purview_Audit_Log_Processor.ps1 `
	-RAWInputCSV "C:\Exports\\" `
	-UserIds "john.doe@contoso.com","jane.smith@contoso.com" `
	-OutputPath "C:\Exports\\"

# Combine with agent filtering for targeted analysis
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExplodeArrays `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Export only Copilot responses
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExplodeArrays `
	-PromptFilter Response `
	-OutputPath "C:\Exports\\"

# Combine with agent filtering: Agent prompts only
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExplodeArrays `
	-AgentsOnly `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Replay mode: Filter prompts from previous export
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExplodeArrays `
	-AgentsOnly `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Non-agent interactions only, prompts only
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "poweruser@contoso.com" `
	-AgentsOnly `
	-OutputPath "C:\Exports\\"

# Executive team with specific declarative agent
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-GroupNames "Sales Team" `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Individual user's full conversations (prompts + responses, no resource rows)
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentId "CopilotStudio.Declarative.SalesAssistant" `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Agent responses only (for quality/latency analysis)
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-GroupNames "Marketing Team" `
	-AgentId "ContentCreation.Agent" `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Executive team's full conversations with all agents
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-RAWInputCSV "C:\Exports\\" `
	-UserIds "poweruser@contoso.com","analyst@contoso.com" `
	-AgentsOnly `
	-PromptFilter Both `
	-OutputPath "C:\Exports\\"

# Replay: User + PromptFilter (client-side user filtering from JSON)
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeDSPMForAI

# DSPM with existing activity types (additive)
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeDSPMForAI
# Output: Purview_DSPM_Export_20251030_143022.csv (all activities)

# Separate mode
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
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

	# Certificate thumbprint (local cert store)

```powershell
# Audit specific user's AI interactions
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "executive@contoso.com" `
	-IncludeDSPMForAI

# Audit executive team's DSPM AI usage
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExportWorkbook
# Output: Purview_Export_20251030_143022.xlsx
# Tabs: CopilotInteraction

# Multi-activity multi-tab export
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ActivityTypes CopilotInteraction,MessageSent,FileAccessed `
	-ExportWorkbook
# Output: Purview_Export_20251030_143022.xlsx
# Tabs: CopilotInteraction, MessageSent, FileAccessed

# DSPM multi-tab export
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExportWorkbook `
	-CombineOutput
# Output: Purview_Audit_CombinedUsageActivity_<timestamp>.xlsx
# Tab: CombinedUsageActivity

# DSPM combined export
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-06 `
	-EndDate 2025-10-13 `
	-ExportWorkbook `
	-OutputPath "C:\Reports\\"

# Monday: Week 2 append
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
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

## Incremental Data Collection

<details>
<summary>📂 View Incremental Data Collection guidance (click to expand)</summary>

### Overview

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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate (Get-Date).AddDays(-1) `
	-EndDate (Get-Date) `
	-ExportWorkbook `
	-CombineOutput `
	-OutputPath "C:\AuditArchive"
# Creates: Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx

# Daily append (scheduled task)
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-31 `
	-ExportWorkbook `
	-CombineOutput

# Phase 2: Offline replay with deep explosion (specific week only)
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-ExportWorkbook `
	-CombineOutput `
	-OutputPath "C:\Customers\CustomerA"
# Creates: Purview_Audit_CombinedUsageActivity_20251110_143022.xlsx

# Customer A - Tenant 1 (append Week 2)
./PAX_Purview_Audit_Log_Processor.ps1 `
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
.\PAX_Purview_Audit_Log_Processor.ps1 ... -AppendFile "C:\temp\Report.xlsx"

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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-08 `
	-ExportWorkbook `
	-CombineOutput `
	-OutputPath "C:\Reports"
# Output: Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx

# Week 2: Append
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-08 `
	-EndDate 2025-10-15 `
	-ExportWorkbook `
	-CombineOutput `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx" `
	-OutputPath "C:\Reports"

# Week 3: Append
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-08 `
	-ActivityTypes CopilotInteraction `
	-CombineOutput `
	-OutputPath "C:\Data"
# Output: Purview_Audit_CombinedUsageActivity_20251110_080000.csv

# Append: All users, Week 2
./PAX_Purview_Audit_Log_Processor.ps1 `
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
./PAX_Purview_Audit_Log_Processor.ps1 `
	-RAWInputCSV "C:\RawExports\October_Raw.csv" `
	-ExportWorkbook `
	-CombineOutput
# Output: Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx

# Append: Transform November data to same workbook
./PAX_Purview_Audit_Log_Processor.ps1 `
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
$scriptPath = "C:\Scripts\PAX_Purview_Audit_Log_Processor.ps1"
$outputPath = "C:\AuditArchive"
$fileName = "Annual_Audit_2025.xlsx"
$serviceAccountPassword = ConvertTo-SecureString "<service-account-password>" -AsPlainText -Force

# Task action
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument @"
-NoProfile -Command "$scriptPath -StartDate (Get-Date).AddDays(-1) -EndDate (Get-Date) -ExportWorkbook -CombineOutput -AppendFile '$fileName' -OutputPath '$outputPath' -Silent"
"@

# Task trigger (daily 2 AM)
$trigger = New-ScheduledTaskTrigger -Daily -At 2am

# Register task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -User "DOMAIN\ServiceAccount" -Password $serviceAccountPassword

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

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Checkpoint & Resume

<details>
<summary>💾 View Checkpoint & Resume Details (Click to Expand)</summary>

### Overview

PAX automatically saves progress during long-running operations for all authentication modes. This enables resumption after Ctrl+C, network failures, token expiry, or any interruption without losing completed work.

### When Checkpoints Are Created

| Authentication Mode | Checkpoint Created | Reason |
|--------------------|--------------------|--------|
| WebLogin | ✅ Yes | Enables resume after any interruption |
| DeviceCode | ✅ Yes | Enables resume after any interruption |
| AppRegistration | ✅ Yes | Enables resume after any interruption |

### Checkpoint Lifecycle

1. **Creation:** Checkpoint file created at start of Graph API query execution
2. **Updates:** Saved after each partition completes successfully
3. **Location:** `<OutputPath>\.pax_checkpoint_<timestamp>.json`
4. **Deletion:** Automatically removed on successful run completion

### Incremental Data Saves

To prevent data loss during authentication failures or interruptions, PAX saves completed partition data immediately to disk in a hidden incremental folder:

| Item | Details |
|------|--------|
| **Location** | `<OutputPath>\.pax_incremental\` (hidden folder) |
| **Format** | JSON Lines (JSONL) files named `Part<N>_<timestamp>_<count>records.jsonl` |
| **When Created** | After each partition completes successfully |
| **Purpose** | Ensures no data loss if authentication expires mid-run |
| **Cleanup** | Automatically merged into final output and deleted on successful completion |

**Recovery Scenario:** If a run is interrupted and you cannot resume:
1. The `.pax_incremental` folder contains JSONL files with completed partition data (one record per line)
2. Each file can be opened and processed manually if needed
3. Files are automatically merged and deduplicated when using `-Resume`

> ⚠️ **Important:** Do not delete the `.pax_incremental` folder during an active run or before resuming an interrupted run, as it contains your retrieved data.

### Token Refresh Prompts

When using delegated authentication (WebLogin/DeviceCode), PAX uses **reactive** token refresh detection with a **silent-first** approach. Instead of prompting at a fixed time interval, the script monitors for 401 Unauthorized errors indicating the token has actually expired. When detected:

1. **Immediate pause:** Job monitoring pauses to prevent further failed requests
2. **Silent refresh attempt:** Script first attempts to refresh using SDK's cached refresh token (no user interaction)
3. **Prompt only if needed:** If silent refresh fails, user is prompted to re-authenticate or quit
4. **No data loss:** Completed partitions are saved incrementally, and the failed partition is marked for retry
5. **Seamless resume:** After re-authentication, execution continues automatically with failed partitions retried

This reactive approach is more reliable than time-based prompts because token lifetimes vary by tenant configuration (typically 60-90 minutes, but can be shorter).

> ⚠️ **401 vs 403 Errors:** PAX differentiates between these error types:
> - **401 Unauthorized:** Token expired or invalid → Token refresh will help
> - **403 Forbidden:** Permissions issue → Token refresh will NOT help. Check `AuditLog.Read.All` consent and role assignments.

### Resume Mode: Standalone Behavior

**IMPORTANT:** The `-Resume` switch is standalone. All processing parameters are restored from the checkpoint file to ensure data consistency. You cannot specify other parameters with `-Resume` (except authentication overrides).

**Allowed with `-Resume`:**
- `-Force` - Use most recent checkpoint without prompting
- `-Auth` - Override authentication method
- `-TenantId`, `-ClientId`, `-ClientSecret` - Auth credentials for AppRegistration
- `-ExplosionThreads` - Override thread count for parallel explosion (e.g., resuming on different hardware)

**NOT Allowed with `-Resume`:**
- Any other parameter (dates, activities, explosion settings, etc.)

This restriction prevents schema inconsistencies, such as first half of data exported with explosion and second half without.

### Resume Workflow

**Scenario:** Run interrupted after 2 hours due to token expiry

```powershell
# Original run (interrupted)
.\PAX_Purview_Audit_Log_Processor.ps1 `
    -StartDate 2025-12-01 `
    -EndDate 2025-12-15 `
    -ExplodeDeep `
    -IncludeM365Usage `
    -OutputPath C:\Exports\

# Resume - ALL settings restored from checkpoint
.\PAX_Purview_Audit_Log_Processor.ps1 -Resume

# Resume with different auth method
.\PAX_Purview_Audit_Log_Processor.ps1 -Resume -Auth DeviceCode

# Resume with AppRegistration for unattended completion
.\PAX_Purview_Audit_Log_Processor.ps1 -Resume -Auth AppRegistration -ClientId "xxx" -TenantId "yyy"
```

### Resume Options

| Option | Behavior |
|--------|----------|
| `-Resume` | Auto-discover checkpoint in current directory; prompts if multiple found |
| `-Resume "path\to\file.json"` | Use specific checkpoint file |
| `-Resume -Force` | Use most recent checkpoint without prompting |
| `-Resume -Auth <method>` | Resume with different authentication method |

### What Gets Restored

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
| Auth (method only) | Auth, TenantId, ClientId (no secrets) |
| Partition State | Completed partitions, query IDs, record counts |

### Best Practices

1. **Use AppRegistration for long queries:** Tokens refresh automatically, no checkpoints needed
2. **React quickly to auth prompts:** When a 401 error triggers the reauth prompt, re-authenticate promptly to minimize failed partitions
3. **Keep OutputPath accessible:** Resume requires access to checkpoint file location
4. **Verify completion:** Check final output for expected record counts
5. **Change auth if needed:** Use `-Resume -Auth DeviceCode` to switch auth methods
6. **Incremental saves protect data:** Completed partition data is saved immediately, so even if auth fails, no data is lost

### Checkpoint File Format (v2)

```json
{
  "version": 2,
  "runTimestamp": "20251215_143022",
  "created": "2025-12-15T14:30:22.000Z",
  "lastUpdated": "2025-12-15T15:45:00.000Z",
  "parameters": {
    "startDate": "2025-12-01T00:00:00Z",
    "endDate": "2025-12-15T00:00:00Z",
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
    "partialCsv": "Purview_Audit_CopilotInteraction_PARTIAL_20251215_143022.csv",
    "finalCsv": "Purview_Audit_CopilotInteraction_20251215_143022.csv"
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

</details>

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
| `Email` | Email address | `jane.smith@contoso.com` |
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
| `AssignedLicenses` | All licenses (semicolon-separated) | `Office 365 E5;Microsoft 365 Copilot` |
| `HasLicense` | M365 Copilot license | `True` or `False` |
| `LicenseCount` | Total licenses | `5` |
| `ManagerID` | Manager Entra ID | `a1b2c3d4-...` |
| `BusinessAreaLabel` | Business area/division | `Engineering` |
| `CountryofEmployment` | Country of employment | `United States` |
| `CompanyCodeLabel` | Company code/name | `Contoso Corporation` |
| `CostCentreLabel` | Cost center | `CC1234` |
| `UserName` | User display name | `Jane Smith` |
| `EffectiveDate` | Effective date (HR systems) | (null) |
| `FunctionType` | Function type (HR systems) | (null) |
| `BusinessAreaCode` | Business area code (HR systems) | (null) |
| `OrgLevel_3Label` | Org level 3 (HR systems) | (null) |
| ... (additional extended attributes) | ... | ... |

**License Detection Logic:**

The script automatically detects Microsoft 365 Copilot licenses using SKU pattern matching:

- `SPE_E3_RPA1`, `SPE_E5_RPA1` - Copilot for Enterprise E3/E5
- `O365_PREMIUM`, `M365_F1_COMM`, `M365_F3_COMM` - Commercial licenses with Copilot entitlements
- Additional SKUs: `MICROSOFT_BUSINESS_CENTER`, `TEAMS_COMMERCIAL_TRIAL`, etc.

`HasLicense` column: `True` if any matching SKU detected, `False` otherwise

---

### Usage Examples

<details>
<summary>💻 Show Entra Enrichment Examples</summary>

```powershell
# Basic Entra enrichment (CSV mode)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeUserInfo
# Output: CopilotInteraction_<timestamp>.csv + EntraUsers_MAClicensing_<timestamp>.csv

# Entra enrichment with Excel (embedded tab)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeUserInfo `
	-ExportWorkbook `
	-CombineOutput
# Output: Purview_Audit_CombinedUsageActivity_EntraUsers_MAClicensing_<timestamp>.xlsx
# Tabs: CombinedUsageActivity, EntraUsers_MAClicensing

# Entra enrichment with DSPM activities
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeDSPMForAI `
	-IncludeUserInfo `
	-ExportWorkbook
# Output: Purview_DSPM_Export_<timestamp>.xlsx
# Tabs: CopilotInteraction, ConnectedAIAppInteraction, AIInteraction, AIAppInteraction, EntraUsers_MAClicensing

# Entra enrichment with exploded schema
./PAX_Purview_Audit_Log_Processor.ps1 `
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
2. Filter EntraUsers by `HasLicense`
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
4. **License Auditing:** Export EntraUsers separately and audit `HasLicense` against actual license assignments
5. **Power BI Templates:** When importing into Copilot ROI Analytics team Power BI templates, use the same PAX-generated EntraUsers file for both the "User/Org Data" and "Licensing Data" import prompts—the file contains all required columns for both

**Troubleshooting:**

- **Error: "Entra enrichment requires Graph API mode"** → Remove `-UseEOM` parameter
- **Error: "Insufficient privileges to complete the operation"** → Grant `User.Read.All` and `Organization.Read.All` Graph API permissions
- **Empty HasLicense:** Update SKU detection list in script if new Copilot SKUs released

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

## Record & Service Filters

<details>
<summary>📄 View Record & Service Filter Guide (Click to Expand)</summary>

### Overview

Two optional switches—`-RecordTypes` and `-ServiceTypes`—pass Microsoft Graph `recordTypeFilters` and `serviceFilter` values directly to the audit query body. Use them to unlock classic Microsoft 365 app usage telemetry (Word, Excel, PowerPoint, OneNote, Loop, SharePoint, OneDrive, and Teams files) that sometimes requires explicit workload targeting when using the Graph Security endpoint.

- **Graph-only:** The switches are honored in Graph API mode (default). They are ignored automatically in EOM mode (`-UseEOM`) and replay mode.
- **Optional behavior:** If omitted, the script submits only `operationFilters`, matching prior behavior.
- **Automatic sanitation:** Empty strings are removed, casing is preserved, and duplicate values are deduplicated before dispatching queries.

### Parameter Summary

| Parameter | Scope | Description | Example |
| --- | --- | --- | --- |
| `-RecordTypes <string[]>` | Graph API | Supplies one or more record type identifiers (for example, `sharePointFileOperation`, `onedriveFileOperation`). | `-RecordTypes sharePointFileOperation` |
| `-ServiceTypes <string[]>` | Graph API | Supplies one or more workload names that align with Microsoft Purview audit services (for example, `SharePoint`, `OneDrive`). | `-ServiceTypes SharePoint,OneDrive` |

**Tip:** Reference Microsoft Learn for the [record type and service guidance](https://learn.microsoft.com/en-us/purview/audit-log-activities) when assembling your filter lists.

### Example: Office File Activity via Graph API

```powershell
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-12-01 `
	-EndDate 2025-12-02 `
	-ActivityTypes FileAccessed,FilePreviewed `
	-RecordTypes sharePointFileOperation `
	-ServiceTypes SharePoint,OneDrive `
	-OutputPath "C:\Exports\"
```

This query targets SharePoint/OneDrive file operations—surfacing Word, Excel, PowerPoint, and OneNote activity—while still honoring any Copilot operations listed in `-ActivityTypes`.

### Best Practices

- **Pair with `-ActivityTypes`:** Provide the audit operations you care about (for example, `FileModified`, `TeamFileDownloaded`) alongside the matching record type/service values.
- **Start broad, refine later:** If unsure which service is correct, begin with a single record type and omit `-ServiceTypes`, then add the service filter once validated in Purview UI.
- **Monitor logs:** The script logs the exact filters submitted and the filters stored by Microsoft Graph, making it easy to confirm backend acceptance.
- **Parallel friendly:** Filters are applied per partition; existing concurrent query behavior is unchanged.

### Troubleshooting Checklist

- Empty responses with non-Copilot operations? Add the documented record type/service pair to `-RecordTypes` / `-ServiceTypes`.
- Receiving an error about unsupported parameters? Ensure `-OnlyUserInfo` is not specified (it blocks audit retrieval and rejects these switches).
- Seeing unexpected services in verification logs? Confirm casing and spelling in Purview or Microsoft Learn documentation.

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Microsoft 365 Usage Bundle

<details>
<summary>📊 View Microsoft 365 Usage Bundle Guide (Click to Expand)</summary>

### Overview

The `-IncludeM365Usage` switch activates a curated bundle of activity types spanning the core Microsoft 365 productivity suite. This single-switch activation replaces the need to manually specify dozens of individual activity types and their corresponding record types.

**Why Use This Bundle?**

- **Adoption Analytics:** Correlate Copilot usage with actual productivity patterns across Outlook, Teams, SharePoint, and Office apps
- **ROI Measurement:** Compare activity volumes before and after Copilot deployment to measure workflow impact
- **Behavioral Insights:** Understand if Copilot changes how users interact with M365 (more files accessed? fewer emails sent? different collaboration patterns?)
- **Single-Pass Efficiency:** Retrieve all activity types in one API call instead of multiple queries

### Activity Types by Category

The bundle includes activities from 11 categories:

#### Authentication

| Operation | Description |
|-----------|-------------|
| UserLoggedIn | User sign-in to Microsoft 365 |

#### Outlook / Exchange

| Operation | Description |
|-----------|-------------|
| MailboxLogin | User accessed mailbox |
| MailItemsAccessed | Email items accessed (read/preview) |
| Send | Email sent |
| SendOnBehalf | Email sent on behalf of another user |
| SoftDelete | Item moved to Deleted Items |
| HardDelete | Item permanently deleted |
| MoveToDeletedItems | Item moved to Deleted Items folder |
| CopyToFolder | Item copied to folder |

#### SharePoint / OneDrive - Files

| Operation | Description |
|-----------|-------------|
| FileAccessed | File accessed |
| FileDownloaded | File downloaded |
| FileUploaded | File uploaded |
| FileModified | File modified |
| FileDeleted | File deleted |
| FileMoved | File moved |
| FileCheckedIn | File checked in |
| FileCheckedOut | File checked out |
| FileRecycled | File moved to recycle bin |
| FileRestored | File restored from recycle bin |
| FileVersionsAllDeleted | All file versions deleted |

#### SharePoint / OneDrive - Sharing

| Operation | Description |
|-----------|-------------|
| SharingSet | Sharing permissions set |
| SharingInvitationCreated | Sharing invitation created |
| SharingInvitationAccepted | Sharing invitation accepted |
| SharedLinkCreated | Shared link created |
| SharingRevoked | Sharing permissions revoked |
| AddedToSecureLink | User added to secure link |
| RemovedFromSecureLink | User removed from secure link |
| SecureLinkUsed | Secure link accessed |

#### Groups

| Operation | Description |
|-----------|-------------|
| AddMemberToUnifiedGroup | Member added to M365 group |
| RemoveMemberFromUnifiedGroup | Member removed from M365 group |

#### Teams - Team/Channel

| Operation | Description |
|-----------|-------------|
| TeamCreated | Team created |
| TeamDeleted | Team deleted |
| TeamArchived | Team archived |
| TeamSettingChanged | Team settings changed |
| TeamMemberAdded | Member added to team |
| TeamMemberRemoved | Member removed from team |
| MemberAdded | Member added |
| MemberRemoved | Member removed |
| MemberRoleChanged | Member role changed |
| ChannelAdded | Channel added |
| ChannelDeleted | Channel deleted |
| ChannelSettingChanged | Channel settings changed |
| ChannelOwnerResponded | Channel owner responded |
| ChannelMessageSent | Message sent in channel |
| ChannelMessageDeleted | Message deleted in channel |
| BotAddedToTeam | Bot added to team |
| BotRemovedFromTeam | Bot removed from team |
| TabAdded | Tab added to channel |
| TabRemoved | Tab removed from channel |
| TabUpdated | Tab updated |
| ConnectorAdded | Connector added |
| ConnectorRemoved | Connector removed |
| ConnectorUpdated | Connector updated |

#### Teams - Chat/Messaging

| Operation | Description |
|-----------|-------------|
| TeamsSessionStarted | Teams session started |
| ChatCreated | Chat created |
| ChatRetrieved | Chat retrieved |
| ChatUpdated | Chat updated |
| MessageSent | Message sent |
| MessageRead | Message read |
| MessageDeleted | Message deleted |
| MessageUpdated | Message updated |
| MessagesListed | Messages listed |
| MessageCreation | Message created |
| MessageCreatedHasLink | Message created with link |
| MessageEditedHasLink | Message edited with link |
| MessageHostedContentRead | Hosted content read |
| MessageHostedContentsListed | Hosted contents listed |
| SensitiveContentShared | Sensitive content shared |

#### Teams - Meetings

| Operation | Description |
|-----------|-------------|
| MeetingCreated | Meeting created |
| MeetingUpdated | Meeting updated |
| MeetingDeleted | Meeting deleted |
| MeetingStarted | Meeting started |
| MeetingEnded | Meeting ended |
| MeetingParticipantJoined | Participant joined meeting |
| MeetingParticipantLeft | Participant left meeting |
| MeetingParticipantRoleChanged | Participant role changed |
| MeetingRecordingStarted | Recording started |
| MeetingRecordingEnded | Recording ended |
| MeetingDetail | Meeting details accessed |
| MeetingParticipantDetail | Participant details accessed |
| LiveNotesUpdate | Live notes updated |
| AINotesUpdate | AI notes updated |
| RecordingExported | Recording exported |
| TranscriptsExported | Transcripts exported |

#### Teams - Apps/Approvals

| Operation | Description |
|-----------|-------------|
| AppInstalled | App installed |
| AppUpgraded | App upgraded |
| AppUninstalled | App uninstalled |
| CreatedApproval | Approval created |
| ApprovedRequest | Request approved |
| RejectedApprovalRequest | Approval request rejected |
| CanceledApprovalRequest | Approval request canceled |

#### Word, Excel, PowerPoint, OneNote

| Operation | Description |
|-----------|-------------|
| Create | Document created |
| Edit | Document edited |
| Open | Document opened |
| Save | Document saved |
| Print | Document printed |

#### Forms

| Operation | Description |
|-----------|-------------|
| CreateForm | Form created |
| EditForm | Form edited |
| DeleteForm | Form deleted |
| ViewForm | Form viewed |
| CreateResponse | Response created |
| SubmitResponse | Response submitted |
| ViewResponse | Response viewed |
| DeleteResponse | Response deleted |

#### Stream

| Operation | Description |
|-----------|-------------|
| StreamModified | Video modified |
| StreamViewed | Video viewed |
| StreamDeleted | Video deleted |
| StreamDownloaded | Video downloaded |

#### Planner

| Operation | Description |
|-----------|-------------|
| PlanCreated | Plan created |
| PlanDeleted | Plan deleted |
| PlanModified | Plan modified |
| TaskCreated | Task created |
| TaskDeleted | Task deleted |
| TaskModified | Task modified |
| TaskAssigned | Task assigned |
| TaskCompleted | Task completed |

#### PowerApps

| Operation | Description |
|-----------|-------------|
| LaunchedApp | App launched |
| CreatedApp | App created |
| EditedApp | App edited |
| DeletedApp | App deleted |
| PublishedApp | App published |

#### Copilot

| Operation | Description |
|-----------|-------------|
| CopilotInteraction | Microsoft 365 Copilot interaction |

### Record Types

The bundle automatically includes these record types:

| Record Type | Associated Workloads |
|-------------|---------------------|
| ExchangeAdmin | Exchange administration |
| ExchangeItem | Exchange items (email) |
| ExchangeMailbox | Exchange mailbox operations |
| SharePointFileOperation | SharePoint/OneDrive file operations |
| SharePointSharingOperation | SharePoint sharing operations |
| SharePoint | SharePoint general |
| OneDrive | OneDrive operations |
| MicrosoftTeams | Teams operations |
| OfficeNative | Word, Excel, PowerPoint, OneNote |
| MicrosoftForms | Forms operations |
| MicrosoftStream | Stream operations |
| PlannerPlan | Planner plan operations |
| PlannerTask | Planner task operations |
| PowerAppsApp | PowerApps operations |

### Usage Examples

```powershell
# Full M365 usage bundle including Copilot
./PAX_Purview_Audit_Log_Processor.ps1 `
    -StartDate 2025-12-01 `
    -EndDate 2025-12-02 `
    -IncludeM365Usage `
    -OutputPath "C:\Exports\"

# M365 usage WITHOUT Copilot data
./PAX_Purview_Audit_Log_Processor.ps1 `
    -StartDate 2025-12-01 `
    -EndDate 2025-12-02 `
    -IncludeM365Usage `
    -ExcludeCopilotInteraction `
    -OutputPath "C:\Exports\"

# Combined output for easier analysis
./PAX_Purview_Audit_Log_Processor.ps1 `
    -StartDate 2025-12-01 `
    -EndDate 2025-12-02 `
    -IncludeM365Usage `
    -CombineOutput `
    -OutputPath "C:\Exports\"

# With Entra user enrichment
./PAX_Purview_Audit_Log_Processor.ps1 `
    -StartDate 2025-12-01 `
    -EndDate 2025-12-02 `
    -IncludeM365Usage `
    -IncludeUserInfo `
    -ExportWorkbook `
    -OutputPath "C:\Exports\"
```

### Important Behaviors

| Behavior | Description |
|----------|-------------|
| **CopilotInteraction included by default** | Use `-ExcludeCopilotInteraction` to remove it from the bundle |
| **ServiceTypes set to NULL** | The bundle queries all workloads in a single API pass; any `-ServiceTypes` value you provide is silently ignored |
| **RecordTypes merged** | If you also specify `-RecordTypes`, your values are merged with the bundle's record types (deduplicated) |
| **Additive with -ActivityTypes** | If you specify both, the bundle operations are added to your custom list |

### Best Practices

1. **Start with combined output:** Use `-CombineOutput` to get all activity types in a single file for initial analysis
2. **Add user context:** Include `-IncludeUserInfo` to enrich data with department, job title, and license information
3. **Use date ranges strategically:** Start with 1-2 days to validate data volume before running larger date ranges
4. **Export to Excel for pivoting:** Use `-ExportWorkbook` for multi-tab analysis by activity category
5. **Exclude Copilot if focusing on baseline:** Use `-ExcludeCopilotInteraction` when establishing pre-Copilot baseline metrics

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

### Adaptive Concurrency

New adaptive concurrency heuristics refine scaling decisions based on latency and throughput stability:
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

### Hitting the 1M Record Limit (Graph API Mode)

**Context:** The Microsoft Graph security/auditLog API has a hard limit of 1,000,000 records per query. While rare, very high-volume enterprise tenants may encounter this limit. PAX automatically detects and handles this situation.

**Symptoms (Graph API Mode):**

- Log shows: `[SUBDIVISION] Partition X/Y - Fetched 1,000,000 records (Graph API limit reached) - Needs subdivision`
- If minimum window reached: `[LIMIT] Partition X/Y - Fetched 1,000,000 records at minimum subdivision window`

**Automatic Handling:**

PAX uses the same BlockHours auto-subdivision algorithm as EOM 10K handling:
1. Partition time window is automatically halved and re-queried
2. Process repeats recursively until results fit or minimum window reached
3. Minimum window: `0.016667` hours (1 minute)

**Proactive Tuning for High-Volume Tenants:**

<details>
<summary>💻 Show 1M Limit Prevention Examples</summary>

```powershell
# Use smaller block hours for very high-volume tenants
pwsh -ExecutionPolicy Bypass -File ./PAX_Purview_Audit_Log_Processor.ps1 `
  -BlockHours 0.25 `
  -StartDate 2026-01-01 `
  -EndDate 2026-01-02

# For extremely dense data, use even smaller windows
pwsh -ExecutionPolicy Bypass -File ./PAX_Purview_Audit_Log_Processor.ps1 `
  -BlockHours 0.1 `
  -StartDate 2026-01-01 `
  -EndDate 2026-01-01
```

</details>

**Recommendations:**

| Scenario | Recommendation |
|----------|----------------|
| Seeing `[SUBDIVISION]` messages frequently | Use smaller `-BlockHours` (e.g., 0.25 or 0.1) |
| Large enterprise with millions of daily events | Consider shorter date ranges for initial exports |
| Automation/scheduled exports | Monitor logs for `[SUBDIVISION]` warnings to tune `-BlockHours` |

---

### Hitting the 10K Service Limit (EOM Mode Only)

**⚠️ Note:** The 10K limit applies only to EOM mode (`-UseEOM`). Graph API mode has a higher 1M limit (see above).

**Symptoms (EOM Mode):**

- Log shows: `CRITICAL: 10K limit reached for time window <dates>`
- CSV may be incomplete for dense periods

**Immediate Action:**

<details>
<summary>💻 Show 10K Limit Fix Examples</summary>

```powershell
# Reduce block hours to 15 minutes or less
pwsh -ExecutionPolicy Bypass -File ./PAX_Purview_Audit_Log_Processor.ps1 `
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

**Note:** Graph API mode (default) automatically handles large result sets through async query pagination. The 1M limit is much higher than EOM's 10K and includes automatic subdivision.

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
./PAX_Purview_Audit_Log_Processor.ps1 -UseEOM -PacingMs 250 -StartDate 2025-10-01 -EndDate 2025-10-02

# Reduce ResultSize to smaller batches
./PAX_Purview_Audit_Log_Processor.ps1 -UseEOM -ResultSize 5000 -StartDate 2025-10-01 -EndDate 2025-10-02

# Combine both approaches
./PAX_Purview_Audit_Log_Processor.ps1 -UseEOM -ResultSize 5000 -PacingMs 250 -StartDate 2025-10-01 -EndDate 2025-10-02
```

**Graph API Mode (Default) - Reduce Concurrency:**

```powershell
# Lower concurrent query limit
./PAX_Purview_Audit_Log_Processor.ps1 -MaxConcurrency 5 -StartDate 2025-10-01 -EndDate 2025-10-02

# Conservative parallel settings
./PAX_Purview_Audit_Log_Processor.ps1 -MaxConcurrency 3 -MaxParallelGroups 2 -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

### Memory Optimization

**For Deep Flatten with Wide Schemas:**

<details>
<summary>💻 Show Memory Optimization Examples</summary>

```powershell
# Increase schema sample, reduce chunk size
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeDeep `
  -StreamingSchemaSample 5000 `
  -StreamingChunkSize 2000 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**For Narrow Schemas (Faster Processing):**

```powershell
# Reduce schema sample, increase chunk size
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeArrays `
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
./PAX_Purview_Audit_Log_Processor.ps1 -ParallelMode On `
  -MaxConcurrency 2 `
  -MaxParallelGroups 2 `
  -ActivityTypes CopilotInteraction,MessageSent,FileAccessed
```

**Aggressive Approach (Maximum Throughput):**

```powershell
./PAX_Purview_Audit_Log_Processor.ps1 -ParallelMode On `
  -MaxConcurrency 4 `
  -MaxParallelGroups 3 `
  -ActivityTypes CopilotInteraction,MessageSent,FileAccessed
```

</details>

### Adaptive Concurrency Guidance

If adaptive scaling appears too assertive in your environment, lower `-AdaptiveConcurrencyCeiling` or raise `-ThroughputDropPct`. If scaling is too conservative, raise `-AdaptiveConcurrencyCeiling` (but keep `-MaxConcurrency` equal or higher) or lower `-LowLatencyMs` only if your baseline latency is consistently very low.

### Parallel Explosion Tuning (PS 7+ only)

When using `-ExplodeArrays` or `-ExplodeDeep` with large datasets, parallel explosion can provide significant speedups:

<details>
<summary>💻 Show Parallel Explosion Tuning Examples</summary>

**Auto-Detection (Recommended for Most Cases):**

```powershell
# Let script choose optimal thread count (2-8 based on CPU cores)
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeDeep -ExplosionThreads 0 -StartDate 2025-10-01 -EndDate 2025-10-31
```

**Explicit Thread Control:**

```powershell
# High-core server: use maximum 8 threads for best throughput
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeDeep -ExplosionThreads 8 -StartDate 2025-10-01 -EndDate 2025-10-31

# Resource-constrained environment: limit to 4 threads
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeDeep -ExplosionThreads 4 -StartDate 2025-10-01 -EndDate 2025-10-31
```

**Force Serial (Debugging/Compatibility):**

```powershell
# Serial processing for debugging or PS 5.1 compatibility testing
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeArrays -ExplosionThreads 1 -StartDate 2025-10-01 -EndDate 2025-10-02
```

**Replay Mode with Parallel Explosion:**

```powershell
# Transform large raw CSV with parallel explosion
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\Exports\Large_Raw.csv" -ExplodeDeep -ExplosionThreads 8
```

</details>

**Thread Count Guidelines:**

| Scenario | Recommended `-ExplosionThreads` |
|----------|--------------------------------|
| General use / auto-detect | `0` (default) |
| 4-core laptop | `0` or `2-4` |
| 8-core workstation | `0` or `4-8` |
| 16+ core server | `0` or `8-16` |
| Resource-constrained / shared | `2-4` |
| Debugging / compatibility | `1` (serial) |

**Architecture Notes:**

- Job queue pattern: Records split into ~1000-record chunks, N workers pull from shared queue
- Ensures good load balancing even with uneven data distribution
- No thread sits idle while work remains
- Automatically falls back to serial on PowerShell 5.1

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
- Verify you have Entra AD role: Compliance Administrator, Security Administrator, or Global Reader
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
- When targeting non-Copilot workloads, include the matching `-RecordTypes` / `-ServiceTypes` values (or confirm spelling/casing); omitting or mis-typing these filters can lead to empty results even if the activity exists
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
<summary>⚠️ View Known Limitations Table (Click to Expand)</summary>

| Area                        | Limitation / Behavior                                                          | Mitigation / Guidance                                                                                        |
| --------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| Unified Audit 10K cap (EOM) | Each `Search-UnifiedAuditLog` window tops at 10,000 records (EOM mode only)    | Script auto-subdivides; if still saturated, re-run with smaller `-BlockHours` (≤30m) or use Graph API mode (default) |
| Graph API 1M cap            | Each Graph API query tops at 1,000,000 records per partition                   | Script auto-subdivides; for very high-volume tenants, use smaller `-BlockHours` (≤0.25) proactively          |
| Row explosion cap           | Per original record explosion capped at 1,000 rows (`ExplosionTruncated` flag) | Investigate fan-out; consider narrower date, filter operations, or deep analysis separately                  |
| JSON / flatten depth        | JSON serialization depth fixed at 60; deep flatten recursion capped at 120     | Extremely deep structures beyond caps truncated; adjust constants if required                                |
| Memory usage                | Streaming, chunked export by default                                           | Tune with `-StreamingSchemaSample` / `-StreamingChunkSize`; shard by date for extreme spans                  |
| Replay mode                 | Non‑exploded mode disabled; always at least exploded schema                    | Use live mode if raw 1:1 row shape required                                                                  |
| Parallel mode               | Graph API: time-partitioned parallel queries; EOM: multi-activity sets only    | Graph API mode (default) provides better parallel performance for single activity types                      |
| Explosion parallelism       | PS7+ only; auto range 2-8 threads; max 8; falls back to serial on PS 5.1       | Use `-ExplosionThreads` to control; `0`=auto, `1`=serial, `2-8`=explicit thread count                        |
| Time zones                  | Dates interpreted as UTC; `yyyy-MM-dd` must be UTC                             | Convert local times to UTC prior to invocation to avoid DST drift                                            |
| Streaming export            | Always on (chunked)                                                            | Adjust sample/chunk sizes for schema width & memory balance                                                  |
| Group filtering             | Only available in EOM mode (`-UseEOM -GroupNames`)                              | Graph API mode does not support group-based filtering; export and filter client-side                         |

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

**Parallel Explosion Processing (PS 7+ only):**

- Applies to **both live query and offline replay** modes when explosion is enabled (`-ExplodeArrays` or `-ExplodeDeep`)
- Controlled via `-ExplosionThreads` parameter: `0`=auto (2-16 based on CPU), `1`=serial, `2-32`=explicit
- Uses `Start-ThreadJob` with job queue architecture for optimal load balancing
- Processes records in ~1000-record chunks with N concurrent workers picking from shared queue
- Output is **identical to serial mode** (same columns, data, row count; only row order may differ due to parallel completion)
- Falls back to serial automatically on PowerShell 5.1 or when `-ExplosionThreads 1` specified
- Checkpoint files preserve `explosionThreads` setting for resume consistency
- Detailed metrics emitted at completion (threads used, chunks processed, throughput)

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
- **Entra AD Role:** Compliance Administrator, Security Administrator, Security Reader, or Global Reader
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

### Copilot ROI Analytics Power BI Templates

The Microsoft Copilot ROI Analytics team provides the following Power BI templates for Copilot usage analysis:

**Compatible with PAX output (Purview-based):**

- **[AI-in-One Dashboard](https://github.com/microsoft/AI-in-One-Dashboard)** - Comprehensive Copilot usage analysis using Purview audit logs
- **[Copilot Chat & Agent Intelligence Dashboards](https://github.com/microsoft/CopilotChatAnalytics)** - Copilot chat and agent activity analysis using Purview audit logs
- **[Portable Audit eXporter (PAX)](https://github.com/microsoft/PAX)** - This repository: audit log processor scripts that generate input files for the above templates

**Viva Insights-based (does not use PAX output):**

- **[Super Usage Analysis Dashboard](https://github.com/microsoft/DecodingSuperUsage)** - Copilot usage analysis using Viva Insights organizational data (separate data source)

### Related Tools

- **[Power BI](https://powerbi.microsoft.com/)** - Visualize exported audit data
- **[Azure Synapse Analytics](https://azure.microsoft.com/en-us/products/synapse-analytics/)** - Data warehousing for large audit datasets
- **[Microsoft Sentinel](https://azure.microsoft.com/en-us/products/microsoft-sentinel/)** - SIEM integration for audit logs

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Support

For questions or issues, refer to the documentation:

- **Documentation v1.10.x (Markdown):** [PAX_Purview_Audit_Log_Processor_Documentation.md](https://github.com/microsoft/PAX/blob/main/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.10.0.md)

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com) with any feedback.*

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

© Microsoft Corporation — MIT Licensed


