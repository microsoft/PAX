# Portable Audit eXporter (PAX) - Purview Audit Log Exporter

**Script:** `PAX_Purview_Audit_Log_Processor_v1.5.6.ps1`  
**Version:** 1.5.6  
**Audience:** IT admins, security/compliance analysts, BI/data teams  
**Runtime:** PowerShell 5.1 (compatible) / PowerShell 7+ (recommended)  
**License:** MIT

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
10. [Advanced Features](#advanced-features)
11. [Performance Tuning](#performance-tuning)
12. [Troubleshooting & FAQ](#troubleshooting--faq)
13. [Known Limitations](#known-limitations)
14. [Security & Compliance](#security--compliance)
15. [Contributing](#contributing)

---

## Overview

### What It Does

The **Portable Audit eXporter (PAX)** is an enterprise-grade PowerShell script that exports Microsoft Purview Unified Audit Log events, with specialized support for Microsoft 365 Copilot activities and related operations. It transforms raw audit data into analysis-ready CSV files with enriched metadata, intelligent query optimization, and flexible schema options.

**Core Capabilities:**

- Retrieves audit events from Microsoft 365 Unified Audit Log via Exchange Online Management
- Exports to structured CSV with optional array explosion and deep JSON flattening
- Includes enriched usage & ROI fields (tokens, models, latency, acceptance metrics)
- Supports both live querying and offline replay/transformation of previously exported data
- Implements adaptive time slicing to navigate service limits intelligently
- Provides detailed logging of all operations, warnings, and performance metrics

**Execution Modes:**

1. **Standard Mode** - One row per audit record (raw JSON preserved in `CopilotEventData` column)
2. **Array Explosion Mode** (`-ExplodeArrays`) - Canonical Purview 35-column schema with array elements expanded
3. **Deep Flatten Mode** (`-ExplodeDeep`) - 35-column base schema + fully flattened `CopilotEventData.*` columns
4. **Offline Replay Mode** (`-RAWInputCSV`) - Re-process previously exported raw audit CSV files without querying the service

---

## Key Features

### Intelligent Query Management

- **Adaptive Block Sizing:** Automatically adjusts time window sizes based on data density
- **10K Limit Detection:** Identifies when Microsoft 365 service cap is reached and recommends mitigation
- **Automatic Subdivision:** Binary/aggressive splitting of dense time periods to maximize completeness
- **Throttle Resilience:** Exponential backoff with jitter for retry operations
- **Volume Classification:** Smart batching based on activity type (High/Medium/Low volume)

### Data Processing & Output

- **Purview Schema Compliance:** Matches Microsoft Purview's canonical exploded schema structure
- **Deep JSON Flattening:** Optional recursive flattening of nested `CopilotEventData` structures
- **Streaming Export:** Memory-efficient chunked CSV writing for large datasets
- **UTF-8 Encoding:** Consistent UTF-8 (no BOM) output for cross-platform compatibility
- **Header Stability:** Always writes CSV header even when zero records match (ensures schema consistency)

### Performance Optimization

- **Parallel Execution (PS7+):** Concurrent processing of multiple activity types with controlled throttling
- **Learned Block Sizes:** Per-activity and global adaptive sizing based on observed densities
- **Fast CSV Writer:** Direct `StreamWriter` usage eliminates repeated `Export-Csv` overhead
- **Schema Sampling:** Configurable initial sampling to optimize column discovery vs. memory usage

### Operational Excellence

- **Composite Progress:** Single weighted percentage across Query/Explosion/Export phases
- **Detailed Logging:** Comprehensive log file with parameters, decisions, warnings, and metrics
- **Version Pinning:** `$ScriptVersion` dynamically read from `package.json` for release alignment
- **Offline Replay:** Transform previously exported raw CSVs without Exchange Online connection

---

## Use Cases

### Adoption & Usage Analytics

- Track Microsoft 365 Copilot adoption across your organization
- Measure user engagement with AI features (interactions, token consumption, model usage)
- Identify power users and underutilized licenses
- Calculate ROI metrics based on time saved and acceptance rates

### Compliance & Governance

- Audit Copilot interactions for regulatory compliance requirements
- Monitor data access patterns and sensitivity indicators
- Track plugin usage and custom GPT deployment
- Generate audit trails for security reviews

### Performance & Capacity Planning

- Analyze response latencies and model performance
- Identify throttling patterns and peak usage periods
- Forecast infrastructure needs based on token consumption trends
- Optimize block sizing for your tenant's data density

### Data Integration & BI

- Export enriched data to Power BI, Azure Synapse, or data warehouses
- Join audit data with licensing information for coverage analysis
- Build custom dashboards with wide-schema flattened data
- Maintain historical archives with consistent schema over time

### Development & Testing

- Offline replay mode for reproducible transformations
- Test schema changes against synthetic or sanitized datasets
- Validate data pipelines without querying production audit logs
- Develop downstream analytics without live tenant access

---

## Prerequisites

| Requirement                         | Details                                 | Notes                                                                         |
| ----------------------------------- | --------------------------------------- | ----------------------------------------------------------------------------- |
| **PowerShell**                      | 5.1 or 7+                               | 7+ strongly recommended for parallel execution and UTF-8 handling             |
| **ExchangeOnlineManagement Module** | Any reasonably current version          | Install: `Install-Module -Name ExchangeOnlineManagement`                      |
| **Unified Audit Logging**           | Enabled in tenant                       | Verify in Microsoft Purview compliance portal                                 |
| **Permissions**                     | View-Only Audit Logs or Audit Logs role | Least privilege: Use read-only audit role                                     |
| **Network Access**                  | Microsoft 365 endpoints                 | Ensure firewall allows connections to `*.protection.outlook.com`              |
| **Execution Policy**                | Bypass or RemoteSigned                  | See [Authentication Methods](#authentication-methods) for invocation patterns |

### Permission Details

**Minimum RBAC Requirements:**

- **View-Only Audit Logs** role (read-only, recommended for production)
- **Audit Logs** role (if write operations needed elsewhere)
- Member of appropriate role groups in Microsoft Purview compliance portal

**Verification:**

```powershell
# Check if audit logging is enabled
Get-AdminAuditLogConfig | Select-Object UnifiedAuditLogIngestionEnabled

# Verify your audit search permissions
Get-ManagementRoleAssignment -RoleAssignee user@domain.com | Where-Object {$_.Role -like "*Audit*"}
```

### Why PowerShell 7+?

| Feature              | PowerShell 5.1                | PowerShell 7+                  |
| -------------------- | ----------------------------- | ------------------------------ |
| Parallel Execution   | ❌ Not Available              | ✅ `ForEach-Object -Parallel`  |
| UTF-8 Default        | ❌ Requires explicit encoding | ✅ Native UTF-8                |
| Performance          | Baseline                      | 🚀 30-50% faster JSON/pipeline |
| TLS/Cipher Support   | Legacy protocols              | ✅ Modern TLS 1.3              |
| Cross-Platform       | ❌ Windows only               | ✅ Windows/macOS/Linux         |
| Side-by-Side Install | N/A                           | ✅ Does not replace PS 5.1     |

**Download PowerShell 7:** https://aka.ms/powershell

---

## Installation & Setup

### Step 1: Install ExchangeOnlineManagement Module

```powershell
# Install for current user (no admin rights required)
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser

# Or install globally (requires admin)
Install-Module -Name ExchangeOnlineManagement -Scope AllUsers

# Verify installation
Get-Module -Name ExchangeOnlineManagement -ListAvailable
```

### Step 2: Download the Script

**Option A: Clone the repository**

```powershell
git clone https://github.com/Rance9/PAX.git
cd PAX/scripts
```

**Option B: Direct download**

1. Navigate to the [releases page](https://github.com/Rance9/PAX/releases)
2. Download `PAX_Purview_Audit_Log_Processor_v1.5.6.ps1`
3. Save to a working directory (e.g., `C:\Scripts\PAX\`)

### Step 3: Verify Audit Log Access

```powershell
# Quick connectivity test (interactive auth)
Connect-ExchangeOnline

# Test a simple audit search (last 24 hours)
$testDate = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
Search-UnifiedAuditLog -StartDate $testDate -EndDate (Get-Date).ToString('yyyy-MM-dd') -ResultSize 10

# Disconnect
Disconnect-ExchangeOnline -Confirm:$false
```

### Step 4: First Run (Quick Start)

```powershell
# PowerShell 7+ (recommended)
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# Windows PowerShell 5.1
powershell -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
```

**What Happens:**

1. Interactive browser sign-in prompt (unless `-Auth` specified)
2. Queries Unified Audit Log for the specified date range
3. Exports to `C:\Temp\CopilotInteraction_<timestamp>.csv` (default path)
4. Creates matching `.log` file with detailed execution metrics

---

## Parameters Reference

### Date & Time Parameters

#### `-StartDate` (string)

**Purpose:** UTC start date (inclusive) for audit log query or replay filter  
**Format:** `yyyy-MM-dd` (e.g., `2025-10-01`)  
**Default (Live Mode):** Previous full UTC day if both dates omitted  
**Default (Replay Mode):** No filter applied if omitted  
**Use When:** Defining the beginning of your audit window  
**Example:** `-StartDate 2025-10-01`

#### `-EndDate` (string)

**Purpose:** UTC end date (exclusive) for audit log query or replay filter  
**Format:** `yyyy-MM-dd` (e.g., `2025-10-02`)  
**Default (Live Mode):** Previous full UTC day + 1 if both dates omitted  
**Default (Replay Mode):** No filter applied if omitted  
**Use When:** Defining the end of your audit window  
**Example:** `-EndDate 2025-10-02`

**Date Behavior:**

- **Live mode:** If both dates omitted, defaults to previous full UTC day (midnight to midnight)
- **Live mode:** Must specify both or neither (partial specification rejected)
- **Replay mode:** Both dates optional; act as filters on `CreationDate` column
- **Time zone:** All dates interpreted as UTC; convert local times before invocation

---

### Output & File Parameters

#### `-OutputFile` (string)

**Purpose:** Target CSV file path for exported audit data  
**Default:** `C:\Temp\CopilotInteraction_<timestamp>.csv`  
**Use When:** Specifying custom output location or naming convention  
**Example:** `-OutputFile "C:\AuditData\Copilot_$(Get-Date -Format 'yyyyMMdd').csv"`  
**Notes:** Parent directories created automatically if missing

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
  **Example:** `-RAWInputCSV "C:\PreviousExports\Copilot_RAW_20251001.csv"`  
  **Restrictions:** Cannot combine with live query parameters (`-Auth`, `-BlockHours`, `-ResultSize`, `-PacingMs`, `-ParallelMode`, `-MaxConcurrency`, `-MaxParallelGroups`)  
  **Allowed with RAWInputCSV:** `-StartDate`, `-EndDate`, `-ActivityTypes`, `-OutputFile`, `-ExplodeDeep`, `-ExportProgressInterval`, `-StreamingSchemaSample`, `-StreamingChunkSize`

---

### Parallel Execution Parameters (PowerShell 7+ Only)

#### `-ParallelMode` (string)

**Purpose:** Controls parallel execution of multiple activity type groups  
**Valid Values:** `Off`, `On`, `Auto`  
**Default:** `Off`  
**Use When:**

- **Off:** Predictable sequential processing, easier debugging
- **On:** Force parallel (PS7+ required), maximum speed for multi-activity runs
- **Auto:** Let heuristics decide based on workload characteristics
  **Examples:**
- `-ParallelMode Off` - Always sequential
- `-ParallelMode On -MaxConcurrency 4` - Force parallel with 4 threads
- `-ParallelMode Auto` - Smart activation
  **Auto Criteria:** PS7+, ≤1 High volume group, ≥1 Medium/Low group, ≤15 activities, >1 group, concurrency >1  
  **Notes:** Only affects live queries; replay is always sequential explosion phase

#### `-MaxConcurrency` (int)

**Purpose:** Maximum concurrent threads per activity group in parallel mode  
**Range:** `1` to `50`  
**Default:** `2`  
**Use When:** Balancing speed vs. throttling risk  
**Example:** `-MaxConcurrency 4`  
**Notes:** Higher values increase speed but may trigger rate limiting

#### `-MaxParallelGroups` (int)

**Purpose:** Maximum number of activity groups to process concurrently  
**Range:** `0` to `50`  
**Default:** `3`  
**Use When:**

- Limiting overall parallelism across groups
- Preventing excessive API pressure
- Tuning for tenant throttling thresholds
  **Example:** `-MaxParallelGroups 2`  
  **Notes:** Set to `0` to disable parallel group processing entirely

#### `-EnableParallel` (switch)

**Purpose:** Legacy synonym for `-ParallelMode On`  
**Default:** Off  
**Use When:** Maintaining backward compatibility with older scripts  
**Example:** `-EnableParallel` (equivalent to `-ParallelMode On`)  
**Notes:** Prefer `-ParallelMode` syntax in new scripts

---

### Progress & UI Parameters

#### `-ExportProgressInterval` (int)

**Purpose:** How many rows to process before updating export progress indicator  
**Range:** `1` to `10000`  
**Default:** `10`  
**Use When:**

- Monitoring large exports (lower value = more updates)
- Reducing console noise (higher value = fewer updates)
  **Examples:**
- `-ExportProgressInterval 1` - Update every row (testing)
- `-ExportProgressInterval 100` - Reduce UI overhead (large files)
  **Notes:** Does not affect actual processing, only display frequency

---

### Advanced Streaming Parameters

#### `-StreamingSchemaSample` (int)

**Purpose:** Number of rows to sample initially for column schema discovery  
**Range:** `100` to `50000`  
**Default:** `1000`  
**Use When:**

- Wide schemas with many optional fields (increase to 3000-6000)
- Narrow/consistent schemas (decrease to 500 for faster header freeze)
- Memory constraints (balance with chunk size)
  **Examples:**
- `-StreamingSchemaSample 5000` - Comprehensive column discovery
- `-StreamingSchemaSample 500` - Fast freeze, risk late columns ignored
  **Notes:** New columns after freeze are counted but not written (warning emitted)

#### `-StreamingChunkSize` (int)

**Purpose:** Number of rows to accumulate before flushing to CSV file  
**Range:** `100` to `50000`  
**Default:** `5000`  
**Use When:**

- Balancing memory usage vs. I/O efficiency
- Very wide schemas (reduce to 1500-2500 for lower peak memory)
- Narrow schemas (increase to 10000+ for throughput)
  **Examples:**
- `-StreamingChunkSize 2000` - Memory-constrained environments
- `-StreamingChunkSize 10000` - Fast I/O, ample memory
  **Notes:** Auto-adjusts dynamically based on column count (>250, >500, >750, >1000 cols)

---

### Help Parameter

#### `-Help` (switch)

**Purpose:** Display full inline help from script synopsis/description  
**Use When:** Quick reference without opening documentation  
**Example:** `.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -Help`  
**Notes:** Uses PowerShell `Get-Help` cmdlet; exits after displaying help

---

## Authentication Methods

### WebLogin (Default - Interactive Browser)

**Best For:** Interactive sessions, first-time setup, MFA-enabled accounts  
**Requirements:** Web browser access, interactive session  
**Example:**

```powershell
.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
# Browser window opens for authentication
```

### DeviceCode (Headless/Remote Sessions)

**Best For:** Remote servers, SSH sessions, locked-down environments  
**Requirements:** Access to any device with web browser and internet  
**Example:**

```powershell
.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -Auth DeviceCode -StartDate 2025-10-01 -EndDate 2025-10-02
# Displays URL and code - authenticate from any device
```

**Flow:**

1. Script displays: "To sign in, use a web browser to open https://microsoft.com/devicelogin and enter code ABC123"
2. User opens browser on any device, enters code
3. Completes authentication
4. Script continues automatically

### Credential (Username/Password Prompt)

**Best For:** Service accounts without MFA, testing scenarios  
**Requirements:** Valid username/password, no MFA  
**Example:**

```powershell
.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -Auth Credential -StartDate 2025-10-01 -EndDate 2025-10-02
# PowerShell credential prompt appears
```

**Security Note:** Credential stored in memory only for session duration

### Silent (Cached Token Reuse)

**Best For:** Repeated runs in short succession, managed workstations  
**Requirements:** Valid cached token from previous authentication  
**Example:**

```powershell
# First run with interactive auth
.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# Subsequent runs can use silent (within token lifetime)
.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -Auth Silent -StartDate 2025-10-03 -EndDate 2025-10-04
```

**Behavior:** Falls back to WebLogin if no valid cached token found

---

## Usage Examples

### Basic Scenarios

#### Example 1: Minimal Run (Default Settings)

```powershell
# Queries previous full UTC day, exports to default location
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1

# Or specify dates explicitly
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
```

#### Example 2: Custom Output Path

```powershell
# Specify explicit output location
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02 `
  -OutputFile "C:\AuditData\Copilot\October_2025.csv"
```

#### Example 3: Multiple Activity Types

```powershell
# Query Copilot, Teams messages, and file access in one run
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-03 `
  -ActivityTypes CopilotInteraction,MessageSent,FileAccessed,MeetingDetail
```

---

### Exploded Schema Examples

#### Example 4: Array Explosion (Purview 35-column Schema)

```powershell
# One row per array element - matches Purview export format
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ExplodeArrays `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02 `
  -OutputFile ".\Copilot_exploded.csv"
```

#### Example 5: Deep Flatten (Maximum Column Extraction)

```powershell
# Base 29 columns + all CopilotEventData.* fields flattened
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ExplodeDeep `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02 `
  -OutputFile ".\Copilot_deep_flat.csv"
```

---

### Performance Tuning Examples

#### Example 6: Dense Data Period (Reduce Block Size)

```powershell
# Hitting 10K limits - reduce window to 15 minutes
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -BlockHours 0.25 `
  -StartDate 2025-10-03 `
  -EndDate 2025-10-03 `
  -ActivityTypes CopilotInteraction
```

#### Example 7: Sparse Historical Backfill (Increase Block Size)

```powershell
# Low activity period - use larger windows for speed
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -BlockHours 8 `
  -StartDate 2025-07-01 `
  -EndDate 2025-07-15 `
  -ActivityTypes CopilotInteraction
```

#### Example 8: Throttle Mitigation

```powershell
# Add pacing delays between API calls
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -PacingMs 300 `
  -ResultSize 5000 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

---

### Parallel Execution Examples (PowerShell 7+ Only)

#### Example 9: Automatic Parallel Mode

```powershell
# Let script decide whether to parallelize
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ParallelMode Auto `
  -ActivityTypes CopilotInteraction,MessageSent,FileAccessed,SearchQueryPerformed `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

#### Example 10: Forced Parallel with Custom Concurrency

```powershell
# Force parallel execution with higher thread count
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ParallelMode On `
  -MaxConcurrency 4 `
  -MaxParallelGroups 3 `
  -ActivityTypes CopilotInteraction,MessageSent,FileAccessed `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

---

### Authentication Examples

#### Example 11: Device Code Authentication

```powershell
# Best for remote/headless sessions
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -Auth DeviceCode `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

#### Example 12: Silent Authentication (Cached Token)

```powershell
# Reuse cached token from previous session
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -Auth Silent `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

---

### Offline Replay Examples

#### Example 13: Basic Replay (Forced Explosion)

```powershell
# Transform previously exported raw CSV - explosion forced
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -RAWInputCSV ".\output\Copilot_RAW_20251001.csv" `
  -OutputFile ".\Copilot_replay_exploded.csv"
```

#### Example 14: Replay with Date Filtering

```powershell
# Filter subset of dates from existing export
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -RAWInputCSV ".\output\Copilot_RAW_October.csv" `
  -StartDate 2025-10-05 `
  -EndDate 2025-10-07 `
  -OutputFile ".\Copilot_Oct5to7.csv"
```

#### Example 15: Replay with Deep Flatten + Activity Filter

```powershell
# Deep transformation on specific operations only
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -RAWInputCSV ".\output\Copilot_RAW_Q4.csv" `
  -ExplodeDeep `
  -ActivityTypes CopilotInteraction `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-31 `
  -OutputFile ".\Copilot_October_Deep.csv"
```

---

### Advanced Streaming Tuning Examples

#### Example 16: Wide Schema (High Schema Sample, Low Chunk Size)

```powershell
# Maximize column discovery, minimize peak memory
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ExplodeDeep `
  -StreamingSchemaSample 6000 `
  -StreamingChunkSize 1500 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02 `
  -OutputFile ".\Copilot_wide_schema.csv"
```

#### Example 17: Fast Freeze (Low Sample, High Chunk)

```powershell
# Quick header freeze for narrow/consistent schemas
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ExplodeDeep `
  -StreamingSchemaSample 500 `
  -StreamingChunkSize 10000 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02 `
  -OutputFile ".\Copilot_fast_freeze.csv"
```

---

### Production & Automation Examples

#### Example 18: Scheduled Daily Export (Task Scheduler / Cron)

```powershell
# Script for daily automated runs - captures previous day
# No dates needed - uses auto-default (previous full UTC day)
pwsh -File "C:\Scripts\PAX\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1" `
  -Auth Silent `
  -ExplodeArrays `
  -OutputFile "C:\AuditData\Daily\Copilot_$(Get-Date -Format 'yyyyMMdd').csv" `
```

#### Example 19: Multi-Week Historical Backfill

```powershell
# Large date range with optimized settings
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -StartDate 2025-09-01 `
  -EndDate 2025-10-01 `
  -BlockHours 2 `
  -PacingMs 200 `
  -ActivityTypes CopilotInteraction,MessageSent `
  -OutputFile ".\Copilot_September.csv"
```

#### Example 20: Clean Logs for CI/CD

```powershell
# Suppress progress for log file clarity
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02 `
  -OutputFile ".\Copilot.csv"
```

---

### Windows PowerShell 5.1 Examples

#### Example 21: PowerShell 5.1 with ExecutionPolicy Bypass

```powershell
# Windows PowerShell 5.1 invocation
powershell.exe -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02 `
  -OutputFile "C:\Temp\Copilot.csv"
```

---

### Activity Types Reference

**Common High-Volume Activities:**

- `CopilotInteraction` - Microsoft 365 Copilot usage events
- `MessageSent` - Teams/Exchange message sending
- `FileAccessed` - SharePoint/OneDrive file access
- `MailItemsAccessed` - Email access events

**Common Medium-Volume Activities:**

- `MessageRead` - Message read receipts
- `FileModified` - File edit operations
- `MeetingDetail` - Teams meeting metadata
- `SearchQueryPerformed` - Search queries

**Common Low-Volume Activities:**

- `CreatePlugin` - Copilot plugin creation
- `UpdatePlugin` - Plugin modifications
- `DeletePlugin` - Plugin removal
- `EnablePlugin` / `DisablePlugin` - Plugin state changes

**Finding Available Activities:**

```powershell
# Query all available record types
Get-UnifiedAuditLog -StartDate (Get-Date).AddDays(-1) -EndDate (Get-Date) -ResultSize 100 |
  Select-Object -Unique Operations |
  Sort-Object Operations
```

---

## Output Files & Schema

### Output Files

Every execution produces two files:

#### 1. CSV File (Data Export)

- **Location:** Specified by `-OutputFile` parameter
- **Encoding:** UTF-8 without BOM
- **Format:** Standard CSV with quoted fields
- **Header:** Always written (even when zero records match)
- **Line Endings:** CRLF on Windows, LF on macOS/Linux

#### 2. Log File (Execution Metrics)

- **Location:** Same directory as CSV, `.csv` replaced with `.log`
- **Contents:**
  - Runtime parameters and date range
  - Authentication and connection details
  - Adaptive block size decisions
  - Warnings (10K limits, throttling, truncation)
  - Performance metrics (query/explosion/export timing)
  - Per-activity record counts
  - Parallel execution summary
  - Error messages and stack traces

### Schema Modes

#### Standard Mode (Default - 1:1 Rows)

**Columns:** Base audit fields + single `CopilotEventData` JSON blob  
**Row Count:** One row per audit record  
**Use When:** Fastest processing, preserving original structure  
**Example Row:**

```csv
RecordId,CreationDate,Operation,UserId,CopilotEventData
abc123,2025-10-01T14:23:45.123Z,CopilotInteraction,user@domain.com,"{""Tokens"":150,""Model"":""GPT-4"",…}"
```

#### Exploded Arrays Mode (`-ExplodeArrays`)

**Columns:** Purview canonical 35-column schema  
**Row Count:** Multiple rows per audit record (one per array element combination)  
**Use When:** Matching Microsoft Purview export format, relational analysis  
**Base 35 Columns:**

1. `RecordId` - Unique audit record identifier (GUID)
2. `CreationDate` - UTC timestamp when record created (ISO 8601)
3. `RecordType` - Numeric record type (e.g., 261 = CopilotInteraction)
4. `Operation` - Operation name (e.g., "CopilotInteraction")
5. `UserId` - User principal name (UPN)
6. `AssociatedAdminUnits` - Admin unit IDs (semicolon-separated)
7. `AssociatedAdminUnitsNames` - Admin unit names (semicolon-separated)
8. `AgentId` - AI agent identifier
9. `AgentName` - AI agent display name
10. `AppIdentity` - Application identity object
11. `AppIdentity_DisplayName` - Application display name
12. `AppIdentity_PublisherId` - Publisher identifier
13. `ApplicationName` - Application name string
14. `CreationTime` - UTC timestamp of actual event occurrence
15. `ClientRegion` - Geographic region code
16. `ClientIP` - Client IP address
17. `Audit_UserId` - Audit-specific user identifier
18. `AppHost` - Hosting application identifier
19. `ThreadId` - Conversation thread identifier
20. `Context_Id` - Context identifier
21. `Context_Type` - Context type designation
22. `Message_Id` - Message unique identifier
23. `Message_isPrompt` - Boolean indicator (TRUE/FALSE)
24. `AccessedResource_Action` - Resource action type
25. `AccessedResource_PolicyDetails` - Policy metadata
26. `AccessedResource_SiteUrl` - SharePoint site URL
27. `AISystemPlugin_Id` - Plugin identifier
28. `AISystemPlugin_Name` - Plugin name
29. `ModelTransparencyDetails_ModelName` - AI model name
30. `MessageIds` - Related message IDs (semicolon-separated)
31. `OrganizationId` - Organization identifier (tenant ID)
32. `Version` - Schema version number
33. `UserType` - User type code (0=Regular, 2=Admin, etc.)
34. `CopilotLogVersion` - Copilot log schema version
35. `Workload` - Workload identifier

**Explosion Metadata Columns (when explosion occurs):**

- `ArrayIndex_Messages` - Index position in Messages array
- `ArrayIndex_Contexts` - Index position in Contexts array
- `ArrayIndex_References` - Index position in References array
- `ExplosionTruncated` - TRUE if row cap (1000) exceeded

#### Deep Flatten Mode (`-ExplodeDeep`)

**Columns:** Base 35 columns + all `CopilotEventData.*` dynamically flattened  
**Row Count:** Multiple rows per audit record  
**Use When:** Maximum data extraction, ML pipelines, wide-schema data warehouses  
**Additional Columns (examples):**

- `CopilotEventData.TokensPrompt` - Input token count
- `CopilotEventData.TokensCompletion` - Output token count
- `CopilotEventData.ModelFamily` - Model family designation
- `CopilotEventData.OutcomeStatus` - Success/failure status
- `CopilotEventData.DurationMs` - Request duration milliseconds
- `CopilotEventData.ConversationId` - Conversation identifier
- `CopilotEventData.TurnNumber` - Turn sequence number
- `CopilotEventData.AcceptanceRate` - Suggestion acceptance percentage
- `CopilotEventData.RetryCount` - Number of retries
- _(Hundreds more depending on event structure)_

**Schema Freeze Behavior:**

- First N rows (default 1000, configurable via `-StreamingSchemaSample`) determine column set
- Columns discovered after freeze are counted but ignored (warning emitted)
- Increase `-StreamingSchemaSample` if seeing late-ignored column warnings

### Date/Time Normalization

All timestamps normalized to ISO 8601 UTC with millisecond precision:

- **Format:** `yyyy-MM-ddTHH:mm:ss.fffZ`
- **Example:** `2025-10-01T14:23:45.123Z`
- **Columns Affected:** `CreationDate`, `CreationTime`, all other datetime fields

### Multi-Value Field Handling

Arrays and collections rendered as semicolon-delimited strings:

- **Format:** `value1; value2; value3`
- **Example:** `MessageId1; MessageId2; MessageId3`
- **Columns:** `MessageIds`, `AssociatedAdminUnits`, `AssociatedAdminUnitsNames`, etc.

### Boolean Normalization

Boolean values standardized:

- **True:** `TRUE`
- **False:** `FALSE`
- **Null/Empty:** (empty string)

---

## Advanced Features

### Adaptive Block Sizing

The script learns optimal time window sizes during execution:

**Initial Sizing:**

- **High-volume activities:** 30 minutes (0.5 hours)
- **Medium-volume activities:** 2 hours
- **Low-volume activities:** 8 hours
- **Custom/unknown:** `-BlockHours` parameter value

**Learning Behavior:**

- **Saturated window (exactly ResultSize records):** Shrink by 30% for next window
- **Sparse window (<10% of ResultSize):** Grow by 50% for next window
- **Failed window:** Shrink by 50% and retry

**Subdivision Strategy:**
When exactly 10,000 records returned (service limit):

1. Emits CRITICAL warning with time window details
2. Automatically subdivides window (binary or aggressive split)
3. Continues with smaller chunks
4. Logs recommendation to reduce `-BlockHours` for future runs

**Subdivision Sequence:**
`30min → 15min → 8min → 4min → 2min → 1min`

### Parallel Execution Engine (PowerShell 7+)

**Group Classification:**

- **High Volume:** `CopilotInteraction`, `MessageSent`, `FileAccessed`, `MailItemsAccessed`
- **Medium Volume:** `MessageRead`, `FileModified`, `MeetingDetail`, `SearchQueryPerformed`
- **Low Volume:** All plugin operations, custom activities

**Batching Strategy:**

- High-volume activities: Individual groups (1 activity per group)
- Medium-volume activities: Batches of 3
- Low-volume activities: Batches of 5

**Auto-Activation Criteria (`-ParallelMode Auto`):**
✅ PowerShell 7+  
✅ MaxParallelGroups > 0  
✅ MaxConcurrency > 1  
✅ ≤ 1 High-volume group  
✅ ≥ 1 Medium or Low-volume group  
✅ Total activities ≤ 15  
✅ Total groups > 1

**Manual Activation (`-ParallelMode On`):**

- Bypasses heuristics
- Requires PowerShell 7+
- Honors MaxConcurrency and MaxParallelGroups settings
- Monitor logs for throttling warnings

### Streaming Export Architecture

**Phase 1: Schema Sampling**

1. Collect first N rows (default 1000, `-StreamingSchemaSample`)
2. Discover all unique columns across samples
3. Freeze column order (deterministic across runs)
4. Write CSV header

**Phase 2: Chunked Processing**

1. Process rows in batches (default 5000, `-StreamingChunkSize`)
2. Flush each batch to file immediately
3. Dynamic chunk size adjustment:
   - **Narrow schemas (≤60 columns):** Boost to 15,000 rows
   - **Wide schemas (>250 columns):** Reduce progressively
     - > 250 cols: 3,500 rows
     - > 500 cols: 2,000 rows
     - > 750 cols: 1,500 rows
     - > 1000 cols: 1,000 rows

**Phase 3: Post-Freeze Handling**

- New columns after freeze: Count but ignore (warning emitted)
- Rows with new columns: Written with empty values for new columns
- Metrics: `postFreezeNewColumns` counter in log

**Memory Benefits:**

- Eliminates need to hold entire dataset in memory
- Predictable memory ceiling regardless of row count
- Suitable for multi-million row exports

### Offline Replay Mode

**Purpose:** Re-process previously exported raw Purview audit CSV files without querying Exchange Online

**Workflow:**

1. Initial export (live query, standard mode):

   ```powershell
   pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
     -StartDate 2025-10-01 `
     -EndDate 2025-10-31 `
     -OutputFile ".\October_RAW.csv"
   ```

2. Subsequent transformations (offline replay):

   ```powershell
   # Exploded version
   pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
     -RAWInputCSV ".\October_RAW.csv" `
     -OutputFile ".\October_Exploded.csv"

   # Deep flatten version
   pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
     -RAWInputCSV ".\October_RAW.csv" `
     -ExplodeDeep `
     -OutputFile ".\October_Deep.csv"

   # Filtered subset
   pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
     -RAWInputCSV ".\October_RAW.csv" `
     -StartDate 2025-10-15 `
     -EndDate 2025-10-20 `
     -ActivityTypes CopilotInteraction `
     -OutputFile ".\October_Mid_Copilot.csv"
   ```

**Requirements:**

- Source CSV must contain `AuditData` column with JSON
- Explosion mode automatically forced (cannot disable)
- Authentication skipped entirely

**Allowed Parameters with `-RAWInputCSV`:**
✅ `-StartDate` (optional filter)  
✅ `-EndDate` (optional filter)  
✅ `-ActivityTypes` (optional filter)  
✅ `-OutputFile`  
✅ `-ExplodeDeep`  
✅ `-ExportProgressInterval`  
✅ `-StreamingSchemaSample`  
✅ `-StreamingChunkSize`

**Disallowed Parameters (error if present):**
❌ `-Auth`  
❌ `-BlockHours`  
❌ `-ResultSize`  
❌ `-PacingMs`  
❌ `-ParallelMode`  
❌ `-MaxConcurrency`  
❌ `-MaxParallelGroups`  
❌ `-EnableParallel`

**Benefits:**

- Reproducible transformations for auditing
- Development/testing without live tenant access
- Multiple output formats from single raw export
- Experimentation with explosion settings

### Progress Tracking System

**Weighted Phases:**

- **Live Query + Explosion:** Query 30% | Explosion 60% | Export 10%
- **Live Query Only:** Query 80% | Export 20%
- **Replay Mode:** Parsing 10% | Explosion 80% | Export 10%

**Display Format:**

```
PAX Purview Audit Log Processing
Status: Query: 45/100(45%) | Explosion: 12000/25000(48%) | Export: 0/1(0%) :: 42%
```

**Batch Progress (Explosion Phase):**

```
Explosion: Records 5001-10000/50000 Batch: 2/~10(20%-40%) | Export: 0/1(0%) :: 68%
```

**Components:**

- **Overall percentage:** Weighted composite across all phases
- **Phase detail:** Current/Total (percentage) for each active phase
- **Batch info:** Current batch number, estimated total, percentage range
- **Record range:** Shows which records currently processing (in batches)

---

## Performance Tuning

### Hitting the 10K Service Limit

**Symptoms:**

- Log shows: `CRITICAL: 10K limit reached for time window <dates>`
- CSV may be incomplete for dense periods

**Immediate Action:**

```powershell
# Reduce block hours to 15 minutes or less
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -BlockHours 0.25 `
  -StartDate 2025-10-03 `
  -EndDate 2025-10-03
```

**Progressive Tuning:**

1. Start: `-BlockHours 0.5` (30 min) → If still hitting: `0.25` (15 min)
2. If still saturated: `0.133333` (8 min) → `0.066667` (4 min)
3. Minimum: `0.016667` (1 min)

**Verification:**

- Check log for "Data retrieval completed without hitting limits"
- Compare record counts across runs
- Monitor `Hit10KLimit` flag in metrics section

### Throttling & Rate Limiting

**Symptoms:**

- Frequent "429 Too Many Requests" errors
- Extended retry sequences in logs
- Slow overall completion times

**Mitigation Strategies:**

**Strategy 1: Add Pacing**

```powershell
# Conservative: 250-500ms between pages
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -PacingMs 300 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**Strategy 2: Reduce ResultSize**

```powershell
# Fetch fewer records per window
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ResultSize 5000 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**Strategy 3: Disable/Reduce Parallelism**

```powershell
# Force sequential processing
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ParallelMode Off `
  -ActivityTypes CopilotInteraction,MessageSent `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**Strategy 4: Run Off-Peak**

- Schedule during low-tenant-usage hours (nights, weekends)
- Avoid concurrent audit queries from other tools

### Memory Optimization

**For Wide Schemas (ExplodeDeep):**

```powershell
# Increase schema sample, decrease chunk size
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ExplodeDeep `
  -StreamingSchemaSample 5000 `
  -StreamingChunkSize 1500 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**For Narrow Schemas (Fast Processing):**

```powershell
# Decrease sample, increase chunk for throughput
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ExplodeArrays `
  -StreamingSchemaSample 500 `
  -StreamingChunkSize 10000 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**Large Date Ranges:**

- Break into smaller chunks (weekly/monthly)
- Process sequentially rather than one massive run
- Monitor disk space for output files

### Speed Optimization

**Fastest Configuration:**

```powershell
# Standard mode, no explosion, large blocks, no progress UI
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -BlockHours 4 `
  -StartDate 2025-09-01 `
  -EndDate 2025-09-30
```

**Parallel Speed (PS7+):**

```powershell
# Force parallel with multiple activity types
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ParallelMode On `
  -MaxConcurrency 4 `
  -MaxParallelGroups 3 `
  -ActivityTypes CopilotInteraction,MessageSent,FileAccessed,MeetingDetail `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**Benchmark Expectations (typical tenant):**

- **Standard mode:** 50,000-100,000 records/hour
- **Exploded mode:** 30,000-60,000 records/hour
- **Deep flatten mode:** 10,000-30,000 records/hour
- **Replay transformation:** 100,000-500,000 records/hour (CPU-bound)

---

## Troubleshooting & FAQ

### Common Issues

#### Issue: Zero Records Returned (Header-Only CSV)

**Symptoms:**

- CSV file contains only header row
- Log shows "Records exported: 0"

**Causes & Solutions:**

| Cause                     | Solution                                                                   |
| ------------------------- | -------------------------------------------------------------------------- |
| No activity in date range | Verify audit events exist: `Search-UnifiedAuditLog` manually               |
| Incorrect date format     | Ensure `yyyy-MM-dd` format, UTC interpretation                             |
| Insufficient permissions  | Verify audit log roles: `Get-ManagementRoleAssignment`                     |
| Audit logging disabled    | Check: `Get-AdminAuditLogConfig \| Select UnifiedAuditLogIngestionEnabled` |
| Time zone confusion       | Dates are UTC; convert local times before passing                          |

**Verification:**

```powershell
# Manual test query
Connect-ExchangeOnline
Search-UnifiedAuditLog -StartDate "10/01/2025" -EndDate "10/02/2025" -Operations CopilotInteraction -ResultSize 10
```

---

#### Issue: 10K Limit Warnings

**Symptoms:**

- Log shows: `CRITICAL: 10K limit reached`
- `Hit10KLimit: True` in metrics
- Missing records suspected

**Solution:**

```powershell
# Reduce block hours incrementally
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -BlockHours 0.25 `  # Start with 15 minutes
  -StartDate 2025-10-03 `
  -EndDate 2025-10-03

# If still hitting limit, go smaller
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -BlockHours 0.066667 `  # 4 minutes
  -StartDate 2025-10-03 `
  -EndDate 2025-10-03
```

**Verification:**

- Re-run with reduced `-BlockHours`
- Check log for "Data retrieval completed without hitting limits"
- Compare record counts between runs

---

#### Issue: Frequent Throttling (429 Errors)

**Symptoms:**

- Many retry attempts in log
- Extended execution times
- "Too Many Requests" errors

**Solutions:**

**Step 1: Add Pacing**

```powershell
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -PacingMs 500 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**Step 2: Reduce Concurrency**

```powershell
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ParallelMode Off `
  -ResultSize 5000 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**Step 3: Schedule Off-Peak**

- Run during nights/weekends
- Avoid overlap with other audit tools
- Coordinate with tenant admin team

---

#### Issue: Slow Deep Flatten Performance

**Symptoms:**

- Explosion phase takes hours
- High CPU usage
- Large CSV output (hundreds of MB)

**Solutions:**

**Test First:**

```powershell
# Always test deep flatten with short date range
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ExplodeDeep `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-01  # Single day only
```

**Optimize Settings:**

```powershell
# Balance schema width vs. memory
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ExplodeDeep `
  -StreamingSchemaSample 3000 `
  -StreamingChunkSize 2500 `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**Alternative:**

- Use standard `-ExplodeArrays` instead (much faster)
- Do deep analysis on subset of records only
- Post-process deep flatten in dedicated BI tool

---

#### Issue: Parallel Mode Ignored

**Symptoms:**

- Log shows "Parallel mode: Off" despite setting `-ParallelMode Auto`
- Sequential execution even with multiple activities

**Causes:**

| Condition              | Auto Eligibility  |
| ---------------------- | ----------------- |
| PowerShell 5.1         | ❌ Requires PS7+  |
| >1 High-volume groups  | ❌ Fails criteria |
| Zero Medium/Low groups | ❌ Fails criteria |
| >15 total activities   | ❌ Fails criteria |
| Single group           | ❌ Fails criteria |
| MaxConcurrency = 1     | ❌ Fails criteria |

**Solutions:**

**Check PowerShell Version:**

```powershell
$PSVersionTable.PSVersion  # Should be 7.0+
```

**Force Parallel (if PS7+):**

```powershell
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ParallelMode On `
  -MaxConcurrency 3 `
  -ActivityTypes CopilotInteraction,MessageSent,FileAccessed `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**Review Heuristics in Log:**

```
Auto criteria (PS7+, MPG>0, MC>1, <=1 High, >=1 Med/Low, activities<=15, groups>1): not met
High=2 Medium=0 Low=0 Activities=2 Groups=2
```

---

#### Issue: Late-Ignored Columns Warning

**Symptoms:**

- Log shows: "NOTICE: N row(s) contained new columns after schema freeze (ignored)"
- Some fields missing from output

**Cause:**

- Column discovered after initial schema sample
- Heterogeneous data structures across records
- `-StreamingSchemaSample` too small

**Solution:**

```powershell
# Increase schema sample size
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ExplodeDeep `
  -StreamingSchemaSample 5000 `  # Up from default 1000
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**Trade-off:**

- Larger sample = more complete schema, slower header freeze
- Smaller sample = faster start, risk missing columns
- Review log for list of ignored columns to assess impact

---

#### Issue: Authentication Failures

**Symptoms:**

- "Access Denied" errors
- "Unable to connect to Exchange Online"
- MFA challenges failing

**Solutions:**

**Verify Permissions:**

```powershell
Connect-ExchangeOnline
Get-ManagementRoleAssignment -RoleAssignee your.email@domain.com |
  Where-Object {$_.Role -like "*Audit*"}
```

**Try Alternative Auth:**

```powershell
# Device code for MFA
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -Auth DeviceCode `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

**Check Module Version:**

```powershell
Get-Module -Name ExchangeOnlineManagement -ListAvailable
Update-Module -Name ExchangeOnlineManagement
```

---

#### Issue: Replay Mode Errors

**Symptoms:**

- "ERROR: -RAWInputCSV cannot be combined with..."
- File not found errors
- Parsing failures

**Solutions:**

**Check File Path:**

```powershell
# Verify file exists and has AuditData column
Import-Csv ".\path\to\file.csv" | Select-Object -First 1 | Get-Member
```

**Remove Conflicting Parameters:**

```powershell
# WRONG - has live query params
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -RAWInputCSV ".\export.csv" `
  -Auth WebLogin `  # ❌ Not allowed
  -BlockHours 2     # ❌ Not allowed

# CORRECT - only filtering params
pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -RAWInputCSV ".\export.csv" `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02 `
  -ExplodeDeep
```

**Verify CSV Format:**

- Must have `AuditData` column with JSON
- Use standard Purview export format
- Check for encoding issues (UTF-8 expected)

---

### Frequently Asked Questions

#### Q: Does the script modify or delete any audit data?

**A:** No. The script is read-only. It queries the Unified Audit Log via `Search-UnifiedAuditLog` cmdlet and exports to CSV. No write operations are performed on Microsoft 365 services.

---

#### Q: How are time zones handled?

**A:** All dates are interpreted as UTC. Input parameters (`-StartDate`, `-EndDate`) must be in UTC. Output timestamps (`CreationDate`, `CreationTime`) are UTC in ISO 8601 format (`yyyy-MM-ddTHH:mm:ss.fffZ`). Convert local times to UTC before passing to script.

---

#### Q: Can I filter by specific users or models at query time?

**A:** Not directly. The `Search-UnifiedAuditLog` cmdlet filters by operation/date only. For user/model filtering, export all data then post-process:

```powershell
# Export all, filter in Power Query or SQL
Import-Csv ".\Copilot.csv" | Where-Object {$_.UserId -eq "user@domain.com"}
```

---

#### Q: What's the maximum flatten depth?

**A:**

- **Standard explosion:** 60 levels
- **Deep flatten (`-ExplodeDeep`):** 120 levels
- **JSON serialization:** 60 levels (all modes)
- Constants: `$FlatDepthStandard`, `$FlatDepthDeep`, `$JsonDepth` (can be modified in script)

---

#### Q: How long are audit logs retained?

**A:**

- **Audit Standard:** 180 days (changed from 90 days after October 17, 2023)
- **Audit Premium:** 1 year (E5 licenses) or up to 10 years with add-ons
- Verify your tenant's retention: `Get-AdminAuditLogConfig`

---

#### Q: Can I run this on a schedule?

**A:** Yes. Recommended approach:

```powershell
# Daily Task Scheduler / Cron job
pwsh -File "C:\Scripts\PAX\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1" `
  -Auth Silent `
  -ExplodeArrays `
  -OutputFile "C:\AuditArchive\Daily_$(Get-Date -Format 'yyyyMMdd').csv" `
# Dates default to previous full UTC day when omitted
```

**Task Scheduler Setup (Windows):**

1. Program: `pwsh.exe`
2. Arguments: `-File "C:\Scripts\PAX\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1" -Auth Silent
3. Schedule: Daily, 2:00 AM
4. Run with: Service account with audit permissions

---

#### Q: How do I join audit data with license information?

**A:** Audit logs don't contain license data. Export separately and join:

```powershell
# Step 1: Export audit data
.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# Step 2: Export license data (requires Microsoft.Graph module)
Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All"
Get-MgUser -All | Select-Object UserPrincipalName, AssignedLicenses |
  Export-Csv ".\licenses.csv"

# Step 3: Join in Power Query, SQL, or pandas
# Match on UserPrincipalName (audit UserId) = UserPrincipalName (license)
```

---

#### Q: What if I see "ExplosionTruncated: TRUE" in output?

**A:** One or more audit records expanded to >1000 rows (per-record cap). This is rare but possible with extremely large arrays.

**Mitigation:**

- Review affected records manually
- Consider narrower date ranges
- Filter to specific operations with `-ActivityTypes`
- Investigate data quality (unusually large arrays may indicate issues)

**Check Metrics:**

```
Explosion events: 1523 | Max rows in a single record: 847
WARNING: One or more exploded records exceeded row cap (1000) and were truncated.
```

---

#### Q: Can I use this for non-Copilot activities?

**A:** Absolutely. The script supports ANY operation available in Unified Audit Log:

```powershell
# SharePoint activity
.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ActivityTypes FileAccessed,FileModified,FileDeleted `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02

# Exchange activity
.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ActivityTypes MessageSent,MessageReceived,MailItemsAccessed `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02

# Teams activity
.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -ActivityTypes MeetingDetail,MessageSent,CallRecord `
  -StartDate 2025-10-01 `
  -EndDate 2025-10-02
```

---

#### Q: How do I calculate ROI from the exported data?

**A:** Use token counts and time savings:

```sql
-- Example SQL query on exported data
SELECT
  UserId,
  COUNT(*) as Interactions,
  SUM(CAST(CopilotEventData_TokensPrompt as INT) +
      CAST(CopilotEventData_TokensCompletion as INT)) as TotalTokens,
  AVG(CAST(CopilotEventData_DurationMs as INT)) as AvgLatencyMs,
  SUM(CASE WHEN CopilotEventData_AcceptanceRate > 0.5 THEN 1 ELSE 0 END) as HighAcceptanceCount
FROM CopilotAudit
WHERE CreationDate BETWEEN '2025-10-01' AND '2025-10-31'
GROUP BY UserId
```

**ROI Metrics:**

- Token consumption → API costs
- Acceptance rates → User satisfaction
- Interaction frequency → Adoption rates
- Time saved per interaction → Productivity gains

---

#### Q: What's the difference between `CreationDate` and `CreationTime`?

**A:**

- **`CreationDate`:** When the audit record was ingested into the log system
- **`CreationTime`:** When the actual event occurred
- Usually very close (seconds/minutes apart)
- Use `CreationTime` for event analysis
- Use `CreationDate` for audit trail integrity

---

#### Q: Can I export to formats other than CSV?

**A:** CSV is the only native format. For other formats, post-process:

```powershell
# CSV to JSON
$data = Import-Csv ".\Copilot.csv"
$data | ConvertTo-Json -Depth 10 | Out-File ".\Copilot.json"

# CSV to Excel (requires ImportExcel module)
Install-Module -Name ImportExcel
Import-Csv ".\Copilot.csv" | Export-Excel ".\Copilot.xlsx" -AutoSize -TableName "CopilotAudit"

# CSV to Azure SQL / Synapse
# Use Data Factory, SSIS, or bcp utility
```

---

#### Q: How do I handle very large exports (millions of rows)?

**A:** Chunking strategies:

**Option 1: Date Sharding**

```powershell
# Process one week at a time
$start = Get-Date "2025-01-01"
$end = Get-Date "2025-12-31"
while ($start -lt $end) {
  $weekEnd = $start.AddDays(7)
  if ($weekEnd -gt $end) { $weekEnd = $end }

  .\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
    -StartDate $start.ToString('yyyy-MM-dd') `
    -EndDate $weekEnd.ToString('yyyy-MM-dd') `
    -OutputFile ".\Archive\Copilot_$($start.ToString('yyyyMMdd')).csv" `
  $start = $weekEnd
}
```

**Option 2: Streaming Settings**

```powershell
# Optimize for large datasets
.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 `
  -StreamingSchemaSample 2000 `
  -StreamingChunkSize 10000 `
  -StartDate 2025-01-01 `
  -EndDate 2025-12-31
```

**Option 3: Direct DB Load**

```powershell
# Export and load in batches
.\PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
# Then use SQL BULK INSERT or Azure Data Factory
```

---

## Known Limitations

| Area                         | Limitation                                         | Mitigation                                               |
| ---------------------------- | -------------------------------------------------- | -------------------------------------------------------- |
| **Service Cap**              | 10,000 records per `Search-UnifiedAuditLog` window | Reduce `-BlockHours`, script auto-subdivides             |
| **Explosion Row Cap**        | 1,000 exploded rows per original record            | Review affected records, filter operations               |
| **JSON Depth**               | Serialization depth 60 levels                      | Extremely rare; adjust `$JsonDepth` constant if needed   |
| **Flatten Depth**            | Standard 60 / Deep 120 recursion levels            | Adjust `$FlatDepthStandard` / `$FlatDepthDeep` constants |
| **Replay Non-Exploded**      | Cannot replay in 1:1 standard mode                 | Use live query for standard mode output                  |
| **Parallel Single Activity** | Parallel only helps multi-activity sets            | Accept serial path or add more activity types            |
| **Module Dependency**        | Requires ExchangeOnlineManagement                  | Auto-check at runtime; install if missing                |
| **Date Filtering**           | UTC only, no time-of-day granularity               | Filter by hour post-export if needed                     |
| **User/Model Filtering**     | No source filtering in query                       | Post-process CSV for user/model filtering                |
| **Real-Time**                | Not designed for streaming/live monitoring         | Use Microsoft Sentinel for real-time scenarios           |
| **Chain of Custody**         | No cryptographic hashing/signing                   | Implement external hash verification if required         |

**Architectural Constraints:**

- **Memory:** Streaming mitigates most issues; extremely wide schemas (>2000 cols) may challenge chunk processing
- **Disk I/O:** CSV writes are chunked and flushed; ensure sufficient disk space (estimate 1-5KB per row)
- **Network:** Relies on stable internet; transient failures handled via retry logic
- **Authentication:** Token expiration during long runs (hours+) may require re-authentication

---

## Security & Compliance

### Data Handling

**No Anonymization:**

- Script exports data as-is from audit logs
- User identities (UPN), IP addresses, and content metadata included
- Treat output files as sensitive/confidential

**Access Control:**

- Store CSV and log files in secure locations
- Apply ACLs to restrict access to authorized personnel only
- Consider encryption at rest for archived files

**Data Retention:**

- Apply external retention policies matching regulatory requirements
- Audit logs have built-in retention; exports are YOUR responsibility
- Document retention schedule and destruction procedures

### Network Security

**Endpoints Accessed:**

- `*.protection.outlook.com` (Exchange Online Management)
- `login.microsoftonline.com` (Azure AD authentication)
- `*.office365.com` (Microsoft 365 services)

**Firewall Rules:**

- Ensure outbound HTTPS (443) allowed to above domains
- Use proxy/PAC files if organizational policy requires

### Authentication Security

**Credential Storage:**

- Script does NOT store credentials to disk
- Credentials held in memory only during execution
- Clear PowerShell session history if credential prompts used

**Token Caching:**

- ExchangeOnlineManagement module may cache tokens per Microsoft Graph SDK behavior
- Tokens stored in user profile (encrypted by OS)
- Use `-Auth Silent` for token reuse; automatic expiration after ~1 hour

**Recommended Practices:**

- Use service accounts with minimum required permissions (View-Only Audit Logs)
- Enable MFA on accounts with audit access
- Rotate service account credentials regularly
- Monitor audit logs for script usage (log the logger!)

### Compliance Considerations

**Regulatory Frameworks:**

- **GDPR:** Audit data may contain PII; apply data minimization and purpose limitation
- **HIPAA:** Healthcare audit data requires BAA coverage and encryption
- **SOX:** Financial audit trails should include hash verification
- **ISO 27001:** Document script usage in ISMS procedures

**Audit Trail:**

- Script logs all executions with timestamps, parameters, and outcomes
- Retain log files alongside CSV exports for complete audit trail
- Consider forwarding logs to SIEM (Splunk, Sentinel, etc.)

**Validation:**

- Compare record counts against Microsoft Purview compliance portal
- Spot-check exported data against source audit logs
- Validate schema consistency across runs

### Responsible Disclosure

Security vulnerabilities should be reported privately:

1. **DO NOT** open public GitHub issues for security concerns
2. Follow process in **[SECURITY.md](./SECURITY.md)**
3. Allow reasonable time for patching before public disclosure
4. Security researchers eligible for acknowledgment (with permission)

---

## Contributing

Community contributions are welcome! By participating, you agree to follow our **[Code of Conduct](./CODE_OF_CONDUCT.md)**.

### Contribution Workflow

**Step 1: Open an Issue**

- Describe enhancement, bug, or feature request
- Include repro steps for bugs (PowerShell version, parameters, error messages)
- Tag appropriately (bug, enhancement, documentation, etc.)

**Step 2: Fork & Branch**

```bash
git clone https://github.com/<your-username>/PAX.git
cd PAX
git checkout -b feat/short-description  # or fix/short-description
```

**Step 3: Make Changes**

- Keep commits focused and atomic
- Update documentation if behavior changes
- Add examples for new features
- Test with both PowerShell 5.1 and 7+

**Step 4: Submit Pull Request**

- Reference the related issue number
- Describe changes and rationale
- Include before/after examples for UI/output changes
- Respond to review feedback

**Step 5: Review & Merge**

- Maintainers will review within 1-2 weeks (best effort)
- CI validates syntax and basic execution (if configured)
- Squash commits if requested for clean history

### Scope Guidelines

**In-Scope Contributions:**

- Bug fixes (authentication, parsing, performance)
- New explosion modes or schema variations
- Performance optimizations (memory, speed, parallelism)
- Documentation improvements (examples, FAQ, troubleshooting)
- Error handling and retry logic enhancements
- Support for additional activity types

**Out-of-Scope:**

- Real-time streaming or event-driven architectures (different design paradigm)
- GUI/web interfaces (CLI-first philosophy)
- Non-audit-log data sources (scope creep)
- Major rewrites without prior discussion (open issue first!)

### Code Standards

- **Style:** Follow existing PowerShell conventions (PascalCase functions, camelCase variables)
- **Comments:** Explain WHY, not WHAT (code should be self-documenting)
- **Error Handling:** Use try/catch with actionable error messages
- **Logging:** Use `Write-LogHost` for user-facing messages, `Write-Log` for file-only
- **Testing:** Validate with `-StartDate 2025-01-01 -EndDate 2025-01-02` (minimal run)

### Security-Impacting Changes

Changes affecting authentication, script execution policy, module installation, or credential handling require:

- Detailed risk assessment in PR description
- Consideration of least-privilege principles
- Validation on multiple OS platforms (Windows, macOS, Linux for PS7+)
- Documentation of security tradeoffs

---

## License & Disclaimer

**License:** MIT License - see [LICENSE](./LICENSE) for full text

**Copyright:** © Microsoft Corporation

**Disclaimer:** This script is provided "AS IS" without warranties or official support. Validate fit for purpose before production use. Not endorsed or officially supported by Microsoft Product Groups. Community-driven maintenance model.

---

## Additional Resources

### Documentation

| `PacingMs` | 0 | Inter-page delay for throttle tuning |
| `ActivityTypes` | CopilotInteraction | Operations set |
| `ExplodeArrays` | (off) | Purview exploded 35-column schema |
| `ExplodeDeep` | (off) | 35-column schema + deep CopilotEventData.\* |
| `RAWInputCSV` | (blank) | Offline replay of prior raw Purview audit CSV (forces explosion) |
| `MaxConcurrency` | 2 | Per-group concurrency cap |
| `ParallelMode` | Off | Off / On / Auto (heuristic) |
| `MaxParallelGroups` | 3 | Limit concurrent groups |
| `ExportProgressInterval` | 10 | Row interval for export updates |

Date range tip: If 10K window warnings appear, reduce `BlockHours` or shorten the total span.

Live date defaults: Omitting BOTH `StartDate` and `EndDate` in live mode auto-runs for the previous full UTC day. Provide both to override (partial specification is rejected).
Replay date behavior: With `-RAWInputCSV`, omitting `StartDate`/`EndDate` applies no date filtering (entire CSV ingested). Supplying either/both filters by `CreationDate` (inclusive lower / exclusive upper).

RAWInputCSV notes: When you supply `-RAWInputCSV` the script skips live queries and always produces at least the 35‑column exploded schema. Allowed additional switches with `-RAWInputCSV`: `StartDate`, `EndDate`, `ActivityTypes`, `OutputFile`, `-ExplodeDeep`, `-ExportProgressInterval`, `-StreamingSchemaSample`, `-StreamingChunkSize`. Disallowed (error if present): `BlockHours`, `ResultSize`, `PacingMs`, `Auth`, `ParallelMode`, `MaxParallelGroups`, `MaxConcurrency`, `EnableParallel`.

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
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -OutputFile .\replay_exploded.csv

# Replay with date & activity filtering + deep flatten
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -ActivityTypes CopilotInteraction -OutputFile .\replay_deep.csv

# Replay limiting to multiple operations
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ActivityTypes CopilotInteraction MessageSent FileAccessed -OutputFile .\replay_multi.csv
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
| `ExportProgressInterval`  | Optional         | Optional              | Affects row progress emission; replay counts exploded rows         |
| `StreamingSchemaSample`   | Optional         | Optional              | Initial sampling for column discovery                              |
| `StreamingChunkSize`      | Optional         | Optional              | CSV flush batch size                                               |

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
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile .\Copilot.csv

# Array explosion
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile .\Copilot_exploded.csv

# Deep flatten + explosion
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile .\Copilot_deep.csv

# Offline replay (forced explosion)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -OutputFile .\Copilot_replay_exploded.csv

# Offline replay deep flatten + filtering
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -ActivityTypes CopilotInteraction -OutputFile .\Copilot_replay_deep.csv

# Parallel heuristic (PS7+)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -ParallelMode Auto -ActivityTypes CopilotInteraction MessageSent FileAccessed

# Force parallel
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -ParallelMode On -MaxConcurrency 3 -MaxParallelGroups 2 -ActivityTypes CopilotInteraction MessageSent

# Deep flatten (wide schema) – advanced streaming tuning
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 4000 -StreamingChunkSize 3000 -OutputFile .\Copilot_deep_tuned.csv

# Extremely wide / memory sensitive: increase sample to capture columns, shrink chunk to lower peak memory
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 6000 -StreamingChunkSize 1500 -OutputFile .\Copilot_deep_memoryguard.csv

# Faster header freeze for narrow schemas (accept risk of late columns ignored)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 800 -StreamingChunkSize 6000 -OutputFile .\Copilot_deep_fastfreeze.csv

# Replay deep flatten with tuned streaming (large historical file)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ExplodeDeep -StreamingSchemaSample 5000 -StreamingChunkSize 2500 -OutputFile .\Copilot_replay_deep_tuned.csv
```

Windows PowerShell 5.1: prefix with `powershell -File`; PS 7+: `pwsh -File` (syntax identical).

---

### 23. Comprehensive Examples

Below is a fuller catalog of invocation patterns. Adjust paths/dates as needed. Dates are UTC.

```powershell
# 1. Minimal (defaults for everything else)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# 2. Specify explicit output path (creates folder if missing)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile C:\Data\Copilot\copilot_20251001.csv

# 3. Multiple activity types (mix of presumed high & medium volume)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-03 -ActivityTypes CopilotInteraction MessageSent FileAccessed MeetingDetail

# 4. Narrow block size to improve completeness under heavy load
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-05 -EndDate 2025-10-05 -BlockHours 0.25

# 5. Larger initial block (sparse historical data, multi-day span)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-09-01 -EndDate 2025-09-04 -BlockHours 4

# 6. Reduce ResultSize (fetch fewer records per window intentionally)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -ResultSize 2500

# 7. Add pacing between pages (mitigate throttling bursts)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-02 -EndDate 2025-10-03 -PacingMs 500

# 8. Array explosion only (one extra row per element of target arrays)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile .\copilot_exploded.csv

# 9. Deep flatten (explosion + wide column set)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile .\copilot_deep.csv

# 10. Parallel (forced) with tuned concurrency (PS 7+ only)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -ParallelMode On -MaxConcurrency 4 -MaxParallelGroups 3 -ActivityTypes CopilotInteraction MessageSent FileAccessed MeetingDetail SearchQueryPerformed

# 11. Parallel heuristic (Auto) – lets script decide
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -ParallelMode Auto -ActivityTypes CopilotInteraction MessageSent FileAccessed

# 12. Disable progress UI (clean logs / quiet CI runs)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
# 13. Increase export progress granularity (update every 1 row)
./PAX_Purview_Audit_Log_Processor_v1.5.6.ps1 -StartDate 2025-10-01 -EndDate 2025-10-01 -ExportProgressInterval 1

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
