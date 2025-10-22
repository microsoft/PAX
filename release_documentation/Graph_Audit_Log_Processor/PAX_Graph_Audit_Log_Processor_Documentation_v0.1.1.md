# Portable Audit eXporter (PAX) - <br/>Graph Audit Log Processor

> **🚀 Quick Start:** Download the script → [`PAX_Graph_Audit_Log_Processor_v0.1.1.ps1`](https://github.com/microsoft/PAX/releases/download/graph-v0.1.1/PAX_Graph_Audit_Log_Processor_v0.1.1.ps1)
>
> **📋 Release Notes:** See what's new → [v0.1.1 Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Graph_Audit_Log_Processor/PAX_Graph_Audit_Log_Processor_Release_Note_v0.1.1.md) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Graph_Audit_Log_Processor)
>
> **📜 Previous Script Versions:** [All Graph Releases](https://github.com/microsoft/PAX/releases?q=graph-&expanded=true)
>
> **📚 Documentation Archive:** [v0.1.1 MD](https://github.com/microsoft/PAX/blob/release/release_documentation/Graph_Audit_Log_Processor/PAX_Graph_Audit_Log_Processor_Documentation_v0.1.1.md) | [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Graph_Audit_Log_Processor)

**Script:** `PAX_Graph_Audit_Log_Processor_v0.1.1.ps1`  
**Version:** 0.1.1  
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

The **Portable Audit eXporter (PAX) - Graph Audit Log Processor** is an enterprise-grade PowerShell script that exports Microsoft 365 and Copilot usage analytics from Microsoft Graph API. It retrieves aggregated usage reports and transforms them into analysis-ready CSV files with optional Entra user enrichment.

**Core Capabilities:**

- **Default Focus:** M365 App Usage endpoint (most essential usage data)
- **Flexible Expansion:** Opt-in for Copilot, curated endpoint sets, and Entra user enrichment
- **15 Available Endpoints:** Full coverage when using `-IncludeCurated` (Copilot, Teams, Email, SharePoint, OneDrive, etc.)
- **Rich User Data:** 35 Entra user properties including manager hierarchy (with `-IncludeEntraUsers`)
- **Period-Based Queries:** Aggregated reports covering D7, D30, D90, D180, or ALL time periods
- **Auto-Installation:** Automatically handles Microsoft.Graph PowerShell SDK setup
- **Enterprise-Ready:** Detailed logging, error handling with automatic retry logic
- **Unified Output:** Combines all endpoint data into a single CSV (optional)

**Query Mode:**

- **Period Mode** (`-Period D7|D30|D90|D180|ALL`) - Server-aggregated usage reports covering specified time windows
- **Default Period:** D7 (last 7 days) when no period specified
- **Combined Output Mode** (`-CombineOutput`) - Single CSV with full outer join across all endpoints

**Endpoint Selection Modes:**

- **Default Mode:** M365 App Usage only (most essential endpoint)
- **Include Copilot:** Add `-IncludeCopilot` for Copilot usage data
- **Include Curated Set:** Add `-IncludeCurated` for all 13 curated endpoints (includes Copilot)
- **Include Entra Users:** Add `-IncludeEntraUsers` for user enrichment with manager hierarchy

**Why Use This Script:**

- **Fast Deployment:** No Azure app registration required (uses interactive authentication by default)
- **Flexible Coverage:** Default M365 App Usage endpoint + opt-in for Copilot, curated endpoints, and Entra user enrichment
- **Power BI Ready:** CSV output optimized for direct import into analytics tools
- **Enterprise Scale:** Handles large tenants with automatic throttling and retry logic
- **Privacy Aware:** Detects data obfuscation settings and provides remediation guidance

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
- **Custom Filenames:** Specify exact output filenames (no timestamp added)
- **Column Reordering:** Report Period moved to position 2 for better readability
- **Array Explosion:** Optional expansion of nested arrays (licenses, plans, etc.)

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
# Get last 30 days of Copilot usage with user enrichment
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeCopilot -IncludeEntraUsers -CombineOutput -OutputFileName "Copilot_Adoption_Report.csv"
```

**Benefits:**
- Identify power users and non-adopters
- Track feature usage (Word, Excel, PowerPoint, Teams, Outlook Copilot)
- Calculate ROI metrics with enriched user properties (department, manager, location)

</details>

<details>
<summary>M365 Service Usage Analysis</summary>

**Scenario:** Analyze Microsoft 365 application usage patterns

```powershell
# Get last 90 days of M365 usage across all services
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D90 -IncludeCurated -IncludeEntraUsers -CombineOutput
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D180 -CombineOutput
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -IncludeCurated -IncludeEntraUsers -CombineOutput -OutputFileName "PowerBI_M365_Usage.csv"
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D180 -IncludeCurated -IncludeEntraUsers -CombineOutput
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
| **Permissions**            | Global Reader or Reports Reader   | Or explicit API scopes: `Reports.Read.All`, `User.Read.All`, `Directory.Read.All` |
| **Network Access**         | Microsoft Graph API               | Ensure firewall allows connections to `graph.microsoft.com`  |
| **Execution Policy**       | Bypass or RemoteSigned            | See [Installation & Setup](#installation--setup)             |

**Note:** The script automatically handles Microsoft.Graph module detection, installation, and connection. No manual setup required.

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

```powershell
# Download from GitHub Releases
Invoke-WebRequest -Uri "https://github.com/microsoft/PAX/releases/download/graph-v0.1.1/PAX_Graph_Audit_Log_Processor_v0.1.1.ps1" -OutFile "PAX_Graph_Audit_Log_Processor_v0.1.1.ps1"
```

### Step 2: Run Script

```powershell
# Basic usage - last 7 days
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -OutputPath "C:\Reports\M365"
```

### Device Code Authentication (Limited Browser)

```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -Auth DeviceCode
```

### Client Secret Authentication (Automation)

```powershell
# Set environment variables
$env:GRAPH_TENANT_ID = "your-tenant-id"
$env:GRAPH_CLIENT_ID = "your-client-id"  
$env:GRAPH_CLIENT_SECRET = "your-client-secret"

# Run with credential auth
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -Auth Credential
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1

# Specify 30-day period
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30

# Get all available historical data
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period ALL
```

---

### Output Parameters

#### `-OutputPath <string>`
Directory for output files (default: `C:\Temp\MS_Graph`)

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -OutputPath "C:\Reports"
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -CombineOutput -OutputFileName "Weekly_Report.csv"

# Auto-generated timestamped filename
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -CombineOutput
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -CombineOutput
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -Auth DeviceCode

# Credential flow
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -Auth Credential
```

</details>

<details>
<summary>Processing Parameters</summary>

### `-IncludeCopilot`
Include Copilot Usage endpoint in addition to default M365 App Usage

**Use When:**
- Tracking Copilot adoption and feature usage
- Analyzing Copilot activity across apps (Word, Excel, Teams, etc.)
- Want Copilot data without all other curated endpoints

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -IncludeCopilot
```

---

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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeCurated
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -IncludeEntraUsers
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -ExplodeArrays
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -PacingMs 100
```

---

### Utility Parameters

#### `-Help`
Display full help information

**Example:**
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Help
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -Auth DeviceCode
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -Auth Credential
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -Auth Silent
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1
```

### Last 30 Days with Combined Output
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -CombineOutput
```

### Last 90 Days
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D90
```

### Custom Output Location
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -OutputPath "C:\Reports\M365"
```

</details>

<details>
<summary>💻 Show Long-Term Analysis Examples</summary>

### Last 180 Days for Trend Analysis
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D180 -CombineOutput
```

### All Available Historical Data
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period ALL -CombineOutput -OutputFileName "Historical_Analysis.csv"
```

### Quarterly Review
```powershell
# 90-day period for Q1 review
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D90 -IncludeCurated -IncludeEntraUsers -CombineOutput -OutputFileName "Q1_Review.csv"
```

</details>

<details>
<summary>💻 Show Power BI Integration Examples</summary>

### Daily Scheduled Refresh
```powershell
# Scheduled task: runs daily at 8 AM
# Always uses same filename for Power BI datasource
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -CombineOutput -OutputFileName "PowerBI_M365_Usage.csv" -OutputPath "C:\PowerBI\Data"
```

### Weekly Snapshot
```powershell
# Scheduled task: runs Monday at 6 AM
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -CombineOutput -OutputFileName "Weekly_Snapshot.csv" -OutputPath "C:\PowerBI\Data"
```

### Monthly Report
```powershell
# Scheduled task: runs 1st of month at 2 AM
# Get last 30 days of data
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -CombineOutput -OutputFileName "Monthly_Report.csv"
```

</details>

<details>
<summary>💻 Show Advanced Usage Examples</summary>

### M365 App Usage Only (Default Behavior)
```powershell
# Only M365 App Usage endpoint (fastest execution)
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30
```

### Copilot Analysis with User Context
```powershell
# M365 App Usage + Copilot + Entra user enrichment
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeCopilot -IncludeEntraUsers -CombineOutput
```

### Comprehensive M365 Analysis
```powershell
# All curated endpoints (includes Copilot) + Entra enrichment
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D90 -IncludeCurated -IncludeEntraUsers -CombineOutput
```

### Large Tenant with Throttling
```powershell
# Add 200ms delay between requests
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D90 -IncludeCurated -CombineOutput -PacingMs 200
```

### Array Explosion for License Details
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeEntraUsers -ExplodeArrays -CombineOutput
```

### Device Code Authentication
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -IncludeCurated -Auth DeviceCode -CombineOutput
```

### Automated Execution with Client Secret
```powershell
# Environment variables set separately or in script
$env:GRAPH_TENANT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$env:GRAPH_CLIENT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$env:GRAPH_CLIENT_SECRET = "your~client~secret"

.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeCurated -Auth Credential -CombineOutput -OutputFileName "Automated_Report.csv"
```

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Output Files & Schema

<details>
<summary>📁 Output File Structure</summary>

### Individual Endpoint Files
When `-CombineOutput` is **not** specified, the script generates one CSV file per endpoint:

**Filename Pattern:**
```
{ReportName}_{Period or DateRange}_{Timestamp}.csv
```

**Examples:**
- `getM365Copilot_D30_20251021_143052.csv`
- `getEmailActivity_DaysBack5_20251021_143105.csv`
- `EntraUsers_D30_20251021_143120.csv`

### Combined Output File
When `-CombineOutput` is specified:

**Default Filename:**
```
Combined_M365_Usage_{Period or DateRange}_{Timestamp}.csv
```

**Custom Filename:**
```powershell
# With -OutputFileName parameter
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -CombineOutput -OutputFileName "My_Report.csv"
# Creates: My_Report.csv (no timestamp)
```

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
Microsoft 365 includes privacy settings that **obfuscate user-identifiable data** in usage reports. When enabled, all usage data shows as `null` or empty.

### Detection
The script automatically detects obfuscation by checking for null values in expected fields:

```
⚠️ WARNING: Data obfuscation detected in Microsoft Graph reports.
All usage data is showing as null/empty due to tenant privacy settings.
```

### Impact
**When obfuscation is enabled:**
- ❌ All user-level usage metrics return null
- ❌ Cannot track individual adoption
- ❌ Cannot identify power users or non-adopters
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7
# Check CSV output for non-null values in usage columns
```

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Endpoint Reference

<details>
<summary>🔗 15 Microsoft Graph API Endpoints</summary>

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

#### 2. **Teams Activity** (`getTeamsUserActivity`)
```
GET /reports/microsoft.graph.getTeamsUserActivityUserDetail(period='{period}')
```

**Metrics:**
- Team chat messages
- Private chat messages
- Calls
- Meetings organized/participated
- Last activity date

#### 3. **Teams Device Usage** (`getTeamsDeviceUsage`)
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

#### 4. **Email Activity** (`getEmailActivity`)
```
GET /reports/microsoft.graph.getEmailActivityUserDetail(period='{period}')
```

**Metrics:**
- Send count
- Receive count
- Read count
- Meeting created/accepted count

#### 5. **Email App Usage** (`getEmailAppUsage`)
```
GET /reports/microsoft.graph.getEmailAppUsageUserDetail(period='{period}')
```

**Metrics:**
- Outlook desktop usage
- Outlook web usage
- Outlook mobile usage
- IMAP/POP/SMTP usage
- Last activity date per app

#### 6. **Mailbox Usage** (`getMailboxUsage`)
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

#### 7. **Office Activations** (`getOfficeActivations`)
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

#### 8. **OneDrive Activity** (`getOneDriveActivity`)
```
GET /reports/microsoft.graph.getOneDriveActivityUserDetail(period='{period}')
```

**Metrics:**
- Files viewed/edited
- Files synced
- Files shared internally/externally
- Last activity date

#### 9. **OneDrive Usage** (`getOneDriveUsage`)
```
GET /reports/microsoft.graph.getOneDriveUsageAccountDetail(period='{period}')
```

**Metrics:**
- Storage used (bytes)
- Storage allocated (bytes)
- File count
- Active file count
- Last activity date

#### 10. **SharePoint Activity** (`getSharePointActivity`)
```
GET /reports/microsoft.graph.getSharePointActivityUserDetail(period='{period}')
```

**Metrics:**
- Files viewed/edited
- Files synced
- Files shared internally/externally
- Pages visited
- Last activity date

#### 11. **SharePoint Site Usage** (`getSharePointSiteUsage`)
```
GET /reports/microsoft.graph.getSharePointSiteUsageDetail(period='{period}')
```

**Metrics:**
- Storage used (bytes)
- Storage allocated (bytes)
- File count
- Active file count
- Page view count

#### 12. **Yammer Activity** (`getYammerActivity`)
```
GET /reports/microsoft.graph.getYammerActivityUserDetail(period='{period}')
```

**Metrics:**
- Messages posted
- Messages read
- Messages liked
- Last activity date

#### 13. **Yammer Device Usage** (`getYammerDeviceUsage`)
```
GET /reports/microsoft.graph.getYammerDeviceUsageUserDetail(period='{period}')
```

**Metrics:**
- Web usage
- Windows phone usage
- Android phone usage
- iPhone usage
- iPad usage

#### 14. **Yammer Groups Activity** (`getYammerGroupsActivity`)
```
GET /reports/microsoft.graph.getYammerGroupsActivityDetail(period='{period}')
```

**Metrics:**
- Group name
- Members count
- Messages posted
- Messages read
- Messages liked

---

### Entra ID (1 Endpoint)

#### 15. **Entra Users** (`EntraUsers`)
```
GET /users?\={35 properties}&\=manager
```

**Properties:** See [CSV Schema Overview](#csv-schema-overview) for complete list.

**Special Handling:**
- Filters: `UserType eq 'Member'` (excludes guests)
- Filters: `accountEnabled eq true`
- Excludes: Rooms, resources (`ResourceType` property)
- Expands: Manager relationship (4 additional properties)

</details>

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Advanced Features

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
Processing page 1 of EntraUsers data...
Processing page 2 of EntraUsers data...
Processing page 3 of EntraUsers data...
```

### Error Isolation
If one endpoint fails, script continues with remaining endpoints:
```
✅ Successfully retrieved: getTeamsUserActivity
❌ Failed to retrieve: getEmailActivity (Error: 403 Forbidden)
✅ Successfully retrieved: getSharePointActivity
```

</details>

<details>
<summary>Performance Optimization</summary>

### Parallel Endpoint Queries
All selected endpoints are queried **concurrently** using PowerShell jobs for maximum throughput.

**Typical Execution Time:**
- Default (M365 App Usage only): 10-20 seconds
- With -IncludeCopilot: 15-30 seconds
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

[⬆ Back to Top](#portable-audit-exporter-pax---graph-audit-log-processor)

---

## Performance Tuning

<details>
<summary>⚡ Optimization Strategies</summary>

### For Large Tenants (10,000+ users)

#### 1. Use Appropriate Period for Your Needs
```powershell
# Short-term analysis (fastest)
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7

# Medium-term analysis
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30

# Long-term trends
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D90
```

#### 2. Add Pacing to Avoid Throttling
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D90 -IncludeCurated -PacingMs 200
```

#### 3. Minimize Endpoints for Faster Execution
```powershell
# Default (M365 App Usage only) is fastest
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30

# Add only what you need
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeCopilot  # +1 endpoint
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeEntraUsers  # +user enrichment
```

#### 4. Use Client Secret Authentication
```powershell
# Faster than interactive login (no browser overhead)
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeCurated -Auth Credential
```

### For Scheduled Execution

#### Daily Refresh (Power BI)
```powershell
# Fastest: D7 period with fixed filename
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -CombineOutput -OutputFileName "Daily_Refresh.csv" -Auth Credential
```

#### Weekly Summary
```powershell
# Balanced: D30 period for trend analysis
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -CombineOutput -OutputFileName "Weekly_Summary.csv" -Auth Credential
```

### For Historical Analysis

#### Use Longer Periods for Trends
```powershell
# 6-month trend analysis
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D180 -CombineOutput -OutputFileName "Historical_Trends.csv"

# All available data
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period ALL -CombineOutput -OutputFileName "Complete_History.csv"
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D90 -PacingMs 250
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -PacingMs 200
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
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D180 -CombineOutput -OutputFileName "Last_6_Months.csv"

# All available historical data
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period ALL -CombineOutput -OutputFileName "Complete_History.csv"
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

### 1. CSV Output Only
**Limitation:** Script only exports to CSV format.

**Workaround:** Import CSV into Power BI, Excel, or other analytics tools.

---

### 2. No Incremental Updates
**Limitation:** Each execution retrieves full dataset (no delta queries).

**Impact:** Cannot efficiently update existing datasets.

**Workaround:** Use `-Period D7` for daily refreshes with minimal data.

---

### 3. Single Tenant Only
**Limitation:** Script queries one tenant per execution.

**Workaround:** Run script multiple times with different credentials for multi-tenant scenarios.

---

### 4. No Data Filtering
**Limitation:** Script retrieves all users (no filtering by department, location, etc.).

**Workaround:** Filter data post-export in Power BI, Excel, or SQL.

---

### 5. English Only
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
- ⚠️ Token cache persists across sessions (logout to clear: `Disconnect-MgGraph`)

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
