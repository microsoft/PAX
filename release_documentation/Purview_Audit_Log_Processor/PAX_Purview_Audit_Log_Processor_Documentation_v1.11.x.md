# Portable Audit eXporter (PAX) - <br/>Purview Audit Log Processor

> **📥 Quick Start:** Download the script → [`PAX_Purview_Audit_Log_Processor_v1.11.3.ps1`](https://github.com/microsoft/PAX/releases/download/purview-v1.11.3/PAX_Purview_Audit_Log_Processor_v1.11.3.ps1)
>
> **📅 Script v1.11.3 Release Date:** 2026-06-01
>
> **📋 Release Notes:** See what's new → [v1.11.x Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.11.x.md) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Purview_Audit_Log_Processor)
>
> **📜 Script Archive:** [All Script Versions](https://github.com/microsoft/PAX/releases?q=purview-&expanded=true)
>
> **📚 Documentation Archive:** [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Purview_Audit_Log_Processor)

**Documentation Version:** v1.11.x (Current Script Version: v1.11.3)
**Audience:** IT admins, security/compliance analysts, BI/data teams  
**Runtime:** PowerShell 7+ (required for default Graph API mode); PowerShell 5.1 supported only with `-UseEOM`  
**License:** MIT

---

> **📝 A note on navigating this document**
>
> This documentation is intentionally comprehensive — it covers every parameter, authentication method, output destination, troubleshooting scenario, and known limitation in detail so you can rely on it as a single reference.
>
> If you are looking for a specific answer rather than reading end-to-end, try opening this page in a Copilot-enabled view (for example, the Microsoft 365 Copilot chat side panel, GitHub Copilot Chat in VS Code, or Edge's Copilot pane) and asking it to summarize a section, locate a parameter, or walk you through a particular scenario. Sample prompts: *"Summarize how to send PAX output to SharePoint,"* *"What permissions do I need to write output to Microsoft Fabric (OneLake)?"*, or *"Show me only the troubleshooting steps for managed-identity sign-in."* Copilot can comfortably handle this file and will get you to the right place faster than scrolling.

---

<table>
<tr>
<td bgcolor="#FFF8C5">
<font color="#000000">

<h3>⚠️ Sensitive Data Warning — Customer Responsibility</h3>

**The audit data exported by this script is highly sensitive.** Output may contain user identifiers (UPN, email, GUID), file/site/resource paths, conversation and message IDs, agent identifiers, prompt/response metadata (timestamps, lengths, classifications), and other personally identifiable information drawn directly from your tenant's Unified Audit Log.

- **Data is NOT hashed, masked, redacted, anonymized, or de-identified** in any way. Records are exported in their raw, attributable form exactly as Microsoft Purview returns them.
- Outputs (CSV/JSON metrics, checkpoint files, logs) may contain confidential business content, regulated data (PII, PHI, financial, IP), and end-user communications.
- **The customer (you / your organization) is solely responsible** for the secure handling, storage, transmission, retention, disclosure, access control, and deletion of all data produced by this script, and for ensuring its use complies with all applicable laws, regulations, contractual obligations, and internal policies — including but not limited to GDPR, HIPAA, CCPA, employee monitoring laws, works-council agreements, and data-residency requirements.
- **Microsoft has no visibility into, control over, or responsibility for** the data customers extract using this tool or how that data is subsequently used, shared, or stored. Microsoft disclaims any and all liability arising from or related to customer use of this script and its output.
- Treat all output files as **Highly Confidential**. Restrict access to authorized personnel with a documented business need. Encrypt at rest and in transit. Apply tenant DLP / sensitivity labels as appropriate.

</font>
</td>
</tr>
</table>

---

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Use Cases](#use-cases)
4. [Prerequisites](#prerequisites)
5. [Installation & Setup](#installation--setup)
6. [Parameters Reference](#parameters-reference)
7. [Authentication Methods](#authentication-methods)
8. [Sending Output to SharePoint](#sending-output-to-sharepoint)
9. [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake)
10. [Usage Examples](#usage-examples)
11. [Agent Filtering](#agent-filtering)
12. [User and Group Filtering](#user-and-group-filtering)
13. [Prompt and Response Filtering](#prompt-and-response-filtering)
14. [Combining Filters](#combining-filters)
15. [Microsoft 365 Usage Bundle](#microsoft-365-usage-bundle)
16. [Rollup Post-Processor (Power BI)](#rollup-post-processor-power-bi)
17. [Incremental Data Collection](#incremental-data-collection)
18. [Checkpoint & Resume](#checkpoint--resume)
19. [Output Files & Schema](#output-files--schema)
20. [Activity Types Reference](#activity-types-reference)
21. [Record & Service Filters](#record--service-filters)
22. [Advanced Features](#advanced-features)
23. [Performance Tuning](#performance-tuning)
24. [Troubleshooting](#troubleshooting)
25. [Known Limitations](#known-limitations)
26. [Security & Compliance](#security--compliance)

---

## Overview

<details open>
<summary>What It Does</summary>

The **Portable Audit eXporter (PAX)** is an enterprise-grade PowerShell script that exports Microsoft Purview Unified Audit Log events, with specialized support for Microsoft 365 Copilot activities and related operations. It extends Graph-based retrieval so you can capture classic Microsoft 365 app usage (Word, Excel, PowerPoint, OneNote, SharePoint, OneDrive, Teams) in the same run — without falling back to ExchangeOnlineManagement — alongside Copilot telemetry. It transforms raw audit data into analysis-ready output — **CSV files** for local folders and SharePoint document libraries, or **Delta tables** under the `Tables/` namespace of a Microsoft Fabric Lakehouse for downstream notebooks, pipelines, and Power BI semantic models — with enriched metadata, intelligent query optimization, and flexible schema options.

**Core Capabilities:**

- Retrieves audit events from Microsoft 365 Unified Audit Log via **Graph API (default)** or **EOM mode** (`-UseEOM`)
- **Graph API filter passthrough:** Optional `-RecordTypes` / `-ServiceTypes` switches target documented Purview workloads (SharePoint, OneDrive, and future additions) so non-Copilot office app activity returns alongside Copilot operations
- **Microsoft 365 usage data (`-IncludeM365Usage`):** Curated cross-workload activity bundle spanning Outlook, Teams, SharePoint, OneDrive, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, and PowerApps — captured in the same Graph audit run alongside Copilot telemetry for ROI and behavior-change analysis
- Exports to structured CSV
- Includes enriched usage & ROI fields (tokens, models, latency, acceptance metrics)
- Implements adaptive time slicing to navigate service limits intelligently
- Provides detailed logging of all operations, warnings, and performance metrics
- Automatically handles module installation and authentication (`Microsoft.Graph.Authentication` and `Microsoft.Graph.Security` for Graph API mode; `ExchangeOnlineManagement` for EOM mode). `Az.Accounts` — needed only for Fabric OneLake output — must be installed manually if missing.
- **Flexible output destinations:** A single `-OutputPath` parameter accepts a local folder path, a SharePoint document library URL, or a Microsoft Fabric Lakehouse OneLake URL — PAX infers the destination tier from the URL form. Local and SharePoint destinations receive identical CSV filenames; Fabric destinations receive the same data as Delta tables whose names are derived from the CSV basenames (the trailing `_YYYYMMDD_HHMMSS` run-timestamp is stripped so tables are evergreen across runs)
- **Microsoft Fabric (OneLake) as a first-class destination:** Provide a Fabric **Lakehouse** URL to `-OutputPath` and PAX writes audit data as Delta tables under the Lakehouse `Tables/` namespace, with operational artifacts (run log, metrics JSON) under `Files/` — eliminating the local-disk + manual-upload hop and landing data in a form Fabric notebooks, pipelines, and Direct Lake Power BI semantic models consume natively. Only Lakehouse items are supported as Fabric destinations; Warehouse items are not.
- **Fabric-ready for production at scale:** OneLake credentials are refreshed automatically in the background and large CSV uploads to SharePoint use resumable chunked transfer, so multi-hour exports complete without interruption
- **Fabric + managed identity for fully unattended runs:** Combine an `-OutputPath` Fabric URL with `-Auth ManagedIdentity` to run PAX as a scheduled/event-driven Azure Container Apps Job (or any Azure compute) that lands data directly in a Fabric workspace with no secrets to manage — see the repo-root **`fabric_resources`** folder for container images, Bicep/ARM templates, and the Azure-role + Fabric-workspace-role + Fabric-tenant-setting checklist
- **Unattended Azure-hosted runs:** Sign in with a managed identity (`-Auth ManagedIdentity`) for scheduled/event-driven jobs on Azure Container Apps Jobs, Azure VMs, or similar Azure compute — no secrets to manage
- **Graph API mode (default):** Supports Entra ID user enrichment + Microsoft 365 Copilot license detection via `-IncludeUserInfo` and `-OnlyUserInfo`; group expansion via `-GroupNames` uses `Get-MgGroup` + `Get-MgGroupMember` (requires `GroupMember.Read.All`)
- **EOM mode (`-UseEOM`):** Supports group expansion via `-GroupNames` (uses `Get-DistributionGroupMember`) and 10K-per-query limit detection

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

</details>

<details>
<summary>Data Processing & Output</summary>

- **Purview Schema Compliance:** Matches Microsoft Purview's canonical schema structure
- **Microsoft 365 Usage Bundle:** Single-switch activation (`-IncludeM365Usage`) captures activity types across Exchange (Outlook), Teams, SharePoint, OneDrive, Office apps (Word, Excel, PowerPoint, OneNote), Forms, Stream, Planner, and Power Apps alongside Copilot data — for Copilot ROI baselining and cross-workload behavior analysis
- **Agent Filtering:** Filter records by specific AgentId values or any agent-related activity
- **Record & Service Filters (Graph):** Use `-RecordTypes` / `-ServiceTypes` to target specific Microsoft 365 workloads (examples: `SharePoint`, `OneDrive`, `Exchange`, `MicrosoftTeams`, `AzureActiveDirectory`; record types include `SharePointFileOperation`, `ExchangeItem`, `MicrosoftTeams`, etc.) without leaving Graph mode
- **User Filtering:** Filter by user emails via `-UserIds` parameter — server-side (via `Search-UnifiedAuditLog -UserIds`) in `-UseEOM` mode; client-side after retrieval in Graph API mode (the Graph audit query API does not support UPN filtering server-side)
- **Group Filtering:** Group expansion via `-GroupNames` — uses `Get-DistributionGroupMember` (Exchange Online RBAC) in `-UseEOM` mode and `Get-MgGroup` + `Get-MgGroupMember` (requires `GroupMember.Read.All`) in Graph API mode
- **Entra ID Enrichment + M365 Copilot Licensing (Graph API Mode Only):** Enrich audit data with Entra user attributes and M365 Copilot (MAC) license information via `-IncludeUserInfo` (default mode, not compatible with `-UseEOM`)
- **User-Only Export (Graph API Mode Only):** Export only Entra ID user data and M365 Copilot licensing without audit records via `-OnlyUserInfo` (requires `-IncludeUserInfo`, not compatible with `-UseEOM`)
- **Streaming Export:** Memory-efficient chunked data writing for large datasets
- **UTF-8 Encoding:** Consistent UTF-8 (no BOM) output for CSV files
- **Header Stability:** Always writes file headers even when zero records match (ensures schema consistency)
- **Multiple Output Destinations:** A single `-OutputPath` parameter accepts the destination that matches the consumer of the run — PAX infers the tier from the value:
  - **Local folder** (default; best for ad-hoc analysis on the host machine) — CSV files
  - **SharePoint document library** when `-OutputPath` is a SharePoint URL (best for team visibility, sharing-link distribution, and Power BI direct-from-SharePoint consumption — see [Sending Output to SharePoint](#sending-output-to-sharepoint)) — CSV files with identical schemas to Local
  - **Microsoft Fabric Lakehouse / OneLake** when `-OutputPath` is a Fabric lakehouse URL (best for downstream Fabric notebooks, pipelines, dataflows, and Direct Lake Power BI semantic models — see [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake)) — Delta tables under `Tables/`, with operational artifacts under `Files/`. Column names containing Delta-forbidden characters (space, comma, semicolon, parentheses, etc.) are sanitized to underscores at table-write time only; the underlying CSV column names are preserved
- **Pre-Flight Destination Check:** When `-OutputPath` targets SharePoint or Microsoft Fabric, PAX verifies the destination exists and is writable **before pulling any audit data**, so permission gaps fail fast rather than after hours of querying
- **Resumable Uploads:** Large files (dense CSVs) use chunked, resumable upload to SharePoint, and OneLake credentials are refreshed automatically in the background — multi-hour exports finish without interruption

</details>

<details>
<summary>Microsoft Fabric Integration</summary>

- **Direct OneLake Output:** Provide a Fabric **Lakehouse** URL to `-OutputPath` and PAX writes audit data as Delta tables under the Lakehouse `Tables/` namespace, queryable directly from the Fabric SQL endpoint and consumable by Direct Lake Power BI semantic models. Operational artifacts (run log, metrics JSON, checkpoint files) land under `Files/`. Only Lakehouse items are supported; Warehouse items are not.
- **Evergreen Tables:** Delta table names are derived from the CSV basename with the `_YYYYMMDD_HHMMSS` run-timestamp stripped, so the same table is overwritten run-after-run (or appended into, when an `-Append*` switch is used) while the underlying CSV filenames continue to carry the timestamp suffix
- **Schema Evolution:** Delta tables are written with `schema_mode='merge'` so additive schema changes between runs are absorbed automatically; pre-flight rejects breaking schema-shape mismatches before any audit query is issued
- **`deltalake` Auto-Install:** The `deltalake>=0.15` Python package is verified on first use and auto-installed per-user if missing; offline / locked-down hosts can pre-install it manually
- **No Intermediate Hop:** Eliminates the local-disk + manual-upload step that Fabric consumers would otherwise need
- **Managed-Identity Friendly:** Pair with `-Auth ManagedIdentity` for scheduled, fully unattended Azure-hosted runs writing directly to Fabric
- **Supporting Materials in `fabric_resources` (repo root):** The repository's **`fabric_resources` folder** (top level of the repo) contains the supporting material for adopting Fabric output in production, including:
  - Container images and Dockerfiles for hosting PAX in Azure with Fabric as the destination
  - Bicep / ARM / deployment templates for the Azure resources that host PAX (Azure Container Apps Jobs, Azure Container Instances, etc.)
  - Managed-identity and RBAC setup guidance (Azure role + Fabric workspace role + Fabric tenant setting)
  - Sample Fabric notebooks and pipelines that consume PAX output from the lakehouse
  - End-to-end walkthroughs for scheduled / event-driven PAX runs landing in Fabric
- **Three-Layer Permissions Model:** Documented and enforced at pre-flight — Azure role (`Storage Blob Data Contributor`) + Fabric workspace role (**Contributor**) + Fabric tenant setting (*Service principals can use Fabric APIs*); see [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake)

</details>

<details>
<summary>Performance Optimization</summary>

- **Parallel Query Execution:** Concurrent processing of multiple activity types with controlled throttling
- **Learned Block Sizes:** Per-activity and global adaptive sizing based on observed densities
- **Fast Data Writer:** Direct `StreamWriter` usage for CSV
- **Schema Sampling:** Configurable initial sampling to optimize column discovery vs. memory usage
- **Memory Management:** Automatic memory monitoring (`-MaxMemoryMB`) that streams records directly to JSONL files when system memory reaches the threshold (75% of RAM by default)

</details>

<details>
<summary>Operational Excellence</summary>

- **Real-Time Progress Tracking:** Live status updates across Query and Export phases with percentage completion
- **CSV Export:** Native CSV output with consistent schemas
- **Detailed Logging:** Comprehensive log file with parameters, decisions, warnings, and metrics
- **Automated Setup:** Graph API mode (default) auto-installs the `Microsoft.Graph.Authentication` module if needed; EOM mode auto-installs `ExchangeOnlineManagement` if needed

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
- Analyze Word, Excel, PowerPoint, and OneNote document activity by pairing `-ActivityTypes` (e.g., `FileAccessed`, `FilePreviewed`) with `-RecordTypes`/`-ServiceTypes` to capture SharePoint and OneDrive workloads alongside Copilot usage

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
- Expand investigations to include Microsoft 365 productivity workloads — SharePoint and OneDrive (including Teams files, which are tracked under `SharePointFileOperation`) — by applying `-RecordTypes` / `-ServiceTypes` filters alongside document-operation activity types such as `FileModified` or `FileDownloaded`

</details>

<details>
<summary>Performance & Capacity Planning</summary>

- Track Copilot usage patterns and peak activity periods
- Evaluate load across Office workloads by monitoring file operations returned through `-RecordTypes` / `-ServiceTypes`
- Analyze model names and app host distribution across your tenant
- Optimize script performance with adaptive block sizing for your tenant's data density
- Identify query throttling patterns during high-volume periods

</details>

<details>
<summary>Data Integration & BI</summary>

- Export enriched data to Power BI, Azure Synapse, or data warehouses
- Join audit data with licensing information for coverage analysis
- Maintain historical archives with consistent schema over time
- Blend Copilot telemetry with Microsoft 365 app usage metrics (SharePoint/OneDrive document interactions, Teams file usage) by leveraging record/service filters before loading into BI platforms
- **Land results in a Microsoft Fabric lakehouse on every run** by passing a Fabric lakehouse URL to `-OutputPath` so notebooks, pipelines, and Power BI semantic models can pick up the latest export with no manual upload step (supporting templates and walkthroughs live in the `fabric_resources` folder at the repo root)
- **Distribute results to a SharePoint team library** by passing a SharePoint document library URL to `-OutputPath` for analysts who consume audit output directly from Power BI's SharePoint connector or Excel in the browser

</details>

<details>
<summary>Unattended Scheduled Operations</summary>

- Schedule PAX inside Azure (Azure Container Apps Jobs, Azure VMs, Azure Container Instances) using `-Auth ManagedIdentity` for fully unattended runs with no secrets on disk
- Land each run's output directly in SharePoint or Microsoft Fabric so downstream teams and BI assets pick up new data automatically
- Pair scheduled audit pulls with the `fabric_resources` supporting material (container images, Bicep templates, RBAC setup) for a production-grade pipeline
- Run daily / hourly exports without manual sign-in, token rotation, or file copying

</details>

<details>
<summary>Agents</summary>

- Inventory all agent activity across your tenant using `-AgentsOnly` to filter audit records that involve any Copilot Studio declarative agent, custom agent, or Microsoft-built agent
- Analyze adoption and usage of specific agents using `-AgentId` for targeted investigations (single or multiple agent IDs)
- Compare agent vs. non-agent Copilot interactions using `-ExcludeAgents` to baseline standard Copilot usage against agent-driven activity
- Combine agent filters with `-UserIds`, `-GroupNames`, or `-PromptFilter` for focused analyses (e.g., specific user's interactions with a specific agent)

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Prerequisites

<details>
<summary>📋 View Prerequisites (Click to Expand)</summary>

| Requirement                 | Details                                 | Notes                                                        |
| --------------------------- | --------------------------------------- | ------------------------------------------------------------ |
| **PowerShell**              | 7+                                      | Required for default Graph API mode. PS 5.1 is supported ONLY with `-UseEOM` (serial). Download: https://aka.ms/powershell |
| **Unified Audit Logging**   | Enabled in tenant                       | Verify in Microsoft Purview compliance portal                |
| **Graph API Permissions**   | See [Permission Details](#permission-details) below | Required for Graph API mode (default). Consented during interactive sign-in or pre-configured for app registrations. |
| **Audit Role**              | Purview Audit Reader (or higher) | Required only for EOM mode (`-UseEOM`) and the Purview UI. Not required for Graph API mode (default), regardless of authentication method. |
| **SharePoint write access** *(only when `-OutputPath` is a SharePoint URL)* | Edit/Contribute on the destination library + folder, plus the Graph delegated or application permissions `Sites.ReadWrite.All` and `Files.ReadWrite.All` | See [Sending Output to SharePoint](#sending-output-to-sharepoint) for the full setup. |
| **Microsoft Fabric / OneLake access** *(only when `-OutputPath` is a Fabric lakehouse URL)* | All three layers are required: **(1)** the Azure role `Storage Blob Data Contributor` on the OneLake storage scope, **(2)** the **Contributor** (or higher) role on the Fabric workspace in the Fabric portal, **(3)** the tenant setting allowing service principals / Entra IDs to access Fabric APIs must be enabled by your Fabric admin | See [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake) for the full setup, and the `fabric_resources` folder in the repo root for detailed container/runbook material. |
| **Az.Accounts PowerShell module** *(only when `-OutputPath` is a Fabric lakehouse URL)* | Used to obtain the OneLake storage token | Install manually if missing: `Install-Module Az.Accounts -Scope CurrentUser`. PAX surfaces a clear error at pre-flight if the module is not present. (Already present on Azure Cloud Shell and the PAX-on-ACA container image.) |
| **Network Access**          | Microsoft 365 endpoints                 | Ensure firewall allows connections to Microsoft Graph and Exchange Online endpoints. When `-OutputPath` is a SharePoint URL, also allow `*.sharepoint.com`. When `-OutputPath` is a Fabric lakehouse URL, also allow `onelake.dfs.fabric.microsoft.com`. |
| **Execution Policy**        | Bypass or RemoteSigned                  | See [Authentication Methods](#authentication-methods)        |

**Note:** Graph API mode (default) requires the `Microsoft.Graph.Authentication` and `Microsoft.Graph.Security` PowerShell modules, both of which are automatically detected and installed by the script if missing. EOM mode (`-UseEOM`) automatically handles `ExchangeOnlineManagement` module detection and installation if needed. The `Az.Accounts` module (needed only for Fabric OneLake output) is the one exception — it must be installed manually before the first Fabric run.

<details>
<summary>Permission Details</summary>

**Permissions by Execution Mode:**

Graph API mode requests scopes conditionally based on the switches you pass. The umbrella `AuditLogsQuery.Read.All` permission is the baseline; per-workload, user-directory, and group-expansion scopes are requested only when the corresponding feature is enabled. Grant any conditional scopes for features you intend to use.

| Permission | Purpose | When required (Graph API) | Graph API (Delegated) | Graph API (AppRegistration) | ExchangeOnlineManagement (EOM) |
|------------|---------|---------------------------|:---------------------:|:---------------------------:|:------------------------------:|
| **Graph: AuditLogsQuery.Read.All** | Umbrella permission for the Microsoft Graph audit query API — covers `CopilotInteraction` record type | Always (except `-OnlyUserInfo`) | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-Exchange.Read.All** | Exchange Online audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-OneDrive.Read.All** | OneDrive audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-SharePoint.Read.All** | SharePoint Online audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: User.Read.All** | Entra user directory, MAC licensing | `-IncludeUserInfo`, `-OnlyUserInfo`, or `-GroupNames` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Organization.Read.All** | Tenant/organization context, license metadata | `-IncludeUserInfo` or `-OnlyUserInfo` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: GroupMember.Read.All** | Group lookup and membership expansion (least privilege) | `-GroupNames` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Sites.ReadWrite.All** | Resolve the SharePoint site/library/folder and upload output files | `-OutputPath` is a SharePoint URL | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Files.ReadWrite.All** | Create, replace, and resume uploads of output files in the SharePoint folder | `-OutputPath` is a SharePoint URL | ✅ Yes | ✅ Yes | — N/A |
| **Azure role: Storage Blob Data Contributor** | Write PAX output into the OneLake `Tables/` namespace (Delta tables) and `Files/` namespace (operational artifacts) of the destination Lakehouse | `-OutputPath` is a Fabric lakehouse URL | ✅ Required on the signed-in user / managed identity | ✅ Required on the service principal | — N/A |
| **Fabric portal role: Contributor** (or higher) on the workspace | Allow the identity to see and write into the lakehouse via Fabric APIs | `-OutputPath` is a Fabric lakehouse URL | ✅ Required | ✅ Required | — N/A |
| **Fabric tenant setting: "Service principals can use Fabric APIs"** | Enables Entra service principals / managed identities to call Fabric/OneLake | `-OutputPath` is a Fabric lakehouse URL (only when using `-Auth AppRegistration` or `-Auth ManagedIdentity`) | — | ✅ Must be enabled by a Fabric admin | — N/A |
| **Purview Audit Reader** | Purview UI/EOM | EOM only | ❌ No | ❌ No | ✅ Yes |

> **📚 Reference:** [Microsoft Graph Audit Log Query Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditcoreroot-post-auditlogqueries#permissions) | [Get auditLogQuery Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditlogquery-get#permissions)

**Audit Role Requirement and Enforcement Behavior:**

The **Purview Audit Reader** role is only required for EOM mode (`-UseEOM`) and the Purview UI — it is enforced by the Exchange audit backend. In Graph API mode (default), audit authorization is evaluated solely against the caller's Microsoft Graph permissions for both delegated and application authentication, and no user-level audit role is required.

> **⚠️ Troubleshooting (EOM mode): "User is not authorized" or 403 Errors**  
> If an EOM-mode run fails with `"User is not authorized for the RBAC roles"` or returns a `403 Forbidden` response, this typically indicates a stale role assignment. The Purview Audit Reader role may appear correctly assigned in the Purview portal, but the Exchange audit backend no longer recognizes it.  
> **Fix:** Remove and re-assign the **Purview Audit Reader** role to the user. This refreshes the Exchange audit authorization mapping. No new permissions are required.

**Entra ID User Enrichment + M365 Copilot Licensing (Optional Feature - Graph API Mode Only):**
- Requires the **User.Read.All** and **Organization.Read.All** permissions (requested only when this feature is enabled)
- Enabled via `-IncludeUserInfo` or `-OnlyUserInfo` parameters
- Provides access to Entra user attributes AND M365 Copilot (MAC) license information
- Not applicable in EOM mode (`-UseEOM`)

**Microsoft 365 Usage Bundle (Optional Feature - Graph API Mode Only):**
- Requires the **AuditLogsQuery-Exchange.Read.All**, **AuditLogsQuery-OneDrive.Read.All**, and **AuditLogsQuery-SharePoint.Read.All** permissions (requested only when this feature is enabled)
- Enabled via `-IncludeM365Usage` parameter
- Provides curated single-pass query bundle spanning Outlook, SharePoint, OneDrive, Teams, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, PowerApps, and Copilot
- Not applicable in EOM mode (`-UseEOM`)

**Sending output directly to SharePoint (Optional Feature - Graph API Mode Only):**
- Requires the Graph permissions **Sites.ReadWrite.All** and **Files.ReadWrite.All**, requested only when `-OutputPath` is a SharePoint URL
- The signed-in account (or, for unattended runs, the service principal / managed identity) must additionally have **Edit** or **Contribute** permission on the destination SharePoint library and folder
- See [Sending Output to SharePoint](#sending-output-to-sharepoint) for the full walkthrough, including how to get a valid URL and what kinds of links cannot be used
- Not applicable in EOM mode (`-UseEOM`)

**Sending output directly to Microsoft Fabric / OneLake (Optional Feature - Graph API Mode Only):**
- All three layers below must be in place — granting only one of them is not enough:
  1. **Azure role:** `Storage Blob Data Contributor` for the identity running PAX, scoped to the OneLake storage of the destination workspace
  2. **Fabric portal role:** **Contributor** (or higher) on the destination workspace, assigned in the Fabric portal under *Workspace settings → Manage access*
  3. **Fabric tenant setting:** *"Service principals can use Fabric APIs"* must be enabled by a Fabric admin (required for `-Auth AppRegistration` and `-Auth ManagedIdentity`)
- Requires the `Az.Accounts` PowerShell module on the host running PAX. **Install manually if missing** (`Install-Module Az.Accounts -Scope CurrentUser`); PAX surfaces a clear error at pre-flight if it cannot find the module.
- See [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake) for the walkthrough, and the **`fabric_resources` folder in the repo root** for detailed setup, container, and deployment material if you plan to run PAX inside Azure
- Not applicable in EOM mode (`-UseEOM`)

**Managed-identity sign-in (Optional Feature - Graph API Mode Only):**
- When running PAX inside Azure (for example, an Azure Container Apps Job, Azure VM, or Azure Container Instance) you can sign in using a managed identity instead of a password or app secret
- The managed identity must hold all the same Graph and destination permissions described in the table above — managed-identity sign-in only controls *how* PAX authenticates, not *what* it is allowed to do
- If your host has more than one identity attached, set the `AZURE_CLIENT_ID` environment variable to the client ID of the one you want PAX to use
- Not applicable in EOM mode (`-UseEOM`)

</details>

<details>
<summary>PowerShell 7+ Capabilities</summary>

| Feature              | PowerShell 7+                  |
| -------------------- | ------------------------------ |
| Parallel Execution   | ✅ `ForEach-Object -Parallel`  |
| UTF-8 Default        | ✅ Native UTF-8                |
| TLS/Cipher Support   | ✅ Modern TLS 1.3              |
| Cross-Platform       | ✅ Windows / macOS / Linux     |

**Download PowerShell 7+:** https://aka.ms/powershell

**PowerShell 5.1 (legacy):** Supported ONLY with `-UseEOM` (serial Exchange Online Management mode). Default Graph API mode and parallel query features require PowerShell 7+.

</details>

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Installation & Setup

<details>
<summary>Show Installation & Setup steps</summary>

### Download the Script

- **Script:** [PAX_Purview_Audit_Log_Processor_v1.11.3.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.11.3/PAX_Purview_Audit_Log_Processor_v1.11.3.ps1)
- **Release Notes:** [v1.11.x](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.11.x.md)

Save the downloaded script to a working directory (e.g., `C:\Scripts\PAX\`).

### First Run (Quick Start)

<details>
<summary>💻 Show Quick Start Commands</summary>

```powershell
# PowerShell 7+ - Graph API Mode (Default)
pwsh -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# Windows PowerShell 5.1 - EOM mode only (serial, no parallelism)
powershell -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor.ps1 -UseEOM -StartDate 2025-10-01 -EndDate 2025-10-02
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

*Core setup:*
- [Date & Time Parameters](#date--time-parameters)
- [Output & File Parameters](#output--file-parameters)
- [Authentication Parameters](#authentication-parameters)

*Filtering & selection:*
- [Query Behavior Parameters](#query-behavior-parameters)
- [CopilotInteraction Control Parameters](#copilotinteraction-control-parameters)

*Workload selection (what to collect):*
- [Microsoft 365 Usage Parameters](#microsoft-365-usage-parameters)
- [Dual-Mode & Enrichment Parameters](#dual-mode--enrichment-parameters)

*Performance & reliability:*
- [Parallel Execution Parameters](#parallel-execution-parameters)
- [Advanced Tuning Parameters](#advanced-tuning-parameters)
- [Observability & Completeness Parameters](#observability--completeness-parameters)
- [Resilience & Recovery Parameters](#resilience--recovery-parameters)

*Helpers:*
- [Helper Parameters](#helper-parameters)

<details>
<summary>🔤 All Switches (A-Z)</summary>

| A | B-C | D-E | F-I | L-O | P-R | S-Z |
|---|-----|-----|-----|-----|-----|-----|
| `-ActivityTypes` | `-BlockHours` | `-EmitMetricsJson` | `-Force` | `-LowLatencyMs` | `-PacingMs` | `-ServiceTypes` |
| `-AdaptiveConcurrencyCeiling` | `-ClientCertificatePassword` | `-EndDate` | `-GroupNames` | `-MaxConcurrency` | `-ParallelMode` | `-StartDate` |
| `-AgentId` | `-ClientCertificatePath` | `-ExcludeAgents` | `-Help` | `-MaxMemoryMB` | `-PromptFilter` | `-StatusIntervalSeconds` |
| `-AgentsOnly` | `-ClientCertificateStoreLocation` | `-ExcludeCopilotInteraction` | `-IncludeCopilotInteraction` | `-MaxParallelGroups` | `-RecordTypes` | `-StreamingChunkSize` |
| `-AppendFile` | `-ClientCertificateThumbprint` | `-ExportProgressInterval` | `-IncludeM365Usage` | `-MetricsPath` | `-Resume` | `-StreamingSchemaSample` |
| `-Auth` | `-ClientId` |   | `-IncludeTelemetry` | `-OnlyUserInfo` | `-ResultSize` | `-TenantId` |
| `-AutoCompleteness` | `-ClientSecret` |   | `-IncludeUserInfo` | `-OutputPath` |   | `-ThroughputDropPct` |
|   | `-CombineOutput` |   |   |   |   | `-UseEOM` |
|   |   |   |   |   |   | `-UserIds` |

</details>

---

### Date & Time Parameters

#### `-StartDate` (string)

**Purpose:** UTC start date (inclusive) for the audit log query  
**Format:** `yyyy-MM-dd` (e.g., `2025-10-01`)  
**Default:** Previous full UTC day if both dates omitted  
**Example:** `-StartDate 2025-10-01`

---

#### `-EndDate` (string)

**Purpose:** UTC end date (exclusive) for the audit log query  
**Format:** `yyyy-MM-dd` (e.g., `2025-10-02`)  
**Default:** Previous full UTC day + 1 if both dates omitted  
**Example:** `-EndDate 2025-10-02`

**Date Behavior:**

- If both dates are omitted, defaults to previous full UTC day (midnight to midnight)
- Must specify both or neither (partial specification rejected)
- **Time zone:** All dates interpreted as UTC; convert local times before invocation
- **Date-range accuracy:** The Purview API may return records slightly beyond the requested `EndDate`. PAX automatically trims these so the exported output contains only records within your specified `[StartDate, EndDate)` range. The number of trimmed records is reported in the log file's Pipeline Summary.

---

### Output & File Parameters

#### `-OutputPath` (string)

**Purpose:** Directory path where output files will be created with auto-generated timestamped filenames  
**Default:** `C:\Temp\`

> 💡 `-OutputPath` accepts a local folder, a SharePoint document-library URL, or a Microsoft Fabric lakehouse URL. PAX infers the destination tier from the form of the value you pass and writes to exactly one location per run. See [Sending Output to SharePoint](#sending-output-to-sharepoint) and [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake) for the URL formats and required permissions.

**Auto-Generated Filenames:** Script creates descriptive filenames based on:
- **Activity types** being exported
- **Combined vs separate output** mode
- **Current timestamp** (yyyyMMdd_HHmmss format)

**Examples of Auto-Generated Filenames:**
- `Purview_CopilotInteraction_Export_20251110_143022.csv`
- `Purview_Audit_CombinedUsageActivity_20251110_143022.csv`

**Use When:** Specifying custom output directory location  
**Example:** `-OutputPath "D:\AuditData\2025\\"`

---

#### `-AppendFile` (string)

**Purpose:** Append new audit records to an existing output file (CSV) instead of creating new timestamped files  
**Default:** Not set (creates new timestamped files)  
**Use When:**

- Building continuous audit trails spanning multiple time periods
- Incremental dataset updates for scheduled exports

**Examples:**

- Filename only: `-AppendFile "Report.csv"` (uses `-OutputPath` directory)
- Full path: `-AppendFile "C:\Data\\"`

**Notes:**

- See [Incremental Data Collection](#incremental-data-collection) section for complete documentation
- Validates header compatibility before appending
- NOT compatible with `-IncludeUserInfo` or `-OnlyUserInfo`

---

#### `-CombineOutput` (switch)

**Purpose:** Combine all activity types into single output file  
**Default:** Off (creates separate files per activity type)  
**Use When:** Need consolidated single-file output for ingestion pipelines or simplified analysis  
**Applies to:** CSV exports  
**Example:** `-CombineOutput`

**Behavior:**

**Without `-CombineOutput` (Default):**
- Creates separate CSV file per activity type (e.g., `CopilotInteraction_<timestamp>.csv`, `ConnectedAIAppInteraction_<timestamp>.csv`)

**With `-CombineOutput` switch:**
- Merges all activity types into single file: `Purview_Audit_CombinedUsageActivity_<timestamp>.csv` (with `Operations` column identifying type)

**Use Cases:**

- **Ingestion Pipelines:** Single combined file simplifies automated ingestion workflows
- **Cross-Activity Analysis:** Easier correlation across activity types in single dataset
- **Simplified Distribution:** Single file for stakeholder sharing instead of multiple files

**Notes:**

- EntraUsers data always exported separately (not merged with activity data)
- Can be combined with `-AppendFile` for incremental single-file builds
- Separate files (default) enable parallel processing and activity-specific analysis

---

### Authentication Parameters

#### `-Auth` (string)

**Purpose:** Authentication method for connecting to Microsoft services  
Select the authentication flow that matches your environment (interactive, semi-interactive, or fully unattended). Detailed descriptions and examples for every supported method—including AppRegistration—are available in the [Authentication Methods](#authentication-methods) section.

> **Automation note:** For unattended service principal runs, configure an Entra AD app registration with Microsoft Graph application permissions and use `-Auth AppRegistration` together with `-TenantId`, `-ClientId`, and either `-ClientSecret` or the certificate parameters documented below.

**Valid Values:**  
`WebLogin`, `DeviceCode`, `Credential`, `Silent`, `AppRegistration`, `ManagedIdentity`

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
- `-Auth ManagedIdentity` – Sign in using the managed identity of the Azure resource PAX is running on (no secrets, no interactive prompts). Best for unattended runs from Azure Container Apps Jobs, Azure VMs, and similar Azure-hosted environments.

**Notes:**

- Available in both Graph API and EOM modes, except `AppRegistration` and `ManagedIdentity` (Graph mode only)
- See [Authentication Methods](#authentication-methods) section for detailed guidance

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
**Mode Compatibility:** Graph API mode (default) only; ignored in EOM mode (`-UseEOM`).  
**Use When:**

- Retrieving Microsoft 365 app usage (Word, Excel, PowerPoint, OneNote) that maps to SharePoint or OneDrive operations
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
**Mode Compatibility:** Graph API mode (default) only; ignored in EOM mode (`-UseEOM`).  
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
- Mutually exclusive with `-AgentId` and `-AgentsOnly`
- Filters at record level during parsing phase

---

#### `-UserIds` (string[])

**Purpose:** Filter audit records to include only those from specific user(s)  
**Default:** Not set (no user filtering)  
**Mode Compatibility:**
- **Graph API Mode (Default):** Client-side filtering after retrieval (filters all retrieved records)
- **EOM Mode (`-UseEOM`):** Server-side filtering via `Search-UnifiedAuditLog -UserIds` (highly efficient)

**Use When:**

- Investigating specific user's Copilot activity
- Security reviews or compliance audits for individual accounts
- Troubleshooting user-reported issues
- Analyzing power users or early adopters

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

**Purpose:** Filter audit records to include only those from members of specific distribution group(s) (or Entra ID security groups / mail-enabled groups in Graph API mode)  
**Default:** Not set (no group filtering)  
**Mode Compatibility:**
- **EOM Mode (`-UseEOM`):** Uses `Get-DistributionGroupMember` to expand groups to member emails (server-side via Exchange Online), then filters server-side via `Search-UnifiedAuditLog -UserIds`
- **Graph API Mode (default):** Uses `Get-MgGroup` + `Get-MgGroupMember` to expand groups (requires the `GroupMember.Read.All` scope; the script requests it automatically when `-GroupNames` is supplied), then filters client-side after retrieval (the Graph audit query API does not support UPN filtering server-side)

**Use When:**

- Analyzing department-wide or team-level Copilot adoption
- Tracking usage across organizational units
- Compliance audits for specific business groups
- ROI analysis by functional group

**Examples:**

- Graph API mode (default): `-GroupNames "Engineering-Team@contoso.com"`
- EOM mode: `-UseEOM -GroupNames "Engineering-Team@contoso.com"`
- Multiple: `-GroupNames "Sales@contoso.com","Marketing@contoso.com"`
- Array: `-GroupNames @("Group1@contoso.com", "Group2@contoso.com")`

**Notes:**
- Identifiers can be group display name, mail address, or (in Graph API mode) the group's object ID
- Expansion adds ~2-5 seconds per group (one-time cost)
- Can be combined with `-UserIds` (users are merged and deduplicated)
- Works with all other filters (`-AgentsOnly`, `-AgentId`, `-ExcludeAgents`, `-PromptFilter`)

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
- Can be combined with `-AgentsOnly`, `-ExcludeAgents`, or `-AgentId`
- Provides detailed metrics in summary (record/conversation retention, type breakdown)

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
- If CopilotInteraction is already in the list, no duplicate is added

---

#### `-ExcludeCopilotInteraction` (switch)

**Purpose:** Explicitly remove CopilotInteraction from the final activity list  
**Default:** Off  
**Use When:**

- Using `-IncludeM365Usage` but only want non-AI collaboration signals
- Building exports focused purely on classic M365 workloads

**Examples:**

- `-IncludeM365Usage -ExcludeCopilotInteraction` — Full M365 usage bundle WITHOUT CopilotInteraction

**Notes:**
- Overrides default auto-inclusion of CopilotInteraction
- Removes CopilotInteraction from bundles that include it (like `-IncludeM365Usage`)
- **Conflict Detection:** If used with `-IncludeCopilotInteraction` or explicit CopilotInteraction in `-ActivityTypes`, the script prompts for resolution (or honors `-Force` to exclude)

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
| Outlook (Exchange) | MailItemsAccessed, Send, SendOnBehalf, SoftDelete, HardDelete, MoveToDeletedItems, CopyToFolder |
| SharePoint/OneDrive (Files) | FileAccessed, FileDownloaded, FileUploaded, FileModified, FileDeleted, FileMoved, FileCheckedIn, FileCheckedOut, FileRecycled, FileRestored, FileVersionsAllDeleted |
| SharePoint/OneDrive (Sharing) | SharingInvitationCreated, SharingInvitationAccepted, SharedLinkCreated, SharingRevoked, RemovedFromSecureLink |
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

- **Graph API is the default mode**
- EOM mode does NOT support `-IncludeUserInfo` (Entra enrichment requires Graph API)
- `-GroupNames` is supported in both modes — Graph API mode expands groups via `Get-MgGroup` + `Get-MgGroupMember` (requires `GroupMember.Read.All`), then filters client-side after retrieval; EOM mode expands via `Get-DistributionGroupMember` and filters server-side via `Search-UnifiedAuditLog -UserIds`
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
- **Output:** Adds `EntraUsers_MAClicensing_<timestamp>.csv` file

**Schema:** Comprehensive schema including UserPrincipalName, DisplayName, Email, Department, JobTitle, Manager, AssignedLicenses (semicolon-separated M365 licenses), HasLicense (boolean, **dynamically detected** — see License Detection Logic below), AccountEnabled, and more

**Notes:**

- One-time Graph API call per unique user in audit dataset
- Minimal performance impact (<5 seconds for typical datasets)
- User data cached for session duration
- **License data:** Retrieved via User.Read.All scope from Microsoft Graph - includes all assigned licenses
- **License detection (dynamic, future-proof):** PAX queries the tenant's `/subscribedSkus` endpoint and discovers every `servicePlanId` whose `servicePlanName` matches the wildcard `*COPILOT*`. A user's `HasLicense` flag is `True` when the user has any `assignedPlan` with `capabilityStatus == 'Enabled'` AND `servicePlanId` in the discovered set. No SKU allow-list is hard-coded in the script; new Copilot SKUs (M365, EDU, Sales, Service, Finance, GCC, etc.) are picked up automatically.
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
- Exports standalone `EntraUsers_MAClicensing_<timestamp>.csv`
- **Skips all audit log queries** (completes in 5-15 seconds vs. minutes/hours)
- Automatically enables `-IncludeUserInfo` internally

**Requirements:**

- **Graph API Mode:** NOT compatible with `-UseEOM` (requires Graph API)
- **Permissions:** User.Read.All (includes user profiles and license data), Organization.Read.All
- **Output:** Single file containing 37 columns of user + license data

**Compatible Parameters:**

- `-OutputPath` (specify output directory)
- `-Auth` (choose authentication method: WebLogin, DeviceCode, etc.)

**Note:** `-AppendFile` is NOT compatible with `-OnlyUserInfo` since EntraUsers data represents point-in-time snapshots, not time-based activity that should be appended.

**Incompatible Parameters (automatically blocked):**

All audit-related parameters are incompatible and will trigger validation errors:

- **Date Filtering:** StartDate, EndDate
- **Activity Types:** ActivityTypes, ExcludeCopilotInteraction
- **User/Agent Filtering:** UserIds, GroupNames, AgentId, AgentsOnly, ExcludeAgents, PromptFilter
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

# Custom output directory
.\PAX_Purview_Audit_Log_Processor.ps1 -OnlyUserInfo -OutputPath "D:\LicenseAudits\"

# Device code auth for automation/headless scenarios
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyUserInfo -Auth DeviceCode
```

---

### Parallel Execution Parameters

#### `-ParallelMode` (string)

**Purpose:** Control parallel execution of multiple activity types  
**Valid Values:** `Off`, `On`, `Auto`  
**Default:** `Auto` (PowerShell 7+ engages parallel processing automatically unless explicitly set to `Off`; PowerShell 5.1 / `-UseEOM` always runs serial)  
**Use When:**

- Processing multiple high-volume activity types
- Maximizing throughput on multi-core systems
- Need `Auto` heuristic to decide based on activity count

**Examples:**

- `-ParallelMode Auto` - Let script decide based on activity count and volume (default)
- `-ParallelMode On` - Force parallel execution
- `-ParallelMode Off` - Sequential processing

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
**Range:** `0` to `50` (aligns with Microsoft Purview's ~10 query safe limit per user account; values >10 increase scheduling pressure but rarely raw throughput)  
**Default:** `8`  
**Use When:** Tuning total concurrent group execution; lower to reduce throttling pressure, raise only if you have headroom against the per-user-account search-job limit  
**Example:** `-MaxParallelGroups 4`

---

### Advanced Tuning Parameters

#### `-StreamingSchemaSample` (int)

**Purpose:** Number of initial records to sample for schema discovery (serial mode only)  
**Range:** `100` to `10000`  
**Default:** `5000`  
**Use When:**

- Wide schemas need more samples to discover all columns
- Narrow schemas can use smaller samples for faster processing

**Note:** In parallel mode, this parameter is ignored—PAX performs a full scan of ALL rows for 100% column coverage.

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

#### `-MaxMemoryMB` (int)

**Purpose:** Memory threshold that controls when PAX switches to JSONL-only streaming mode (records bypass in-memory collection and are written directly to incremental JSONL files). Active by default — PAX automatically monitors memory usage and streams to disk when the threshold is reached.  
**Range:** `-1` to `65536`  
**Default:** `-1` (auto = 75% of system RAM)  
**Adjust When:**

- Running on memory-constrained machines where 75% of RAM is still too generous
- Running alongside other processes that need available RAM — set an explicit lower cap
- Scheduled/unattended exports where you want a predictable, fixed memory ceiling

**Notes:**

- Always active by default at 75% of system RAM — no action needed for most users
- Set to `0` to disable the memory threshold entirely (all records collected in memory)
- Stored in checkpoint and can be overridden with `-Resume` (e.g., resuming on different hardware)

**Examples:**

```
-MaxMemoryMB 4096        # Override auto-detection — cap at 4 GB
-MaxMemoryMB 0           # Disable — keep all records in memory
```

---

#### `-StatusIntervalSeconds` (int)

**Purpose:** Controls how frequently PAX displays status updates during job polling and backpressure waits  
**Range:** `30` to `600`  
**Default:** `60`  
**Use When:**

- Reduce to see more frequent progress output during long-running exports
- Increase to reduce console noise on extended runs
- Adjusting visibility during unattended/scheduled exports

**Example:** `-StatusIntervalSeconds 120`

**Notes:**

- Stored in checkpoint and restored on `-Resume`
- Affects polling status messages and backpressure wait progress output

---

### Observability & Completeness Parameters

#### `-EmitMetricsJson` (switch)

**Purpose:** Emit a structured JSON metrics file summarizing the export session (query windows, timings, exit code)  
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

The `-Resume` switch restores ALL settings from the checkpoint file to ensure data consistency. You cannot specify other processing parameters with `-Resume`. This prevents schema mismatches between the original run and the resumed run.

**Allowed with `-Resume`:**

| Parameter | Purpose |
|-----------|----------|
| `-Resume [path]` | Auto-discover checkpoint or use specific file |
| `-Force` | Use most recent checkpoint without prompting |
| `-Auth` | Override authentication method |
| `-TenantId` | Override tenant ID (for AppRegistration) |
| `-ClientId` | Override client ID (for AppRegistration) |
| `-ClientSecret` | Provide client secret (for AppRegistration) |
| `-MaxMemoryMB` | Override memory threshold (e.g., resuming on different hardware) |

**NOT Allowed with `-Resume`:**

Any other parameter (dates, activities, M365 bundles, etc.). These are all restored from checkpoint.

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
| M365/User Info | IncludeM365Usage, IncludeUserInfo |
| Partitioning | BlockHours, PartitionHours, MaxPartitions |
| Output | OutputPath, CombineOutput |
| Other | ResultSize, MaxConcurrency, AutoCompleteness, IncludeTelemetry, StatusIntervalSeconds |

**Notes:**

- Auth parameters can be overridden at resume time for flexibility
- ClientSecret is never stored in checkpoint (security)

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
- Auto-resolving parameter conflicts

**Example:** `-Force`

**Behaviors:**

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
| **Group Filtering** (`-GroupNames`) | ✅ Supported (group expansion via Graph; client-side audit filter) | ✅ Supported (group expansion via EXO; server-side audit filter via `Search-UnifiedAuditLog -UserIds`) |
| **Performance** | Better (modern API) | Good (mature module) |
| **Authentication Methods** | WebLogin, DeviceCode, Credential, Silent, AppRegistration*, ManagedIdentity* | WebLogin, DeviceCode, Credential, Silent |
| **Default** | ✅ Yes | Use `-UseEOM` to enable |

**Recommendation:** Use Graph API mode (default) unless you have legacy constraints; both modes support `-GroupNames` filtering.

> **Important:** Graph API mode requires multiple permissions for the Microsoft Purview Audit Search API. See [Permission Details](#permission-details) in the Prerequisites section for the complete list. The **Purview Audit Reader** role is only required for EOM mode (`-UseEOM`) and the Purview UI — it is not required for Graph API mode regardless of authentication method.

**Required Permissions by Execution Mode:**

Graph API mode requests scopes conditionally based on the switches you pass. The umbrella `AuditLogsQuery.Read.All` permission is the baseline; per-workload, user-directory, and group-expansion scopes are requested only when the corresponding feature is enabled. Grant any conditional scopes for features you intend to use.

| Permission | Purpose | When required (Graph API) | Graph API (Delegated) | Graph API (AppRegistration) | ExchangeOnlineManagement (EOM) |
|------------|---------|---------------------------|:---------------------:|:---------------------------:|:------------------------------:|
| **Graph: AuditLogsQuery.Read.All** | Umbrella permission for the Microsoft Graph audit query API — covers `CopilotInteraction` record type | Always (except `-OnlyUserInfo`) | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-Exchange.Read.All** | Exchange Online audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-OneDrive.Read.All** | OneDrive audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-SharePoint.Read.All** | SharePoint Online audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: User.Read.All** | Entra user directory, MAC licensing | `-IncludeUserInfo`, `-OnlyUserInfo`, or `-GroupNames` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Organization.Read.All** | Tenant/organization context, license metadata | `-IncludeUserInfo` or `-OnlyUserInfo` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: GroupMember.Read.All** | Group lookup and membership expansion (least privilege) | `-GroupNames` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Sites.ReadWrite.All** | Resolve and upload to SharePoint destination folder | `-OutputPath` is a SharePoint URL | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Files.ReadWrite.All** | Create / replace / resume uploads to the SharePoint folder | `-OutputPath` is a SharePoint URL | ✅ Yes | ✅ Yes | — N/A |
| **Azure role: Storage Blob Data Contributor** | Write into the OneLake `Files/` area of the destination lakehouse | `-OutputPath` is a Fabric lakehouse URL | ✅ Required on user / managed identity | ✅ Required on service principal | — N/A |
| **Fabric portal role: Contributor (or higher)** | Workspace access in the Fabric portal | `-OutputPath` is a Fabric lakehouse URL | ✅ Required | ✅ Required | — N/A |
| **Fabric tenant setting: "Service principals can use Fabric APIs"** | Allows non-interactive identities to call Fabric/OneLake | `-OutputPath` is a Fabric lakehouse URL (when using `-Auth AppRegistration` or `-Auth ManagedIdentity`) | — | ✅ Must be enabled by a Fabric admin | — N/A |
| **Purview Audit Reader** | Purview UI/EOM | EOM only | ❌ No | ❌ No | ✅ Yes |

> **📚 Reference:** [Microsoft Graph Audit Log Query Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditcoreroot-post-auditlogqueries#permissions) | [Get auditLogQuery Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditlogquery-get#permissions)

> **⚠️ Troubleshooting (EOM mode): "User is not authorized" or 403 Errors**  
> If an EOM-mode run fails with `"User is not authorized for the RBAC roles"` or returns a `403 Forbidden` response, this typically indicates a stale role assignment. The Purview Audit Reader role may appear correctly assigned in the Purview portal, but the Exchange audit backend no longer recognizes it.  
> **Fix:** Remove and re-assign the **Purview Audit Reader** role to the user. This refreshes the Exchange audit authorization mapping. No new permissions are required.

---

*AppRegistration is available only in Graph API mode.*

---

The script supports six authentication methods:

- **WebLogin (Default):** Interactive browser sign-in for admins running the script manually.
- **DeviceCode:** Device-code flow when no browser is available (RDP, SSH, jump hosts).
- **Credential:** Prompts once for username/password and stores it in memory for the session.
- **Silent:** Reuses cached authentication tokens when available (falls back to WebLogin).
- **AppRegistration:** Non-interactive service principal credentials for automation pipelines (Graph mode only).
- **ManagedIdentity:** Uses the managed identity of the Azure resource PAX is running on — no secrets, no interactive prompts (Graph mode only).

### Token Refresh Behavior

| Auth Method | Token Lifetime | Refresh Behavior | Long Query Support |
|-------------|---------------|------------------|-------------------|
| WebLogin | ~60-90 min | Silent attempt first, then prompt if needed | Checkpoint/Resume + Incremental saves |
| DeviceCode | ~60-90 min | Silent attempt first, then prompt if needed | Checkpoint/Resume + Incremental saves |
| AppRegistration | ~60-90 min | Proactive @ 45-50 min + Reactive on 401 | No checkpoint needed |
| ManagedIdentity | ~60-90 min (managed by Azure) | Proactive refresh + reactive on 401, fully automatic | No checkpoint needed |
| Credential | Session | Manual re-auth if expired | Limited |
| Silent | Cached | Falls back to WebLogin if expired | Depends on fallback |

**Token Refresh Details:**
- **AppRegistration:** Proactively refreshes token at ~45-50 minutes (before expiry). Also handles 401 errors reactively as a backup. Fully automatic and silent.
- **ManagedIdentity:** Azure issues short-lived tokens; PAX renews them automatically in the background, including for the separate OneLake sign-in used when `-OutputPath` is a Fabric lakehouse URL. No user interaction is ever required.
- **Interactive (WebLogin/DeviceCode):** On 401 error, first attempts silent refresh using SDK's cached refresh token. Only prompts user if silent refresh fails.
- **403 Forbidden errors:** Indicate a permissions issue, NOT token expiry. Token refresh will not help—check `AuditLogsQuery.Read.All` consent and role assignments.
- **Long uploads to SharePoint and Fabric:** When `-OutputPath` is a SharePoint URL or a Fabric lakehouse URL, PAX maintains a separate sign-in to the storage endpoint (Graph for SharePoint, OneLake for Fabric) and refreshes it independently of the audit-query token. Multi-hour exports upload without interruption regardless of which interactive or non-interactive auth method was used.

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
- **Prerequisites:** App registration with Graph application permissions (at minimum `AuditLogsQuery.Read.All`, plus any conditional scopes required by the switches you use — see the Permissions table above), admin consent, and either a client secret or certificate.
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

<br />

**ManagedIdentity (Azure-hosted runs only — Graph mode only)**

Sign in using the managed identity attached to the Azure resource that is running PAX. No secrets are stored on disk, no interactive prompts are required, and tokens are renewed automatically by Azure.

- **Best for:** Scheduled or event-driven PAX runs hosted in Azure Container Apps Jobs, Azure VMs, Azure Container Instances, or other Azure compute that supports managed identities. Particularly recommended when output is being written to SharePoint or Microsoft Fabric (OneLake) from the same Azure environment.
- **Prerequisites:**
  - A system-assigned or user-assigned managed identity on the Azure resource hosting PAX.
  - The identity granted the same Microsoft Graph application permissions an `AppRegistration` would need (at minimum `AuditLogsQuery.Read.All`, plus any conditional scopes for the switches you use — see the Permissions tables above).
  - When `-OutputPath` is a Fabric lakehouse URL: the identity also needs `Storage Blob Data Contributor` (Azure role on the OneLake storage), the **Contributor** role on the Fabric workspace, and the Fabric tenant setting *Service principals can use Fabric APIs* enabled.
  - When `-OutputPath` is a SharePoint URL: the identity also needs `Sites.ReadWrite.All` and `Files.ReadWrite.All`, plus Edit/Contribute on the destination folder.
  - If multiple identities are attached to the host (for example, both a system-assigned and one or more user-assigned identities), set the `AZURE_CLIENT_ID` environment variable to the client ID of the one PAX should use.
- **Works in:** Graph API mode only; automatically blocked when `-UseEOM` is supplied.
- **Automation suitability:** Strongly preferred over `AppRegistration` for any workload that already runs inside Azure — no secret rotation, no certificate management.

> 💡 Tip: When you also send output to SharePoint or Fabric, run a short test export (one day, no member expansion) first. This validates **all three** sets of permissions — audit-log read, destination write, and managed-identity sign-in — in a few minutes rather than discovering a missing role partway through a multi-hour export.

<details>
<summary>💻 Show ManagedIdentity Examples</summary>

```powershell
# System-assigned managed identity (single identity attached to the host)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth ManagedIdentity `
	-TenantId "<tenant-guid>" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02

# User-assigned managed identity (host has more than one identity)
$env:AZURE_CLIENT_ID = "<user-assigned-identity-client-id>"
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth ManagedIdentity `
	-TenantId "<tenant-guid>" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02

# Managed identity writing output directly to Fabric / OneLake
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth ManagedIdentity `
	-TenantId "<tenant-guid>" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/audit"
```

</details>

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Sending Output to SharePoint

<details>
<summary>📤 View SharePoint Output Guide (click to expand)</summary>

PAX can write every output file (CSV, log, metrics JSON) **directly into a SharePoint document library folder** instead of a local drive. This is useful when:

- Several people on your team need to see results as soon as a run finishes.
- The destination is governed by your tenant's normal SharePoint sharing, retention, and DLP policies.
- Downstream tools (Power BI, Excel, Power Automate) already read from SharePoint and a local-disk hop is unnecessary.

Pass a SharePoint URL as the `-OutputPath` parameter:

```powershell
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"
```

### How PAX uses your SharePoint folder

1. **Pre-flight check (before any audit data is pulled).** PAX verifies the site, library, and folder exist, that the signed-in identity has write access, and that none of the requested filenames already exist as locked items. If anything fails, the run stops with a clear error — no half-uploaded files are left behind.
2. **Staging.** Each output file is briefly written to a local scratch folder, then uploaded to SharePoint with the same filename. Small files use a single upload; large CSVs use a chunked, resumable upload that keeps working through transient network blips.
3. **Cleanup.** Once a file lands in SharePoint successfully, the local scratch copy is removed. Nothing PAX-related is left on disk after the run.
4. **End-of-run summary.** PAX prints a consolidated list of every file that landed in SharePoint, with sizes, so you can confirm visually before opening the folder.

### How to get the right URL (and what NOT to paste)

This is the part most people get wrong, so read it carefully. PAX needs the **canonical folder URL** of a SharePoint site library — the kind of address you would type to open the folder in a browser.

**The shape PAX expects:**

```
https://<tenant>.sharepoint.com/sites/<site>/<library>[/<folder>][/<subfolder>]
```

A real example:

```
https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output
```

> Government tenants are also supported — for example `https://contoso.sharepoint.us/...` and `https://contoso.sharepoint-mil.us/...`. PAX detects the cloud automatically from the host name.

**The simplest way to get a valid URL:**

1. Open the destination library in your browser (any modern browser is fine).
2. Navigate into the exact folder where you want PAX output to land. Create it first if it does not exist yet — PAX will not create new folders for you.
3. Look at the browser **address bar**. The URL you see while *viewing* the folder is the one PAX wants. Copy the part from `https://` up to (and including) the folder name. **Do not** copy anything after a `?` — those are view/filter parameters PAX cannot use.
4. Paste it as the value of `-OutputPath`, in quotes. Keep spaces in folder names as-is (`"Shared Documents"`) — PowerShell quoting handles them. Do not manually replace spaces with `%20`.

**URLs that look right but will NOT work — do not paste any of these:**

| Bad URL shape | Why it fails |
|---|---|
| Anything from **"Copy link"** or **"Share"** — usually starts with `/:f:/s/...` or `/:f:/r/sites/...` | These are sharing/tokenized links, not folder paths. PAX cannot list or upload to them. |
| Anything containing `/_layouts/` (e.g. `/_layouts/15/onedrive.aspx?...`) | This is a UI page, not the folder. |
| Anything ending in `Forms/AllItems.aspx` (with or without a query string) | This is the library *view* page, not the folder path. Trim `Forms/AllItems.aspx` and everything after it. |
| Anything containing `?id=...` or `?web=1` | The `?id=` query parameter encodes the folder for the UI to display; PAX needs the path itself. Remove the `?` and everything after it. |
| **OneDrive personal** URLs (`https://<tenant>-my.sharepoint.com/personal/<user>/...`) | OneDrive for Business personal sites are a different surface; PAX targets SharePoint sites/team libraries. |
| A site URL with **no library** (e.g. `https://contoso.sharepoint.com/sites/AuditTeam`) | PAX writes into a *folder inside a library*. Append the library and folder. |
| `http://...` (no `s`) | PAX requires HTTPS. |
| Encoded spaces like `Shared%20Documents` pasted manually | Let PowerShell quote the URL — type spaces normally inside the quotes. |

**Watch out for "display name vs internal name" on libraries.** Some libraries show a friendly display name in the UI (for example, "Audit Files") but have a different *internal* URL segment (for example, `Audit%20Files` or `AuditFiles`). The URL in the address bar uses the internal name — that is the one PAX needs. If you can navigate to the folder in your browser and the URL works there, it will work for PAX.

### Required permissions

| Layer | What you need | Why |
|---|---|---|
| Microsoft Graph application or delegated permission | `Sites.ReadWrite.All` | Resolve the site and library |
| Microsoft Graph application or delegated permission | `Files.ReadWrite.All` | Create, replace, and resume uploads of output files |
| SharePoint folder permission | Edit or Contribute on the destination folder | Standard SharePoint write access for the identity running PAX |

For unattended runs using `-Auth AppRegistration` or `-Auth ManagedIdentity`, the same two Graph permissions must be granted to the service principal / managed identity as **application permissions** with tenant admin consent, and the identity must additionally hold Edit/Contribute on the folder.

### More examples

<details>
<summary>💻 Show SharePoint output examples</summary>

```powershell
# 1. Simple interactive run, output goes straight to a team folder
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"

# 2. Subfolder in a non-default library
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://contoso.sharepoint.com/sites/AuditTeam/Audit Files/2025/October"

# 3. Government cloud tenant
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://contoso.sharepoint.us/sites/AuditTeam/Shared Documents/PAX-Output"

# 4. Unattended run from an Azure Container Apps Job using a managed identity
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth ManagedIdentity `
	-TenantId "<tenant-guid>" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"

# 5. Service principal with a client secret (CI/CD pipeline)
$clientSecret = ConvertTo-SecureString $env:PAX_CLIENT_SECRET -AsPlainText -Force
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth AppRegistration `
	-TenantId "<tenant-guid>" `
	-ClientId "<app-id>" `
	-ClientSecret $clientSecret `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"
```

</details>

### If something goes wrong

| What you see | Most likely cause | What to do |
|---|---|---|
| `Could not resolve SharePoint folder...` at the very start of the run | The URL is a sharing link, view page, or query-string URL, not the folder path | Re-read the *How to get the right URL* section above and copy the address-bar URL from inside the folder. |
| `Access denied` to the folder during the pre-flight check | The identity has Graph permissions but no SharePoint folder permission | Add Edit/Contribute on the destination folder for the identity, then re-run. |
| `Sites.ReadWrite.All` or `Files.ReadWrite.All` listed as missing on consent | App registration / managed identity lacks one of the two required Graph permissions | Add the missing permission and grant admin consent. |
| A long run uploads most files but the last big one fails | Almost always a transient network or auth blip | Re-run with the same parameters. PAX uses checkpoint/resume on the audit side and resumable upload on the destination side; you will not pay the full cost again. |
| The folder is empty after PAX prints "Run complete" | Check the script log file — PAX always uploads its own log last; if the log is in the folder, the run succeeded. If you are looking in the wrong folder, double-check the URL you passed. | — |

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Sending Output to Microsoft Fabric (OneLake)

<details>
<summary>📤 View Microsoft Fabric (OneLake) Output Guide (click to expand)</summary>

PAX can write output directly into a **OneLake folder inside a Microsoft Fabric lakehouse**. This is the right choice when:

- The downstream consumer is a Fabric notebook, pipeline, dataflow, or Power BI semantic model.
- You want results to be immediately queryable in Fabric without an upload step.
- You are running PAX from inside Azure (an Azure Container Apps Job, Azure VM, or similar) and want to skip the SharePoint hop entirely.

Pass a Fabric lakehouse URL as the `-OutputPath` parameter:

```powershell
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse"
```

When you point `-OutputPath` at the lakehouse root, PAX writes **Delta tables under `Tables/`** (raw, rollup interactions, rollup users) and **operational artifacts under `Files/`** (run log, metrics JSON, checkpoint). You can also point `-OutputPath` directly at `.../Tables` or `.../Tables/<schema>` (Schemas-mode Lakehouse) to control table location, and use `-OutputPathLog` / `-OutputPathUserInfo` to override individual destinations.

> 📁 For container images, deployment templates, identity setup walkthroughs, and other supporting material for running PAX inside Azure with a Fabric lakehouse destination, see the **`fabric_resources` folder in the repository root**. The instructions in this section cover the script-side experience; the `fabric_resources` folder covers the Azure-side hosting and setup.

### How PAX uses your Fabric lakehouse

1. **Pre-flight check (before any audit data is pulled).** PAX verifies the OneLake URL is valid, the lakehouse exists, and the signed-in identity has write access. If anything fails, the run stops with a clear error.
2. **Delta tables (`Tables/`).** PAX writes audit data as **Delta tables** — the raw event-level table, the rollup interactions table, and the rollup users table — directly under the lakehouse `Tables/` area. Tables stay at stable names across runs so downstream notebooks, pipelines, and Power BI semantic models bind once.
3. **Operational artifacts (`Files/`).** The run log, metrics JSON, and checkpoint file land under the lakehouse `Files/` area. You can redirect any of these with `-OutputPathLog` and related switches.
4. **Long-run handling.** OneLake sign-in is maintained automatically in the background, so multi-hour exports finish without interruption regardless of which authentication method you used for the audit side.
5. **Visibility.** Delta tables appear immediately under the lakehouse explorer's **Tables** section and become queryable from Fabric notebooks, pipelines, dataflows, and Power BI semantic models. Operational files appear under the **Files** section.

### How to get the right URL (and what NOT to paste)

PAX needs the **OneLake DFS URL** of a Fabric lakehouse (or a folder underneath it). The URL shape is:

```
https://onelake.dfs.fabric.microsoft.com/<workspace>/<item>.Lakehouse[/Tables[/<schema>]]
https://onelake.dfs.fabric.microsoft.com/<workspace>/<item>.Lakehouse[/Files[/<folder>]]
```

**Recommended:** point `-OutputPath` at the lakehouse root — PAX automatically routes Delta tables to `Tables/` and operational artifacts to `Files/`:

```
https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse
```

For a **Schemas-mode Lakehouse**, append `/Tables/<schema>` (default schema is `dbo`) to land Delta tables under a specific schema:

```
https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Tables/dbo
```

Warehouse items (`.Warehouse` suffix) are also accepted by the URL parser, but Delta-table writes are designed for Lakehouse items — use a Lakehouse for the Tables/ side of the output.

**How to build it:**

1. In the Fabric portal, open the destination workspace.
2. Note the **workspace name** (the URL segment after `/groups/<id>/` in the browser, *or* the display name shown in the workspace settings). The workspace name in the URL is case-sensitive.
3. Open the destination **lakehouse**. Note its name — that is the `<item>` value. The suffix must be `.Lakehouse` exactly.
4. (Optional) For finer control, append `/Tables` (or `/Tables/<schema>` on a Schemas-mode Lakehouse) to direct Delta tables, or `/Files/<folder>` to direct operational artifacts. Otherwise, just use the lakehouse root and PAX handles routing automatically.
5. Assemble the URL in the shape shown above.

**URLs that will NOT work — do not paste any of these:**

| Bad URL shape | Why it fails |
|---|---|
| Anything from a **Power BI report**, **dataset**, or **semantic model** link | Those are different surfaces; PAX writes to OneLake `Tables/` and `Files/`, not to a model or report. |
| The lakehouse **portal URL** from your browser (e.g. `https://app.fabric.microsoft.com/groups/<guid>/lakehouses/<guid>`) | That is a UI page. PAX needs the OneLake DFS URL, which begins with `https://onelake.dfs.fabric.microsoft.com/`. |
| A URL with no item-type suffix (missing `.Lakehouse` or `.Warehouse`) | OneLake routes requests by item type; the suffix is required. |
| `http://...` (no `s`) | PAX requires HTTPS. |

### Required permissions (all three layers — partial setup will fail)

| Layer | What you need | Granted in |
|---|---|---|
| **Azure role** | `Storage Blob Data Contributor` on the OneLake storage of the destination workspace | Azure portal → workspace → Access control (IAM) |
| **Fabric workspace role** | **Contributor** (or higher) on the destination workspace | Fabric portal → workspace → Manage access |
| **Fabric tenant setting** | *Service principals can use Fabric APIs* enabled (only required for `-Auth AppRegistration` or `-Auth ManagedIdentity`) | Fabric admin portal → Tenant settings |

> 💡 If the run fails at the OneLake step with a permission error and you are sure the identity has both the Azure role and the workspace role, the missing piece is almost always the tenant setting. Only a Fabric admin can flip it.

### Module prerequisite

A Fabric lakehouse `-OutputPath` requires the `Az.Accounts` PowerShell module (used to acquire the OneLake access token) **and** the Python `deltalake` package (used to write the Delta tables). PAX does **not** auto-install `Az.Accounts` — install it once ahead of time:

```powershell
Install-Module Az.Accounts -Scope CurrentUser
```

PAX will install the Python `deltalake` package automatically on first use if a Python environment is available; on locked-down hosts, install it once ahead of time:

```powershell
pip install deltalake
```

### More examples

<details>
<summary>💻 Show Fabric output examples</summary>

```powershell
# 1. Interactive run, output goes into a Fabric lakehouse Files folder
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse"

# 2. Schemas-mode Lakehouse — land Delta tables under a specific schema
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-31 `
	-OutputPath "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Tables/dbo"

# 3. Lakehouse root plus separate Files/ subfolder for the run log
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse" `
	-OutputPathLog "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/logs"

# 4. Containerized run on Azure Container Apps Jobs using a managed identity
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth ManagedIdentity `
	-TenantId "<tenant-guid>" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse"
```

</details>

### If something goes wrong

| What you see | Most likely cause | What to do |
|---|---|---|
| `OneLake URL is not in the expected shape` at the very start | Missing `.Lakehouse` / `.Warehouse` suffix, wrong host, or malformed path | Rebuild the URL using the shape in *How to get the right URL* above. |
| `Access denied to OneLake Tables/...` or `Files/...` during pre-flight | Identity is missing one of: Azure role, Fabric workspace role, or tenant setting | Verify all three layers in the permissions table above. If two are in place, suspect the tenant setting — only a Fabric admin can change it. |
| `Module 'Az.Accounts' could not be installed` or `Az.Accounts not found` | Locked-down host that blocks PowerShell Gallery, or the module was never installed | Pre-install with `Install-Module Az.Accounts -Scope CurrentUser` (or AllUsers) from an environment that can reach PowerShell Gallery. |
| `deltalake` Python package errors during table write | Python or `deltalake` not present on the host | Install Python 3.9+ and `pip install deltalake`. |
| Multi-hour export fails partway through with an auth error to OneLake | Rare; usually a tenant-side credential rotation | Re-run with the same parameters. PAX uses checkpoint/resume on the audit side; you will not start over from zero. |
| Delta tables do not appear in the Fabric lakehouse explorer | You may be looking at the wrong workspace/lakehouse, or filtering by name | Open the destination lakehouse → **Tables** section. PAX writes stable table names; refresh the lakehouse explorer if the tables were created during your current session. |

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

### Performance Tuning Examples

<details>
<summary>💻 Show Performance Tuning Examples</summary>

```powershell
# Reduce block size for dense data (hitting 10K limit)
./PAX_Purview_Audit_Log_Processor.ps1 -BlockHours 0.25 -StartDate 2025-10-01 -EndDate 2025-10-01

# Increase block size for sparse historical data
./PAX_Purview_Audit_Log_Processor.ps1 -BlockHours 4.0 -StartDate 2025-09-01 -EndDate 2025-09-07

# Add pacing to reduce throttling
./PAX_Purview_Audit_Log_Processor.ps1 -PacingMs 250 -StartDate 2025-10-01 -EndDate 2025-10-02

# Cap memory at 4 GB for large standard exports
./PAX_Purview_Audit_Log_Processor.ps1 -MaxMemoryMB 4096 -StartDate 2025-10-01 -EndDate 2025-10-31
```

</details>

### Parallel Execution

<details>
<summary>💻 Show Parallel Execution Examples</summary>

**Query Parallelism (Multiple Activity Types):**

```powershell
# Auto-detect parallel benefit
./PAX_Purview_Audit_Log_Processor.ps1 -ParallelMode Auto -ActivityTypes CopilotInteraction,MessageSent,FileAccessed

# Force parallel with custom concurrency
./PAX_Purview_Audit_Log_Processor.ps1 -ParallelMode On -MaxConcurrency 4 -MaxParallelGroups 2 -ActivityTypes CopilotInteraction,MessageSent,FileAccessed
```

</details>

### Agent Filtering

<details>
<summary>💻 Show Agent Filtering Examples</summary>

```powershell
# Filter for any agent-related records (live query)
./PAX_Purview_Audit_Log_Processor.ps1 -AgentsOnly -StartDate 2025-10-01 -EndDate 2025-10-02

# Filter for specific agent ID(s)
./PAX_Purview_Audit_Log_Processor.ps1 -AgentId "SYSTEM_CreateGPT.declarativeCopilot" -StartDate 2025-10-01 -EndDate 2025-10-02

# Multiple agent IDs
./PAX_Purview_Audit_Log_Processor.ps1 -AgentId "SYSTEM_CreateGPT.declarativeCopilot","CopilotStudio.Declarative.T_..." -StartDate 2025-10-01 -EndDate 2025-10-02
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

# Group filtering (works in both Graph API and EOM modes)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
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

# ManagedIdentity (Azure-hosted, unattended, no secrets)
./PAX_Purview_Audit_Log_Processor.ps1 -Auth ManagedIdentity -TenantId "<tenant-guid>" -StartDate 2025-10-01 -EndDate 2025-10-02
```

</details>

### Sending Output to SharePoint

<details>
<summary>💻 Show SharePoint Output Examples</summary>

```powershell
# Interactive run, output goes straight to a team folder
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"

# Unattended run from Azure using a managed identity
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth ManagedIdentity `
	-TenantId "<tenant-guid>" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"
```

See [Sending Output to SharePoint](#sending-output-to-sharepoint) for full details, including how to obtain a valid URL.

</details>

### Sending Output to Microsoft Fabric

<details>
<summary>💻 Show Fabric Output Examples</summary>

```powershell
# Output goes straight to a Fabric lakehouse (Delta tables under Tables/, operational artifacts under Files/)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse"

# Containerized run on Azure using a managed identity
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth ManagedIdentity `
	-TenantId "<tenant-guid>" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPath "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse"
```

See [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake) for full details, including how to build the URL and the required three-layer permissions.

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
```

</details>

### How Agent Filtering Works

<details>
<summary>🔍 Show Technical Details</summary>

1. **Agent Filtering Phase**:
   - Each record's `ParsedAuditData.AgentId` field is evaluated
   - `-AgentsOnly`: Includes any record where `AgentId` is present and non-empty
   - `-AgentId`: Includes records where `AgentId` matches one of the specified values (case-insensitive)
   - Non-matching records are excluded from output

2. **Output Generation**:
   - Summary includes pre/post filter counts and retention rate
   - Log file documents exact filter criteria applied

</details>

### Agent Filtering Performance

<details>
<summary>📊 Show Performance Metrics</summary>

- Agent filtering occurs server-side via activity type selection
- Use standard Copilot activity types (CopilotInteraction, etc.)
- Agent switches apply additional post-retrieval filtering

**Memory Usage:**
- Low overhead: only filtered records remain in memory
- Safe for processing multi-million record datasets

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

- **Efficiency**: In live mode, reduces data retrieved from Purview server-side
- **User-Specific Investigations**: Track a specific user's Copilot interactions for security reviews, compliance audits, or support troubleshooting
- **Group Analysis**: Automatically expand distribution groups to monitor department-wide or team-level adoption
- **Performance**: Reduce processing time and data transfer by targeting specific users
- **Compliance**: Isolate user activity for regulatory audits, eDiscovery requests, or data governance

### Modes and Behavior

**User Filtering (`-UserIds`):**
- **Graph API Mode (Default):** Client-side filtering after retrieval (filters all retrieved records)
- **EOM Mode (`-UseEOM`):** Server-side filtering via `Search-UnifiedAuditLog -UserIds`

**Group Filtering (`-GroupNames`):**
- **Graph API Mode (Default):** Groups are expanded via `Get-MgGroup` + `Get-MgGroupMember` (requires `GroupMember.Read.All`), then the resulting member emails are applied as a client-side filter after retrieval
- **EOM Mode (`-UseEOM`):** Groups are expanded via `Get-DistributionGroupMember` (Exchange Online), then filtered server-side via `Search-UnifiedAuditLog -UserIds`
- Supported in both modes; identifier can be display name, mail address, or (in Graph API mode) the group's object ID

### When to Use User/Group Filtering

**Use `-UserIds`** when:
- Investigating specific user(s) Copilot activity
- Conducting security reviews or compliance audits for individual accounts
- Troubleshooting user-reported issues
- Analyzing power users or early adopters
- Works with both Graph API (default) and EOM mode

**Use `-GroupNames`** when:
- Analyzing department-wide or team-level adoption (works in both Graph API and EOM modes)
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

# Filter for a distribution group (Graph API mode - default)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-GroupNames "Engineering-Team@contoso.com" `
	-OutputPath "C:\Exports\\"

# Same group filter under EOM mode (server-side audit filter)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UseEOM `
	-GroupNames "Engineering-Team@contoso.com" `
	-OutputPath "C:\Exports\\"

# Filter for multiple groups (Graph API mode)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-GroupNames "Sales@contoso.com","Marketing@contoso.com" `
	-OutputPath "C:\Exports\\"

# Combine UserIds and GroupNames
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "ceo@contoso.com","cfo@contoso.com" `
	-GroupNames "ExecutiveTeam@contoso.com" `
	-OutputPath "C:\Exports\\"

# Combine with agent filtering for targeted analysis
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-UserIds "poweruser@contoso.com" `
	-AgentsOnly `
	-OutputPath "C:\Exports\\"
```

</details>

### How User and Group Filtering Works

<details>
<summary>🔍 Show Technical Details</summary>

**Live Mode Process:**

1. **Group Expansion** (if `-GroupNames` used):
   - **Graph API mode (default):** Calls `Get-MgGroup` to resolve each group, then `Get-MgGroupMember` to enumerate members (requires `GroupMember.Read.All`); extracts member UPNs/emails
   - **EOM mode (`-UseEOM`):** Connects to Exchange Online, calls `Get-DistributionGroupMember`, extracts `PrimarySmtpAddress` from each member
   - Combines results with any `-UserIds` provided and deduplicates the final user list

2. **Audit Filtering:**
   - **EOM mode:** Passes expanded user list to `Search-UnifiedAuditLog -UserIds` parameter; the Purview server filters records matching any UserIds and only matching records are transmitted to the client (server-side, highly efficient)
   - **Graph API mode:** The Graph audit query API does not accept UPN filters server-side; the full audit window is retrieved and PAX applies the user-list filter client-side after retrieval (still benefits from any `-RecordTypes` / `-ActivityTypes` / date filtering)

3. **Progress Tracking**:
   - Shows user/group expansion status
   - Displays target user count
   - Progress bar reflects retrieval and processing phases

</details>

### User and Group Filtering Performance

<details>
<summary>📊 Show Performance Metrics</summary>

**Live Query Mode (mode-dependent):**
- **EOM mode:** Extremely efficient — filtering happens server-side at Microsoft 365 Purview; only matching records transmitted over the network
- **Graph API mode:** User filtering is client-side after retrieval; combine with `-RecordTypes`, `-ActivityTypes`, and tight date ranges to keep the retrieval window small
- Group expansion adds ~2-5 seconds per group (one-time cost; same in both modes)
- **Recommended** when targeting specific users/groups in either mode

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

- **Authentication:** In EOM mode, group expansion requires Exchange Online authentication; in Graph API mode, group expansion uses the Microsoft Graph session and requires the `GroupMember.Read.All` scope
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
- **Performance**: Two-stage filtering optimizes processing (pre-filter records + conversation-level filtering during processing)

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
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Export only Copilot responses
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-PromptFilter Response `
	-OutputPath "C:\Exports\\"

# Combine with agent filtering: Agent prompts only
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentsOnly `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"
```

</details>

### How PromptFilter Works

<details>
<summary>🔍 Show Filtering Technical Details</summary>

PromptFilter analyzes each record's Messages array (conversation turns) and:

- Categorizes records: Mixed (prompts+responses), Prompt-only, Response-only, No conversation data
- Filters out records without matching conversation turns
- Filters individual conversation turns matching the selected filter option

**PromptFilter Behavior by Option:**

- **Prompt**: Keeps records with at least one prompt; outputs only prompt conversation turns
- **Response**: Keeps records with at least one response; outputs only response conversation turns
- **Both**: Keeps records with at least one conversation turn having explicit isPrompt value
- **Null**: Keeps records with null isPrompt conversation turns

</details>

### PromptFilter + Agent Filtering Combination

<details>
<summary>💻 Show PromptFilter + Agent Examples</summary>

```powershell
# Agent interactions only, prompts only
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-AgentsOnly `
	-PromptFilter Prompt `
	-OutputPath "C:\Exports\\"

# Non-agent interactions only, prompts only
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
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
- **Processing time**: Filter execution time

</details>

### Output Schema

When using PromptFilter, the `Message_isPrompt` column will contain:

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

1. **User/Group Filtering** - Server-side in EOM mode (via `Search-UnifiedAuditLog -UserIds`), client-side in Graph API mode (parsing UserId from JSON)
2. **Agent Filtering** - Filters by agent presence or specific agent IDs (AgentsOnly, AgentId, ExcludeAgents)
3. **Prompt Filtering** - Filters conversation turns by isPrompt property

**Performance Note:** User/Group filtering performance varies by mode. EOM mode (`-UseEOM`) offers server-side filtering which is highly efficient. Graph API mode (default) uses client-side filtering, which retrieves all records first then filters.

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
- Removes resource-only rows (cleaner message-focused dataset)
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
	-OutputPath "C:\Exports\\"
```

</details>

**Benefits:**
- **Maximum precision:** Combines server-side user filtering, agent filtering, and conversation turn filtering
- **Optimal performance:** Server-side reduces data transfer (live mode)
- **Clean dataset:** Only relevant conversation turns for the targeted user/agent combination
- **Typical reduction:** 95%+ of original data filtered out for highly focused analysis

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
- **Graph API Mode (Default):** User filtering is client-side - retrieves all records first then filters; consider EOM mode for user-specific queries
- **PromptFilter Impact:** Reduces output rows by 15-20% when using `Both` (removes resource-only rows)
- **Three-Filter Combo:** Can reduce final output by 95%+ for highly targeted analysis

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

The bundle includes a curated set of 22 activity types across five groups:

#### Exchange / Email

| Operation | Description |
|-----------|-------------|
| MailItemsAccessed | Email items accessed (read/preview) |
| MailboxLogin | Mailbox sign-in |
| Send | Email sent |

#### SharePoint / OneDrive - File Access

| Operation | Description |
|-----------|-------------|
| FileAccessed | File accessed |
| FileViewed | File viewed |
| FilePreviewed | File previewed |
| FileModified | File modified |
| FileDownloaded | File downloaded |
| FileUploaded | File uploaded |

#### Teams - Chat/Messaging

| Operation | Description |
|-----------|-------------|
| MessageSent | Message sent |
| MessageRead | Message read |
| MessagesListed | Messages listed |
| ChatRetrieved | Chat retrieved |
| ChatCreated | Chat created |
| TeamsSessionStarted | Teams session started |

#### Teams - Meeting Lifecycle

| Operation | Description |
|-----------|-------------|
| MeetingParticipantJoined | Participant joined meeting |
| MeetingStarted | Meeting started |
| MeetingEnded | Meeting ended |
| MeetingParticipantDetail | Participant details accessed |
| MeetingDetail | Meeting details accessed |

#### Copilot / Connected AI

| Operation | Description |
|-----------|-------------|
| CopilotInteraction | Microsoft 365 Copilot interaction |
| ConnectedAIAppInteraction | Connected AI app interaction |

Any Microsoft 365 operation outside this curated set can still be requested individually through `-ActivityTypes` (the bundle operations are added to whatever you supply there).

For easy copy/paste into scripts or pipelines, the full list of activity types enabled by `-IncludeM365Usage` is provided below as a single comma-separated list.

```text
MailItemsAccessed,MailboxLogin,Send,FileAccessed,FileViewed,FilePreviewed,FileModified,FileDownloaded,FileUploaded,MessageSent,MessageRead,MessagesListed,ChatRetrieved,ChatCreated,TeamsSessionStarted,MeetingParticipantJoined,MeetingStarted,MeetingEnded,MeetingParticipantDetail,MeetingDetail,CopilotInteraction,ConnectedAIAppInteraction
```

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

For easy copy/paste into scripts or pipelines, the full list of record types enabled by `-IncludeM365Usage` is provided below as a single comma-separated list.

```text
ExchangeAdmin,ExchangeItem,ExchangeMailbox,SharePointFileOperation,SharePointSharingOperation,SharePoint,OneDrive,MicrosoftTeams,OfficeNative,MicrosoftForms,MicrosoftStream,PlannerPlan,PlannerTask,PowerAppsApp
```

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
4. **Exclude Copilot if focusing on baseline:** Use `-ExcludeCopilotInteraction` when establishing pre-Copilot baseline metrics

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Rollup Post-Processor (Power BI)

<details>
<summary>📊 View Rollup Post-Processor Guide (Click to Expand)</summary>

> **Purpose & scope.** The `-Rollup` and `-RollupPlusRaw` switches (added in **v1.11.1**) exist **solely to produce input files for the Microsoft Copilot Growth ROI Advisory Team's Power BI templates** published at <https://github.com/microsoft/Analytics-Hub>. The rolled-up CSVs are shaped specifically for those templates — schema, column names, aggregation grain, and join keys are all dictated by the Power BI data models. **The rollup outputs are not intended for any other downstream use.** If you need a generic analytics export, run PAX without `-Rollup` / `-RollupPlusRaw` and consume the raw CSV directly.

### Overview

When `-Rollup` or `-RollupPlusRaw` is specified, PAX runs an **embedded Python post-processor** against the audit run's final CSV immediately after a successful export. The processor — and therefore the target Power BI template — is auto-selected based on the activity-type shape of the run:

| Run shape | Embedded processor | Inputs consumed | Target Analytics-Hub dashboard(s) |
| --- | --- | --- | --- |
| **CopilotInteraction-only** (default activity type, or `-ActivityTypes 'CopilotInteraction'`) | `Purview_CopilotInteraction_Processor` | Purview CSV **+** Entra users CSV (`EntraUsers_MAClicensing_<timestamp>.csv`) | **AI-in-One** and **AI Business Value** |
| **`-IncludeM365Usage`** | `Purview_M365_Usage_Bundle_Explosion_Processor` | Combined Purview CSV (single file) | **M365 Usage Analytics** |

### Switches

| Switch | Behavior |
| --- | --- |
| `-Rollup` | After the embedded processor succeeds, **deletes the raw CSV(s)** so only the rolled-up output remains. Mutually exclusive with `-RollupPlusRaw`. |
| `-RollupPlusRaw` | After the embedded processor succeeds, **keeps the raw CSV(s)** alongside the rolled-up output. Mutually exclusive with `-Rollup`. |

On processor failure, raw CSV(s) are always retained — raw outputs are the canonical successful audit-run artifact; rollup is best-effort.

### Auto-Enabled Switches

Depending on the run shape, the rollup feature auto-enables companion switches so the embedded processor receives the inputs it requires:

- **CopilotInteraction-only run:** `-IncludeUserInfo` is auto-enabled so the Entra users CSV is produced (the processor consumes both files). See [User and Group Filtering](#user-and-group-filtering) and [Output Files & Schema](#output-files--schema).
- **`-IncludeM365Usage` run:** `-CombineOutput` is auto-enabled by `-IncludeM365Usage` so a single combined Purview CSV is fed to the processor. See [Microsoft 365 Usage Bundle](#microsoft-365-usage-bundle).

### Runtime Requirements

| Requirement | Detail |
| --- | --- |
| **PowerShell** | 7.0+ (the rollup feature is unavailable under PowerShell 5.1 / `-UseEOM`). |
| **Python** | 3.10+. If Python is not on `PATH`, the script attempts a per-user silent install: `winget install Python.Python.3.13` first, falling back to the official python.org installer. |
| **`orjson`** | Auto-installed (`pip install --user orjson`) for faster JSON parsing. Optional — the processor falls back to the stdlib `json` module if installation fails. |

### Banner

When the rollup feature is active, PAX prints a cyan banner near the start of the run identifying the selected processor, target Analytics-Hub dashboard(s), retention behavior, and runtime requirements — so the operator can confirm the correct Power BI template is being targeted before the audit query begins.

### Checkpoint Persistence

Rollup configuration is persisted in the checkpoint JSON (`rollupMode` ∈ `None | Rollup | RollupPlusRaw`, plus `processorMode`). On resume, the saved values take precedence (last-write-wins) and the script re-derives the runtime processor selection so a resumed run produces the same Power BI input file as the original.

### Blocked Combinations

The rollup feature is intentionally narrow in scope. The script exits with an explicit error if any of the following is combined with `-Rollup` / `-RollupPlusRaw`:

- `-UseEOM` (PowerShell 5.1 path)
- `-OnlyUserInfo`
- `-ExcludeCopilotInteraction` **without** `-IncludeM365Usage`

### Output Files

Rolled-up CSVs are written to the same directory as the raw Purview CSV (default: `./output/`). File names follow the embedded processor's own naming conventions and are the exact files expected by the Analytics-Hub Power BI templates — **do not rename them**. See [Output Files & Schema](#output-files--schema) for the surrounding directory layout.

### Examples

```powershell
# CopilotInteraction-only rollup → AI-in-One + AI Business Value dashboards.
# Raw CSV(s) deleted on success; only the rollup output remains.
.\PAX_Purview_Audit_Log_Processor.ps1 -StartDate '2026-04-01' -EndDate '2026-04-30' -Rollup

# Same as above but keep the raw Purview + Entra users CSVs alongside the rollup output.
.\PAX_Purview_Audit_Log_Processor.ps1 -StartDate '2026-04-01' -EndDate '2026-04-30' -RollupPlusRaw

# M365 Usage Analytics dashboard input. -IncludeM365Usage auto-enables -CombineOutput;
# -Rollup deletes the raw combined CSV after the rollup output is produced.
.\PAX_Purview_Audit_Log_Processor.ps1 -StartDate '2026-04-01' -EndDate '2026-04-30' -IncludeM365Usage -Rollup
```

### Best Practices

1. **Match the switch to the dashboard.** Use a CopilotInteraction-only run for **AI-in-One** / **AI Business Value**; use `-IncludeM365Usage` for **M365 Usage Analytics**. Mixing the two in a single run is not supported by the Power BI templates.
2. **Prefer `-RollupPlusRaw` for first-time validation.** Keeping the raw CSV lets you spot-check the rollup output against the source data before deleting raws on subsequent runs.
3. **Don't rename output files.** The Analytics-Hub templates load files by name pattern. Renaming will break the data refresh.
4. **Don't repurpose rollup outputs.** The schemas are tuned for the named Power BI templates. For ad-hoc analytics, BI ingestion outside Analytics-Hub, or custom data warehouses, use the raw Purview CSV instead.
5. **Review the rollup banner.** Confirm the displayed target dashboard matches your intended Power BI template before letting a long audit run continue.

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
- **Maintain consistent naming** for scheduled reports and automation workflows

**Key Benefits:**
- **Zero data loss:** Safe header validation prevents schema conflicts
- **Flexible workflows:** Works with CSV output (multi-file or combined)
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

---

### File Path Resolution

| Scenario | `-AppendFile` Value | `-OutputPath` Value | Final Path Used |
|----------|---------------------|---------------------|-----------------|
| **Full path** | `"C:\Data\Report.csv"` | (any value) | `C:\Data\Report.csv` |
| **Filename only** | `"Report.csv"` | `"C:\Data"` | `C:\Data\Report.csv` |
| **Filename + default** | `"Report.csv"` | (not specified) | `.\output\Report.csv` |
| **Conflicting paths** | `"C:\Data\Report.csv"` | `"C:\Other"` | `C:\Data\Report.csv` (warns about conflict) |

**Recommendation:** Use full paths in automation scripts for explicit control; use filename-only in interactive workflows with `-OutputPath`.

---

### Restrictions & Requirements

**Cannot Be Used With:**
- **`-OnlyUserInfo`:** That mode outputs a point-in-time user/license snapshot only — no audit data stream exists to append into

**Pairs With (companion switches):**
- **`-AppendUserInfo`:** Parallel switch for the EntraUsers CSV stream. Use `-AppendFile` + `-AppendUserInfo` together when you also want to incrementally update the user/license snapshot file. `-AppendUserInfo` auto-enables `-IncludeUserInfo`.

**Requires:**
- **Single-file output:** Must use one of:
  - `-CombineOutput` (CSV combined mode)
  - Single activity type (e.g., `-ActivityTypes CopilotInteraction` only)
- **File must exist:** Run once without `-AppendFile` to create initial file, then use `-AppendFile` for subsequent runs

**Works With:**
- **Live query mode:** Append new date ranges to existing files
- **`-IncludeUserInfo`:** Compatible — `-AppendFile` only touches the Purview audit CSV; the EntraUsers CSV is a separate file (manage it with `-AppendUserInfo` or `-OutputPathUserInfo`)
- **All filtering options:** Agent, user, group, prompt filtering fully compatible

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
	-CombineOutput `
	-OutputPath "C:\AuditArchive"
# Creates: Purview_Audit_CombinedUsageActivity_20251110_080000.csv

# Daily append (scheduled task)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate (Get-Date).AddDays(-1) `
	-EndDate (Get-Date) `
	-CombineOutput `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_080000.csv" `
	-OutputPath "C:\AuditArchive"
```

**Benefits:**
- Single CSV contains entire 90-day history
- No manual consolidation required
- Consistent naming for downstream tools (Power BI, etc.)

</details>

<details>
<summary>💼 Multi-Tenant Consolidation</summary>

**Scenario:** MSP managing multiple customer tenants, consolidating audit data into single file per customer

```powershell
# Customer A - Tenant 1 (initial)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-CombineOutput `
	-OutputPath "C:\Customers\CustomerA"
# Creates: Purview_Audit_CombinedUsageActivity_20251110_143022.csv

# Customer A - Tenant 1 (append Week 2)
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-08 `
	-EndDate 2025-10-09 `
	-CombineOutput `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_143022.csv" `
	-OutputPath "C:\Customers\CustomerA"
```

**Benefits:**
- Single file per customer (easy distribution)
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
```

#### Common Schema Mismatch Causes

| Cause | Solution |
|-------|----------|
| **Changed activity types** | Maintain same `-ActivityTypes` list across runs |
| **Schema evolution** | Microsoft adds new fields to API response — rebuild initial file when this happens |

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
Get-Process | Where-Object {$_.MainWindowTitle -like "*Report.csv*"}

# Copy to local folder
Copy-Item "C:\OneDrive\Reports\Report.csv" "C:\temp\Report.csv"
.\PAX_Purview_Audit_Log_Processor.ps1 ... -AppendFile "C:\temp\Report.csv"

# Verify permissions
Test-Path "C:\Data\Report.csv" -PathType Leaf
(Get-Acl "C:\Data\Report.csv").Access
```

#### Pattern Matching Issues

**Issue:** Script doesn't find existing file when using pattern-based search

**Cause:** Filename doesn't match expected pattern

**Solution:** Use explicit full path instead of relying on pattern matching:
```powershell
# Instead of relying on pattern match
-AppendFile -OutputPath "C:\Data"

# Use explicit filename
-AppendFile "C:\Data\Purview_Export_20251030_143022.csv"
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
	-CombineOutput `
	-OutputPath "C:\Reports"
# Output: Purview_Audit_CombinedUsageActivity_20251110_080000.csv

# Week 2: Append
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-08 `
	-EndDate 2025-10-15 `
	-CombineOutput `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_080000.csv" `
	-OutputPath "C:\Reports"

# Week 3: Append
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-15 `
	-EndDate 2025-10-22 `
	-CombineOutput `
	-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_080000.csv" `
	-OutputPath "C:\Reports"

# Result: Single CSV with 3 weeks of continuous data
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
<summary>🏢 Enterprise Scheduled Task</summary>

```powershell
# Scheduled task: Daily at 2 AM
$taskName = "PAX_Daily_Append"
$scriptPath = "C:\Scripts\PAX_Purview_Audit_Log_Processor.ps1"
$outputPath = "C:\AuditArchive"
$fileName = "Annual_Audit_2025.csv"
$serviceAccountPassword = ConvertTo-SecureString "<service-account-password>" -AsPlainText -Force

# Task action
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument @"
-NoProfile -Command "$scriptPath -StartDate (Get-Date).AddDays(-1) -EndDate (Get-Date) -CombineOutput -AppendFile '$fileName' -OutputPath '$outputPath' -Silent"
"@

# Task trigger (daily 2 AM)
$trigger = New-ScheduledTaskTrigger -Daily -At 2am

# Register task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -User "DOMAIN\ServiceAccount" -Password $serviceAccountPassword

# Result: Single CSV automatically updated daily with previous 24h of data
```

</details>

---

### Best Practices

**Naming Strategy:**
- Use descriptive, date-based names: `Audit_2025_Q4.csv`
- Avoid spaces in filenames (simplifies automation)
- Include scope in name: `Executive_Team_Copilot_Usage_2025.csv`

**Schema Consistency:**
- Document parameters used for initial export
- Maintain same parameters for all append operations
- Test append on copy before production use

**File Management:**
- Keep backups before each append operation
- Use compression for archived datasets (7-Zip, etc.)

**Error Handling:**
- Always check exit code in automation: `if ($LASTEXITCODE -ne 0) { Send-MailMessage ... }`
- Log append operations to separate file for audit trail
- Test file accessibility before starting long-running queries

**Performance:**
- Appending adds minimal overhead (< 5 seconds for header validation)
- CSV append is fast even for very large datasets

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
> - **403 Forbidden:** Permissions issue → Token refresh will NOT help. Check `AuditLogsQuery.Read.All` consent and role assignments.

### Resume Mode: Standalone Behavior

**IMPORTANT:** The `-Resume` switch is standalone. All processing parameters are restored from the checkpoint file to ensure data consistency. You cannot specify other parameters with `-Resume` (except authentication overrides).

**Allowed with `-Resume`:**
- `-Force` - Use most recent checkpoint without prompting
- `-Auth` - Override authentication method
- `-TenantId`, `-ClientId`, `-ClientSecret` - Auth credentials for AppRegistration
- `-MaxMemoryMB` - Override memory threshold (e.g., resuming on different hardware)

**NOT Allowed with `-Resume`:**
- Any other parameter (dates, activities, output settings, etc.)

This restriction prevents schema inconsistencies between partitions of the same run.

### Resume Workflow

**Scenario:** Run interrupted after 2 hours due to token expiry

```powershell
# Original run (interrupted)
.\PAX_Purview_Audit_Log_Processor.ps1 `
    -StartDate 2025-12-01 `
    -EndDate 2025-12-15 `
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
| M365/User Info | IncludeM365Usage, IncludeUserInfo |
| Partitioning | BlockHours, PartitionHours, MaxPartitions |
| Output | OutputPath, CombineOutput |
| Auth (method only) | Auth, TenantId, ClientId (no secrets) |
| Tuning | ResultSize, MaxConcurrency, AutoCompleteness, IncludeTelemetry, StatusIntervalSeconds |
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

#### 1. Data Export File (CSV)

- **Location:** Specified by `-OutputPath` parameter (directory) or `-AppendFile` (specific filename/path)
- **Format:** UTF-8 without BOM, standard CSV with quoted fields, CRLF line endings (Windows) or LF (macOS/Linux)
- **Header:** Always written (even when zero records match)
- **Default:** Separate files per activity type (use `-CombineOutput` to merge into single file)

**CSV File Naming:**
- **Default (separate files per activity type):** `<ActivityTypeName>_<timestamp>.csv` (e.g., `CopilotInteraction_20251107_143022.csv`, `ConnectedAIAppInteraction_20251107_143022.csv`)
- **Combined mode (with `-CombineOutput`):** `Purview_Audit_CombinedUsageActivity_<timestamp>.csv`
- **Entra users file (when `-IncludeUserInfo` used):** `EntraUsers_MAClicensing_<timestamp>.csv`

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

**Column Count:** 8 fixed columns (matching Purview UI audit export format)

**Columns:** RecordId, CreationDate, RecordType, Operation, UserId, AuditData, AssociatedAdminUnits, AssociatedAdminUnitsNames

**Use When:** Need raw data for custom processing or minimal transformation

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

**Mode requirement:** Requires **Graph API mode** (default) — not compatible with `-UseEOM`

---

### Requirements

| Requirement | Details |
|-------------|---------|
| **Mode** | Graph API (default) - **NOT compatible with `-UseEOM`** |
| **Parameter** | `-IncludeUserInfo` switch |
| **Permissions** | `User.Read.All`, `Organization.Read.All` (least privilege Graph API scopes) |
| **Output** | Separate `EntraUsers_MAClicensing_<timestamp>.csv` file |
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

`HasLicense` is computed dynamically against the live tenant catalog — there is **no hard-coded SKU allow-list** in the script:

1. PAX calls Microsoft Graph `/subscribedSkus` and enumerates each SKU's `servicePlans` collection.
2. Every `servicePlanId` whose `servicePlanName` matches the wildcard `*COPILOT*` is added to a per-run "Copilot service plan" set.
3. For each user, PAX inspects every entry in `assignedPlans`. The user is flagged `HasLicense = True` when **any** assigned plan satisfies both:
   - `capabilityStatus == 'Enabled'`, AND
   - `servicePlanId` is in the discovered Copilot service plan set.
4. Users with no matching enabled plan get `HasLicense = False`. The full friendly SKU name list still appears in `AssignedLicenses` for traceability.

**Why dynamic:** Microsoft adds new Copilot SKUs and renames existing ones regularly (e.g., across M365, EDU, Sales, Service, Finance, GCC). The wildcard match against the live `/subscribedSkus` catalog auto-adapts to any current or future Copilot SKU without requiring a script update.

**Caveats:**

- Detection depends on the SKU's `servicePlanName` containing the substring `COPILOT`. SKUs that ship Copilot capabilities under a non-`COPILOT` plan name will not be detected.
- Plans assigned but disabled at the user level (`capabilityStatus != 'Enabled'`) deliberately do not count, matching real entitlement state.

---

### Usage Examples

<details>
<summary>💻 Show Entra Enrichment Examples</summary>

```powershell
# Basic Entra enrichment
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-IncludeUserInfo
# Output: CopilotInteraction_<timestamp>.csv + EntraUsers_MAClicensing_<timestamp>.csv
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

1. **Cache Reuse:** Run multiple audit queries in same session to reuse cached user data
2. **Selective Filtering:** Use `-UserIds` or `-GroupNames` to reduce audit dataset size before enrichment
3. **License Auditing:** Export EntraUsers separately and audit `HasLicense` against actual license assignments
4. **Power BI Templates:** When importing into Copilot ROI Analytics team Power BI templates, use the same PAX-generated EntraUsers file for both the "User/Org Data" and "Licensing Data" import prompts—the file contains all required columns for both

**Troubleshooting:**

- **Error: "Entra enrichment requires Graph API mode"** → Remove `-UseEOM` parameter
- **Error: "Insufficient privileges to complete the operation"** → Grant `User.Read.All` and `Organization.Read.All` Graph API permissions
- **Empty HasLicense:** Verify the tenant actually has Copilot SKUs in `/subscribedSkus`. PAX detects any SKU whose `servicePlanName` matches `*COPILOT*` automatically — there is no hard-coded SKU list to update. If a Copilot capability ships under a non-`COPILOT` plan name, file an issue.

---

### Limitations

| Limitation | Details | Workaround |
|------------|---------|------------|
| **Not compatible with `-UseEOM`** | Requires Graph API mode | Remove `-UseEOM` or skip `-IncludeUserInfo` |
| **Tenant-wide query** | Retrieves all users (no server-side filtering) | Use Graph API's `$filter` with custom script modifications |
| **Requires elevated permissions** | `User.Read.All` Graph scope needed | Request consent from Global Admin or Privileged Role Admin |
| **Guest user limitations** | Guest users may have limited attribute population | Expected behavior - guest profiles often sparse |
| **License SKU changes** | New Copilot SKUs are detected automatically via `/subscribedSkus` + `servicePlanName -like '*COPILOT*'` | None required — dynamic detection is future-proof for any SKU whose plan name contains `COPILOT` |

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Activity Types Reference

<details>
<summary>📊 View Activity Types Reference (Click to Expand)</summary>

### Copilot & AI Activities

- `CopilotInteraction` - Microsoft 365 Copilot usage events (default activity type)
- `ConnectedAIAppInteraction` - Connected AI app interactions (MIXED FREE/PAYG)
- `AIInteraction` - AI interactions (MIXED FREE/PAYG, currently Microsoft platforms only)
- `AIAppInteraction` - Third-party AI app interactions (PAYG, ~$0.0132/1K records)

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

Two optional switches—`-RecordTypes` and `-ServiceTypes`—pass Microsoft Graph `recordTypeFilters` and `serviceFilter` values directly to the audit query body. Use them to unlock classic Microsoft 365 app usage telemetry (Word, Excel, PowerPoint, OneNote, SharePoint, OneDrive, and Teams files) that sometimes requires explicit workload targeting when using the Graph Security endpoint.

- **Graph-only:** The switches are honored in Graph API mode (default). They are ignored automatically in EOM mode (`-UseEOM`).
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

### Parallel Execution

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

### Progress Tracking System

Real-time progress updates across three phases:

**Display Format:**

```
PAX Purview Audit Log Processing
Status: Query: 45/100(45%) | Export: 0/1(0%) :: 42%
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
	"ScriptVersion": "1.11.2",
	"StartTimestampUtc": "2025-10-26T14:05:23Z",
	"EndTimestampUtc": "2025-10-26T14:07:11Z",
	"TotalWindows": 42,
	"SubdividedWindows": 6,
	"Hit10KLimitWindows": 2,
	"AutoCompletenessIterations": 1,
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
- Atomic file write minimizes race conditions

**Tip:** If monitoring progress externally, tail the log file; metrics JSON only appears at end.

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

<details>
<summary>💻 Show Memory Optimization Examples</summary>

**For Large Exports:**

PAX automatically monitors memory and streams to JSONL when 75% of system RAM is reached. Use `-MaxMemoryMB` only to override the default threshold or disable it.

```powershell
# Override auto-detection — explicit 4 GB cap on memory-constrained machines
./PAX_Purview_Audit_Log_Processor.ps1 -MaxMemoryMB 4096 -StartDate 2025-10-01 -EndDate 2025-10-31

# Disable memory threshold — keep all records in memory (not recommended for large exports)
./PAX_Purview_Audit_Log_Processor.ps1 -MaxMemoryMB 0 -StartDate 2025-10-01 -EndDate 2025-10-31
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

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Troubleshooting

<details>
<summary>❓ View Troubleshooting (Click to Expand)</summary>

**Common Issues:**

- [Authentication Failures](#authentication-failures)
- [No Data Returned](#no-data-returned)
- [10K Limit Warnings](#10k-limit-warnings)
- [Memory Issues](#memory-issues)
- [Throttling Errors](#throttling-errors)
- [SharePoint Output Issues](#sharepoint-output-issues)
- [Fabric / OneLake Output Issues](#fabric--onelake-output-issues)
- [Managed-Identity Sign-In Issues](#managed-identity-sign-in-issues)

---

### Common Issues

#### Authentication Failures

**Problem:** "Unable to connect to Microsoft Graph" or "Unable to connect to Exchange Online"

**Solutions:**

**Graph API Mode (Default):**
- Verify you have `AuditLogsQuery.Read.All` permission (Application or Delegated). If you use `-IncludeM365Usage`, also verify the per-workload `AuditLogsQuery-Exchange.Read.All`, `AuditLogsQuery-OneDrive.Read.All`, and `AuditLogsQuery-SharePoint.Read.All` permissions are consented.
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

#### SharePoint Output Issues

**Problem:** Run fails at the very start with "Could not resolve SharePoint folder" or a similar URL error.

**Solutions:**
- Confirm the URL is the canonical folder path copied from the browser address bar while *viewing the folder*, not a "Copy link"/sharing link (`/:f:/s/...`), `_layouts/...` page, `Forms/AllItems.aspx`, or anything containing `?id=` / `?web=1`.
- Strip everything from `?` onward — query strings cannot be used.
- Confirm the URL uses HTTPS (PAX rejects `http://`).
- For OneDrive personal sites (`<tenant>-my.sharepoint.com/personal/...`), use a SharePoint team site library instead — OneDrive personal is not supported.
- See [Sending Output to SharePoint](#sending-output-to-sharepoint) for the full URL guide.

**Problem:** Pre-flight succeeds but the run fails mid-upload with an access-denied or scratch-folder error.

**Solutions:**
- Verify the identity holds Edit or Contribute on the destination folder, not just the parent library or site.
- Confirm the host running PAX has write access to its local scratch folder (PAX stages each file briefly before upload). The scratch folder lives next to the script's working directory; pick a host path that the identity can write to.

**Problem:** Run prints "Complete" but the SharePoint folder appears empty.

**Solutions:**
- Refresh the SharePoint folder view in the browser — newly uploaded files can take a few seconds to appear in the modern UI.
- Verify you are looking at the same folder URL you passed to PAX. The script's end-of-run summary lists every uploaded file with its full path.
- Check the script log file — it is uploaded last, so if the log is in the folder, the run did succeed.

#### Fabric / OneLake Output Issues

**Problem:** Run fails at the very start with "OneLake URL is not in the expected shape."

**Solutions:**
- The URL must start with `https://onelake.dfs.fabric.microsoft.com/` and address a Lakehouse (`.Lakehouse`) or Warehouse (`.Warehouse`) item under a workspace. The lakehouse-root form is recommended — PAX writes Delta tables under `Tables/` and operational artifacts (logs, JSONL incrementals, metrics) under `Files/` automatically.
- Do **not** paste the Fabric portal URL (`https://app.fabric.microsoft.com/...`); that is a UI page, not the OneLake DFS endpoint.
- For schema-enabled lakehouses you may also point at `Tables/<schema>` (e.g., `.Lakehouse/Tables/dbo`).
- See [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake) for the URL guide.

**Problem:** Run fails at the pre-flight check with "Access denied to OneLake Files/..." even though the identity can sign in.

**Solutions:**
- Confirm **all three** permission layers are in place: Azure role `Storage Blob Data Contributor` on the OneLake storage, Fabric workspace role **Contributor** (or higher), and the Fabric tenant setting *Service principals can use Fabric APIs* enabled (the tenant setting is required for `-Auth AppRegistration` and `-Auth ManagedIdentity`).
- If two of the three are in place and the run still fails, the missing piece is almost always the tenant setting. Only a Fabric admin can enable it.

**Problem:** Run fails to install or load `Az.Accounts`.

**Solutions:**
- On locked-down hosts where PowerShell Gallery is blocked, pre-install the module once from an environment that can reach the gallery: `Install-Module Az.Accounts -Scope CurrentUser`.
- Confirm the host can reach `onelake.dfs.fabric.microsoft.com` over HTTPS.

#### Managed-Identity Sign-In Issues

**Problem:** `-Auth ManagedIdentity` fails on a host that has multiple identities attached (one system-assigned plus one or more user-assigned).

**Solutions:**
- Set the `AZURE_CLIENT_ID` environment variable to the client ID of the specific managed identity PAX should use, then re-run.
- If the wrong identity is being chosen even with `AZURE_CLIENT_ID` set, verify the environment variable is exported in the same process / job that runs PAX (not just the parent shell).

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
| Memory usage                | Streaming, chunked export by default                                           | Tune with `-StreamingSchemaSample` / `-StreamingChunkSize`; shard by date for extreme spans                  |
| Parallel mode               | Graph API: time-partitioned parallel queries; EOM: multi-activity sets only    | Graph API mode (default) provides better parallel performance for single activity types                      |
| Time zones                  | Dates interpreted as UTC; `yyyy-MM-dd` must be UTC                             | Convert local times to UTC prior to invocation to avoid DST drift                                            |
| Streaming export            | Always on (chunked)                                                            | Adjust sample/chunk sizes for schema width & memory balance                                                  |
| Group filtering             | Supported in both modes — EOM filters server-side via `Search-UnifiedAuditLog -UserIds` after expanding via `Get-DistributionGroupMember`; Graph API mode expands via `Get-MgGroupMember` and applies the user filter client-side after retrieval | In Graph API mode, combine `-GroupNames` with tight date ranges / `-RecordTypes` to keep the retrieval window small |
| Microsoft 365 Usage bundle  | Requires per-workload Graph scopes: `AuditLogsQuery-Exchange.Read.All`, `AuditLogsQuery-OneDrive.Read.All`, `AuditLogsQuery-SharePoint.Read.All` in addition to base `AuditLogsQuery.Read.All` | Consent the per-workload scopes at first run. Without them, the bundle silently returns no data for the missing workloads. |
| SharePoint output URL       | `-OutputPath` accepts SharePoint folder URLs only in canonical form (`https://<tenant>.sharepoint.com/sites/<site>/<library>/...`). Sharing links (`/:f:/s/...`), `_layouts/` pages, `Forms/AllItems.aspx` view URLs, query-string URLs, OneDrive personal sites, and HTTP URLs are all rejected. | Copy the URL from the browser address bar while *viewing the destination folder*; strip everything from `?` onward. See [Sending Output to SharePoint](#sending-output-to-sharepoint). |
| Fabric output URL           | `-OutputPath` accepts Fabric output only as OneLake DFS URLs that address a Lakehouse (`.Lakehouse`) or Warehouse (`.Warehouse`) item under a workspace (lakehouse-root form recommended; `.Lakehouse/Tables/<schema>` also accepted for schema-enabled lakehouses). Fabric portal URLs and Power BI report/dataset URLs are rejected. PAX writes Delta tables under `Tables/` and operational artifacts (logs, JSONL incrementals, metrics) under `Files/` automatically. | Build the URL using the workspace and lakehouse/warehouse names. See [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake). |
| Fabric permissions          | Fabric output requires **three** layers: Azure role `Storage Blob Data Contributor`, Fabric workspace **Contributor** role, and Fabric tenant setting *Service principals can use Fabric APIs* enabled (for `AppRegistration` / `ManagedIdentity`). Partial setup will fail at the pre-flight check. | Coordinate the three roles with the workspace owner, Azure subscription admin, and Fabric tenant admin before scheduling unattended runs. |

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

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Security & Compliance

<details>
<summary>🔒 View Security & Compliance Information (Click to Expand)</summary>

> **Disclaimer**
>
> The information below describes how PAX is **designed** to handle credentials, data, and APIs. It is **not** a substitute for your organization's own security review, certification, accreditation, or compliance assessment. PAX is provided **AS IS** under the MIT License with no warranty and no official Microsoft Product Group support. Before adopting PAX in any regulated, production, or otherwise sensitive environment:
>
> - Have your security, privacy, and compliance teams review the script source code, the Graph permissions it requests, and the destination of its output files.
> - Validate that PAX's behavior meets your tenant's data-handling, retention, residency, and audit-trail requirements.
> - Confirm that any service principals, app registrations, role assignments, and consented Graph scopes you create for PAX conform to your least-privilege and separation-of-duties policies.
> - Treat all PAX output (CSV / Excel) as **sensitive audit data** and apply the same controls (storage, access, retention, encryption) you would apply to native Purview audit exports.
>
> The notes below are **PAX-side design facts**, not an endorsement, certification, or compliance attestation.

### What PAX Does (Design Facts)

- **Read-only against Microsoft Graph and Exchange Online.** PAX issues only `GET`-equivalent audit / catalog calls. It never writes to audit logs, never modifies tenant configuration, and never alters Entra / Graph state.
- **No third-party telemetry, no callbacks.** PAX does not transmit audit data, prompts, responses, user identities, or any tenant content to any non-Microsoft service. All processing happens on the local execution machine.
- **In-memory credential handling.** Tokens, client secrets, and certificate passwords are passed as in-memory strings or `SecureString` and are not written to disk by PAX. Token cache files written by `Microsoft.Graph` / `MSAL` modules are governed by those modules, not PAX.
- **Output to operator-supplied destination only.** PAX writes its CSV / JSON metrics output to the path you supply (`-OutputPath`) — a local folder, a SharePoint folder URL, or a Microsoft Fabric OneLake URL. It does not transmit data to any other destination.
- **Logged operations.** Each run produces a timestamped log file alongside the export, capturing parameter values (with secrets redacted) and per-phase timings for traceability.

### Graph Scopes PAX Requests (Least-Privilege Reference)

PAX is designed to request the **minimum scopes required for the features you actually invoke**. Your security team is responsible for confirming this matches your tenant's policy before consent.

**Graph API mode (default):**

| Feature | Scope(s) Requested |
|---|---|
| Baseline audit query (always) | `AuditLogsQuery.Read.All` |
| `-IncludeM365Usage` | `AuditLogsQuery-Exchange.Read.All`, `AuditLogsQuery-OneDrive.Read.All`, `AuditLogsQuery-SharePoint.Read.All` |
| `-IncludeUserInfo` / `-OnlyUserInfo` | `User.Read.All`, `Organization.Read.All` |
| `-GroupNames` | `User.Read.All`, `GroupMember.Read.All` |

PAX does **not** request write scopes, directory write scopes, mail/file content scopes, or tenant configuration scopes under any feature combination.

**EOM mode (`-UseEOM`):**

- Requires the Entra **View-Only Audit Logs** or **Audit Logs** role on the connecting principal. No additional Graph scopes.

### Operator Responsibilities

PAX cannot enforce these on your behalf — your security and compliance teams must:

- Approve and consent the requested Graph scopes through your standard admin-consent / change-control process.
- Provision a dedicated service account or app registration for automated runs, scoped to least privilege.
- Restrict who can execute PAX and where its output is written.
- Apply your tenant's retention, encryption, residency, and access-control policies to the output files.
- Review log files for anomalies and integrate them into your existing monitoring / SIEM where applicable.

### Recommended Operational Hardening

These are **suggestions**, not requirements, and are common to any read-only PowerShell tool that touches Microsoft Graph:

1. Use `RemoteSigned` execution policy and verify the script hash against the published release.
2. Pin to a published release tag rather than `main` for production runs.
3. Use certificate-based app authentication (`-Auth AppRegistration` with `-ClientCertificateThumbprint`) over client secrets where possible.
4. Store output on encrypted volumes or in access-controlled file shares; treat exported audit data as sensitive.
5. Enforce TLS 1.2+ at the OS / network layer (PAX relies on the platform's TLS stack).
6. Install required PowerShell modules (`Microsoft.Graph.*`, `ExchangeOnlineManagement`) only from the official PowerShell Gallery, and pin module versions in regulated environments.
7. Rotate any service-principal secrets / certificates per your tenant's secret-rotation policy.

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

**Purview Audit & Microsoft Graph:**

- [Microsoft Purview Audit (Premium)](https://learn.microsoft.com/en-us/purview/audit-premium) — Overview of audit capabilities
- [Audit log activities](https://learn.microsoft.com/en-us/purview/audit-log-activities) — Complete list of auditable activities
- [Search the audit log](https://learn.microsoft.com/en-us/purview/audit-log-search) — Audit log search basics
- [Microsoft Graph Security API](https://learn.microsoft.com/en-us/graph/api/resources/security-api-overview) — Graph API security capabilities
- [AuditLog resource type](https://learn.microsoft.com/en-us/graph/api/resources/auditlog) — Graph API audit log documentation
- [Exchange Online PowerShell](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell) — Exchange Online module documentation (EOM mode)

### Companion Analytics Hub

The Microsoft Copilot Analytics Hub is the central landing page for PAX-compatible Power BI templates, dashboards, and companion analytics tooling — including the AI-in-One Dashboard, Copilot Chat & Agent Intelligence Dashboards, and the broader ROI / adoption / governance visualization library.

- **[Microsoft Copilot Analytics Hub](https://github.com/microsoft/Copilot-Analytics-Hub)** — Single entry point for downstream visualization and analysis assets that consume PAX output

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Support

For questions or issues, refer to the documentation:

- **Documentation v1.11.x (Markdown):** [PAX_Purview_Audit_Log_Processor_Documentation.md](https://github.com/microsoft/PAX/blob/main/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.11.x.md)

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com) with any feedback.*

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

© Microsoft Corporation — MIT Licensed


