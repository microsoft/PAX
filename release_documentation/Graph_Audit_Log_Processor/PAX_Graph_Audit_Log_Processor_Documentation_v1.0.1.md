# Portable Audit eXporter (PAX) - <br/>Graph Audit Log Processor

> **🚀 Quick Start:** Download the script → [`PAX_Graph_Audit_Log_Processor_v1.0.1.ps1`](https://github.com/microsoft/PAX/releases/download/graph-v1.0.1/PAX_Graph_Audit_Log_Processor_v1.0.1.ps1)
>
> **📋 Release Notes:** See what's new → [v1.0.1 Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Graph_Audit_Log_Processor/PAX_Graph_Audit_Log_Processor_Release_Note_v1.0.1.md) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Graph_Audit_Log_Processor)
>
> **📜 Previous Script Versions:** [All Graph Releases](https://github.com/microsoft/PAX/releases?q=graph-&expanded=true)
>
> **📚 Documentation:** [v1.0.1 MD](https://github.com/microsoft/PAX/blob/release/release_documentation/Graph_Audit_Log_Processor/PAX_Graph_Audit_Log_Processor_Documentation_v1.0.1.md) | [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Graph_Audit_Log_Processor)

**Script:** `PAX_Graph_Audit_Log_Processor_v1.0.1.ps1`  
**Version:** 1.0.1  
**Audience:** IT admins, BI analysts, Copilot adoption teams  
**Runtime:** PowerShell 5.1 (compatible) / PowerShell 7+ (recommended)  
**License:** MIT

---

<details>
<summary>⚠️ Important Usage & Compliance Disclaimer</summary>

**Please note:**

While this tool helps customers better understand their Microsoft 365 and Copilot usage data, Microsoft has no visibility into the data that customers input into this script/tool, nor does Microsoft have any control over how customers will use this script/tool in their environment.

Customers are solely responsible for ensuring that their use of the script/tool complies with all applicable laws and regulations, including those related to data privacy and security.

Microsoft disclaims any and all liability arising from or related to customers' use of the script/tool.

**Experimental Script Notice:**

This is an experimental script. On occasion, you may notice small deviations from metrics in official Microsoft dashboards. We will continue to iterate based on your feedback. Currently available in English only.

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
9. [Output Files & Schema](#output-files--schema)
10. [Data Obfuscation Warning](#data-obfuscation-warning)
11. [Endpoint Reference](#endpoint-reference)
12. [Advanced Features](#advanced-features)
13. [Performance Tuning](#performance-tuning)
14. [Troubleshooting & FAQ](#troubleshooting--faq)
15. [Known Limitations](#known-limitations)
16. [Security & Compliance](#security--compliance)

---

## Overview

<details open>
<summary>What It Does</summary>

The **Portable Audit eXporter (PAX) - Graph Audit Log Processor** is an enterprise-grade PowerShell script that exports Microsoft 365 and Copilot usage analytics from Microsoft Graph API. It retrieves aggregated usage reports and transforms them into analysis-ready CSV files **or professional Excel workbooks** with comprehensive Entra user enrichment.

**Core Capabilities:**

- **Default Curated Set:** Queries 9 essential endpoints covering usage, licensing, and user directory data (M365AppUserDetail, TeamsUserActivity, EmailActivity, SharePointActivity, OneDriveActivity, CopilotUsage, MACCopilotLicensing, MACLicenseSummary, EntraUsers)
- **Flexible Selection:** Granular control with `-Include*` parameters to replace defaults, or `-Exclude*` parameters to selectively remove endpoints from the curated set
- **17 Available Endpoints:** Full coverage including MAC Copilot Licensing (per-user assignments) and MAC License Summary (tenant-wide capacity)
- **Rich User Data:** 35 Entra user properties including manager hierarchy, licenses, and organizational metadata
- **Period-Based Queries:** Aggregated reports covering D7, D30, D90, D180, or ALL time periods
- **Excel Export:** Multi-sheet workbooks with professional formatting, frozen headers, auto-sized columns, and append capabilities
- **License Management:** Comprehensive Copilot license tracking with per-user assignments, tenant-wide capacity metrics, and three-tier SKU detection
- **Auto-Installation:** Automatically handles Microsoft.Graph and ImportExcel PowerShell modules
- **Enterprise-Ready:** Detailed logging, error handling with automatic retry logic
- **Unified Output:** Options to combine all endpoint data into a single CSV or multi-sheet Excel workbook

**Query Mode:**

- **Period Mode** (`-Period D7|D30|D90|D180|ALL`) - Server-aggregated usage reports covering specified time windows
- **Default Period:** D7 (last 7 days) when no period specified
- **Combined Output Mode** (`-CombineOutput`) - Single CSV with full outer join across all endpoints
- **Excel Workbook Mode** (`-ExportWorkbook`) - Multi-sheet Excel workbook with separate sheet tabs for each endpoint output

**Endpoint Selection Modes:**

- **Default Mode:** Queries 9 curated endpoints (M365AppUserDetail, TeamsUserActivity, EmailActivity, SharePointActivity, OneDriveActivity, CopilotUsage, MACCopilotLicensing, MACLicenseSummary, EntraUsers)
- **Granular Selection:** Individual `-Include*` parameters replace default set with custom endpoint selection (IncludeCopilotUsage, IncludeM365AppUserDetail, IncludeTeamsActivity, IncludeOutlookActivity, IncludeSharePointActivity, IncludeOneDriveActivity, IncludeMACCopilotLicensing, IncludeMACLicenseSummary, IncludeEntraUsers)
- **Explicit Curated:** `-IncludeCurated` explicitly includes all 9 curated endpoints (can combine with other `-Include*` parameters for additive selection)
- **Selective Removal:** `-Exclude*` parameters (ExcludeEntraUsers, ExcludeMACCopilotLicensing, ExcludeMACLicenseSummary) remove specific endpoints from the default curated set
- **Custom Endpoint Array:** `-IncludeCustomEndpoints` accepts array of endpoint names for programmatic control

**Why Use This Script:**

- **Fast Deployment:** No Azure app registration required (uses interactive authentication by default)
- **Comprehensive Coverage:** Default curated set provides complete tenant analysis including usage analytics, license management, and user enrichment
- **Excel-Ready Output:** Professional multi-sheet workbooks perfect for executive reporting and sharing, and unified usage data analysis
- **License Management:** Complete Copilot license tracking with per-user assignments, tenant capacity metrics, and utilization analysis
- **Power BI Ready:** Output optimized for direct import into analytics tools
- **Enterprise Scale:** Handles large tenants with automatic throttling and retry logic
- **Privacy Aware:** Detects data obfuscation settings and provides remediation guidance
- **Three-Tier SKU Detection:** Comprehensive license detection for Copilot SKUs (hardcoded list + pattern matching + M365/Office 365 base SKUs)

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Key Features

<details>
<summary>Query Flexibility</summary>

- **Period-Based Queries:** Pre-aggregated data for D7, D30, D90, D180, or ALL time periods
- **Default Period:** Defaults to D7 (last 7 days) when no period specified
- **Efficient Data Retrieval:** Server-side aggregation for fast query performance
- **Multiple Time Windows:** Choose the time period that matches your reporting needs

</details>

<details>
<summary>Data Enrichment</summary>

- **35 Entra User Properties:** Identity, job info, location, org data, licenses, provisioned plans
- **Manager Hierarchy:** Automatic manager expansion with 4 key manager properties
- **License Tracking:** Full license and service plan assignments with enabled/disabled status
- **Email Aliases:** Primary SMTP and all proxy addresses extracted
- **Real User Filtering:** Automatically excludes rooms, resources, and service accounts

</details>

<details>
<summary>Output Options</summary>

- **Individual Files:** One CSV per endpoint with auto-generated timestamps
- **Combined Output:** Single unified CSV with full outer join on userPrincipalName
- **Excel Workbook Export:** Multi-sheet workbook with professional formatting (frozen headers, auto-sized columns, ordered tabs)
- **Append Mode:** Add data to existing Excel workbooks with column validation
- **Custom Filenames:** Specify exact output filenames (no timestamp added)
- **Column Reordering:** Report Period moved to position 2 for better readability
- **Array Explosion:** Optional expansion of nested arrays (licenses, plans, etc.)

</details>

<details>
<summary>Excel Workbook Features</summary>

- **Multi-Sheet Layout:** One worksheet per endpoint (no individual CSV files when using `-ExportWorkbook`)
- **Professional Formatting:** 
  - Frozen top row for scrollable headers
  - Auto-sized columns for readability
  - Bold header row styling
  - Prevents Excel auto-conversion of phone numbers, dates, and numeric strings
- **Ordered Tabs:** Logical tab ordering (Entra Users → Licensing → Usage → Services)
- **Append Mode:** Add new data to existing workbooks with intelligent column validation
- **Timestamped Duplicates:** Automatic duplicate tab creation when column headers change
- **ImportExcel Module:** Auto-installs from PowerShell Gallery if missing

</details>

<details>
<summary>Reliability & Performance</summary>

- **Auto-Retry Logic:** Exponential backoff for throttling (429) and transient errors
- **Pagination Handling:** Automatic @odata.nextLink traversal for large result sets
- **Parallel Processing:** All selected endpoints queried concurrently
- **Throttle Control:** `-PacingMs` parameter for rate limiting in large tenants
- **Error Handling:** Comprehensive try-catch with detailed error messages

</details>

<details>
<summary>Security & Compliance</summary>

- **Interactive Authentication:** No stored credentials (browser-based OAuth by default)
- **Device Code Flow:** Alternative for limited browser environments
- **Credential Support:** Client secret authentication for automated scenarios
- **Silent Mode:** Managed identity support for Azure environments
- **Audit Logging:** All operations logged to timestamped log files

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Use Cases

<details>
<summary>Copilot Adoption Tracking</summary>

**Scenario:** Track Copilot usage across your organization

```powershell
# Get last 30 days using default curated set (includes Copilot and Entra Users) - CSV
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -CombineOutput -OutputFileName "Copilot_Adoption_Report.csv"

# Export to Excel workbook for easier sharing
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -ExportWorkbook -OutputFileName "Copilot_Adoption_Report.xlsx"

# Focus on just Copilot usage and user data (exclude other endpoints)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeCopilotUsage -IncludeEntraUsers -ExportWorkbook -OutputFileName "Copilot_Only_Report.xlsx"
```

**Benefits:**
- Identify power users and non-adopters
- Track feature usage (Word, Excel, PowerPoint, Teams, Outlook Copilot)
- Calculate ROI metrics with enriched user properties (department, manager, location)
- Excel format for easy sharing with executives and stakeholders

</details>

<details>
<summary>Copilot License Management</summary>

**Scenario:** Track Copilot license assignments and utilization

```powershell
# Default curated set already includes licensing endpoints (CopilotUsage, MACCopilotLicensing, MACLicenseSummary, EntraUsers)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -ExportWorkbook -OutputFileName "Copilot_License_Report.xlsx"

# Focus on just licensing data (exclude M365 app usage endpoints)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCopilotUsage -IncludeMACCopilotLicensing -IncludeMACLicenseSummary -IncludeEntraUsers -ExportWorkbook -OutputFileName "Copilot_Licensing_Only.xlsx"
```

**Benefits:**
- Per-user license assignments with sign-in activity
- Tenant-wide license capacity and utilization metrics
- Three-tier Copilot license detection (Known SKUs + M365 SKUs + Pattern Matching)
- Identify inactive licensed users for license reclamation
- Capacity planning for license procurement

</details>

<details>
<summary>Weekly Excel Dashboard with Scheduled Execution</summary>

**Scenario:** Build recurring weekly Excel reports with automated execution using Windows Task Scheduler

**Step 1: Create Initial Workbook (Manual or Scheduled)**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -ExportWorkbook -OutputFileName "Weekly_Report.xlsx" -OutputPath "C:\Reports"
```

**Step 2: Set Up Weekly Windows Task Scheduler**

**Option A: Using Task Scheduler GUI**
1. Open Task Scheduler → Create Task
2. **General Tab:**
   - Name: "PAX Weekly Excel Dashboard"
   - Run whether user is logged on or not
   - Run with highest privileges
3. **Triggers Tab:**
   - New → Weekly → Monday at 6:00 AM
4. **Actions Tab:**
   - Action: Start a program
   - Program: `C:\Program Files\PowerShell\7\pwsh.exe`
   - Arguments: `-File "C:\Scripts\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1" -Period D7 -IncludeCurated -ExportWorkbook -AppendWorkbook -OutputFileName "Weekly_Report.xlsx" -OutputPath "C:\Reports" -Auth Credential`
   - Start in: `C:\Scripts`

**Option B: Using PowerShell to Create Task**
```powershell
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument '-File "C:\Scripts\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1" -Period D7 -IncludeCurated -ExportWorkbook -AppendWorkbook -OutputFileName "Weekly_Report.xlsx" -OutputPath "C:\Reports" -Auth Credential'
$trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Monday -At 6am
$principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "PAX Weekly Excel Dashboard" -Description "Weekly Microsoft 365 usage data append to Excel workbook"
```

**Step 3: Configure Authentication (Required for Scheduled Tasks)**

For unattended execution, use client secret authentication:
```powershell
# Set environment variables (one-time setup)
[System.Environment]::SetEnvironmentVariable('GRAPH_TENANT_ID', 'your-tenant-id', 'Machine')
[System.Environment]::SetEnvironmentVariable('GRAPH_CLIENT_ID', 'your-client-id', 'Machine')
[System.Environment]::SetEnvironmentVariable('GRAPH_CLIENT_SECRET', 'your-client-secret', 'Machine')
```

**Scheduled Task Command (Full Example):**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeCurated -ExportWorkbook -AppendWorkbook -OutputFileName "Weekly_Report.xlsx" -OutputPath "C:\Reports" -Auth Credential
```

**What Happens Each Week:**
- Week 1: Creates `Weekly_Report.xlsx` with initial D7 data
- Week 2: Appends new D7 data to existing worksheets (if columns match)
- Week 3+: Continues appending, creating timestamped duplicate tabs if schema changes

**Benefits:**
- **Automated Data Collection:** No manual intervention required
- **Time-Series Analysis:** Historical data accumulates in single file
- **Column Validation:** Prevents data corruption from schema changes
- **Timestamped Duplicates:** Schema changes create new tabs (e.g., `CopilotUsage-20251030-060015`)
- **Easy Sharing:** Single Excel file perfect for stakeholders
- **Trend Analysis:** Use Excel pivot tables or Power Query for historical trends
- **No File Merging:** Eliminates manual consolidation work

**Daily Schedule Alternative:**
For daily dashboard updates, change trigger to daily:
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeCurated -ExportWorkbook -AppendWorkbook -OutputFileName "Daily_Dashboard.xlsx" -OutputPath "C:\Reports" -Auth Credential
```

**Troubleshooting:**
- **Task fails silently:** Check Task Scheduler history and ensure environment variables are set at Machine level
- **Authentication errors:** Verify GRAPH_* environment variables and app registration permissions
- **File locked:** Ensure Excel file is not open during scheduled execution
- **Columns mismatch:** Review new timestamped tabs; Microsoft may have added/removed Graph API properties

</details>

<details>
<summary>M365 Service Usage Analysis</summary>

**Scenario:** Analyze Microsoft 365 application usage patterns

```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D90 -IncludeCurated -IncludeEntraUsers -CombineOutput
```

**Benefits:**
- Compare Teams vs Email vs SharePoint adoption
- Identify underutilized services
- Correlate usage with license assignments

</details>

<details>
<summary>Historical Trend Analysis</summary>

**Scenario:** Analyze long-term usage patterns for reporting

```powershell
# Get last 180 days of data for trend analysis
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D180 -CombineOutput
```

**Benefits:**
- Long-term trend analysis
- Quarterly reporting
- Historical baseline analysis

</details>

<details>
<summary>Power BI Dashboard Integration</summary>

**Scenario:** Create automated data pipeline for Power BI

```powershell
# Daily refresh: Last 7 days with consistent filename (customize switches as needed)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeCurated -IncludeEntraUsers -CombineOutput -OutputFileName "PowerBI_M365_Usage.csv"
```

**Benefits:**
- Scheduled Task integration
- Consistent filename for Power BI refresh
- Combined dataset for unified analysis

</details>

<details>
<summary>License Optimization</summary>

**Scenario:** Identify unused licenses and optimization opportunities

```powershell
# Get activation and usage data with license details
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D180 -IncludeCurated -IncludeEntraUsers -CombineOutput
```

**Benefits:**
- Compare license assignments vs actual usage
- Identify inactive users with active licenses
- Track Office activation counts

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Prerequisites

<details>
<summary>📋 View Prerequisites (Click to Expand)</summary>

| Requirement                | Details                           | Notes                                                        |
| -------------------------- | --------------------------------- | ------------------------------------------------------------ |
| **PowerShell**             | 5.1 or 7+                         | 7+ strongly recommended for parallel execution and UTF-8     |
| **Microsoft.Graph Module** | Latest version (2.0+)             | Script auto-installs if missing                              |
| **ImportExcel Module**     | Latest version (7.8+)             | **Only required for `-ExportWorkbook`** — Script auto-installs if missing |
| **Permissions**            | Global Reader or Reports Reader   | Or explicit API scopes: `Reports.Read.All`, `User.Read.All`, `Directory.Read.All` |
| **Permissions (Sign-In Data)** | Azure AD Premium P1/P2 + AuditLog.Read.All | **Only required for `-IncludeMACCopilotLicensing`** (lastSignInDateTime data) |
| **Network Access**         | Microsoft Graph API + PowerShell Gallery | Ensure firewall allows `graph.microsoft.com` and `powershellgallery.com` |
| **Execution Policy**       | Bypass or RemoteSigned            | See [Installation & Setup](#installation--setup)             |

**Note:** The script automatically handles Microsoft.Graph and ImportExcel module detection, installation, and connection. No manual setup required.

<details>
<summary>Permission Details</summary>

**Minimum RBAC Requirements:**

- **Global Reader** role (read-only, recommended for production)
- **Reports Reader** role (minimum for usage reports)
- Or explicit Graph API permissions:
  - `Reports.Read.All` - Read usage reports
  - `User.Read.All` - Read user profiles (for Entra enrichment)
  - `Directory.Read.All` - Read directory data (for manager expansion)

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

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Installation & Setup

<details>
<summary>💻 Show Quick Start Commands</summary>

### Step 1: Download Script

Download from GitHub Releases: [PAX_Graph_Audit_Log_Processor_v1.0.1.ps1](https://github.com/microsoft/PAX/releases/tag/graph-v1.0.1)

### Step 2: Run Script

```powershell
# Basic usage - last 7 days
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7
```

### Step 3: Authenticate

Script will open a browser window for authentication. Sign in with an account that has Reports Reader or Global Reader permissions.

### Step 4: View Output

CSV files will be saved to `C:\Temp\MS_Graph\` by default.

</details>

<details>
<summary>Advanced Setup</summary>

### Custom Output Location

```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -OutputPath "C:\Reports\M365"
```

### Device Code Authentication (Limited Browser)

```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -Auth DeviceCode
```

### Client Secret Authentication (Automation)

```powershell
# Set environment variables
$env:GRAPH_TENANT_ID = "your-tenant-id"
$env:GRAPH_CLIENT_ID = "your-client-id"  
$env:GRAPH_CLIENT_SECRET = "your-client-secret"

# Run with credential auth
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -Auth Credential
```

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Parameters Reference

<details>
<summary>📋 View All Parameters (Click to Expand)</summary>

### Query Parameters

#### `-Period <D7|D30|D90|D180|ALL>`
Pre-aggregated time periods for usage queries

**Valid Values:**
- `D7` - Last 7 days (default)
- `D30` - Last 30 days
- `D90` - Last 90 days
- `D180` - Last 180 days
- `ALL` - All available historical data

**Default:** `D7` (last 7 days)

**Examples:**
```powershell
# Use default D7 period
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1

# Specify 30-day period
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30

# Get all available historical data
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period ALL
```

---

### Output Parameters

#### `-OutputPath <string>`
Directory for output files (default: `C:\Temp\MS_Graph`)

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -OutputPath "C:\Reports"
```

---

### `-OutputFileName <string>`
Custom filename for combined output (requires `-CombineOutput`)

**Behavior:**
- Uses exact filename provided (no timestamp added)
- Automatically adds `.csv` extension if missing
- If omitted with `-CombineOutput`, auto-generates timestamped filename

**Examples:**
```powershell
# Custom filename
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -CombineOutput -OutputFileName "Weekly_Report.csv"

# Auto-generated timestamped filename
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -CombineOutput
```

---

### `-CombineOutput`
Merge all endpoint data into single CSV file

**Behavior:**
- Performs full outer join on `userPrincipalName`
- One row per unique user across all endpoints
- Null values for endpoints where user has no data

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -CombineOutput
```

</details>

<details>
<summary>Authentication Parameters</summary>

### `-Auth <WebLogin|DeviceCode|Credential|Silent>`
Authentication method (default: `WebLogin`)

**WebLogin** (Default)
- Interactive browser authentication
- Recommended for manual execution

**DeviceCode**
- Device code flow for limited browser environments
- Displays code to enter at microsoft.com/devicelogin

**Credential**
- Client secret authentication
- Requires environment variables:
  - ``
  - ``
  - ``

**Silent**
- Managed identity or existing token
- For Azure Automation or Azure Functions

**Examples:**
```powershell
# Device code flow
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -Auth DeviceCode

# Credential flow
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -Auth Credential
```

</details>

<details>
<summary>Processing Parameters</summary>

### `-IncludeCurated`
Include all 13 curated endpoints (automatically includes Copilot)

**Adds:**
- Copilot Usage
- Teams Activity
- Teams Device Usage
- Email Activity
- Email App Usage
- Mailbox Usage
- Office Activations
- Office Activations User Detail
- SharePoint Activity
- SharePoint Site Usage
- OneDrive Activity
- OneDrive Usage
- Yammer Activity

**Use When:**
- Need comprehensive M365 usage analysis
- Building executive dashboards
- License optimization projects

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeCurated
```

---

### `-IncludeEntraUsers`
Include Entra Users endpoint for user enrichment with 35 properties

**Adds:**
- Identity properties (displayName, mail, userPrincipalName)
- Job information (jobTitle, department, companyName)
- Location data (city, state, country, officeLocation)
- Manager hierarchy (4 manager properties)
- License assignments (35+ license SKUs)
- Service plans (enabled/disabled status)
- Email aliases (primary SMTP + all proxy addresses)

**Use When:**
- Need user context for usage data
- Building org hierarchy reports
- License optimization analysis
- Manager-based reporting

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeEntraUsers
```

---

### `-ExplodeArrays`
Expand array properties into separate columns

**Expands:**
- `assignedLicenses` → License SKU IDs
- `assignedPlans` → Service plan IDs
- `provisionedPlans` → Provisioned services
- `proxyAddresses` → Email aliases

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -ExplodeArrays
```

---

### `-PacingMs <0-10000>`
Delay between API requests in milliseconds (default: `0`)

**Use When:**
- Large tenants experiencing throttling
- Rate limiting for scheduled runs
- Recommended: 100-500ms for very large tenants

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -PacingMs 100
```

---

### Granular Include Parameters

#### `-IncludeCopilotUsage`
Include Copilot Usage endpoint (per-user Copilot feature usage across all Microsoft 365 apps)

**Use When:**
- Tracking Copilot adoption metrics
- Analyzing which Copilot features are being used
- Need detailed Copilot activity without all curated endpoints

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeCopilotUsage
```

---

#### `-IncludeM365AppUserDetail`
Include M365 App User Detail endpoint (app-specific usage per user)

**Use When:**
- Analyzing Teams vs Outlook vs Word usage patterns
- License optimization based on actual app usage
- User activity tracking across all Microsoft 365 apps

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeM365AppUserDetail
```

---

#### `-IncludeTeamsActivity`
Include Teams Activity endpoint (Teams-specific user activity)

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeTeamsActivity
```

---

#### `-IncludeOutlookActivity`
Include Outlook Activity endpoint (email-specific user activity)

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeOutlookActivity
```

---

#### `-IncludeSharePointActivity`
Include SharePoint Activity endpoint (SharePoint-specific user activity)

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeSharePointActivity
```

---

#### `-IncludeOneDriveActivity`
Include OneDrive Activity endpoint (OneDrive-specific user activity)

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeOneDriveActivity
```

---

#### `-IncludeMACCopilotLicensing`
Include MAC Copilot Licensing endpoint (per-user Copilot license assignments with sign-in activity)

**Returns:**
- All users with Copilot licenses assigned
- License SKU details and assignment status
- Sign-in activity (lastSignInDateTime)
- Three-tier Copilot license detection:
  - **Tier 1:** Known Copilot SKU IDs (20+ hardcoded SKUs)
  - **Tier 2:** Known M365 SKU IDs (pattern matching)
  - **Tier 3:** SKU name pattern matching ("Copilot" in name)

**Requirements:**
- Azure AD Premium P1 or P2 (for sign-in activity)
- AuditLog.Read.All permission (auto-requested if missing)

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeMACCopilotLicensing
```

**Use When:**
- Auditing Copilot license assignments
- Tracking license utilization by sign-in activity
- Identifying inactive licensed users

---

#### `-IncludeMACLicenseSummary`
Include MAC License Summary endpoint (tenant-wide Copilot license capacity and utilization)

**Returns:**
- All Copilot and M365 SKUs in tenant
- Purchased vs consumed license counts
- Available licenses remaining
- Utilization percentages
- Capacity planning metrics

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeMACLicenseSummary
```

**Use When:**
- License capacity planning
- Procurement and budget forecasting
- Compliance reporting (license compliance)

---

#### `-IncludeCustomEndpoints`
Specify a custom array of endpoint names to query

**Valid Endpoint Names:**
- `CopilotUsage`
- `M365AppUserDetail`
- `TeamsUserActivity`
- `EmailActivity`
- `SharePointActivity`
- `OneDriveActivity`
- `MACCopilotLicensing`
- `MACLicenseSummary`
- `EntraUsers`
- (Plus 6+ more curated endpoints)

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCustomEndpoints @('CopilotUsage', 'M365AppUserDetail', 'EntraUsers')
```

---

### Exclude Parameters

#### `-ExcludeEntraUsers`
Exclude Entra Users from the default curated set

**Use When:**
- Already have user data from another source
- Want faster execution (Entra Users can be large)
- Privacy requirements exclude user enrichment

**Conflict Resolution:**
- If `-IncludeEntraUsers` and `-ExcludeEntraUsers` both specified:
  - Without `-Force`: Prompts user to choose
  - With `-Force`: Include wins (exclude ignored)

**Example:**
```powershell
# Default curated set WITHOUT Entra Users
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -ExcludeEntraUsers
```

---

#### `-ExcludeMACCopilotLicensing`
Exclude MAC Copilot Licensing from the default curated set

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -ExcludeMACCopilotLicensing
```

---

#### `-ExcludeMACLicenseSummary`
Exclude MAC License Summary from the default curated set

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -ExcludeMACLicenseSummary
```

---

### Excel Workbook Export Parameters

#### `-ExportWorkbook`
Export data to Excel workbook (.xlsx) with multi-sheet layout instead of CSV files

**Key Features:**
- **Multi-Sheet Layout:** One worksheet per endpoint (no individual CSV files created)
- **Professional Formatting:** 
  - Frozen top row for scrollable headers
  - Auto-sized columns for readability
  - Bold header row
  - Prevents Excel auto-conversion (phone numbers, dates, etc. preserved as text)
- **Ordered Tabs:** Logical tab ordering (Entra Users → Licensing → Usage → Services)
- **ImportExcel Module:** Auto-installs if missing (PowerShell Gallery)

**Tab Ordering:**
1. EntraUsers
2. MACCopilotLicensing
3. MACLicenseSummary
4. CopilotUsage
5. M365AppUserDetail
6. TeamsUserActivity
7. EmailActivity
8. SharePointActivity
9. OneDriveActivity

**Requirements:**
- ImportExcel PowerShell module (auto-installs from PowerShell Gallery)
- Internet connectivity to PowerShell Gallery (first run only)

**Filename Behavior:**
- With `-OutputFileName`: Uses exact filename (adds `.xlsx` extension if missing)
- Without `-OutputFileName`: Auto-generates timestamped filename (e.g., `Graph_Usage_Export_20240315_143022.xlsx`)

**Examples:**
```powershell
# Basic Excel export
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -ExportWorkbook

# Custom filename
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -ExportWorkbook -OutputFileName "Copilot_Report.xlsx"

# Full curated set to Excel
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeCurated -ExportWorkbook -OutputPath "C:\Reports"
```

**Important Notes:**
- When `-ExportWorkbook` is specified, NO individual CSV files are created (Excel-only output)
- `-CombineOutput` is ignored when `-ExportWorkbook` is used (workbook already combines data)
- Each endpoint with data gets its own worksheet (empty endpoints are skipped)

---

#### `-AppendWorkbook`
Append data to an existing Excel workbook (requires `-ExportWorkbook`)

**How It Works:**
1. **Pre-Flight Validation:** Checks target workbook exists and is readable
2. **Column Validation:** Compares new data headers with existing worksheet headers
3. **Smart Appending:**
   - **Headers Match:** Appends rows to existing worksheet
   - **Headers Mismatch:** Creates timestamped duplicate worksheet (e.g., `CopilotUsage-20240315-143022`)
4. **Preserves Existing Data:** Never overwrites or deletes existing worksheets

**Conflict Handling:**
- Duplicate worksheets created when column structure changes
- Timestamp format: `WorksheetName-YYYYMMDD-HHMMSS`
- Prevents data loss from schema changes

**Requirements:**
- Target Excel file must exist (create with `-ExportWorkbook` first)
- Must specify `-ExportWorkbook` alongside `-AppendWorkbook`
- Target file must not be open in Excel (file lock check)

**Examples:**
```powershell
# Create initial workbook
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -ExportWorkbook -OutputFileName "Weekly_Report.xlsx"

# Append new week's data
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -ExportWorkbook -AppendWorkbook -OutputFileName "Weekly_Report.xlsx"

# Append with different endpoints (creates new tabs)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeMACLicenseSummary -ExportWorkbook -AppendWorkbook -OutputFileName "Weekly_Report.xlsx"
```

**Error Handling:**
- File doesn't exist: Error message with guidance to create workbook first
- File is open: Error with instruction to close Excel
- Column mismatch: Creates timestamped duplicate tab with warning
- Invalid Excel file: Error with file format validation message

---

#### `-Force`
Auto-resolve conflicts between `-Include*` and `-Exclude*` parameters without prompting

**Conflict Resolution Rules:**
- Include parameters take precedence over Exclude parameters
- Conflicts resolved silently (no user prompt)
- Endpoint is included (exclude is ignored)

**Example Conflicts:**
```powershell
# Without -Force: Prompts user to choose
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeEntraUsers -ExcludeEntraUsers

# With -Force: Auto-resolves (Entra Users INCLUDED, exclude ignored)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeEntraUsers -ExcludeEntraUsers -Force
```

**Use Cases:**
- Automated/unattended execution
- Scheduled tasks
- CI/CD pipelines
- Scripts where user interaction is not possible

---

### Utility Parameters

#### `-Help`
Display full help information

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Help
```

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Authentication Methods

<details>
<summary>WebLogin (Interactive Browser)</summary>

### Overview
Default authentication method using interactive browser-based OAuth flow.

### Requirements
- Web browser access
- Internet connectivity
- User with Reports.Read.All permissions

### Example
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30
# Browser window opens automatically for sign-in
```

### Use Cases
- Manual ad-hoc queries
- Interactive analysis sessions
- First-time setup and testing

</details>

<details>
<summary>DeviceCode (Limited Browser)</summary>

### Overview
Device code flow for environments with limited or no browser access.

### How It Works
1. Script displays a code and URL
2. User navigates to microsoft.com/devicelogin
3. Enter displayed code
4. Complete authentication in browser
5. Script continues automatically

### Example
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -Auth DeviceCode
# Follow displayed instructions to authenticate
```

### Use Cases
- Remote terminal sessions
- Jump boxes without GUI
- Restricted browser environments

</details>

<details>
<summary>Credential (Client Secret)</summary>

### Overview
Non-interactive authentication using Azure AD app registration with client secret.

### Prerequisites
1. Register app in Azure AD
2. Grant API permissions:
   - `Reports.Read.All`
   - `User.Read.All`
   - `Directory.Read.All`
3. Create client secret
4. Admin consent required

### Setup
```powershell
# Set environment variables
$env:GRAPH_TENANT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$env:GRAPH_CLIENT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$env:GRAPH_CLIENT_SECRET = "your~client~secret~value"
```

### Example
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -Auth Credential
```

### Use Cases
- Scheduled tasks / cron jobs
- Azure Automation runbooks
- CI/CD pipelines
- Unattended execution

</details>

<details>
<summary>Silent (Managed Identity)</summary>

### Overview
Uses existing authentication context (managed identity or cached token).

### Requirements
- Azure environment with managed identity
- Or existing `Connect-MgGraph` session

### Example
```powershell
# In Azure Automation with managed identity
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -Auth Silent
```

### Use Cases
- Azure Functions
- Azure Automation with system-assigned identity
- Pre-authenticated sessions

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Usage Examples

<details>
<summary>💻 Show Basic Examples</summary>

### Default (Last 7 Days)
```powershell
# Uses default D7 period
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1
```

### Last 30 Days with Combined Output
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -CombineOutput
```

### Last 90 Days
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D90
```

### Custom Output Location
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -OutputPath "C:\Reports\M365"
```

</details>

<details>
<summary>💻 Show Long-Term Analysis Examples</summary>

### Last 180 Days for Trend Analysis
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D180 -CombineOutput
```

### All Available Historical Data
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period ALL -CombineOutput -OutputFileName "Historical_Analysis.csv"
```

### Quarterly Review
```powershell
# 90-day period for Q1 review (default curated set already includes all essential endpoints)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D90 -CombineOutput -OutputFileName "Q1_Review.csv"
```

</details>

<details>
<summary>💻 Show Power BI Integration Examples</summary>

### Daily Scheduled Refresh (CSV)
```powershell
# Scheduled task: runs daily at 8 AM
# Always uses same filename for Power BI datasource
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -CombineOutput -OutputFileName "PowerBI_M365_Usage.csv" -OutputPath "C:\PowerBI\Data"
```

### Daily Scheduled Refresh (Excel)
```powershell
# Excel workbook for Power BI import
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -ExportWorkbook -OutputFileName "PowerBI_M365_Usage.xlsx" -OutputPath "C:\PowerBI\Data"
```

### Weekly Snapshot with Historical Data
```powershell
# Week 1: Create initial workbook (default curated set)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -ExportWorkbook -OutputFileName "Weekly_Snapshot.xlsx" -OutputPath "C:\PowerBI\Data"

# Week 2+: Append new data for trend analysis
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -ExportWorkbook -AppendWorkbook -OutputFileName "Weekly_Snapshot.xlsx" -OutputPath "C:\PowerBI\Data"
```

### Monthly Report
```powershell
# Scheduled task: runs 1st of month at 2 AM
# Get last 30 days of data
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -CombineOutput -OutputFileName "Monthly_Report.csv"
```

</details>

<details>
<summary>💻 Show Advanced Usage Examples</summary>

### Default Curated Set (9 Endpoints)
```powershell
# Comprehensive analysis: M365 App Usage, Teams, Email, SharePoint, OneDrive, Copilot Usage, MAC Licensing, Entra Users
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30
```

### Focused Analysis with Custom Endpoint Selection
```powershell
# Only Copilot Usage and Entra Users (replaces default curated set)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeCopilotUsage -IncludeEntraUsers -CombineOutput

# Only M365 App Usage (minimal, fastest execution)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeM365AppUserDetail

# Licensing focus only (no M365 app usage endpoints)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeCopilotUsage -IncludeMACCopilotLicensing -IncludeMACLicenseSummary -IncludeEntraUsers -ExportWorkbook
```

### Selective Removal from Default Curated Set
```powershell
# Default curated set minus Entra Users (faster if you don't need user enrichment)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -ExcludeEntraUsers

# Default curated set minus MAC licensing endpoints
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -ExcludeMACCopilotLicensing -ExcludeMACLicenseSummary
```

### Comprehensive M365 Analysis
```powershell
# All curated endpoints (includes Copilot) + Entra enrichment (CSV)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D90 -IncludeCurated -IncludeEntraUsers -CombineOutput

# Excel workbook with multi-sheet layout
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D90 -IncludeCurated -IncludeEntraUsers -ExportWorkbook
```

### Copilot License Management
```powershell
# Copilot usage + license assignments + capacity summary
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCopilotUsage -IncludeMACCopilotLicensing -IncludeMACLicenseSummary -IncludeEntraUsers -ExportWorkbook -OutputFileName "Copilot_Licenses.xlsx"
```

### Excel Workbook Export
```powershell
# Basic Excel export with default curated set
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -ExportWorkbook

# Custom filename
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -ExportWorkbook -OutputFileName "Monthly_Report.xlsx"

# Specific endpoints only
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeTeamsActivity -IncludeOutlookActivity -ExportWorkbook -OutputFileName "Teams_Email_Report.xlsx"
```

### Append to Existing Workbook
```powershell
# Create initial workbook (Week 1)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeCurated -ExportWorkbook -OutputFileName "Weekly_Trends.xlsx"

# Append Week 2 data
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeCurated -ExportWorkbook -AppendWorkbook -OutputFileName "Weekly_Trends.xlsx"

# Append Week 3 data
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeCurated -ExportWorkbook -AppendWorkbook -OutputFileName "Weekly_Trends.xlsx"
```

### Granular Endpoint Selection
```powershell
# Only specific endpoints
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCopilotUsage -IncludeTeamsActivity -IncludeOutlookActivity -CombineOutput

# Custom endpoint array
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCustomEndpoints @('CopilotUsage', 'M365AppUserDetail', 'EntraUsers') -ExportWorkbook
```

### Exclude Specific Endpoints
```powershell
# Default curated set WITHOUT Entra Users
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -ExcludeEntraUsers -ExportWorkbook

# Auto-resolve conflicts with -Force
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeEntraUsers -ExcludeEntraUsers -Force -ExportWorkbook
```

### Large Tenant with Throttling
```powershell
# Add 200ms delay between requests
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D90 -IncludeCurated -CombineOutput -PacingMs 200
```

### Array Explosion for License Details
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeEntraUsers -ExplodeArrays -CombineOutput
```

### Device Code Authentication
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeCurated -Auth DeviceCode -CombineOutput
```

### Automated Execution with Client Secret
```powershell
# Environment variables set separately or in script
$env:GRAPH_TENANT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$env:GRAPH_CLIENT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$env:GRAPH_CLIENT_SECRET = "your~client~secret"

.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -Auth Credential -CombineOutput -OutputFileName "Automated_Report.csv"
```

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Output Files & Schema

<details>
<summary>📁 Output File Structure</summary>

### Individual Endpoint Files
When `-CombineOutput` and `-ExportWorkbook` are **not** specified, the script generates one CSV file per endpoint:

**Filename Pattern:**
```
{ReportName}_{Period or DateRange}_{Timestamp}.csv
```

**Examples:**
- `CopilotUsage_D30_20251021_143052.csv`
- `EmailActivity_D7_20251021_143105.csv`
- `EntraUsers_D30_20251021_143120.csv`
- `MACCopilotLicensing_D30_20251021_143125.csv`

### Combined CSV Output
When `-CombineOutput` is specified (and `-ExportWorkbook` is NOT specified):

**Default Filename:**
```
Combined_M365_Usage_{Period or DateRange}_{Timestamp}.csv
```

**Custom Filename:**
```powershell
# With -OutputFileName parameter
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -CombineOutput -OutputFileName "My_Report.csv"
# Creates: My_Report.csv (no timestamp)
```

### Excel Workbook Output
When `-ExportWorkbook` is specified:

**Default Filename:**
```
Graph_Usage_Export_{Timestamp}.xlsx
```

**Custom Filename:**
```powershell
# With -OutputFileName parameter
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -ExportWorkbook -OutputFileName "Monthly_Report"
# Creates: Monthly_Report.xlsx (adds .xlsx extension automatically)
```

**Workbook Structure:**
- **Multi-Sheet Layout:** One worksheet per endpoint (no CSV files created)
- **Ordered Tabs:** Logical tab ordering for easy navigation
  1. EntraUsers (if included)
  2. MACCopilotLicensing (if included)
  3. MACLicenseSummary (if included)
  4. CopilotUsage (if included)
  5. M365AppUserDetail (if included)
  6. TeamsUserActivity (if included)
  7. EmailActivity (if included)
  8. SharePointActivity (if included)
  9. OneDriveActivity (if included)
  10. (Additional endpoints in alphabetical order)

**Professional Formatting:**
- ✅ Frozen top row (scrollable headers)
- ✅ Auto-sized columns for readability
- ✅ Bold header row
- ✅ Prevents Excel auto-conversion (phone numbers, dates preserved as text)
- ✅ No timestamp columns (cleaner data)

**Append Mode:**
- Use `-AppendWorkbook` to add data to existing workbook
- Column validation ensures data integrity
- Timestamped duplicate tabs created on schema changes (e.g., `CopilotUsage-20240315-143022`)

**Important Notes:**
- When `-ExportWorkbook` is used, NO CSV files are created (Excel-only output)
- `-CombineOutput` is ignored (workbook already combines data into multi-sheet layout)
- Empty endpoints are skipped (no empty worksheets created)

### Log Files
Every execution creates a timestamped log file:
```
MS_Graph_Export_Log_{Timestamp}.txt
```

**Location:** Same as `-OutputPath` (default: `C:\Temp\MS_Graph\`)

</details>

<details>
<summary>📊 CSV Schema Overview</summary>

### Common Columns (All Reports)
- `reportRefreshDate` - Date when report data was last refreshed
- `userPrincipalName` - User's UPN (join key for combined output)
- `reportPeriod` - Time period covered (D7, D30, D90, D180, ALL, or date range)

### Entra User Enrichment Columns (35 Properties)
When `-IncludeEntraUsers` is specified, these columns are added to all reports:

**Identity:**
- `id` - Entra object ID
- `userPrincipalName` - User's UPN
- `mail` - Primary email address
- `proxyAddresses` - All email aliases (array)

**Job Information:**
- `displayName` - User's display name
- `givenName` - First name
- `surname` - Last name
- `jobTitle` - Job title
- `department` - Department
- `companyName` - Company name
- `employeeId` - Employee ID
- `employeeType` - Employee type

**Location:**
- `officeLocation` - Office location
- `city` - City
- `state` - State/province
- `country` - Country
- `usageLocation` - Usage location (for licensing)

**Contact:**
- `mobilePhone` - Mobile phone
- `businessPhones` - Business phones (array)

**Organization:**
- `manager.id` - Manager's object ID
- `manager.userPrincipalName` - Manager's UPN
- `manager.displayName` - Manager's display name
- `manager.mail` - Manager's email

**Account Status:**
- `accountEnabled` - Account enabled status
- `createdDateTime` - Account creation date
- `signInActivity.lastSignInDateTime` - Last interactive sign-in
- `signInActivity.lastNonInteractiveSignInDateTime` - Last non-interactive sign-in

**Licensing:**
- `assignedLicenses` - Assigned licenses (array of SKU IDs)
- `assignedPlans` - Assigned service plans (array)
- `provisionedPlans` - Provisioned plans with status (array)
- `licenseAssignmentStates` - License assignment details (array)

### Report-Specific Columns
Each endpoint has unique metrics. See [Endpoint Reference](#endpoint-reference) for details.

</details>

<details>
<summary>🔗 Combined Output Schema</summary>

### Join Logic
- **Join Key:** `userPrincipalName`
- **Join Type:** Full outer join (all users from all endpoints)
- **Null Handling:** Users with no data for an endpoint show null/empty values

### Column Organization
1. **Report Period** (position 2 for visibility)
2. **Entra User Properties** (35 columns)
3. **Copilot Usage Metrics**
4. **M365 App Usage Metrics** (Teams, Email, SharePoint, OneDrive, etc.)

### Example Row
```
userPrincipalName,reportPeriod,displayName,department,...,copilotUsed,teamsActivity,emailActivity,...
user@contoso.com,D30,John Doe,Sales,...,1,25,150,...
```

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Data Obfuscation Warning

<details>
<summary>⚠️ Privacy Settings Impact</summary>

### What It Is
Microsoft 365 includes privacy settings that **obfuscate user-identifiable data** in usage reports. When enabled, all user identifiers (User Principal Name, Display Name) appear as **32-character hexadecimal hashes** instead of readable names.

### Detection
The script automatically detects obfuscation by checking for hash patterns (MD5 format) in user identifier fields. When detected, it displays:

```
⚠️ OBFUSCATION WARNING:

If Microsoft 365 privacy settings are enabled, Graph API returns HASHED identifiers:
  • User Principal Name: "1609C1ECD4107D22F41A96C5962177E4" (hash, not real UPN)
  • Display Name: "D0CCB9B1B62CF505896366C1FF86F71B" (hash, not real name)

This makes data UNUSABLE for joining with Entra user attributes or performing
meaningful Copilot usage analysis in conjunction with M365 app usage data.

SOLUTION - Disable Obfuscation Setting:

1. Navigate to Microsoft 365 Admin Center
2. Go to Settings → Org Settings → Reports
3. UNCHECK: ☐ "Display concealed user, group, and site names in all reports"
4. Click Save and wait a few minutes for setting to take effect
5. Re-run this script

Direct Link: https://admin.microsoft.com/#/Settings/Services/:/Settings/L1/Reports

NOTE: When CHECKED, the box shows HASHED data. When UNCHECKED, it shows real identifiers.
```

### Impact
**When obfuscation is enabled:**
- ❌ User identifiers replaced with anonymous hashes
- ❌ Cannot identify specific users in usage data
- ❌ Cannot correlate usage across reports by user
- ❌ Cannot track individual adoption or power users
- ✅ Usage metrics themselves remain accurate (activity counts, dates)
- ✅ Entra user properties still available (department, manager, licenses, etc.)
- ✅ Tenant-level aggregated reports may still work

### Remediation
**Global Admin must disable obfuscation in Microsoft 365 Admin Center:**

1. Navigate to **Settings** → **Org Settings** → **Services** → **Reports**
2. **Uncheck:** *Display concealed user, group, and site names in all reports*
3. Click **Save changes**
4. **Wait 24-48 hours** for setting to propagate

**Alternative (PowerShell):**
```powershell
Connect-MgGraph -Scopes "OrgSettings-Microsoft365Install.ReadWrite.All"
Update-MgAdminReportSetting -DisplayConcealedNames:$false
```

### Verification
After disabling obfuscation, re-run the script to verify data appears:
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7
# Check CSV output for non-null values in usage columns
```

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Endpoint Reference

<details>
<summary>🔗 17 Microsoft Graph API Endpoints</summary>

### Copilot Usage (1 Endpoint)

#### 1. **Copilot Usage** (`getM365Copilot`)
```
GET /reports/microsoft.graph.getM365AppUserDetail(period='{period}')
```

**Metrics:**
- Overall Copilot usage flag
- Word Copilot usage
- Excel Copilot usage
- PowerPoint Copilot usage
- Outlook Copilot usage
- Teams Copilot usage
- OneNote Copilot usage

**Query Support:** Period-based queries only (D7, D30, D90, D180, ALL)

---

### M365 App Usage (13 Endpoints)

#### 2. **M365 Activations** (`M365Activations`)
```
GET /reports/microsoft.graph.getOffice365ActivationsUserDetail
```

**Metrics:**
- Office activation counts per user (snapshot, no period parameter)
- Windows, Mac, iOS, Android, Windows 10 Mobile activations
- Activated product details
- Product SKUs assigned

**Note:** Snapshot endpoint - does not accept period parameter

#### 3. **M365 Active Users** (`M365ActiveUsers`)
```
GET /reports/microsoft.graph.getOffice365ActiveUserDetail(period='{period}')
```

**Metrics:**
- Active users across all M365 services
- Exchange, OneDrive, SharePoint, Teams, Yammer activity flags
- Last activity date per service
- License assignment information

#### 4. **M365 App User Detail** (`M365AppUserDetail`)
```
GET /reports/microsoft.graph.getM365AppUserDetail(period='{period}')
```

**Metrics:**
- Per-user usage across all M365 applications
- Word, Excel, PowerPoint, Outlook, Teams, OneNote, Yammer
- Last activity dates per app
- Platform-specific usage (Windows, Mac, Web, Mobile)

#### 5. **Teams Activity** (`getTeamsUserActivity`)
```
GET /reports/microsoft.graph.getTeamsUserActivityUserDetail(period='{period}')
```

**Metrics:**
- Team chat messages
- Private chat messages
- Calls
- Meetings organized/participated
- Last activity date

#### 6. **Teams Device Usage** (`getTeamsDeviceUsage`)
```
GET /reports/microsoft.graph.getTeamsDeviceUsageUserDetail(period='{period}')
```

**Metrics:**
- Windows client usage
- Mac client usage
- iOS usage
- Android usage
- Web client usage
- Last activity date per platform

#### 7. **Email Activity** (`getEmailActivity`)
```
GET /reports/microsoft.graph.getEmailActivityUserDetail(period='{period}')
```

**Metrics:**
- Send count
- Receive count
- Read count
- Meeting created/accepted count

#### 8. **Email App Usage** (`getEmailAppUsage`)
```
GET /reports/microsoft.graph.getEmailAppUsageUserDetail(period='{period}')
```

**Metrics:**
- Outlook desktop usage
- Outlook web usage
- Outlook mobile usage
- IMAP/POP/SMTP usage
- Last activity date per app

#### 9. **Mailbox Usage** (`getMailboxUsage`)
```
GET /reports/microsoft.graph.getMailboxUsageDetail(period='{period}')
```

**Metrics:**
- Storage used (bytes)
- Item count
- Deleted item count
- Issue warning quota
- Prohibit send quota
- Has archive

#### 10. **Office Activations** (`getOfficeActivations`)
```
GET /reports/microsoft.graph.getOfficeUserDetail(period='{period}')
```

**Metrics:**
- Windows activation count
- Mac activation count
- Windows 10 Mobile activation count
- iOS activation count
- Android activation count
- Activated products list

#### 11. **OneDrive Activity** (`getOneDriveActivity`)
```
GET /reports/microsoft.graph.getOneDriveActivityUserDetail(period='{period}')
```

**Metrics:**
- Files viewed/edited
- Files synced
- Files shared internally/externally
- Last activity date

#### 12. **OneDrive Usage** (`getOneDriveUsage`)
```
GET /reports/microsoft.graph.getOneDriveUsageAccountDetail(period='{period}')
```

**Metrics:**
- Storage used (bytes)
- Storage allocated (bytes)
- File count
- Active file count
- Last activity date

#### 13. **SharePoint Activity** (`getSharePointActivity`)
```
GET /reports/microsoft.graph.getSharePointActivityUserDetail(period='{period}')
```

**Metrics:**
- Files viewed/edited
- Files synced
- Files shared internally/externally
- Pages visited
- Last activity date

#### 14. **SharePoint Site Usage** (`getSharePointSiteUsage`)
```
GET /reports/microsoft.graph.getSharePointSiteUsageDetail(period='{period}')
```

**Metrics:**
- Storage used (bytes)
- Storage allocated (bytes)
- File count
- Active file count
- Page view count

#### 15. **Yammer Activity** (`getYammerActivity`)
```
GET /reports/microsoft.graph.getYammerActivityUserDetail(period='{period}')
```

**Metrics:**
- Messages posted
- Messages read
- Messages liked
- Last activity date

#### 16. **Yammer Device Usage** (`getYammerDeviceUsage`)
```
GET /reports/microsoft.graph.getYammerDeviceUsageUserDetail(period='{period}')
```

**Metrics:**
- Web usage
- Windows phone usage
- Android phone usage
- iPhone usage
- iPad usage

---

### Entra ID (1 Endpoint)

#### 17. **Entra Users** (`EntraUsers`)
```
GET /users?$select={35 properties}&$expand=manager
```

**Properties:** See [CSV Schema Overview](#csv-schema-overview) for complete list.

**Special Handling:**
- Filters: `UserType eq 'Member'` (excludes guests)
- Filters: `accountEnabled eq true`
- Excludes: Rooms, resources (`ResourceType` property)
- Expands: Manager relationship (4 additional properties)

---

### Microsoft Copilot License Management (2 Endpoints)

#### 16. **MAC Copilot Licensing** (`MACCopilotLicensing`)
```
GET /users?$select=userPrincipalName,displayName,assignedLicenses&$expand=manager
```

**Metrics:**
- Per-user Copilot license assignments
- SKU name, ID, and friendly name
- Service plan details
- Enabled/disabled service plans
- Last sign-in activity timestamp
- Manager information (displayName, userPrincipalName, mail, id)

**Special Features:**
- **Three-Tier SKU Detection:**
  1. Known Copilot SKU IDs (hardcoded list)
  2. M365/Office 365 base SKU detection
  3. Pattern matching for SKU names containing "Copilot"
- Filters out users without Copilot licenses
- Includes sign-in activity data (requires Azure AD Premium P1/P2)

#### 17. **MAC License Summary** (`MACLicenseSummary`)
```
GET /subscribedSkus
```

**Metrics:**
- Tenant-wide license capacity
- Consumed vs. available licenses
- Utilization percentage
- SKU names and IDs
- All Copilot SKUs detected
- All M365/Office 365 SKUs
- Enabled/disabled status
- Applies-to information (User, Company)

**Special Features:**
- Comprehensive license capacity planning
- Identifies all Copilot-related SKUs in tenant
- Shows M365/Office 365 base licenses
- Utilization tracking for procurement decisions

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Advanced Features

<details>
<summary>Excel Workbook Export with Multi-Sheet Layout</summary>

### Overview
Export all endpoint data to a professional Excel workbook with automatic formatting, intelligent tab ordering, and append capabilities.

### Key Features

**Multi-Sheet Layout:**
- One worksheet per endpoint (no individual CSV files created)
- Empty endpoints automatically skipped (no empty worksheets)
- Logical tab ordering for easy navigation

**Professional Formatting:**
- ✅ **Frozen Top Row:** Scrollable headers for large datasets
- ✅ **Auto-Sized Columns:** Optimal column width based on content
- ✅ **Bold Header Row:** Clear visual separation
- ✅ **No Auto-Conversion:** Phone numbers, dates, and numeric strings preserved as text (prevents Excel corruption)

**Tab Ordering:**
1. **EntraUsers** (user identity and enrichment data)
2. **MACCopilotLicensing** (per-user Copilot license assignments)
3. **MACLicenseSummary** (tenant-wide license capacity)
4. **CopilotUsage** (per-user Copilot feature usage)
5. **M365AppUserDetail** (app-specific usage per user)
6. **TeamsUserActivity** (Teams-specific activity)
7. **EmailActivity** (Outlook/Exchange activity)
8. **SharePointActivity** (SharePoint activity)
9. **OneDriveActivity** (OneDrive activity)
10. Additional endpoints in alphabetical order

### ImportExcel Module
**Automatic Installation:**
- Script auto-detects if ImportExcel module is missing
- Installs from PowerShell Gallery (requires internet connectivity)
- One-time installation per machine
- No manual setup required

**Module Requirements:**
- ImportExcel PowerShell module v7.8.0 or later
- Internet connectivity to PowerShell Gallery (first run only)
- PowerShell 5.1 or later

### Usage Examples

**Basic Excel Export:**
```powershell
# Export default curated set to Excel
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -ExportWorkbook

# Custom filename
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -ExportWorkbook -OutputFileName "Monthly_Report.xlsx"

# Custom output path
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -ExportWorkbook -OutputPath "C:\Reports"
```

**Specific Endpoints:**
```powershell
# Copilot usage + user enrichment only
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeCopilotUsage -IncludeEntraUsers -ExportWorkbook

# Complete licensing analysis
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCopilotUsage -IncludeMACCopilotLicensing -IncludeMACLicenseSummary -IncludeEntraUsers -ExportWorkbook -OutputFileName "Copilot_Licenses.xlsx"

# Teams and Email only
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeTeamsActivity -IncludeOutlookActivity -ExportWorkbook
```

**Full Curated Set:**
```powershell
# All curated endpoints in Excel
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D90 -ExportWorkbook
```

### Append Mode

**Overview:**
Add new data to existing Excel workbooks while preserving all existing worksheets and data.

**How It Works:**
1. **Pre-Flight Validation:**
   - Checks target workbook exists and is not open
   - Validates file is a valid Excel workbook
   - Lists existing worksheets for reference

2. **Column Validation:**
   - Compares new data headers with existing worksheet headers
   - Ensures data integrity before appending

3. **Smart Appending:**
   - **Headers Match:** Appends rows to existing worksheet
   - **Headers Mismatch:** Creates timestamped duplicate worksheet (preserves existing data)

**Column Mismatch Handling:**
- If column headers don't match: Creates new worksheet with timestamp suffix
- Format: `WorksheetName-YYYYMMDD-HHMMSS` (e.g., `CopilotUsage-20240315-143022`)
- Prevents data corruption from schema changes
- Original worksheet remains untouched

**Usage Examples:**
```powershell
# Week 1: Create initial workbook
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -ExportWorkbook -OutputFileName "Weekly_Report.xlsx"

# Week 2: Append new data
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -ExportWorkbook -AppendWorkbook -OutputFileName "Weekly_Report.xlsx"

# Week 3: Continue appending
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -ExportWorkbook -AppendWorkbook -OutputFileName "Weekly_Report.xlsx"
```

**Advanced Append Scenarios:**
```powershell
# Add new endpoint to existing workbook
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeMACLicenseSummary -ExportWorkbook -AppendWorkbook -OutputFileName "Existing_Report.xlsx"

# Update specific endpoint only
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeCopilotUsage -ExportWorkbook -AppendWorkbook -OutputFileName "Report.xlsx"
```

**Error Handling:**
- **File doesn't exist:** Error with guidance to create workbook first (remove `-AppendWorkbook`)
- **File is open:** Error with instruction to close Excel
- **Column mismatch:** Creates timestamped duplicate tab with warning message
- **Invalid Excel file:** Error with file format validation message

### Important Notes

**Excel-Only Output:**
- When `-ExportWorkbook` is specified, NO CSV files are created
- All data exported to single Excel workbook only
- Use CSV export if you need individual files

**CombineOutput Ignored:**
- `-CombineOutput` parameter is ignored when using `-ExportWorkbook`
- Excel workbook already combines data (multi-sheet layout)
- No need to specify both parameters

**File Lock Check:**
- Script validates workbook is not open in Excel before appending
- Close Excel before running with `-AppendWorkbook`

**Schema Change Detection:**
- Automatically detects when column headers change
- Creates timestamped duplicate worksheets to preserve data integrity
- No manual intervention required

### Benefits Over CSV Export

**Executive Sharing:**
- Single file easier to share than multiple CSVs
- Professional formatting improves readability
- Familiar Excel interface for non-technical stakeholders

**Time-Series Analysis:**
- Append mode builds historical data in one file
- Easy trend analysis with Excel pivot tables, Power BI, or Power Query
- No manual file merging required

**Data Integrity:**
- Column validation prevents accidental data corruption
- Timestamped duplicates preserve data on schema changes
- No overwrites or data loss

**Professional Presentation:**
- Frozen headers for large datasets
- Auto-sized columns for optimal readability
- Bold headers for clear visual separation
- Prevents Excel auto-conversion of phone numbers and dates

</details>

<details>
<summary>MAC Copilot Licensing & License Summary Endpoints</summary>

### MACCopilotLicensing Endpoint
**Overview:**
Retrieves per-user Copilot license assignments with sign-in activity data.

**What It Returns:**
- All users with Copilot licenses assigned
- License SKU details (name, SKU ID)
- License assignment status
- Sign-in activity timestamps (lastSignInDateTime, lastNonInteractiveSignInDateTime)
- Three-tier Copilot license detection

**Requirements:**
- **Azure AD Premium P1 or P2:** Required for sign-in activity data
- **AuditLog.Read.All Permission:** Auto-requested if missing (requires admin consent)

**Three-Tier Copilot License Detection:**
1. **Tier 1:** Known Copilot SKU IDs (20+ hardcoded SKUs)
2. **Tier 2:** Known M365 SKU IDs (pattern matching for M365/Office 365)
3. **Tier 3:** SKU name pattern matching ("Copilot" in name)

**Usage Examples:**
```powershell
# Copilot license assignments only
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeMACCopilotLicensing

# With user enrichment for context
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeMACCopilotLicensing -IncludeEntraUsers -ExportWorkbook

# Complete licensing analysis (usage + assignments + capacity)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCopilotUsage -IncludeMACCopilotLicensing -IncludeMACLicenseSummary -IncludeEntraUsers -ExportWorkbook
```

**Use Cases:**
- Audit Copilot license assignments
- Identify inactive licensed users (no recent sign-in)
- License reclamation projects
- Compliance reporting

### MACLicenseSummary Endpoint
**Overview:**
Retrieves tenant-wide Copilot and M365 license capacity and utilization metrics.

**What It Returns:**
- All Copilot and M365 SKUs in tenant
- Purchased license count
- Consumed (assigned) license count
- Available licenses remaining
- Utilization percentage
- Capacity planning metrics

**Three-Tier SKU Detection:**
1. **Tier 1:** Known Copilot SKU IDs (7 explicit Copilot SKUs)
2. **Tier 2:** Known M365/Office 365 SKU IDs (20+ explicit M365/O365 SKUs)
3. **Tier 3:** Pattern matching fallback (regex for M365/O365 in SKU name)

**Usage Examples:**
```powershell
# License capacity summary only
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeMACLicenseSummary

# With detailed licensing analysis
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeMACCopilotLicensing -IncludeMACLicenseSummary -ExportWorkbook
```

**Use Cases:**
- License capacity planning
- Procurement and budget forecasting
- Utilization reporting for executive leadership
- Compliance reporting (license compliance tracking)

### Permission Handling
**AuditLog.Read.All Permission:**
- Required for `lastSignInDateTime` data in MACCopilotLicensing
- Script auto-requests permission if missing
- User prompted to continue without sign-in data or exit to re-authenticate
- Admin consent required for tenant-wide access

**Fallback Behavior:**
- If permission denied: Script continues without sign-in activity columns
- Sign-in columns show null values
- All other license data still available

</details>

<details>
<summary>Granular Endpoint Selection</summary>

### Overview
Granular parameter controls allow selecting specific endpoints without requiring the full curated set.

### Include Parameters
- `-IncludeCopilotUsage` - Copilot feature usage per user
- `-IncludeM365AppUserDetail` - M365 app usage per user
- `-IncludeTeamsActivity` - Teams-specific activity
- `-IncludeOutlookActivity` - Email-specific activity
- `-IncludeSharePointActivity` - SharePoint-specific activity
- `-IncludeOneDriveActivity` - OneDrive-specific activity
- `-IncludeMACCopilotLicensing` - Per-user Copilot license assignments
- `-IncludeMACLicenseSummary` - Tenant-wide license capacity

### Exclude Parameters
- `-ExcludeEntraUsers` - Exclude Entra Users from default curated set
- `-ExcludeMACCopilotLicensing` - Exclude MAC Copilot Licensing from curated set
- `-ExcludeMACLicenseSummary` - Exclude MAC License Summary from curated set

### Usage Examples

**Specific Services Only:**
```powershell
# Teams and Email only
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -IncludeTeamsActivity -IncludeOutlookActivity

# Copilot and user enrichment only
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeCopilotUsage -IncludeEntraUsers -ExportWorkbook
```

**License Analysis Only:**
```powershell
# Per-user license assignments
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeMACCopilotLicensing

# Tenant-wide capacity
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeMACLicenseSummary

# Complete licensing picture
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeMACCopilotLicensing -IncludeMACLicenseSummary -ExportWorkbook
```

**Exclude from Curated Set:**
```powershell
# Curated set WITHOUT user enrichment
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -ExcludeEntraUsers

# Curated set WITHOUT licensing endpoints
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -ExcludeMACCopilotLicensing -ExcludeMACLicenseSummary
```

### Conflict Resolution with -Force Parameter
**Problem:** What happens if both Include and Exclude are specified for the same endpoint?

**Without -Force:**
- Script prompts user to choose: Include or Exclude
- Interactive decision required
- Not suitable for automation

**With -Force:**
- Include parameter takes precedence
- Exclude is ignored for conflicting endpoints
- No user prompt (auto-resolved)
- Suitable for scheduled tasks and automation

**Example:**
```powershell
# Without -Force: User prompted to choose
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeEntraUsers -ExcludeEntraUsers

# With -Force: Entra Users INCLUDED (exclude ignored)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeEntraUsers -ExcludeEntraUsers -Force
```

</details>

<details>
<summary>Automatic Module Management</summary>

### Microsoft.Graph SDK Installation
The script automatically detects and installs the Microsoft.Graph PowerShell SDK if not present.

**Installation Process:**
1. Checks for existing module
2. If missing, prompts user for installation
3. Installs from PowerShellGallery
4. Imports required sub-modules

**Manual Installation:**
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

</details>

<details>
<summary>Query Period Handling</summary>

### Period-Based Queries
The script uses period-based aggregated queries for all endpoints.

**Behavior:**
- Default: Last 7 days (D7)
- `-Period D7`: Last 7 days
- `-Period D30`: Last 30 days
- `-Period D90`: Last 90 days
- `-Period D180`: Last 180 days
- `-Period ALL`: All available historical data

### Why Period-Based Only?
Microsoft Graph UserDetail report endpoints only support period-based aggregation. This is a Graph API limitation, not a script limitation. Period queries provide:
- Server-side aggregated data (faster performance)
- Consistent data across all endpoints
- No daily query iteration overhead

</details>

<details>
<summary>Retry Logic & Error Handling</summary>

### Automatic Retry on Throttling
**HTTP 429 (Too Many Requests):**
- Automatic exponential backoff
- Retries up to 5 times
- Respects `Retry-After` header

**HTTP 503 (Service Unavailable):**
- Automatic retry with delay
- Handles transient Microsoft Graph API issues

### Pagination Handling
Automatically follows `@odata.nextLink` for large result sets:
```
  Pagination detected, retrieving all pages...
  Retrieved 500 total records...
  Retrieved 1000 total records...
  Retrieved 1500 total records...
  ✓ Retrieved 1823 total rows (paginated)
```

### Error Isolation
If one endpoint fails, script continues with remaining endpoints:
```
  ✓ Retrieved 150 rows
  ✗ Authorization failed: Insufficient privileges to complete the operation
  ✓ Retrieved 230 rows
```

</details>

<details>
<summary>Performance Optimization</summary>

### Parallel Endpoint Queries
All selected endpoints are queried **concurrently** using PowerShell jobs for maximum throughput.

**Typical Execution Time:**
- Default (M365 App Usage only): 10-20 seconds
- With -IncludeCopilotUsage: 15-30 seconds
- With -IncludeCurated: 30-60 seconds (small tenant)
- With -IncludeCurated: 2-5 minutes (large tenant)
- Medium tenant (500-5,000 users): 1-3 minutes
- Large tenant (5,000-50,000 users): 3-8 minutes

### Efficient Data Processing
- Stream processing for CSV export (low memory footprint)
- Selective property expansion (only requested properties)
- Optimized join algorithm for combined output

</details>

<details>
<summary>Column Reordering</summary>

### Report Period Visibility
The `reportPeriod` column is automatically moved to **position 2** (after `userPrincipalName`) for better visibility in Excel and Power BI.

**Default API Order:**
```
userPrincipalName,displayName,reportRefreshDate,...,reportPeriod
```

**Script Output Order:**
```
userPrincipalName,reportPeriod,displayName,reportRefreshDate,...
```

</details>

<details>
<summary>Three-Tier SKU Detection System</summary>

### License Tracking
The MAC License Summary endpoint uses a comprehensive three-tier SKU detection system that ensures accurate tracking of both Microsoft 365 Copilot and M365/Office 365 licenses.

### Detection Tiers

**Tier 1: Known Copilot SKU IDs**
- 7 explicitly tracked Microsoft 365 Copilot SKU GUIDs
- Includes all current Copilot license variants
- Highest priority detection method

**Tier 2: Known M365/Office 365 SKU IDs**
- 20+ explicitly tracked Microsoft 365 and Office 365 SKU GUIDs
- Covers Business, Enterprise, and Frontline license types
- Includes:
  - Microsoft 365 Business Basic, Standard, and Premium
  - Microsoft 365 E1, E3, E4, E5 (with and without Audio Conferencing)
  - Microsoft 365 F1, F3, F5
  - Office 365 E1, E3, E4, E5
  - Office 365 Business, Business Premium, Business Essentials

**Tier 3: Pattern Matching Fallback**
- Regex pattern matching for SKU names containing:
  - `Microsoft_365`
  - `Office_365`
  - `M365`
  - `O365`
- Case-insensitive matching
- Catches any M365/O365 SKUs not in Tier 2

### Why This Matters

The three-tier detection system provides:
- Explicit tracking of 20+ M365/Office 365 SKUs
- Comprehensive coverage through multiple detection methods
- Support for M365-only scenarios (zero Copilot licenses)
- Clear user messaging about both license types tracked

### User Messaging

The script clearly communicates that MAC License Summary tracks **both** license types:

```
Processing MAC License Summary endpoint (Copilot + M365/O365 SKUs)
```

When no data is returned, users receive detailed guidance:

```
  ℹ️  LICENSE SUMMARY: No SKUs found
     This endpoint reports on both Copilot and M365/Office 365 licenses.

     This is normal if:
       • No Copilot licenses purchased in this tenant
       • No Microsoft 365 or Office 365 licenses purchased
       • Tenant only has other license types (Azure, Dynamics, etc.)

     ℹ️  What this endpoint tracks:
       • All Microsoft 365 Copilot SKUs
       • All Microsoft 365 Business/Enterprise/Frontline SKUs
       • All Office 365 Business/Enterprise SKUs

     📊 Each license shows: capacity, consumed, available, utilization %
```

### Implementation Details

**Script Variables:**
- `$script:CopilotSkuIds` - Hashtable of known Copilot SKU IDs
- `$script:M365SkuIds` - Hashtable of known M365/Office 365 SKU IDs (NEW)

**Function:** `ConvertTo-FlatMACLicenseSummary`
- Implements three-tier detection logic
- Returns unified license summary with comprehensive coverage

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Performance Tuning

<details>
<summary>⚡ Optimization Strategies</summary>

### For Large Tenants (10,000+ users)

#### 1. Use Appropriate Period for Your Needs
```powershell
# Short-term analysis (fastest)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7

# Medium-term analysis
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30

# Long-term trends
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D90
```

#### 2. Add Pacing to Avoid Throttling
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D90 -IncludeCurated -PacingMs 200
```

#### 3. Minimize Endpoints for Faster Execution
```powershell
# Default (M365 App Usage only) is fastest
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30

# Add only what you need
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeCopilotUsage  # +1 endpoint
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeEntraUsers  # +user enrichment
```

#### 4. Use Client Secret Authentication
```powershell
# Faster than interactive login (no browser overhead)
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -Auth Credential
```

### For Scheduled Execution

#### Daily Refresh (Power BI)
```powershell
# Fastest: D7 period with fixed filename
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -CombineOutput -OutputFileName "Daily_Refresh.csv" -Auth Credential
```

#### Weekly Summary
```powershell
# Balanced: D30 period for trend analysis
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -CombineOutput -OutputFileName "Weekly_Summary.csv" -Auth Credential
```

### For Historical Analysis

#### Use Longer Periods for Trends
```powershell
# 6-month trend analysis
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D180 -CombineOutput -OutputFileName "Historical_Trends.csv"

# All available data
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period ALL -CombineOutput -OutputFileName "Complete_History.csv"
```

</details>

<details>
<summary>⏱️ Throttling Prevention</summary>

### Understanding Microsoft Graph Throttling
Microsoft Graph API enforces rate limits:
- **User-level limits:** 2,000 requests per 10 seconds
- **Tenant-level limits:** 130,000 requests per 10 seconds

### When to Use `-PacingMs`
**Symptoms of throttling:**
- `HTTP 429 Too Many Requests` errors
- Slow performance with many retries
- Execution time significantly longer than expected

**Recommended values:**
- Small tenant (< 1,000 users): `0` (no pacing)
- Medium tenant (1,000-10,000 users): `100`
- Large tenant (10,000-50,000 users): `200-300`
- Very large tenant (50,000+ users): `500`

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D90 -PacingMs 250
```

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Troubleshooting & FAQ

<details>
<summary>🔧 Common Issues & Solutions</summary>

### Issue: "All usage data is null/empty"
**Cause:** Data obfuscation is enabled in tenant settings.

**Solution:** See [Data Obfuscation Warning](#data-obfuscation-warning) section for remediation steps.

---

### Issue: "Permission denied" or "403 Forbidden"
**Cause:** Authenticated user lacks required Graph API permissions.

**Solution:**
1. Ensure user has **Reports Reader** or **Global Reader** role
2. Or grant explicit API permissions:
   - `Reports.Read.All`
   - `User.Read.All`
   - `Directory.Read.All`

---

### Issue: "HTTP 429 Too Many Requests"
**Cause:** Tenant is being throttled due to high API usage.

**Solution:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -PacingMs 200
```

---

### Issue: "Module Microsoft.Graph not found"
**Cause:** Microsoft.Graph PowerShell SDK not installed.

**Solution:**
Script should auto-install. If not:
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

---

### Issue: "Execution takes very long (10+ minutes)"
**Cause:** Large tenant or slow network, or querying too many endpoints.

**Solutions:**
1. Use shorter periods (e.g., D7 instead of D180) for faster queries
2. Add `-PacingMs 0` to remove artificial delays
3. Reduce endpoints: Use default (M365 App Usage only) for fastest execution
4. Check network latency to `graph.microsoft.com`

</details>

<details>
<summary>❓ Frequently Asked Questions</summary>

### Q: What time period should I use?
**A:** Depends on your needs:
- **D7**: Weekly reports, quick snapshots
- **D30**: Monthly reports, trend analysis
- **D90**: Quarterly reviews
- **D180**: Long-term trends
- **ALL**: Complete historical analysis

---

### Q: Why period-based queries only?
**A:** Microsoft Graph UserDetail report endpoints only support period-based aggregation. This is a Graph API limitation, not a script limitation. Period queries provide server-side aggregated data with better performance.

---

### Q: How do I automate this script?
**A:**
1. Set up Azure AD app registration with client secret
2. Set environment variables for tenant ID, client ID, and secret
3. Create scheduled task (Windows) or cron job (Linux)
4. Use `-Auth Credential` and `-OutputFileName` parameters

---

### Q: Does this script work on macOS/Linux?
**A:** Yes! Requires PowerShell 7+ and works on Windows, macOS, and Linux.

---

### Q: Where can I find my tenant ID?
**A:**
```powershell
# Azure AD PowerShell
Get-AzureADTenantDetail | Select-Object ObjectId

# Microsoft Graph PowerShell
Connect-MgGraph
(Get-MgContext).TenantId
```

---

### Q: What's the difference between this script and the Purview script?
**A:**
- **Graph Script:** Aggregated usage reports (high-level metrics, Power BI dashboards)
- **Purview Script:** Detailed audit logs (conversation-level, compliance investigations)

See [PAX Overview](../../../README.md) for detailed comparison.

---

### Q: Can I export to JSON instead of CSV?
**A:** Not currently. CSV is optimized for Power BI and Excel integration. JSON export may be added in future versions.

---

### Q: How do I combine multiple months of historical data?
**A:** Use longer period settings or the ALL period:
```powershell
# Last 6 months
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D180 -CombineOutput -OutputFileName "Last_6_Months.csv"

# All available historical data
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period ALL -CombineOutput -OutputFileName "Complete_History.csv"
```

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Known Limitations

<details>
<summary>🚫 API Limitations</summary>

### 1. Period-Based Queries Only
**Limitation:** Microsoft Graph UserDetail report endpoints only support period-based aggregation (D7, D30, D90, D180, ALL).

**Impact:** Cannot query specific date ranges or individual days.

**Rationale:** This is a Microsoft Graph API design, not a script limitation. Period queries provide server-side aggregated data.

---

### 2. Data Obfuscation
**Limitation:** Tenant privacy settings can obfuscate all usage data.

**Impact:** All usage metrics return null when obfuscation is enabled.

**Remediation:** Global Admin must disable obfuscation (see [Data Obfuscation Warning](#data-obfuscation-warning)).

---

### 3. Report Processing Delay
**Limitation:** Microsoft Graph reports have 24-48 hour processing delays.

**Impact:** Current day's data may be incomplete or unavailable.

**Workaround:** Use D7 or longer periods which aggregate complete data.

---

### 4. No Tenant-Level Aggregates
**Limitation:** Script retrieves user-level data only (not tenant-wide summaries).

**Impact:** Cannot directly query "total tenant Copilot usage" without aggregating user data.

**Workaround:** Import CSV into Power BI/Excel and calculate aggregates.

---

### 6. No Real-Time Data
**Limitation:** Microsoft Graph reports are batch-processed (not real-time).

**Impact:** Cannot track usage "right now" - only historical data.

**Workaround:** Use Purview Audit Logs for near-real-time activity tracking.

---

### 7. Rooms/Resources Included in Some Reports
**Limitation:** Some endpoints include room mailboxes and resource accounts in results.

**Impact:** May inflate user counts and skew licensing calculations.

**Mitigation:** Entra Users endpoint filters these out. Use combined output with Entra enrichment to identify real users.

</details>

<details>
<summary>⚙️ Script Limitations</summary>

### 1. No Incremental Updates
**Limitation:** Each execution retrieves full dataset (no delta queries).

**Impact:** Cannot efficiently update existing datasets.

**Workaround:** Use `-Period D7` for daily refreshes with minimal data.

---

### 2. Single Tenant Only
**Limitation:** Script queries one tenant per execution.

**Workaround:** Run script multiple times with different credentials for multi-tenant scenarios.

---

### 3. No Data Filtering
**Limitation:** Script retrieves all users (no filtering by department, location, etc.).

**Workaround:** Filter data post-export in Power BI, Excel, or SQL.

---

### 4. English Only
**Limitation:** Script output and messages are in English only.

**Impact:** Non-English environments may have localization issues with date formats.

**Workaround:** Use YYYY-MM-DD date format (ISO 8601) for compatibility.

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Security & Compliance

<details>
<summary>🔒 Security Considerations</summary>

### Authentication Security

**Interactive Authentication (WebLogin/DeviceCode):**
- ✅ No credentials stored locally
- ✅ OAuth token cached by Microsoft.Graph SDK (encrypted)
- ✅ Token auto-refreshes when expired
- ✅ Script automatically disconnects from Graph on exit (clears token cache)

**Client Secret Authentication:**
- ⚠️ **Never hardcode secrets in scripts**
- ✅ Use environment variables or Azure Key Vault
- ✅ Rotate secrets regularly (90-day maximum recommended)
- ✅ Apply principle of least privilege (Reports.Read.All only)
- ⚠️ Protect secret files with appropriate ACLs

**Managed Identity:**
- ✅ Most secure for Azure-hosted automation
- ✅ No credential management required
- ✅ Automatic token handling by Azure

### Data Privacy

**What Data is Collected:**
- Usage metrics (counts, dates, activity flags)
- User properties (name, email, department, manager)
- License assignments (SKU IDs, service plans)

**What Data is NOT Collected:**
- Email content or subjects
- File content or names
- Chat/meeting transcripts
- Copilot prompts or responses

**Data Retention:**
- CSV files stored locally (customer-controlled)
- No data transmitted to Microsoft beyond Graph API queries
- Log files contain execution details (no sensitive data)

### Compliance Considerations

**GDPR/Privacy:**
- User-identifiable data exported (name, email, etc.)
- Ensure proper data handling per organizational policies
- Consider data encryption at rest for exported files
- Apply access controls to output directories

**Audit Trail:**
- Every execution creates timestamped log file
- Includes authentication method, parameters, execution time
- Suitable for compliance auditing

**Recommended Security Practices:**
1. Use device code or client secret for unattended execution
2. Store output files in secured network locations
3. Apply encryption for files containing user data
4. Regularly review API permissions (least privilege)
5. Monitor script execution logs for anomalies
6. Implement file retention policies for CSV outputs

</details>

<details>
<summary>🔑 Permissions Reference</summary>

### Microsoft Graph API Scopes

**Reports.Read.All** (Required)
- Purpose: Read all usage reports
- Type: Application or Delegated
- Admin Consent: Required

**User.Read.All** (Required for Entra enrichment)
- Purpose: Read user profiles
- Type: Application or Delegated
- Admin Consent: Required

**Directory.Read.All** (Required for manager expansion)
- Purpose: Read directory data
- Type: Application or Delegated
- Admin Consent: Required

### Azure AD Roles

**Global Reader** (Recommended)
- Full read access to all Microsoft 365 services
- Cannot make changes
- Suitable for security teams

**Reports Reader** (Minimum)
- Read access to usage reports only
- Suitable for BI analysts
- May not include Entra user enrichment permissions

**Global Administrator** (Not Recommended)
- Full access to all services
- Use only for initial setup/testing
- Apply least privilege principle for production

</details>

**Disclaimer:** This script is provided "AS IS" without warranties or official support. Validate fit for purpose before production use. Not endorsed or officially supported by Microsoft Product Groups. Community-driven maintenance model.

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Additional Resources

### Microsoft Documentation

- **[Microsoft Graph API Reports](https://learn.microsoft.com/en-us/graph/api/resources/report)** - Overview of Graph reporting capabilities
- **[Microsoft 365 usage reports](https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/activity-reports)** - Admin center usage reports
- **[Copilot Dashboard](https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/microsoft-365-copilot-usage)** - Official Copilot usage dashboard
- **[Microsoft Graph PowerShell](https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview)** - Graph PowerShell module documentation

### Related Tools

- **[Power BI](https://powerbi.microsoft.com/)** - Visualize exported usage data
- **[Azure Synapse Analytics](https://azure.microsoft.com/en-us/products/synapse-analytics/)** - Data warehousing for large datasets
- **[Microsoft Adoption](https://adoption.microsoft.com/copilot/)** - Copilot adoption resources and best practices

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

© Microsoft Corporation — MIT Licensed
