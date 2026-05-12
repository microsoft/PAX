# Portable Audit eXporter (PAX) - <br/>Purview Audit Log Processor

> **📥 Quick Start:** Download the script → [`PAX_Purview_Audit_Log_Processor_v1.11.1.ps1`](https://github.com/microsoft/PAX/releases/download/purview-v1.11.1/PAX_Purview_Audit_Log_Processor_v1.11.1.ps1)
>
> **📋 Release Notes:** See what's new → [v1.11.x Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.11.x.md) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Purview_Audit_Log_Processor)
>
> **📜 Script Archive:** [All Script Versions](https://github.com/microsoft/PAX/releases?q=purview-&expanded=true)
>
> **📚 Documentation Archive:** [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Purview_Audit_Log_Processor)

**Documentation Version:** 1.11.x  
**Audience:** IT admins, security/compliance analysts, BI/data teams  
**Runtime:** PowerShell 7+ (required for default Graph API mode); PowerShell 5.1 supported only with `-UseEOM`  
**License:** MIT

---

> **📝 A note on navigating this document**
>
> This documentation is intentionally comprehensive — it covers every parameter, authentication method, output destination, troubleshooting scenario, and known limitation in detail so you can rely on it as a single reference.
>
> If you are looking for a specific answer rather than reading end-to-end, try opening this page in a Copilot-enabled view (for example, the Microsoft 365 Copilot chat side panel, GitHub Copilot Chat in VS Code, or Edge's Copilot pane) and asking it to summarize a section, locate a parameter, or walk you through a particular scenario. Sample prompts: *"Summarize how to send PAX output to SharePoint,"* *"What permissions do I need for `-OutputPathFabric`?"*, or *"Show me only the troubleshooting steps for managed-identity sign-in."* Copilot can comfortably handle this file and will get you to the right place faster than scrolling.

---

<table>
<tr>
<td bgcolor="#FFF8C5">
<font color="#000000">

<h3>⚠️ Sensitive Data Warning — Customer Responsibility</h3>

**The audit data exported by this script is highly sensitive.** Output may contain user identifiers (UPN, email, GUID), file/site/resource paths, conversation and message IDs, agent identifiers, prompt/response metadata (timestamps, lengths, classifications), and other personally identifiable information drawn directly from your tenant's Unified Audit Log.

- **Data is NOT hashed, masked, redacted, anonymized, or de-identified** in any way. Records are exported in their raw, attributable form exactly as Microsoft Purview returns them.
- Outputs (CSV/Excel/JSON metrics, checkpoint files, logs) may contain confidential business content, regulated data (PII, PHI, financial, IP), and end-user communications.
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
15. [Microsoft Agent 365 (Frontier)](#microsoft-agent-365-frontier)
16. [Microsoft 365 Usage Bundle](#microsoft-365-usage-bundle)
17. [Rollup Post-Processor (Power BI)](#rollup-post-processor-power-bi)
18. [DSPM for AI](#dspm-for-ai)
19. [Excel Export](#excel-export)
20. [Incremental Data Collection](#incremental-data-collection)
21. [Checkpoint & Resume](#checkpoint--resume)
22. [Output Files & Schema](#output-files--schema)
23. [Activity Types Reference](#activity-types-reference)
24. [Record & Service Filters](#record--service-filters)
25. [Advanced Features](#advanced-features)
26. [Performance Tuning](#performance-tuning)
27. [Troubleshooting](#troubleshooting)
28. [Known Limitations](#known-limitations)
29. [Security & Compliance](#security--compliance)

---

## Overview

<details open>
<summary>What It Does</summary>

The **Portable Audit eXporter (PAX)** is an enterprise-grade PowerShell script that exports Microsoft Purview Unified Audit Log events, with specialized support for Microsoft 365 Copilot activities and related operations. It extends Graph-based retrieval so you can capture classic Microsoft 365 app usage (Word, Excel, PowerPoint, OneNote, Loop, SharePoint, OneDrive, Teams files) in the same run—without falling back to ExchangeOnlineManagement—alongside Copilot telemetry. It transforms raw audit data into analysis-ready **CSV or Excel** output and writes it to the destination of your choice — a **local folder**, a **SharePoint document library**, or directly into **Microsoft Fabric (OneLake)** for downstream notebooks, pipelines, and Power BI semantic models — with enriched metadata, intelligent query optimization, and flexible schema options.

**Core Capabilities:**

- Retrieves audit events from Microsoft 365 Unified Audit Log via **Graph API (default)** or **EOM mode** (`-UseEOM`)
- **Graph API filter passthrough:** Optional `-RecordTypes` / `-ServiceTypes` switches target documented Purview workloads (SharePoint, OneDrive, and future additions) so non-Copilot office app activity returns alongside Copilot operations
- **Microsoft 365 usage data (`-IncludeM365Usage`):** Curated cross-workload activity bundle spanning Outlook, Teams, SharePoint, OneDrive, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, and PowerApps — captured in the same Graph audit run alongside Copilot telemetry for ROI and behavior-change analysis
- **Microsoft Agent 365 catalog (`-IncludeAgent365Info` / `-OnlyAgent365Info`):** Point-in-time snapshot of the Microsoft Agent 365 catalog (28-column schema matching the Microsoft Admin Center "Agent 365" export) for Frontier-enrolled tenants
- Exports to structured CSV or Excel (.xlsx)
- Includes enriched usage & ROI fields (tokens, models, latency, acceptance metrics)
- Implements adaptive time slicing to navigate service limits intelligently
- Provides detailed logging of all operations, warnings, and performance metrics
- Automatically handles module installation and authentication (Microsoft.Graph.Authentication for Graph API mode; ExchangeOnlineManagement for EOM mode)
- **Flexible output destinations:** Write results to a local folder (`-OutputPath`), directly to a SharePoint document library folder (`-OutputPathSP`), or directly to a Microsoft Fabric lakehouse OneLake folder (`-OutputPathFabric`)
- **Microsoft Fabric (OneLake) as a first-class destination (`-OutputPathFabric`):** Writes PAX output files straight into the `Files/` area of a Fabric **Lakehouse** or **Warehouse**, eliminating the local-disk + manual-upload hop that downstream Fabric consumers would otherwise need
- **Fabric-ready for production at scale:** OneLake credentials are refreshed automatically in the background and large workbooks/CSVs use resumable uploads, so multi-hour exports land in Fabric without interruption
- **Fabric + managed identity for fully unattended runs:** Pair `-OutputPathFabric` with `-Auth ManagedIdentity` to run PAX as a scheduled/event-driven Azure Container Apps Job (or any Azure compute) that lands data directly in a Fabric workspace with no secrets to manage — see the repo-root **`fabric_resources`** folder for container images, Bicep/ARM templates, and the Azure-role + Fabric-workspace-role + Fabric-tenant-setting checklist
- **Unattended Azure-hosted runs:** Sign in with a managed identity (`-Auth ManagedIdentity`) for scheduled/event-driven jobs on Azure Container Apps Jobs, Azure VMs, or similar Azure compute — no secrets to manage
- **Graph API mode (default):** Supports Entra ID user enrichment + Microsoft 365 Copilot license detection via `-IncludeUserInfo` and `-OnlyUserInfo`
- **EOM mode (`-UseEOM`):** Supports server-side group expansion via `-GroupNames` and 10K limit detection

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
- **Microsoft 365 Usage Bundle:** Single-switch activation (`-IncludeM365Usage`) captures activity types across Outlook, Teams, SharePoint, OneDrive, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, and PowerApps alongside Copilot data — for Copilot ROI baselining and cross-workload behavior analysis
- **Agent Filtering:** Filter records by specific AgentId values or any agent-related activity
- **Record & Service Filters (Graph):** Use `-RecordTypes` / `-ServiceTypes` to retrieve Microsoft 365 app usage workloads (SharePoint, OneDrive, Loop, Files in Teams) without leaving Graph mode
- **User Filtering:** Filter by user emails via `-UserIds` parameter (server-side with `-UseEOM`, client-side in Graph API mode)
- **Group Filtering (EOM Mode Only):** Server-side group expansion to members via `-GroupNames` parameter (requires `-UseEOM`)
- **Entra ID Enrichment + M365 Copilot Licensing (Graph API Mode Only):** Enrich audit data with Entra user attributes and M365 Copilot (MAC) license information via `-IncludeUserInfo` (default mode, not compatible with `-UseEOM`)
- **User-Only Export (Graph API Mode Only):** Export only Entra ID user data and M365 Copilot licensing without audit records via `-OnlyUserInfo` (requires `-IncludeUserInfo`, not compatible with `-UseEOM`)
- **Microsoft Agent 365 Catalog Enrichment (Frontier-enrolled tenants):** Pull a **point-in-time snapshot** of the Microsoft Agent 365 catalog (28-column schema matching the Microsoft Admin Center "Agent 365" export) via `-IncludeAgent365Info` alongside an audit run, or via `-OnlyAgent365Info` as a standalone catalog snapshot. The catalog reflects the **current state of the tenant at the moment of the call** — it is not historical/time-ranged data and `-StartDate`/`-EndDate` do not apply to the agent phase. Requires Frontier program enrollment and an interactive sign-in for the agent phase (see [Microsoft Agent 365 (Frontier)](#microsoft-agent-365-frontier))
- **Flexible Export Formats:** CSV (default) or Excel (.xlsx) with professional formatting
- **Streaming Export:** Memory-efficient chunked data writing for large datasets
- **UTF-8 Encoding:** Consistent UTF-8 (no BOM) output for CSV files
- **Header Stability:** Always writes file headers even when zero records match (ensures schema consistency)
- **Multiple Output Destinations:** Pick the destination that matches the consumer of the run — all three use identical filenames and schemas:
  - **Local folder** via `-OutputPath` (default; best for ad-hoc analysis on the host machine)
  - **SharePoint document library** via `-OutputPathSP` (best for team visibility, sharing-link distribution, and Power BI direct-from-SharePoint consumption — see [Sending Output to SharePoint](#sending-output-to-sharepoint))
  - **Microsoft Fabric / OneLake** via `-OutputPathFabric` (best for downstream Fabric notebooks, pipelines, dataflows, and Power BI semantic models — see [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake))
- **Pre-Flight Destination Check:** When using `-OutputPathSP` or `-OutputPathFabric`, PAX verifies the destination exists and is writable **before pulling any audit data**, so permission gaps fail fast rather than after hours of querying
- **Resumable Uploads:** Large files (Excel workbooks, dense CSVs) use chunked, resumable upload to SharePoint, and OneLake credentials are refreshed automatically in the background — multi-hour exports finish without interruption

</details>

<details>
<summary>Microsoft Fabric Integration</summary>

- **Direct OneLake Output:** `-OutputPathFabric` writes PAX output files straight into the `Files/` area of a Fabric **Lakehouse** or **Warehouse**, ready for immediate use in Fabric notebooks, pipelines, dataflows, and Power BI
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
- **Fast Data Writer:** Direct `StreamWriter` usage for CSV; ImportExcel module for Excel exports
- **Schema Sampling:** Configurable initial sampling to optimize column discovery vs. memory usage
- **Memory Management:** Automatic memory monitoring (`-MaxMemoryMB`) that streams records directly to JSONL files when system memory reaches the threshold (75% of RAM by default)

</details>

<details>
<summary>Operational Excellence</summary>

- **Real-Time Progress Tracking:** Live status updates across Query and Export phases with percentage completion
- **CSV & Excel Export:** Native support for both CSV files and Excel workbooks with professional formatting
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
- Inventory Microsoft Agent 365 packages (publisher, developer, install counts, last-modified metadata) via `-IncludeAgent365Info` or `-OnlyAgent365Info` for Frontier-enrolled tenants

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
- **Land results in a Microsoft Fabric lakehouse on every run** with `-OutputPathFabric` so notebooks, pipelines, and Power BI semantic models can pick up the latest export with no manual upload step (supporting templates and walkthroughs live in the `fabric_resources` folder at the repo root)
- **Distribute results to a SharePoint team library** with `-OutputPathSP` for analysts who consume audit output directly from Power BI's SharePoint connector or Excel in the browser

</details>

<details>
<summary>Unattended Scheduled Operations</summary>

- Schedule PAX inside Azure (Azure Container Apps Jobs, Azure VMs, Azure Container Instances) using `-Auth ManagedIdentity` for fully unattended runs with no secrets on disk
- Land each run's output directly in SharePoint or Microsoft Fabric so downstream teams and BI assets pick up new data automatically
- Pair scheduled audit pulls with the `fabric_resources` supporting material (container images, Bicep templates, RBAC setup) for a production-grade pipeline
- Run daily / hourly exports without manual sign-in, token rotation, or file copying

</details>

<details>
<summary>Development & Testing</summary>

- Test schema changes against synthetic or sanitized datasets
- Validate data pipelines without querying production audit logs
- Develop downstream analytics without live tenant access

</details>

<details>
<summary>Agents</summary>

- Inventory all agent activity across your tenant using `-AgentsOnly` to filter audit records that involve any Copilot Studio declarative agent, custom agent, or Microsoft-built agent
- Analyze adoption and usage of specific agents using `-AgentId` for targeted investigations (single or multiple agent IDs)
- Compare agent vs. non-agent Copilot interactions using `-ExcludeAgents` to baseline standard Copilot usage against agent-driven activity
- Combine agent filters with `-UserIds`, `-GroupNames`, or `-PromptFilter` for focused analyses (e.g., specific user's interactions with a specific agent)
- Pair with `-IncludeAgent365Info` or `-OnlyAgent365Info` to correlate runtime agent activity with the Microsoft Agent 365 catalog (publisher, developer, install counts) for Frontier-enrolled tenants

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
| **SharePoint write access** *(only if using `-OutputPathSP`)* | Edit/Contribute on the destination library + folder, plus the Graph delegated or application permissions `Sites.ReadWrite.All` and `Files.ReadWrite.All` | See [Sending Output to SharePoint](#sending-output-to-sharepoint) for the full setup. |
| **Microsoft Fabric / OneLake access** *(only if using `-OutputPathFabric`)* | All three layers are required: **(1)** the Azure role `Storage Blob Data Contributor` on the OneLake storage scope, **(2)** the **Contributor** (or higher) role on the Fabric workspace in the Fabric portal, **(3)** the tenant setting allowing service principals / Entra IDs to access Fabric APIs must be enabled by your Fabric admin | See [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake) for the full setup, and the `fabric_resources` folder in the repo root for detailed container/runbook material. |
| **Az.Accounts PowerShell module** *(only if using `-OutputPathFabric`)* | Used to obtain the OneLake storage token | PAX installs it automatically if missing. |
| **Network Access**          | Microsoft 365 endpoints                 | Ensure firewall allows connections to Microsoft Graph and Exchange Online endpoints. If using `-OutputPathSP`, also allow `*.sharepoint.com`. If using `-OutputPathFabric`, also allow `onelake.dfs.fabric.microsoft.com`. |
| **Execution Policy**        | Bypass or RemoteSigned                  | See [Authentication Methods](#authentication-methods)        |

**Note:** Graph API mode (default) requires the `Microsoft.Graph.Authentication` PowerShell module, which is automatically detected and installed by the script if missing. EOM mode (`-UseEOM`) automatically handles `ExchangeOnlineManagement` module detection and installation if needed.

<details>
<summary>Permission Details</summary>

**Permissions by Execution Mode:**

Graph API mode requests scopes conditionally based on the switches you pass. The umbrella `AuditLogsQuery.Read.All` permission is the baseline; per-workload, user-directory, and group-expansion scopes are requested only when the corresponding feature is enabled. Grant any conditional scopes for features you intend to use.

| Permission | Purpose | When required (Graph API) | Graph API (Delegated) | Graph API (AppRegistration) | ExchangeOnlineManagement (EOM) |
|------------|---------|---------------------------|:---------------------:|:---------------------------:|:------------------------------:|
| **Graph: AuditLogsQuery.Read.All** | Umbrella permission for the Microsoft Graph audit query API — covers `CopilotInteraction` record type | Always (except `-OnlyUserInfo` / `-OnlyAgent365Info`) | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-Exchange.Read.All** | Exchange Online audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-OneDrive.Read.All** | OneDrive audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-SharePoint.Read.All** | SharePoint Online audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: User.Read.All** | Entra user directory, MAC licensing | `-IncludeUserInfo`, `-OnlyUserInfo`, or `-GroupNames` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Organization.Read.All** | Tenant/organization context, license metadata | `-IncludeUserInfo` or `-OnlyUserInfo` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: GroupMember.Read.All** | Group lookup and membership expansion (least privilege) | `-GroupNames` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Sites.ReadWrite.All** | Resolve the SharePoint site/library/folder and upload output files | `-OutputPathSP` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Files.ReadWrite.All** | Create, replace, and resume uploads of output files in the SharePoint folder | `-OutputPathSP` | ✅ Yes | ✅ Yes | — N/A |
| **Azure role: Storage Blob Data Contributor** | Write PAX output files into the OneLake `Files/` area of the destination lakehouse | `-OutputPathFabric` | ✅ Required on the signed-in user / managed identity | ✅ Required on the service principal | — N/A |
| **Fabric portal role: Contributor** (or higher) on the workspace | Allow the identity to see and write into the lakehouse via Fabric APIs | `-OutputPathFabric` | ✅ Required | ✅ Required | — N/A |
| **Fabric tenant setting: "Service principals can use Fabric APIs"** | Enables Entra service principals / managed identities to call Fabric/OneLake | `-OutputPathFabric` (only when using `-Auth AppRegistration` or `-Auth ManagedIdentity`) | — | ✅ Must be enabled by a Fabric admin | — N/A |
| **Graph: CopilotPackages.Read.All** | Microsoft Agent 365 catalog/package metadata (Frontier program) | `-IncludeAgent365Info` or `-OnlyAgent365Info` | ✅ Yes (delegated only) | ❌ **Not supported by the API** — see Agent 365 callout below | — N/A |
| **Graph: Application.Read.All** | Developer/publisher resolution for Agent 365 packages | `-IncludeAgent365Info` or `-OnlyAgent365Info` | ✅ Yes (delegated only) | ❌ **Not supported by the API** — see Agent 365 callout below | — N/A |
| **Entra role: AI Administrator OR Global Administrator** | Frontier program server-side gate (separate from Graph scopes) | `-IncludeAgent365Info` or `-OnlyAgent365Info` | ✅ Required on the signed-in caller | ✅ Required on the interactive caller used for the agent phase | — N/A |
| **Purview Audit Reader** | Purview UI/EOM | EOM only | ❌ No | ❌ No | ✅ Yes |

> **📚 Reference:** [Microsoft Graph Audit Log Query Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditcoreroot-post-auditlogqueries#permissions) | [Get auditLogQuery Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditlogquery-get#permissions) | [Microsoft Agent 365 Graph API](https://learn.microsoft.com/en-us/microsoft-agent-365/admin/graph-api)

**Audit Role Requirement and Enforcement Behavior:**

The **Purview Audit Reader** role is only required for EOM mode (`-UseEOM`) and the Purview UI — it is enforced by the Exchange audit backend. In Graph API mode (default), audit authorization is evaluated solely against the caller's Microsoft Graph permissions for both delegated and application authentication, and no user-level audit role is required.

> **⚠️ Troubleshooting (EOM mode): "User is not authorized" or 403 Errors**  
> If an EOM-mode run fails with `"User is not authorized for the RBAC roles"` or returns a `403 Forbidden` response, this typically indicates a stale role assignment. The Purview Audit Reader role may appear correctly assigned in the Purview portal, but the Exchange audit backend no longer recognizes it.  
> **Fix:** Remove and re-assign the **Purview Audit Reader** role to the user. This refreshes the Exchange audit authorization mapping. No new permissions are required.

**DSPM for AI Access:**
- Same permissions as standard audit access (see table above)
- No additional permissions required for DSPM activity types (`ConnectedAIAppInteraction`, `AIInteraction`, `AIAppInteraction`)

**Entra ID User Enrichment + M365 Copilot Licensing (Optional Feature - Graph API Mode Only):**
- Requires the **User.Read.All** and **Organization.Read.All** permissions (requested only when this feature is enabled)
- Enabled via `-IncludeUserInfo` or `-OnlyUserInfo` parameters
- Provides access to Entra user attributes AND M365 Copilot (MAC) license information
- Not applicable in EOM mode (`-UseEOM`)

**Microsoft Agent 365 Catalog Access (Optional Feature - Graph API Mode Only):**
- Requires Graph delegated scopes **CopilotPackages.Read.All** and **Application.Read.All** (requested only when this feature is enabled)
- Requires the signed-in caller to hold the Entra **AI Administrator** or **Global Administrator** role (server-side gate, separate from Graph scopes)
- Requires tenant enrollment in the Microsoft Agent 365 Frontier program
- Enabled via `-IncludeAgent365Info` or `-OnlyAgent365Info` parameters
- The Agent Package Management API does not accept app-only tokens — the agent phase always uses a delegated (interactive) token. See the Frontier callout below for the full authentication matrix.
- Not applicable in EOM mode (`-UseEOM`)

**Microsoft 365 Usage Bundle (Optional Feature - Graph API Mode Only):**
- Requires the **AuditLogsQuery-Exchange.Read.All**, **AuditLogsQuery-OneDrive.Read.All**, and **AuditLogsQuery-SharePoint.Read.All** permissions (requested only when this feature is enabled)
- Enabled via `-IncludeM365Usage` parameter
- Provides curated single-pass query bundle spanning Outlook, SharePoint, OneDrive, Teams, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, PowerApps, and Copilot
- Not applicable in EOM mode (`-UseEOM`)

**Sending output directly to SharePoint (Optional Feature - Graph API Mode Only):**
- Requires the Graph permissions **Sites.ReadWrite.All** and **Files.ReadWrite.All**, requested only when `-OutputPathSP` is used
- The signed-in account (or, for unattended runs, the service principal / managed identity) must additionally have **Edit** or **Contribute** permission on the destination SharePoint library and folder
- See [Sending Output to SharePoint](#sending-output-to-sharepoint) for the full walkthrough, including how to get a valid URL and what kinds of links cannot be used
- Not applicable in EOM mode (`-UseEOM`)

**Sending output directly to Microsoft Fabric / OneLake (Optional Feature - Graph API Mode Only):**
- All three layers below must be in place — granting only one of them is not enough:
  1. **Azure role:** `Storage Blob Data Contributor` for the identity running PAX, scoped to the OneLake storage of the destination workspace
  2. **Fabric portal role:** **Contributor** (or higher) on the destination workspace, assigned in the Fabric portal under *Workspace settings → Manage access*
  3. **Fabric tenant setting:** *"Service principals can use Fabric APIs"* must be enabled by a Fabric admin (required for `-Auth AppRegistration` and `-Auth ManagedIdentity`)
- Requires the `Az.Accounts` PowerShell module on the host running PAX (auto-installed if missing)
- See [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake) for the walkthrough, and the **`fabric_resources` folder in the repo root** for detailed setup, container, and deployment material if you plan to run PAX inside Azure
- Not applicable in EOM mode (`-UseEOM`)

**Managed-identity sign-in (Optional Feature - Graph API Mode Only):**
- When running PAX inside Azure (for example, an Azure Container Apps Job, Azure VM, or Azure Container Instance) you can sign in using a managed identity instead of a password or app secret
- The managed identity must hold all the same Graph and destination permissions described in the table above — managed-identity sign-in only controls *how* PAX authenticates, not *what* it is allowed to do
- If your host has more than one identity attached, set the `AZURE_CLIENT_ID` environment variable to the client ID of the one you want PAX to use
- Not supported with `-IncludeAgent365Info` / `-OnlyAgent365Info` (the Agent 365 catalog API does not accept non-interactive tokens)
- Not applicable in EOM mode (`-UseEOM`)

---

> ### Microsoft Agent 365 (Frontier) Access — Read Before Using `-IncludeAgent365Info` or `-OnlyAgent365Info`
>
> The Agent 365 catalog phase calls the Microsoft Graph **Agent Package Management API** (`/beta/copilot/admin/catalog/packages`). This endpoint behaves very differently from the rest of the Purview audit surface, and the differences are not optional — missing any one of them causes the agent phase to fail or be skipped.
>
> **All four conditions below must be satisfied:**
>
> 1. **Tenant must be enrolled in the Microsoft Agent 365 Frontier program.** If the tenant is not enrolled, PAX shows a banner and skips the agent phase. Audit and EntraUsers phases (when applicable) still complete normally. See the [Microsoft Agent 365 Frontier program](https://www.microsoft.com/en-us/microsoft-365-copilot/frontier-program) for enrollment information.
> 2. **The signed-in caller must hold the Entra `AI Administrator` or `Global Administrator` role.** This is enforced server-side by the Frontier program and is independent of the Graph scopes consented to PAX. Granting Graph scopes alone is **not** sufficient — without the role the endpoint returns 403.
> 3. **Graph delegated scopes `CopilotPackages.Read.All` and `Application.Read.All` must be consented for the signed-in caller.** PAX requests these scopes during the interactive sign-in for the agent phase.
> 4. **The Agent 365 phase requires a delegated (interactive) Graph token.** The Agent Package Management API **does not accept app-only tokens** — there is no `-Auth AppRegistration`-only path for the agent phase, regardless of how the app registration is configured.
>
> **Agent 365 Graph API Authentication behavior matrix:**
>
> | Scenario | Audit phase auth | Agent 365 phase auth | Result |
> |----------|------------------|----------------------|--------|
> | `-Auth WebLogin` / `DeviceCode` / `Credential` / `Silent` + `-IncludeAgent365Info` | Interactive (single sign-in) | Same interactive context | ✅ Single sign-in covers both phases |
> | `-Auth AppRegistration` + `-IncludeAgent365Info` | App-only (service principal) | **One-time interactive prompt launched at the start of the agent phase** to acquire `CopilotPackages.Read.All` and `Application.Read.All` for the signed-in admin | ✅ Dual context — audit runs unattended, agent phase requires a human at that point |
> | `-Auth WebLogin` / `DeviceCode` / `Credential` / `Silent` + `-OnlyAgent365Info` | (skipped) | Interactive | ✅ Supported |
> | **`-Auth AppRegistration` + `-OnlyAgent365Info`** | (skipped) | n/a | ❌ **Not supported.** PAX exits with a clear error. There is no audit phase to justify falling back to a secondary interactive sign-in. Use `-Auth WebLogin` or `-Auth DeviceCode` for `-OnlyAgent365Info`. |
>
> **Reference:** [Microsoft Agent 365 Graph API](https://learn.microsoft.com/en-us/microsoft-agent-365/admin/graph-api)

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

- **Script:** [PAX_Purview_Audit_Log_Processor_v1.11.1.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.11.1/PAX_Purview_Audit_Log_Processor_v1.11.1.ps1)
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
- [Microsoft Agent 365 Parameters](#microsoft-agent-365-parameters)
- [DSPM for AI Parameters](#dspm-for-ai-parameters)

*Data processing:*
- [Data Processing Parameters](#data-processing-parameters)
- [Offline Replay Parameters](#offline-replay-parameters)

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
| `-ActivityTypes` | `-BlockHours` | `-DSPMOutputMode` | `-Force` | `-LowLatencyMs` | `-PacingMs` | `-ServiceTypes` |
| `-AdaptiveConcurrencyCeiling` | `-ClientCertificatePassword` | `-EmitMetricsJson` | `-GroupNames` | `-MaxConcurrency` | `-ParallelMode` | `-StartDate` |
| `-AgentId` | `-ClientCertificatePath` | `-EndDate` | `-Help` | `-MaxMemoryMB` | `-PromptFilter` | `-StatusIntervalSeconds` |
| `-AgentsOnly` | `-ClientCertificateStoreLocation` | `-ExcludeAgents` | `-IncludeAgent365Info` | `-MaxParallelGroups` | `-RAWInputCSV` | `-StreamingChunkSize` |
| `-AppendFile` | `-ClientCertificateThumbprint` | `-ExcludeCopilotInteraction` | `-IncludeCopilotInteraction` | `-MetricsPath` | `-RecordTypes` | `-StreamingSchemaSample` |
| `-Auth` | `-ClientId` | `-ExplodeArrays` | `-IncludeDSPMForAI` | `-OnlyAgent365Info` | `-Resume` | `-TenantId` |
| `-AutoCompleteness` | `-ClientSecret` | `-ExplodeDeep` | `-IncludeM365Usage` | `-OnlyUserInfo` | `-ResultSize` | `-ThroughputDropPct` |
|   | `-CombineOutput` | `-ExplosionThreads` | `-IncludeTelemetry` | `-OutputPath` |   | `-UseEOM` |
|   |   | `-ExportProgressInterval` | `-IncludeUserInfo` | `-OutputPathSP` |   | `-UserIds` |
|   |   |   |   | `-OutputPathFabric` |   |   |

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

> 💡 If you want output to land directly in SharePoint or Microsoft Fabric instead of a local folder, see [`-OutputPathSP`](#-outputpathsp-string) and [`-OutputPathFabric`](#-outputpathfabric-string) below. **Pick exactly one destination per run** — PAX writes locally **or** to SharePoint **or** to Fabric, never two at once. If you pass more than one of `-OutputPath`, `-OutputPathSP`, or `-OutputPathFabric`, PAX exits immediately with an error before any audit data is pulled.

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

**Examples:**

- Filename only: `-AppendFile "Report.xlsx"` (uses `-OutputPath` directory)
- Full path: `-AppendFile "C:\Data\\"`

**Notes:**

- See [Incremental Data Collection](#incremental-data-collection) section for complete documentation
- Validates header compatibility before appending
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
- **CSV Mode:** Merges all activity types into single file: `Purview_Audit_CombinedUsageActivity_<timestamp>.csv` (with `Operations` column identifying type)
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

#### `-OutputPathSP` (string)

**Purpose:** Send all output (CSVs, Excel workbook, log file, metrics JSON) directly to a folder in a SharePoint document library instead of writing it to a local folder.

**Default:** Not set (local output via `-OutputPath` is used).

**URL shape:**

```
https://<tenant>.sharepoint.com/sites/<site>/<library>[/<folder>][/<subfolder>]
```

**Example:** `-OutputPathSP "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"`

**What it does:**

- PAX checks the folder exists and that the signed-in identity has write access **before any audit data is pulled**. If the check fails, PAX exits immediately with a clear error — no half-run files are left behind.
- Every output file that would normally appear in your local output folder (CSV, Excel, log, metrics JSON) is uploaded to the SharePoint folder under the same filename.
- A small local scratch folder is used to stage each file briefly before upload; the local copy is removed after the file lands in SharePoint.
- At the end of the run, PAX prints a consolidated list of every file that landed in SharePoint, with sizes.

**Use When:** You want results to be immediately visible to a team, governed by SharePoint sharing/retention, or consumed by Power BI without a gateway hop.

**Important:**

- **Mutually exclusive with `-OutputPath` and `-OutputPathFabric`.** Pick exactly one destination per run.
- See [Sending Output to SharePoint](#sending-output-to-sharepoint) for the full walkthrough, including **how to obtain a valid URL from a browser address bar** and **a list of URL formats that look right but will not work** (sharing links, `_layouts` pages, query strings, etc.).
- Required permissions: `Sites.ReadWrite.All` and `Files.ReadWrite.All` (Graph), plus Edit/Contribute on the destination folder.

---

#### `-OutputPathFabric` (string)

**Purpose:** Send all output (CSVs, Excel workbook, log file, metrics JSON) directly to a OneLake folder in a Microsoft Fabric lakehouse instead of writing it to a local folder.

**Default:** Not set (local output via `-OutputPath` is used).

**URL shape:**

```
https://onelake.dfs.fabric.microsoft.com/<workspace>/<lakehouse>.Lakehouse/Files[/<folder>]
```

**Example:** `-OutputPathFabric "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/audit"`

**What it does:**

- PAX checks the lakehouse Files area exists and that the signed-in identity has write access **before any audit data is pulled**. If the check fails, PAX exits immediately with a clear error.
- Every output file is uploaded to the OneLake folder using the same filenames it would use locally. Files appear in the Fabric lakehouse explorer under your `Files/...` path and become immediately available to Fabric notebooks, pipelines, and Power BI reports.
- For long runs, PAX keeps its OneLake sign-in current automatically so multi-hour exports finish without interruption.

**Use When:** You want PAX output to land directly in a Fabric workspace for downstream analytics, with no intermediate copy and no manual upload.

**Important:**

- **Mutually exclusive with `-OutputPath` and `-OutputPathSP`.** Pick exactly one destination per run.
- Requires the `Az.Accounts` PowerShell module (auto-installed if missing).
- See [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake) for the walkthrough, including **how to construct the URL from your workspace and lakehouse**, **what kinds of URLs to avoid** (Power BI report links, dataset links), and the three-layer permissions model.
- For containerized / scheduled runs in Azure, see the **`fabric_resources` folder in the repo root** for detailed setup material.

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
- `ManagedIdentity` is not compatible with `-IncludeAgent365Info` / `-OnlyAgent365Info` (the Microsoft Agent 365 catalog API does not accept non-interactive tokens)
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

**Purpose:** Filter audit records to include only those from members of specific distribution group(s)  
**Default:** Not set (no group filtering)  
**Mode Compatibility:**
- **⚠️ EOM Mode Only:** Requires `-UseEOM` parameter (NOT compatible with default Graph API mode)
- Expands groups to member emails, then filters server-side (efficient)

**Use When:**

- Analyzing department-wide or team-level Copilot adoption (EOM mode only)
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
- Querying DSPM activity types without M365 Copilot data
- Building exports focused purely on classic M365 workloads

**Examples:**

- `-IncludeM365Usage -ExcludeCopilotInteraction` — Full M365 usage bundle WITHOUT CopilotInteraction
- `-IncludeDSPMForAI -ExcludeCopilotInteraction` — DSPM activity types only

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

**Schema:** Comprehensive schema including UserPrincipalName, DisplayName, Email, Department, JobTitle, Manager, AssignedLicenses (semicolon-separated M365 licenses), HasLicense (boolean, **dynamically detected** — see License Detection Logic below), AccountEnabled, and more

**Notes:**

- One-time Graph API call per unique user in audit dataset
- Minimal performance impact (<5 seconds for typical datasets)
- User data cached for session duration
- **License data:** Retrieved via User.Read.All scope from Microsoft Graph - includes all assigned licenses
- **License detection (dynamic, future-proof):** PAX queries the tenant's `/subscribedSkus` endpoint and discovers every `servicePlanId` whose `servicePlanName` matches the wildcard `*COPILOT*`. A user's `HasLicense` flag is `True` when the user has any `assignedPlan` with `capabilityStatus == 'Enabled'` AND `servicePlanId` in the discovered set. No SKU allow-list is hard-coded in the script; new Copilot SKUs (M365, EDU, Sales, Service, Finance, GCC, Frontier, etc.) are picked up automatically.
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

### Microsoft Agent 365 Parameters

#### `-IncludeAgent365Info` (switch)

**Purpose:** Add a Microsoft Agent 365 catalog enrichment phase to a normal audit run for tenants enrolled in the **Microsoft Agent 365 Frontier program**.

> **Point-in-time:** The Agent 365 catalog is a **snapshot of the tenant at the moment of the call**. It is *not* historical / time-ranged data. `-StartDate` and `-EndDate` apply only to the audit phase and have no effect on the Agent 365 phase. Each run produces a fresh snapshot; to track changes over time, run on a schedule and retain the per-run CSVs.

**Behavior:**
- Audit phase runs as configured (date range, filters, M365 Usage bundle, DSPM for AI, etc.).
- After the audit phase completes, PAX calls the Microsoft Graph **Agent Package Management API** (`/beta/copilot/admin/catalog/packages`) and emits a point-in-time Frontier-program agent inventory.
- Output schema matches the Microsoft Admin Center "Agent 365" export (28 columns, including agent name, package id, publisher, developer, install counts, last-modified metadata).
- CSV mode: writes a separate file `Agent365_<timestamp>.csv`.
- Excel mode (`-ExportWorkbook`): writes an additional `Agents365` worksheet alongside the audit tabs.
- If the tenant is **not** enrolled in the Frontier program, PAX shows a banner and skips the agent phase. Audit and EntraUsers phases (when applicable) still complete normally.

**Requirements:**
- Tenant must be enrolled in the [Microsoft Agent 365 Frontier program](https://www.microsoft.com/en-us/microsoft-365-copilot/frontier-program).
- The signed-in caller for the agent phase must hold the Entra **AI Administrator** or **Global Administrator** role (server-side gate enforced by the Frontier program, separate from Graph scopes).
- Graph delegated scopes `CopilotPackages.Read.All` and `Application.Read.All` must be consented to PAX (requested at sign-in).
- The agent phase **requires a delegated (interactive) Graph token** — the Agent Package Management API does not accept app-only tokens.

**Authentication behavior:**
- With `-Auth WebLogin` / `DeviceCode` / `Credential` / `Silent`: the same interactive sign-in covers both the audit and agent phases — no extra prompt.
- With `-Auth AppRegistration`: PAX runs the audit phase non-interactively using the service principal, then **launches a one-time interactive sign-in at the start of the agent phase** to acquire `CopilotPackages.Read.All` and `Application.Read.All` for an admin holding the AI Administrator or Global Administrator role.

**Incompatible Parameters:**
- `-RAWInputCSV` (offline replay has no live Graph context for the agent phase)
- `-UseEOM` (the Agent 365 endpoint is Graph-only)
- `-Resume` (the agent phase is a single-shot snapshot and does not participate in checkpoint/resume)
- `-OnlyUserInfo` and `-OnlyAgent365Info` (mutually exclusive standalone-export modes)

**Reference:** [Microsoft Agent 365 Graph API](https://learn.microsoft.com/en-us/microsoft-agent-365/admin/graph-api)

**Examples:**

```powershell
# Audit run with Agent 365 catalog appended (CSV)
./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -IncludeAgent365Info

# Audit run plus Agent 365 catalog as an Excel worksheet
./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -IncludeAgent365Info -ExportWorkbook

# Dual-context: AppRegistration for audit, interactive sign-in for the agent phase
./PAX_Purview_Audit_Log_Processor.ps1 `
    -Auth AppRegistration `
    -TenantId "<tenant-guid>" `
    -ClientId "<app-id>" `
    -ClientSecret $clientSecret `
    -StartDate 2025-10-01 -EndDate 2025-10-02 `
    -IncludeAgent365Info
```

---

#### `-OnlyAgent365Info` (switch)

**Purpose:** Run **only** the Microsoft Agent 365 catalog snapshot — skip the audit phase and any EntraUsers enrichment.

> **Point-in-time:** The Agent 365 catalog reflects the **current state of the tenant at the moment of the call**, not a date-ranged history. `-StartDate` / `-EndDate` are not applicable and are blocked. Each invocation produces a fresh snapshot; schedule recurring runs if you need a longitudinal view.

**Behavior:**
- No audit query is issued. PAX connects to Microsoft Graph and pulls the Agent 365 catalog via `/beta/copilot/admin/catalog/packages`.
- Output: `Agent365_<timestamp>.csv` (or an `Agents365` tab in `-ExportWorkbook` mode).
- A preflight check verifies tenant Frontier enrollment, role membership, and consented scopes before issuing the catalog call. Use `-Force` to bypass non-blocking preflight warnings.
- If the tenant is not enrolled in the Frontier program, PAX shows a banner and exits.

**Requirements:** Same as `-IncludeAgent365Info` (Frontier enrollment, AI Administrator / Global Administrator role, `CopilotPackages.Read.All`, `Application.Read.All`).

**Authentication behavior:**
- Supported: `-Auth WebLogin`, `-Auth DeviceCode`, `-Auth Credential`, `-Auth Silent`.
- **Not supported: `-Auth AppRegistration`.** Because `-OnlyAgent365Info` skips the audit phase entirely, there is no work for a service principal to perform; PAX exits with a clear error directing you to use `-Auth WebLogin` or `-Auth DeviceCode`.

**Incompatible Parameters (automatically blocked):**
- All audit-related parameters: `StartDate`, `EndDate`, `ActivityTypes`, `IncludeDSPMForAI`, `ExcludeCopilotInteraction`, `UserIds`, `GroupNames`, `AgentId`, `AgentsOnly`, `ExcludeAgents`, `PromptFilter`, `ExplodeArrays`, `ExplodeDeep`, `RAWInputCSV`, `BlockHours`, `PartitionHours`, `MaxPartitions`, `ResultSize`, `PacingMs`, `AutoCompleteness`, `ParallelMode`, `MaxParallelGroups`, `MaxConcurrency`, `EnableParallel`, `UseEOM`, `IncludeM365Usage`, `IncludeUserInfo`, `OnlyUserInfo`, `IncludeAgent365Info`, `Resume`, `AppendFile`.
- `-Auth AppRegistration` (see above).

**Use Cases:**
1. **Agent inventory audits:** Periodic snapshots of installed Agent 365 packages for governance/compliance reporting.
2. **Frontier program enablement validation:** Confirm tenant enrollment and admin role assignments produce a successful catalog pull before integrating into broader audit workflows.
3. **Power BI / BI feeds:** Standalone agent catalog data for dashboards without re-running heavy audit queries.

**Examples:**

```powershell
# Standalone Agent 365 catalog snapshot (CSV)
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info

# Excel workbook with the Agents365 worksheet
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info -ExportWorkbook

# Bypass non-blocking preflight warnings
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info -Force

# Device code auth for headless / no-browser workstations
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info -Auth DeviceCode
```

---

### Data Processing Parameters

#### `-ExplodeArrays` (switch)

**Purpose:** Enable Purview canonical 153-column exploded schema (array elements → rows)  
**Default:** Off (standard 1:1 row mode)  
**Use When:**

- Need one row per array element for pivoting
- Matching Microsoft Purview export format
- Preparing for relational BI tools

**Example:** `-ExplodeArrays`  
**Notes:** Forced ON automatically in replay mode

---

#### `-ExplodeDeep` (switch)

**Purpose:** Enable deep flattening (153-column base + all `CopilotEventData.*` columns)  
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

### Parallel Execution Parameters

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
**Range:** `1` to `5`  
**Default:** `3`  
**Use When:** Limiting total concurrent operations  
**Example:** `-MaxParallelGroups 2`

---

#### `-ExplosionThreads` (int)

**Purpose:** Control parallel thread count for array/conversation explosion processing  
**Range:** `0` to `8`  
**Default:** `0` (auto-detect based on CPU cores)  
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
- Checkpoint files store `explosionThreads` for resume consistency
- Serial processing when `-ExplosionThreads 1` specified

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
- Not compatible with `-ExplodeArrays` or `-ExplodeDeep` (explosion modes always use in-memory processing; the threshold is ignored with a logged warning)
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
| `-MaxMemoryMB` | Override memory threshold (e.g., resuming on different hardware) |

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
| Other | ResultSize, MaxConcurrency, AutoCompleteness, IncludeTelemetry, StatusIntervalSeconds |

**Notes:**

- Auth parameters can be overridden at resume time for flexibility
- ClientSecret is never stored in checkpoint (security)
- Incompatible with `-RAWInputCSV` (replay mode doesn't use checkpoints)

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
| **Authentication Methods** | WebLogin, DeviceCode, Credential, Silent, AppRegistration*, ManagedIdentity* | WebLogin, DeviceCode, Credential, Silent |
| **Default** | ✅ Yes | Use `-UseEOM` to enable |

**Recommendation:** Use Graph API mode (default) unless you require `-GroupNames` filtering or have legacy constraints.

> **Important:** Graph API mode requires multiple permissions for the Microsoft Purview Audit Search API. See [Permission Details](#permission-details) in the Prerequisites section for the complete list. The **Purview Audit Reader** role is only required for EOM mode (`-UseEOM`) and the Purview UI — it is not required for Graph API mode regardless of authentication method.

**Required Permissions by Execution Mode:**

Graph API mode requests scopes conditionally based on the switches you pass. The umbrella `AuditLogsQuery.Read.All` permission is the baseline; per-workload, user-directory, and group-expansion scopes are requested only when the corresponding feature is enabled. Grant any conditional scopes for features you intend to use.

| Permission | Purpose | When required (Graph API) | Graph API (Delegated) | Graph API (AppRegistration) | ExchangeOnlineManagement (EOM) |
|------------|---------|---------------------------|:---------------------:|:---------------------------:|:------------------------------:|
| **Graph: AuditLogsQuery.Read.All** | Umbrella permission for the Microsoft Graph audit query API — covers `CopilotInteraction` record type | Always (except `-OnlyUserInfo` / `-OnlyAgent365Info`) | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-Exchange.Read.All** | Exchange Online audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-OneDrive.Read.All** | OneDrive audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: AuditLogsQuery-SharePoint.Read.All** | SharePoint Online audit logs | `-IncludeM365Usage` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: User.Read.All** | Entra user directory, MAC licensing | `-IncludeUserInfo`, `-OnlyUserInfo`, or `-GroupNames` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Organization.Read.All** | Tenant/organization context, license metadata | `-IncludeUserInfo` or `-OnlyUserInfo` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: GroupMember.Read.All** | Group lookup and membership expansion (least privilege) | `-GroupNames` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Sites.ReadWrite.All** | Resolve and upload to SharePoint destination folder | `-OutputPathSP` | ✅ Yes | ✅ Yes | — N/A |
| **Graph: Files.ReadWrite.All** | Create / replace / resume uploads to the SharePoint folder | `-OutputPathSP` | ✅ Yes | ✅ Yes | — N/A |
| **Azure role: Storage Blob Data Contributor** | Write into the OneLake `Files/` area of the destination lakehouse | `-OutputPathFabric` | ✅ Required on user / managed identity | ✅ Required on service principal | — N/A |
| **Fabric portal role: Contributor (or higher)** | Workspace access in the Fabric portal | `-OutputPathFabric` | ✅ Required | ✅ Required | — N/A |
| **Fabric tenant setting: "Service principals can use Fabric APIs"** | Allows non-interactive identities to call Fabric/OneLake | `-OutputPathFabric` (when using `-Auth AppRegistration` or `-Auth ManagedIdentity`) | — | ✅ Must be enabled by a Fabric admin | — N/A |
| **Graph: CopilotPackages.Read.All** | Microsoft Agent 365 catalog/package metadata (Frontier program) | `-IncludeAgent365Info` or `-OnlyAgent365Info` | ✅ Yes (delegated only) | ❌ Not supported by the API | — N/A |
| **Graph: Application.Read.All** | Developer/publisher resolution for Agent 365 packages | `-IncludeAgent365Info` or `-OnlyAgent365Info` | ✅ Yes (delegated only) | ❌ Not supported by the API | — N/A |
| **Entra role: AI Administrator OR Global Administrator** | Frontier program server-side gate (separate from Graph scopes) | `-IncludeAgent365Info` or `-OnlyAgent365Info` | ✅ Required on the signed-in caller | ✅ Required on the interactive caller used for the agent phase | — N/A |
| **Purview Audit Reader** | Purview UI/EOM | EOM only | ❌ No | ❌ No | ✅ Yes |

> **📚 Reference:** [Microsoft Graph Audit Log Query Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditcoreroot-post-auditlogqueries#permissions) | [Get auditLogQuery Permissions](https://learn.microsoft.com/en-us/graph/api/security-auditlogquery-get#permissions) | [Microsoft Agent 365 Graph API](https://learn.microsoft.com/en-us/microsoft-agent-365/admin/graph-api)

> **⚠️ Microsoft Agent 365 (Frontier) requires interactive sign-in even under `-Auth AppRegistration`.** The Agent Package Management API (`/beta/copilot/admin/catalog/packages`) does not accept app-only tokens. When `-Auth AppRegistration` is combined with `-IncludeAgent365Info`, PAX completes the audit phase non-interactively, then launches a one-time interactive sign-in for the agent phase to acquire `CopilotPackages.Read.All` and `Application.Read.All` for an admin holding the **AI Administrator** or **Global Administrator** role. `-OnlyAgent365Info` is **not supported** with `-Auth AppRegistration` — use `-Auth WebLogin` or `-Auth DeviceCode` instead. See the [Microsoft Agent 365 (Frontier) Access](#prerequisites) callout in Prerequisites for the full behavior matrix.

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
- **ManagedIdentity:** Azure issues short-lived tokens; PAX renews them automatically in the background, including for the separate OneLake sign-in used by `-OutputPathFabric`. No user interaction is ever required.
- **Interactive (WebLogin/DeviceCode):** On 401 error, first attempts silent refresh using SDK's cached refresh token. Only prompts user if silent refresh fails.
- **403 Forbidden errors:** Indicate a permissions issue, NOT token expiry. Token refresh will not help—check `AuditLogsQuery.Read.All` consent and role assignments.
- **Long uploads to SharePoint and Fabric:** When using `-OutputPathSP` or `-OutputPathFabric`, PAX maintains a separate sign-in to the storage endpoint (Graph for SharePoint, OneLake for Fabric) and refreshes it independently of the audit-query token. Multi-hour exports upload without interruption regardless of which interactive or non-interactive auth method was used.

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
- **Microsoft Agent 365 (Frontier) caveat:** When combined with `-IncludeAgent365Info`, PAX runs the audit phase using the service principal, then launches a **one-time interactive sign-in** at the start of the agent phase (the Agent Package Management API does not accept app-only tokens). The interactive caller must hold the **AI Administrator** or **Global Administrator** role and must consent to `CopilotPackages.Read.All` and `Application.Read.All`. `-Auth AppRegistration` is **not supported** with `-OnlyAgent365Info`.

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

- **Best for:** Scheduled or event-driven PAX runs hosted in Azure Container Apps Jobs, Azure VMs, Azure Container Instances, or other Azure compute that supports managed identities. Particularly recommended when output is being written to SharePoint (`-OutputPathSP`) or Microsoft Fabric (`-OutputPathFabric`) from the same Azure environment.
- **Prerequisites:**
  - A system-assigned or user-assigned managed identity on the Azure resource hosting PAX.
  - The identity granted the same Microsoft Graph application permissions an `AppRegistration` would need (at minimum `AuditLogsQuery.Read.All`, plus any conditional scopes for the switches you use — see the Permissions tables above).
  - For `-OutputPathFabric`: the identity also needs `Storage Blob Data Contributor` (Azure role on the OneLake storage), the **Contributor** role on the Fabric workspace, and the Fabric tenant setting *Service principals can use Fabric APIs* enabled.
  - For `-OutputPathSP`: the identity also needs `Sites.ReadWrite.All` and `Files.ReadWrite.All`, plus Edit/Contribute on the destination folder.
  - If multiple identities are attached to the host (for example, both a system-assigned and one or more user-assigned identities), set the `AZURE_CLIENT_ID` environment variable to the client ID of the one PAX should use.
- **Works in:** Graph API mode only; automatically blocked when `-UseEOM` is supplied.
- **Automation suitability:** Strongly preferred over `AppRegistration` for any workload that already runs inside Azure — no secret rotation, no certificate management.
- **Microsoft Agent 365 (Frontier) caveat:** Not supported with `-IncludeAgent365Info` or `-OnlyAgent365Info`. The Microsoft Agent 365 catalog API does not accept managed-identity tokens. Use `WebLogin` or the AppRegistration + interactive hybrid pattern for Agent 365 exports.

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
	-OutputPathFabric "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/audit"
```

</details>

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---purview-audit-log-processor)

---

## Sending Output to SharePoint

<details>
<summary>📤 View SharePoint Output Guide (click to expand)</summary>

PAX can write every output file (CSV, Excel, log, metrics JSON) **directly into a SharePoint document library folder** instead of a local drive. This is useful when:

- Several people on your team need to see results as soon as a run finishes.
- The destination is governed by your tenant's normal SharePoint sharing, retention, and DLP policies.
- Downstream tools (Power BI, Excel, Power Automate) already read from SharePoint and a local-disk hop is unnecessary.

Pass the destination as the `-OutputPathSP` parameter:

```powershell
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathSP "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"
```

> ⚠️ `-OutputPathSP`, `-OutputPathFabric`, and `-OutputPath` are **mutually exclusive**. Pick exactly one destination per run. If you pass more than one, PAX exits immediately with an error before any audit data is pulled.

### How PAX uses your SharePoint folder

1. **Pre-flight check (before any audit data is pulled).** PAX verifies the site, library, and folder exist, that the signed-in identity has write access, and that none of the requested filenames already exist as locked items. If anything fails, the run stops with a clear error — no half-uploaded files are left behind.
2. **Staging.** Each output file is briefly written to a local scratch folder, then uploaded to SharePoint with the same filename. Small files use a single upload; large files (Excel workbooks, big CSVs) use a chunked, resumable upload that keeps working through transient network blips.
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
4. Paste it as the value of `-OutputPathSP`, in quotes. Keep spaces in folder names as-is (`"Shared Documents"`) — PowerShell quoting handles them. Do not manually replace spaces with `%20`.

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
	-OutputPathSP "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"

# 2. Subfolder in a non-default library
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathSP "https://contoso.sharepoint.com/sites/AuditTeam/Audit Files/2025/October"

# 3. Government cloud tenant
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathSP "https://contoso.sharepoint.us/sites/AuditTeam/Shared Documents/PAX-Output"

# 4. Unattended run from an Azure Container Apps Job using a managed identity
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth ManagedIdentity `
	-TenantId "<tenant-guid>" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathSP "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"

# 5. Service principal with a client secret (CI/CD pipeline)
$clientSecret = ConvertTo-SecureString $env:PAX_CLIENT_SECRET -AsPlainText -Force
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth AppRegistration `
	-TenantId "<tenant-guid>" `
	-ClientId "<app-id>" `
	-ClientSecret $clientSecret `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathSP "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"
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

Pass the destination as the `-OutputPathFabric` parameter:

```powershell
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathFabric "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/audit"
```

> ⚠️ `-OutputPathFabric`, `-OutputPathSP`, and `-OutputPath` are **mutually exclusive**. Pick exactly one destination per run. If you pass more than one, PAX exits immediately with an error before any audit data is pulled.

> 📁 For container images, deployment templates, identity setup walkthroughs, and other supporting material for running PAX inside Azure with `-OutputPathFabric`, see the **`fabric_resources` folder in the repository root**. The instructions in this section cover the script-side experience; the `fabric_resources` folder covers the Azure-side hosting and setup.

### How PAX uses your Fabric lakehouse

1. **Pre-flight check (before any audit data is pulled).** PAX verifies the OneLake URL is valid, the lakehouse exists, and the signed-in identity has write access to the `Files/` area. If anything fails, the run stops with a clear error.
2. **Streaming upload.** Each output file is uploaded into the OneLake `Files/...` path with the same filename it would use locally.
3. **Long-run handling.** OneLake sign-in is maintained automatically in the background, so multi-hour exports finish without interruption regardless of which authentication method you used for the audit side.
4. **Visibility.** Files appear in the Fabric lakehouse explorer under the path you specified and become immediately available to Fabric notebooks, pipelines, dataflows, and Power BI.

### How to get the right URL (and what NOT to paste)

PAX needs the **OneLake DFS URL** of a folder inside the `Files/` area of a Fabric lakehouse or warehouse. The URL shape is:

```
https://onelake.dfs.fabric.microsoft.com/<workspace>/<item>.Lakehouse/Files[/<folder>]
https://onelake.dfs.fabric.microsoft.com/<workspace>/<item>.Warehouse/Files[/<folder>]
```

A real example:

```
https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/audit
```

**How to build it:**

1. In the Fabric portal, open the destination workspace.
2. Note the **workspace name** (the URL segment after `/groups/<id>/` in the browser, *or* the display name shown in the workspace settings). The workspace name in the URL is case-sensitive.
3. Open the destination **lakehouse** (or warehouse). Note its name — that is the `<item>` value. The suffix must be `.Lakehouse` or `.Warehouse` exactly.
4. Identify the subfolder inside `Files/` where PAX output should land. Create it in the lakehouse explorer first if it does not exist.
5. Assemble the URL in the shape shown above. PAX accepts both lakehouse and warehouse items.

**URLs that will NOT work — do not paste any of these:**

| Bad URL shape | Why it fails |
|---|---|
| Anything from a **Power BI report**, **dataset**, or **semantic model** link | Those are different surfaces; PAX writes to OneLake `Files/`, not to a model or report. |
| The lakehouse **portal URL** from your browser (e.g. `https://app.fabric.microsoft.com/groups/<guid>/lakehouses/<guid>`) | That is a UI page. PAX needs the OneLake DFS URL, which begins with `https://onelake.dfs.fabric.microsoft.com/`. |
| A URL pointing at the `Tables/` area instead of `Files/` | PAX writes flat output files (CSV, Excel, log). `Tables/` is for delta tables managed by Fabric. |
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

`-OutputPathFabric` needs the `Az.Accounts` PowerShell module. PAX installs it automatically the first time you use the parameter; on locked-down hosts where module install is blocked, install it once ahead of time:

```powershell
Install-Module Az.Accounts -Scope CurrentUser
```

### More examples

<details>
<summary>💻 Show Fabric output examples</summary>

```powershell
# 1. Interactive run, output goes into a Fabric lakehouse Files folder
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathFabric "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/audit"

# 2. Subfolder organized by month
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-31 `
	-OutputPathFabric "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/audit/2025-10"

# 3. Warehouse item instead of a lakehouse
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathFabric "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Warehouse/Files/audit"

# 4. Containerized run on Azure Container Apps Jobs using a managed identity
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth ManagedIdentity `
	-TenantId "<tenant-guid>" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathFabric "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/audit"
```

</details>

### If something goes wrong

| What you see | Most likely cause | What to do |
|---|---|---|
| `OneLake URL is not in the expected shape` at the very start | Missing `.Lakehouse` / `.Warehouse` suffix, wrong host, or `Tables/` instead of `Files/` | Rebuild the URL using the shape in *How to get the right URL* above. |
| `Access denied to OneLake Files/...` during pre-flight | Identity is missing one of: Azure role, Fabric workspace role, or tenant setting | Verify all three layers in the permissions table above. If two are in place, suspect the tenant setting — only a Fabric admin can change it. |
| `Module 'Az.Accounts' could not be installed` | Locked-down host that blocks PowerShell Gallery | Pre-install with `Install-Module Az.Accounts -Scope CurrentUser` (or AllUsers) from an environment that can reach PowerShell Gallery. |
| Multi-hour export fails partway through with an auth error to OneLake | Rare; usually a tenant-side credential rotation | Re-run with the same parameters. PAX uses checkpoint/resume on the audit side; you will not start over from zero. |
| Files do not appear in the Fabric lakehouse explorer | You may be looking at the wrong workspace/lakehouse, or at `Tables/` rather than `Files/` | Open the exact `Files/<folder>` path that matches the URL you passed. PAX prints the full list of uploaded files at the end of the run. |

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

### Microsoft Agent 365 (Frontier) Examples

<details>
<summary>💻 Show Microsoft Agent 365 Examples</summary>

> **Note:** Requires tenant enrollment in the [Microsoft Agent 365 Frontier program](https://www.microsoft.com/en-us/microsoft-365-copilot/frontier-program) and an Entra **AI Administrator** or **Global Administrator** role on the interactive caller. See the Prerequisites section for the full requirements matrix.
>
> **Point-in-time data:** The Agent 365 catalog is a snapshot of the tenant at the moment of the call. `-StartDate` / `-EndDate` apply only to the audit phase, never to the Agent 365 phase. To track agent inventory changes over time, run on a schedule and retain the per-run CSVs.

```powershell
# Audit run with the Agent 365 catalog appended (CSV)
./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -IncludeAgent365Info

# Audit run plus Agent 365 catalog as an additional Excel worksheet
./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -IncludeAgent365Info -ExportWorkbook

# Standalone Agent 365 catalog snapshot (no audit phase)
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info

# Standalone Agent 365 snapshot bypassing non-blocking preflight warnings
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info -Force

# Standalone Agent 365 snapshot using device code (headless workstations)
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info -Auth DeviceCode

# Dual-context: AppRegistration drives the audit phase non-interactively,
# then a one-time interactive sign-in covers the agent phase
./PAX_Purview_Audit_Log_Processor.ps1 `
    -Auth AppRegistration `
    -TenantId "<tenant-guid>" `
    -ClientId "<app-id>" `
    -ClientSecret $clientSecret `
    -StartDate 2025-10-01 -EndDate 2025-10-02 `
    -IncludeAgent365Info

# NOT supported — PAX exits with a clear error
# ./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info -Auth AppRegistration ...
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

# Parallel explosion for large datasets
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeDeep -ExplosionThreads 8 -StartDate 2025-10-01 -EndDate 2025-10-31

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

# Replay with parallel explosion (large datasets)
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\PreviousExports\\" -ExplodeDeep -ExplosionThreads 8 -OutputPath "C:\AuditData\"

# Replay with activity filtering
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\PreviousExports\\" -ActivityTypes CopilotInteraction -OutputPath "C:\AuditData\"

# Replay with agent filtering (any agent)
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\PreviousExports\\" -AgentsOnly -OutputPath "C:\AuditData\"


# Replay with specific agent ID
./PAX_Purview_Audit_Log_Processor.ps1 -RAWInputCSV "C:\PreviousExports\\" -AgentId "CopilotStudio.Declarative.T_4e671777-fa6c-601a-b416-df08b6ae4c14.03dc0b8b-a75a-4b77-86d7-98185a176d1b" -OutputPath "C:\AuditData\\"
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

# Multiple agent IDs with deep flatten
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeDeep -AgentId "SYSTEM_CreateGPT.declarativeCopilot","CopilotStudio.Declarative.T_..." -StartDate 2025-10-01 -EndDate 2025-10-02
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
	-OutputPathSP "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"

# Unattended run from Azure using a managed identity
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth ManagedIdentity `
	-TenantId "<tenant-guid>" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathSP "https://contoso.sharepoint.com/sites/AuditTeam/Shared Documents/PAX-Output"
```

See [Sending Output to SharePoint](#sending-output-to-sharepoint) for full details, including how to obtain a valid URL.

</details>

### Sending Output to Microsoft Fabric

<details>
<summary>💻 Show Fabric Output Examples</summary>

```powershell
# Output goes straight to a Fabric lakehouse Files folder
./PAX_Purview_Audit_Log_Processor.ps1 `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathFabric "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/audit"

# Containerized run on Azure using a managed identity
./PAX_Purview_Audit_Log_Processor.ps1 `
	-Auth ManagedIdentity `
	-TenantId "<tenant-guid>" `
	-StartDate 2025-10-01 `
	-EndDate 2025-10-02 `
	-OutputPathFabric "https://onelake.dfs.fabric.microsoft.com/Analytics/PAX.Lakehouse/Files/audit"
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
- **⚠️ EOM Mode Only:** Requires `-UseEOM` parameter
- Groups are expanded to member emails using `Get-DistributionGroupMember` before querying
- NOT supported in Graph API mode (default)
- Requires Exchange Online authentication for group expansion

### When to Use User/Group Filtering

**Use `-UserIds`** when:
- Investigating specific user(s) Copilot activity
- Conducting security reviews or compliance audits for individual accounts
- Troubleshooting user-reported issues
- Analyzing power users or early adopters
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

## Microsoft Agent 365 (Frontier)

<details>
<summary>🤖 View Microsoft Agent 365 (Frontier) Guide (Click to Expand)</summary>

### Overview

Microsoft Agent 365 is the **Frontier program** surface for governing AI agents (Microsoft 365 Copilot agents, declarative agents, and partner-published packages) across the tenant. PAX adds first-class support for the Agent 365 catalog through two switches:

- **`-IncludeAgent365Info`** — appends an Agent 365 catalog snapshot to a normal audit run.
- **`-OnlyAgent365Info`** — runs **only** the Agent 365 catalog snapshot, with no audit query.

The output schema mirrors the **Microsoft Admin Center "Agent 365" export** (28 columns, including agent name, package id, publisher, developer, install counts, and last-modified metadata).

**Reference Links:**
- [Microsoft Agent 365 Frontier program](https://www.microsoft.com/en-us/microsoft-365-copilot/frontier-program)
- [Microsoft Agent 365 Graph API](https://learn.microsoft.com/en-us/microsoft-agent-365/admin/graph-api)

### When to Use Each Switch

| Goal | Use |
|------|-----|
| Combine an audit export with a same-run agent inventory snapshot (e.g., monthly reporting that includes both Copilot interactions and the current installed agent catalog) | `-IncludeAgent365Info` |
| Pull an agent catalog snapshot only (e.g., governance reviews, change tracking, BI feeds) without the cost of an audit query | `-OnlyAgent365Info` |
| Validate Frontier program enablement, role assignments, and consent quickly | `-OnlyAgent365Info` (preflight check produces fast feedback) |

### Requirements & Permissions

All four conditions below must be satisfied before the agent phase can run:

1. **Tenant Frontier program enrollment.** If the tenant is not enrolled, PAX shows a banner and skips the agent phase (with `-IncludeAgent365Info`) or exits (with `-OnlyAgent365Info`).
2. **Entra role: AI Administrator OR Global Administrator** on the signed-in caller for the agent phase. This is enforced server-side by the Frontier program and is **independent of the Graph scopes** consented to PAX. Without the role the endpoint returns 403.
3. **Graph delegated scopes:** `CopilotPackages.Read.All` and `Application.Read.All` consented for the signed-in caller.
4. **Delegated (interactive) Graph token.** The Microsoft Graph **Agent Package Management API** does not accept app-only tokens.

See the [Prerequisites](#prerequisites) section for the full permissions table and the prominent Microsoft Agent 365 (Frontier) Access callout.

### Authentication Flows

| Scenario | Audit phase | Agent 365 phase | Notes |
|----------|------------|-----------------|-------|
| `-Auth WebLogin` / `DeviceCode` / `Credential` / `Silent` + `-IncludeAgent365Info` | Interactive | Same interactive context | Single sign-in covers both phases. |
| `-Auth AppRegistration` + `-IncludeAgent365Info` | App-only (service principal) | **One-time interactive prompt** at the start of the agent phase | The interactive caller must hold AI Administrator / Global Administrator and consent to `CopilotPackages.Read.All` and `Application.Read.All`. Audit phase is unattended; agent phase is not. |
| `-Auth WebLogin` / `DeviceCode` / `Credential` / `Silent` + `-OnlyAgent365Info` | (skipped) | Interactive | Supported. |
| **`-Auth AppRegistration` + `-OnlyAgent365Info`** | (skipped) | n/a | **Not supported.** PAX exits with a clear error directing you to use `-Auth WebLogin` or `-Auth DeviceCode`. |

### Output Schema

When the agent phase runs successfully, PAX writes a 28-column dataset matching the Admin Center "Agent 365" export schema. Output destination depends on switches:

- **CSV mode (default):** `Agent365_<timestamp>.csv` (always a separate CSV file, even when combined output is enabled for the audit phase).
- **Excel mode (`-ExportWorkbook`):** an additional `Agents365` worksheet is added to the workbook alongside the audit tabs.

### Temporal Model & Data Depth (Important)

> **At a glance:** The Agent 365 CSV is a **point-in-time snapshot of the live tenant catalog at the moment the script runs**. It is **not** date-ranged, **not** historical, and **not** affected by `-StartDate` / `-EndDate`. There is **no** `-Rollup` deletion of this file — it is always retained.

#### Data source

The Agent 365 CSV is built from two Microsoft Graph endpoints:

1. **Microsoft Agent 365 Package Management API** — `GET /beta/copilot/admin/catalog/packages` (and `/{id}` for details). Returns the **complete current inventory** of agents and apps in the tenant catalog. ([API reference](https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/api/admin-settings/package/copilotpackages-list))
2. **Unified Audit Log enrichment** (best-effort, optional join) — a narrow Graph audit query for agent / app creation events, used to populate the **Date created** and **Created by** columns. Operations queried: `AppCatalogPublishedAppCreated`, `AppCatalogPublishedAppUpdated`, `AgentCreated`, `AgentPublished`, `CopilotAgentInstalled`.

#### How far back does the catalog go?

The Package Management API is a **current-state inventory call**, not a time-windowed query. There is no "since" / "as-of" / `$top=history` semantic. The factual rules:

| Question | Answer |
| --- | --- |
| **How old can a returned package be?** | Arbitrarily old. As long as the package currently exists in the tenant catalog, it appears in the snapshot — even if it was added years ago and has never been modified. There is **no Microsoft-imposed age cutoff** on returned items. |
| **Can I see deleted / unpublished agents?** | **No.** The API only returns currently-cataloged items. Once a package is removed from the tenant catalog, it disappears from subsequent snapshots and there is no "deleted items" or audit-trail endpoint that re-surfaces it. |
| **Can I get yesterday's catalog state?** | **No.** Each call returns *now*. To track changes over time, run PAX on a schedule and retain the per-run CSVs — PAX does not maintain catalog history itself. |
| **What does `lastModifiedDateTime` (column in the CSV) mean?** | The date Microsoft last updated that specific package's metadata. It is **not** the package's age, install date, or first-seen date — just the most recent modification timestamp Microsoft has recorded for it. |
| **Does the API have a `createdDateTime` field?** | The documented `copilotPackage` schema does not expose a creation timestamp. PAX populates the **Date created** / **Created by** columns by joining to the Unified Audit Log (see below), not from the package itself. |

#### How far back does the Created / Created By enrichment go?

This is the **only** time-bounded part of the Agent 365 output, and the bound is **two layers**:

1. **Tenant audit log retention.** Microsoft retains Unified Audit Log events for:
   - **180 days** — default for most Microsoft 365 / Office 365 plans (E3 and below).
   - **1 year** — default for licenses that include Microsoft 365 Audit (Standard) (E5, E5 Compliance).
   - **Up to 10 years** — with the **Audit (Premium) 10-Year Retention** add-on and an applied retention policy.
   Creation events older than your tenant's retained window are gone and **cannot be enriched**.
2. **The run's date window.** PAX's enrichment query uses the run's `-StartDate` / `-EndDate` if provided; otherwise it defaults to **the last 30 days**. So even if your tenant retains 1 year of audit data, an enrichment run with no explicit dates will only look back 30 days.

If a creation event is not found in either window, the **Date created** and **Created by** columns are left **blank** for that agent (no fabrication).

#### Practical guidance

- **Treat the CSV as a slowly-changing reference dimension** when joining it to date-ranged audit data in BI dashboards. The catalog reflects "now"; the audit data reflects the audit window.
- **For longitudinal catalog tracking**, schedule recurring PAX runs and retain each `Agent365_<timestamp>.csv`. Diff them in BI to detect added / removed / modified packages.
- **To maximize Created / Created By coverage**, either:
  - Run with an explicit `-StartDate` / `-EndDate` covering the period you care about (and within your audit retention window), or
  - Ensure your tenant has Audit (Standard) or Audit (Premium) so older creation events are retrievable.
- **Endpoint version.** PAX targets `https://graph.microsoft.com/beta/copilot/admin/catalog/packages` today (the only currently published endpoint for this data). The endpoint URL is centralized in `Get-Agent365PackagesUri` so a future move to `https://graph.microsoft.com/v1.0/...` is a one-line change.

### Tenant Not Enrolled (Frontier Banner)

If the tenant is not enrolled in the [Microsoft Agent 365 Frontier program](https://www.microsoft.com/en-us/microsoft-365-copilot/frontier-program), PAX:
- With `-IncludeAgent365Info`: prints a clear banner explaining enrollment is required, **skips** the Agent 365 phase, and continues with the audit phase (and EntraUsers enrichment if requested) so no other work is lost.
- With `-OnlyAgent365Info`: prints the same banner and exits.

See the [Microsoft Agent 365 Frontier program](https://www.microsoft.com/en-us/microsoft-365-copilot/frontier-program) page for enrollment information.

### Examples

```powershell
# Audit run with the Agent 365 catalog appended (CSV)
./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -IncludeAgent365Info

# Audit run plus Agent 365 catalog as an additional Excel worksheet
./PAX_Purview_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -IncludeAgent365Info -ExportWorkbook

# Standalone Agent 365 catalog snapshot (no audit phase)
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info

# Standalone Agent 365 snapshot bypassing non-blocking preflight warnings
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info -Force

# Standalone Agent 365 snapshot using device code (headless workstations)
./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info -Auth DeviceCode

# Dual-context: AppRegistration drives the audit phase non-interactively,
# then a one-time interactive sign-in covers the agent phase
./PAX_Purview_Audit_Log_Processor.ps1 `
    -Auth AppRegistration `
    -TenantId "<tenant-guid>" `
    -ClientId "<app-id>" `
    -ClientSecret $clientSecret `
    -StartDate 2025-10-01 -EndDate 2025-10-02 `
    -IncludeAgent365Info
```

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

The bundle includes activities from 10 categories:

#### Outlook / Exchange

| Operation | Description |
|-----------|-------------|
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
| SharingInvitationCreated | Sharing invitation created |
| SharingInvitationAccepted | Sharing invitation accepted |
| SharedLinkCreated | Shared link created |
| SharingRevoked | Sharing permissions revoked |
| RemovedFromSecureLink | User removed from secure link |

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

For easy copy/paste into scripts or pipelines, the full list of activity types enabled by `-IncludeM365Usage` (including `CopilotInteraction`) is provided below as a single comma-separated list.

```text
MailItemsAccessed,Send,SendOnBehalf,SoftDelete,HardDelete,MoveToDeletedItems,CopyToFolder,FileAccessed,FileDownloaded,FileUploaded,FileModified,FileDeleted,FileMoved,FileCheckedIn,FileCheckedOut,FileRecycled,FileRestored,FileVersionsAllDeleted,SharingInvitationCreated,SharingInvitationAccepted,SharedLinkCreated,SharingRevoked,RemovedFromSecureLink,AddMemberToUnifiedGroup,RemoveMemberFromUnifiedGroup,TeamCreated,TeamDeleted,TeamArchived,TeamSettingChanged,TeamMemberAdded,TeamMemberRemoved,MemberAdded,MemberRemoved,MemberRoleChanged,ChannelAdded,ChannelDeleted,ChannelSettingChanged,ChannelOwnerResponded,ChannelMessageSent,ChannelMessageDeleted,BotAddedToTeam,BotRemovedFromTeam,TabAdded,TabRemoved,TabUpdated,ConnectorAdded,ConnectorRemoved,ConnectorUpdated,TeamsSessionStarted,ChatCreated,ChatRetrieved,ChatUpdated,MessageSent,MessageRead,MessageDeleted,MessageUpdated,MessagesListed,MessageCreation,MessageCreatedHasLink,MessageEditedHasLink,MessageHostedContentRead,MessageHostedContentsListed,SensitiveContentShared,MeetingCreated,MeetingUpdated,MeetingDeleted,MeetingStarted,MeetingEnded,MeetingParticipantJoined,MeetingParticipantLeft,MeetingParticipantRoleChanged,MeetingRecordingStarted,MeetingRecordingEnded,MeetingDetail,MeetingParticipantDetail,LiveNotesUpdate,AINotesUpdate,RecordingExported,TranscriptsExported,AppInstalled,AppUpgraded,AppUninstalled,CreatedApproval,ApprovedRequest,RejectedApprovalRequest,CanceledApprovalRequest,Create,Edit,Open,Save,Print,CreateForm,EditForm,DeleteForm,ViewForm,CreateResponse,SubmitResponse,ViewResponse,DeleteResponse,StreamModified,StreamViewed,StreamDeleted,StreamDownloaded,PlanCreated,PlanDeleted,PlanModified,TaskCreated,TaskDeleted,TaskModified,TaskAssigned,TaskCompleted,LaunchedApp,CreatedApp,EditedApp,DeletedApp,PublishedApp,CopilotInteraction
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

## Rollup Post-Processor (Power BI)

<details>
<summary>📊 View Rollup Post-Processor Guide (Click to Expand)</summary>

> **Purpose & scope.** The `-Rollup` and `-RollupPlusRaw` switches (added in **v1.11.1**) exist **solely to produce input files for the Microsoft Copilot Growth ROI Advisory Team's Power BI templates** published at <https://github.com/microsoft/Analytics-Hub>. The rolled-up CSVs are shaped specifically for those templates — schema, column names, aggregation grain, and join keys are all dictated by the Power BI data models. **The rollup outputs are not intended for any other downstream use.** If you need a generic analytics export, run PAX without `-Rollup` / `-RollupPlusRaw` and consume the raw CSV directly.
>
> **Agent 365 companion (when `-IncludeAgent365Info` is also specified):** The same Analytics-Hub dashboards consume `Agent365_<timestamp>.csv` as a companion input alongside the rollup output. That file is a **point-in-time catalog snapshot** (it is **not** filtered by `-StartDate` / `-EndDate`) and is **always retained** — `-Rollup` never deletes it. Note the temporal mismatch when interpreting dashboards: rollup data spans the audit window, while the Agent 365 catalog reflects state at run time.

### Overview

When `-Rollup` or `-RollupPlusRaw` is specified, PAX runs an **embedded Python post-processor** against the audit run's final CSV immediately after a successful export. The processor — and therefore the target Power BI template — is auto-selected based on the activity-type shape of the run:

| Run shape | Embedded processor | Inputs consumed | Target Analytics-Hub dashboard(s) |
| --- | --- | --- | --- |
| **CopilotInteraction-only** (default activity type, or `-ActivityTypes 'CopilotInteraction'`) | `Purview_CopilotInteraction_Processor` v3.0.0 | Purview CSV **+** Entra users CSV (`EntraUsers_MAClicensing_<timestamp>.csv`) | **AI-in-One** and **AI Business Value** |
| **`-IncludeM365Usage`** | `Purview_M365_Usage_Bundle_Explosion_Processor` v2.1.0 | Combined Purview CSV (single file) | **M365 Usage Analytics** |

### Agent 365 Companion File

`-IncludeAgent365Info` is **compatible** with `-Rollup` / `-RollupPlusRaw` even though Agent 365 data is not consumed by the embedded Python processor. The resulting `Agent365_<timestamp>.csv` is loaded directly by the same Analytics-Hub Power BI dashboards as a companion input alongside the rollup output.

| Behavior | Detail |
| --- | --- |
| **Temporal model** | **Point-in-time snapshot of the live tenant catalog at the moment the script runs.** It is **not** filtered by `-StartDate` / `-EndDate`. The Microsoft Graph Package Management API (`/beta/copilot/admin/catalog/packages`) is a current-inventory call — it has no historical / as-of semantic. Items in the catalog are returned regardless of age; deleted items are **not** retrievable. See [Microsoft Agent 365 (Frontier) → Temporal Model & Data Depth](#microsoft-agent-365-frontier) for the full factual breakdown. |
| **Created / Created By columns** | Populated by a separate Unified Audit Log enrichment join. Bounded by **(a)** your tenant's audit retention (180 days E3 / 1 year E5 / up to 10 years with Audit Premium add-on) and **(b)** the run's `-StartDate` / `-EndDate` window (defaults to last 30 days if omitted). Older creation events are left blank — no fabrication. |
| **Retention** | **Always retained.** `-Rollup` never deletes it (the deletion loop has both an explicit allow-list and a defensive file-name guard against `Agent365_*`). |
| **Dashboard interpretation** | Be aware of the temporal mismatch: the rollup file covers the audit-window date range, while the Agent 365 file reflects catalog state at run time. Dashboards joining the two should treat the Agent 365 catalog as a slowly-changing reference dimension. |
| **`-OnlyAgent365Info`** | **Blocked** with rollup (it skips the Purview audit pull entirely, leaving nothing for the Python processor to consume). Use `-IncludeAgent365Info` instead. |

See [Microsoft Agent 365 (Frontier)](#microsoft-agent-365-frontier) for the full Agent 365 schema and switch reference, including the **Temporal Model & Data Depth** subsection that documents the catalog API's current-state semantics and audit-log retention boundaries.

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
- `-ExportWorkbook`
- `-OnlyUserInfo`
- `-OnlyAgent365Info`
- `-IncludeDSPMForAI`
- `-RAWInputCSV`
- `-AppendFile`
- `-ExcludeCopilotInteraction` **without** `-IncludeM365Usage`

### Output Files

Rolled-up CSVs are written to the same directory as the raw Purview CSV (default: `./output/`). File names follow the embedded processor's own naming conventions and are the exact files expected by the Analytics-Hub Power BI templates — **do not rename them**. See [Output Files & Schema](#output-files--schema) for the surrounding directory layout.

### Examples

```powershell
# CopilotInteraction-only rollup → AI-in-One + AI Business Value dashboards.
# Raw CSV(s) deleted on success; only the rollup output remains.
.\PAX_Purview_Audit_Log_Processor_v1.11.1.ps1 -StartDate '2026-04-01' -EndDate '2026-04-30' -Rollup

# Same as above but keep the raw Purview + Entra users CSVs alongside the rollup output.
.\PAX_Purview_Audit_Log_Processor_v1.11.1.ps1 -StartDate '2026-04-01' -EndDate '2026-04-30' -RollupPlusRaw

# M365 Usage Analytics dashboard input. -IncludeM365Usage auto-enables -CombineOutput;
# -Rollup deletes the raw combined CSV after the rollup output is produced.
.\PAX_Purview_Audit_Log_Processor_v1.11.1.ps1 -StartDate '2026-04-01' -EndDate '2026-04-30' -IncludeM365Usage -Rollup

# Rollup + Agent 365 companion file. Rollup output is produced from the audit window,
# Agent 365 catalog snapshot is taken at run time, both feed the Analytics-Hub dashboards.
# The Agents365 CSV is always retained even with -Rollup.
.\PAX_Purview_Audit_Log_Processor_v1.11.1.ps1 -StartDate '2026-04-01' -EndDate '2026-04-30' -IncludeAgent365Info -Rollup
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
- **Cost:** Approximately $0.0132 per 1,000 records (verify current pricing with Microsoft)
- **Billing Alert:** Script displays information about potential PAYG costs before proceeding

---

### DSPM for AI Parameters

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

**Destination does not change filenames.** Whether output is written to a local folder (`-OutputPath`), a SharePoint folder (`-OutputPathSP`), or a Microsoft Fabric lakehouse (`-OutputPathFabric`), PAX uses the same filenames described above. Only the destination differs.

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
- **Maintain consistent naming** for scheduled reports and automation workflows

**Key Benefits:**
- **Zero data loss:** Safe header validation prevents schema conflicts
- **Flexible workflows:** Works with both CSV and Excel output formats
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
> - **403 Forbidden:** Permissions issue → Token refresh will NOT help. Check `AuditLogsQuery.Read.All` consent and role assignments.

### Resume Mode: Standalone Behavior

**IMPORTANT:** The `-Resume` switch is standalone. All processing parameters are restored from the checkpoint file to ensure data consistency. You cannot specify other parameters with `-Resume` (except authentication overrides).

**Allowed with `-Resume`:**
- `-Force` - Use most recent checkpoint without prompting
- `-Auth` - Override authentication method
- `-TenantId`, `-ClientId`, `-ClientSecret` - Auth credentials for AppRegistration
- `-ExplosionThreads` - Override thread count for parallel explosion (e.g., resuming on different hardware)
- `-MaxMemoryMB` - Override memory threshold (e.g., resuming on different hardware)

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
- **Microsoft Agent 365 (Frontier) catalog (with `-IncludeAgent365Info` or `-OnlyAgent365Info`):** an additional `Agents365` worksheet is added to the workbook (28-column schema matching the Microsoft Admin Center "Agent 365" export).

**CSV File Naming:**
- **Default (separate files per activity type):** `<ActivityTypeName>_<timestamp>.csv` (e.g., `CopilotInteraction_20251107_143022.csv`, `ConnectedAIAppInteraction_20251107_143022.csv`)
- **Combined mode (with `-CombineOutput`):** `Purview_Audit_CombinedUsageActivity_<timestamp>.csv`
- **Entra users file (when `-IncludeUserInfo` used):** `EntraUsers_MAClicensing_<timestamp>.csv` (always separate CSV, even in Excel mode unless embedded as tab)
- **Microsoft Agent 365 (Frontier) catalog file (when `-IncludeAgent365Info` or `-OnlyAgent365Info` used):** `Agent365_<timestamp>.csv` (always a separate CSV when not in Excel workbook mode)

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

#### Exploded Mode (`-ExplodeArrays`)

**Purview canonical 153-column schema.** Array elements (Messages, AccessedResources, AISystemPlugins) expanded to separate rows.

**Column Count:** 153 base columns

**Base Columns (153):**

**Core Record Identity (7)**
RecordId, CreationDate, RecordType, Operation, UserId, AssociatedAdminUnits, AssociatedAdminUnitsNames

**Audit & Organization Metadata (14)**
@odata.type, CreationTime, Id, OrganizationId, ResultStatus, UserKey, UserType, Version, Workload, ObjectId, ErrorNumber, CorrelationId, RecordTypeNum, ResultStatus_Audit

**Identity & Authentication (15)**
AzureActiveDirectoryEventType, ActorContextId, ActorIpAddress, InterSystemsId, IntraSystemId, SupportTicketId, TargetContextId, ApplicationId, AuthenticationType, ActorInfoString, AppId, AuthType, TokenObjectId, TokenTenantId, TokenType

**Device & Client (12)**
ClientIP, ClientIPAddress, DeviceProperties.OS, DeviceProperties.BrowserType, DeviceDisplayName, IsManagedDevice, DeviceType, BrowserName, BrowserVersion, Platform, UserAgent, ClientRegion

**SharePoint & OneDrive (18)**
SiteUrl, SourceRelativeUrl, SourceFileName, SourceFileExtension, ListId, ListItemUniqueId, WebId, ApplicationDisplayName, EventSource, ItemType, SiteSensitivityLabelId, GeoLocation, ListBaseType, ListServerTemplate, Site, DoNotDistributeEvent, HighPriorityMediaProcessing, FileSizeBytes

**Exchange & Mailbox (15)**
ClientAppId, ClientInfoString, ExternalAccess, InternalLogonType, LogonType, LogonUserSid, MailboxGuid, MailboxOwnerSid, MailboxOwnerUPN, OrganizationName, OriginatingServer, SessionId, SaveToSentItems, OperationCount, CrossMailboxOperation

**Sharing & Permissions (6)**
Permission, SensitivityLabelId, SharingLinkScope, TargetUserOrGroupType, TargetUserOrGroupName, SensitivityLabel

**Teams & Meetings (17)**
MeetingId, MeetingType, EventSignature, EventData, MeetingURL, ChatId, MessageId, MessageSizeInBytes, MessageType, ChannelId, TeamName, TeamGuid, ResponseId, IsAnonymous, ChannelName, ChannelGuid, ChannelType

**Collaboration & Apps (14)**
FormId, FormName, VideoId, VideoName, ViewDuration, AppName, EnvironmentName, PlanId, PlanName, TaskId, TaskName, PercentComplete, AppHost, ThreadId

**Copilot AI & Model (11)**
CopilotLogVersion, TargetId, ModelId, ModelProvider, ModelFamily, TokensTotal, TokensInput, TokensOutput, DurationMs, OutcomeStatus, ModelTransparencyDetails_ModelName

**Copilot Interaction (11)**
ConversationId, TurnNumber, RetryCount, ClientVersion, ClientPlatform, AgentId, AgentName, AgentVersion, AgentCategory, ApplicationName, MessageIds

**Copilot Context & Resources (13)**
Context_Id, Context_Type, Context_Item, Message_Id, Message_isPrompt, AccessedResource_Action, AccessedResource_PolicyDetails, AccessedResource_SiteUrl, AccessedResource_Name, AccessedResource_SensitivityLabel, AccessedResource_ResourceType, AISystemPlugin_Id, AISystemPlugin_Name

**Use When:** Need relational format for BI tools or matching Microsoft Purview exports

#### Deep Flatten Mode (`-ExplodeDeep`)

**153 base columns + all nested `CopilotEventData.*` columns.** Maximum data extraction with every nested field as a separate column.

**Column Count:** 153+ (dynamic based on data)

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

`HasLicense` is computed dynamically against the live tenant catalog — there is **no hard-coded SKU allow-list** in the script:

1. PAX calls Microsoft Graph `/subscribedSkus` and enumerates each SKU's `servicePlans` collection.
2. Every `servicePlanId` whose `servicePlanName` matches the wildcard `*COPILOT*` is added to a per-run "Copilot service plan" set.
3. For each user, PAX inspects every entry in `assignedPlans`. The user is flagged `HasLicense = True` when **any** assigned plan satisfies both:
   - `capabilityStatus == 'Enabled'`, AND
   - `servicePlanId` is in the discovered Copilot service plan set.
4. Users with no matching enabled plan get `HasLicense = False`. The full friendly SKU name list still appears in `AssignedLicenses` for traceability.

**Why dynamic:** Microsoft adds new Copilot SKUs and renames existing ones regularly (e.g., across M365, EDU, Sales, Service, Finance, GCC, Frontier program). The wildcard match against the live `/subscribedSkus` catalog auto-adapts to any current or future Copilot SKU without requiring a script update.

**Caveats:**

- Detection depends on the SKU's `servicePlanName` containing the substring `COPILOT`. SKUs that ship Copilot capabilities under a non-`COPILOT` plan name will not be detected.
- Plans assigned but disabled at the user level (`capabilityStatus != 'Enabled'`) deliberately do not count, matching real entitlement state.

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

**For Large Standard (Non-Exploded) Exports:**

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

### Parallel Explosion Tuning

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

**Force Serial (Debugging):**

```powershell
# Serial processing for debugging
./PAX_Purview_Audit_Log_Processor.ps1 -ExplodeArrays -ExplosionThreads 1 -StartDate 2025-10-01 -EndDate 2025-10-02
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
| Debugging | `1` (serial) |

**Architecture Notes:**

- Job queue pattern: Records split into ~1000-record chunks, N workers pull from shared queue
- Ensures good load balancing even with uneven data distribution
- No thread sits idle while work remains

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
- [Microsoft Agent 365 (Frontier) Issues](#microsoft-agent-365-frontier-issues)
- [SharePoint Output Issues (`-OutputPathSP`)](#sharepoint-output-issues--outputpathsp)
- [Fabric / OneLake Output Issues (`-OutputPathFabric`)](#fabric--onelake-output-issues--outputpathfabric)
- [Managed-Identity Sign-In Issues](#managed-identity-sign-in-issues)
- [Conflicting Output Destinations](#conflicting-output-destinations)

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

#### Microsoft Agent 365 (Frontier) Issues

All Microsoft Agent 365 (Frontier) failure modes are consolidated below. The Agent 365 catalog is a **point-in-time snapshot** retrieved via the Graph Agent Package Management API; failures generally fall into one of three categories.

##### 1. Tenant Not Enrolled

**Problem:** Run with `-IncludeAgent365Info` or `-OnlyAgent365Info` shows a banner stating the tenant is not enrolled in the Microsoft Agent 365 Frontier program, and the agent phase is skipped.

**Behavior:**
- With `-IncludeAgent365Info`: the audit phase (and EntraUsers enrichment if requested) still completes normally; only the Agent 365 catalog phase is skipped.
- With `-OnlyAgent365Info`: PAX exits because there is no other phase to run.

**Solutions:**
- Confirm tenant enrollment in the [Microsoft Agent 365 Frontier program](https://www.microsoft.com/en-us/microsoft-365-copilot/frontier-program).
- After enrollment is processed, re-run PAX with the same parameters.

##### 2. 403 on the Agent Endpoint

**Problem:** The agent phase fails with a 403 Forbidden response from `/beta/copilot/admin/catalog/packages` even though Graph scopes are consented.

**Cause:** The Agent 365 endpoint enforces an Entra role gate **separate from Graph scopes**. Consenting `CopilotPackages.Read.All` and `Application.Read.All` is necessary but not sufficient — the signed-in caller must also hold the Entra **AI Administrator** or **Global Administrator** role.

**Solutions:**
- Verify the signed-in caller (the interactive admin for the agent phase, even when `-Auth AppRegistration` is used for the audit phase) holds **AI Administrator** or **Global Administrator** in Entra.
- If the role was just assigned, sign out and sign back in to refresh the token's role claims.
- Re-consent `CopilotPackages.Read.All` and `Application.Read.All` if the consent record was revoked.

##### 3. `-OnlyAgent365Info` Rejected With `-Auth AppRegistration`

**Problem:** Running `./PAX_Purview_Audit_Log_Processor.ps1 -OnlyAgent365Info -Auth AppRegistration ...` exits immediately with an error.

**Cause:** The Microsoft Graph Agent Package Management API does not accept app-only tokens. With `-IncludeAgent365Info`, PAX bridges this by adding a one-time interactive sign-in for the agent phase only — but with `-OnlyAgent365Info` there is no audit phase to justify the dual-context flow, so app-only auth is blocked outright.

**Solutions:**
- Use `-Auth WebLogin` for interactive workstations.
- Use `-Auth DeviceCode` for headless or remote sessions.
- If you need a fully scheduled run, use `-IncludeAgent365Info` together with `-Auth AppRegistration` and accept the one-time interactive prompt for the agent phase.

##### Quick Diagnostic Reference

| Symptom | Most Likely Cause | First Fix |
|---|---|---|
| Banner: "tenant not enrolled" | Frontier program enrollment missing | Enroll tenant in Frontier |
| 403 on `/beta/copilot/admin/catalog/packages` | Caller missing AI Administrator / Global Administrator role | Assign role; re-sign-in to refresh token |
| Immediate exit on `-OnlyAgent365Info -Auth AppRegistration` | App-only auth not supported for Agent 365 | Use `-Auth WebLogin` / `-Auth DeviceCode`, or use `-IncludeAgent365Info` with `-Auth AppRegistration` |
| Empty catalog | No agents installed in tenant, or snapshot caught a transient state | Re-run; verify in Admin Center > Agent 365 |

#### SharePoint Output Issues (`-OutputPathSP`)

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

#### Fabric / OneLake Output Issues (`-OutputPathFabric`)

**Problem:** Run fails at the very start with "OneLake URL is not in the expected shape."

**Solutions:**
- The URL must start with `https://onelake.dfs.fabric.microsoft.com/` and contain a `<workspace>/<item>.Lakehouse/Files` (or `.Warehouse/Files`) segment.
- Do **not** paste the Fabric portal URL (`https://app.fabric.microsoft.com/...`); that is a UI page, not the OneLake DFS endpoint.
- Make sure the path points at `Files/...`, not `Tables/...`. PAX writes flat files, not delta tables.
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

**Problem:** `-Auth ManagedIdentity` rejected immediately with an error mentioning Agent 365.

**Solution:** `-IncludeAgent365Info` and `-OnlyAgent365Info` do not support managed-identity tokens. Use `-Auth WebLogin` or `-Auth DeviceCode` for Agent 365 phases. The audit phase can still run unattended with `-Auth AppRegistration` if you accept the one-time interactive sign-in for the agent phase.

#### Conflicting Output Destinations

**Problem:** Run exits immediately with an error saying that `-OutputPath`, `-OutputPathSP`, and `-OutputPathFabric` cannot be combined.

**Solution:** Pick exactly one destination per run. The three parameters are mutually exclusive — PAX writes locally, to SharePoint, or to Fabric on a given run, never two at once. Remove the parameters you did not intend to use and re-run.

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
| Group filtering             | Only available in EOM mode (`-UseEOM -GroupNames`)                              | Graph API mode does not support group-based filtering; export and filter client-side                         |
| Microsoft Agent 365 catalog | Single-shot Graph call to `/beta/copilot/admin/catalog/packages` capped by Microsoft at **400 packages per response** (no server-side paging). Catalog is **point-in-time**, not historical. App-only tokens are rejected; agent phase requires a delegated (interactive) sign-in with **AI Administrator** or **Global Administrator** role. | Tenants exceeding 400 installed agents see a warning and a truncated export — no PAX-side workaround until Microsoft enables paging. For longitudinal change tracking, run on a schedule and retain per-run CSVs. Use `-IncludeAgent365Info` with `-Auth AppRegistration` to pair a non-interactive audit phase with a one-time interactive agent-phase sign-in. |
| Microsoft 365 Usage bundle  | Requires per-workload Graph scopes: `AuditLogsQuery-Exchange.Read.All`, `AuditLogsQuery-OneDrive.Read.All`, `AuditLogsQuery-SharePoint.Read.All` in addition to base `AuditLogsQuery.Read.All` | Consent the per-workload scopes at first run. Without them, the bundle silently returns no data for the missing workloads. |
| Output destination          | `-OutputPath`, `-OutputPathSP`, and `-OutputPathFabric` are **mutually exclusive**. PAX writes to exactly one destination per run; passing more than one causes PAX to exit immediately before any audit data is pulled. | Choose the destination that matches the consumer of the run (local for ad-hoc, SharePoint for team visibility, Fabric for downstream analytics). Run PAX a second time with a different destination if you need both. |
| Managed identity + Agent 365 | `-Auth ManagedIdentity` is **not supported** with `-IncludeAgent365Info` or `-OnlyAgent365Info`. The Microsoft Agent 365 catalog API rejects non-interactive tokens (managed identity and app-only). | Use `-Auth WebLogin` or `-Auth DeviceCode` for Agent 365 phases, or use `-IncludeAgent365Info` with `-Auth AppRegistration` and accept the one-time interactive prompt for the agent phase. |
| SharePoint output URL       | `-OutputPathSP` accepts only canonical SharePoint folder URLs (`https://<tenant>.sharepoint.com/sites/<site>/<library>/...`). Sharing links (`/:f:/s/...`), `_layouts/` pages, `Forms/AllItems.aspx` view URLs, query-string URLs, OneDrive personal sites, and HTTP URLs are all rejected. | Copy the URL from the browser address bar while *viewing the destination folder*; strip everything from `?` onward. See [Sending Output to SharePoint](#sending-output-to-sharepoint). |
| Fabric output URL           | `-OutputPathFabric` accepts only OneLake DFS URLs (`https://onelake.dfs.fabric.microsoft.com/<workspace>/<item>.Lakehouse/Files...` or `.Warehouse/Files...`). Fabric portal URLs, Power BI report/dataset URLs, and `Tables/` paths are rejected. PAX writes flat files; it does not write into delta tables. | Build the URL using the workspace and lakehouse/warehouse names. See [Sending Output to Microsoft Fabric (OneLake)](#sending-output-to-microsoft-fabric-onelake). |
| Fabric permissions          | `-OutputPathFabric` requires **three** layers: Azure role `Storage Blob Data Contributor`, Fabric workspace **Contributor** role, and Fabric tenant setting *Service principals can use Fabric APIs* enabled (for `AppRegistration` / `ManagedIdentity`). Partial setup will fail at the pre-flight check. | Coordinate the three roles with the workspace owner, Azure subscription admin, and Fabric tenant admin before scheduling unattended runs. |

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
- **Local output only.** PAX writes its CSV / Excel / JSON metrics output to the path you supply (`-OutputPath`). It does not upload anywhere.
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
| `-IncludeAgent365Info` / `-OnlyAgent365Info` | `CopilotPackages.Read.All`, `Application.Read.All` (delegated; requires AI Administrator or Global Administrator role on the caller) |

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
6. Install required PowerShell modules (`Microsoft.Graph.*`, `ExchangeOnlineManagement`, `ImportExcel`) only from the official PowerShell Gallery, and pin module versions in regulated environments.
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

**Microsoft Agent 365 (Frontier):**

- [Microsoft Agent 365 Frontier program](https://www.microsoft.com/en-us/microsoft-365-copilot/frontier-program) — Tenant enrollment
- [Microsoft Agent 365 Graph API](https://learn.microsoft.com/en-us/microsoft-agent-365/admin/graph-api) — Agent Package Management API reference

**DSPM for AI:**

- [Microsoft Purview DSPM for AI](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview) — Data Security Posture Management for AI overview

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


