# Release Notes: v1.8.0

## Release Information

- **Version:** 1.8.0
- **Release Date:** 2025-11-07
- **Released By:** Brian Middendorf (@microsoft)
- **Previous Version:** v1.7.4

---

## Overview

Version 1.8.0 is a **major feature release** introducing **dual-mode architecture** with Microsoft Graph API as the new default, **Entra ID user enrichment**, enhanced Excel export capabilities, improved operational resilience, and **simplified CSV output behavior** (now defaults to separate files per activity type). This release represents a significant evolution in data enrichment and modernization while maintaining full backward compatibility.

### What Changed

**1. Dual-Mode Architecture (Graph API + EOM)**
- **Microsoft Graph API is now the default** for audit log retrieval (replaces Exchange Online Management as default)
- New `-UseEOM` switch enables legacy EOM mode when needed
- Graph API provides foundation for advanced features (Entra enrichment, future enhancements)
- EOM mode preserved for `-GroupNames` filtering and legacy compatibility scenarios

**1a. CSV Export Default Behavior Change (`-CombineOutput` Simplified)**
- **BREAKING CHANGE:** CSV exports now default to **separate files per activity type** (was: combined file)
- **Simplified `-CombineOutput` parameter:** Now a simple switch (was: nullable bool with complex logic)
- **New default:** CSV produces one file per activity type (e.g., `Purview_CopilotInteraction_Export_<timestamp>.csv`, `Purview_ConnectedAIAppInteraction_Export_<timestamp>.csv`)
- **To combine:** Add `-CombineOutput` switch to merge all activity types into single `Purview_Audit_CombinedUsageActivity_<timestamp>.csv`
- **Excel unchanged:** Still defaults to multi-tab workbook (one tab per activity type); use `-CombineOutput` for single combined tab
- **Rationale:** Separate files enable parallel processing, easier activity-specific analysis, and align with Excel multi-tab default behavior

**Migration Note:** If your automation expects a single CSV file, add `-CombineOutput` to maintain v1.7.4 behavior:
```powershell
# v1.7.4 default behavior (combined CSV)
./PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
# Output: Single combined CSV

# v1.8.0 NEW default behavior (separate CSVs)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
# Output: Separate CSV per activity type

# v1.8.0 with -CombineOutput (matches v1.7.4 behavior)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -CombineOutput
# Output: Single combined CSV (same as v1.7.4)
```

**2. Entra ID User Enrichment (`-IncludeUserInfo`)**
- **New feature:** Comprehensive user profile enrichment from Microsoft Entra ID
- Includes: DisplayName, GivenName, Surname, Department, JobTitle, Manager, M365 Copilot license detection, AccountEnabled, LastSignIn, and more
- Graph API exclusive feature (not available with `-UseEOM`)
- Output: Separate `EntraUsers_MAClicensing_<timestamp>.csv` (CSV mode) or embedded `EntraUsers_MAClicensing` tab (Excel mode)
- Automatic license SKU detection for M365 Copilot entitlements

**2a. User-Only Export Mode (`-OnlyUserInfo`)**
- **New feature:** Export ONLY Entra user directory and license data (skips all audit log queries)
- Ultra-fast execution (5-15 seconds vs. minutes/hours for audit queries)
- Ideal for license compliance snapshots, user directory exports, and periodic licensing audits
- Compatible with: `-OutputPath`, `-Auth`, `-ExportWorkbook`
- **NOT compatible with `-AppendFile`** (EntraUsers data represents point-in-time snapshots, not time-based activity data)
- Incompatible with: All audit-related parameters (dates, activity types, filtering, explosion, etc.)
- Output: Standalone `EntraUsers_MAClicensing_<timestamp>.csv` or Excel workbook with single tab

**3. Excel Export Enhancements**
- **Combined mode file naming:** `Purview_Audit_CombinedUsageActivity_<timestamp>.xlsx` (new naming convention)
- **Entra-enriched naming:** `Purview_Audit_CombinedUsageActivity_EntraUsers_MAClicensing_<timestamp>.xlsx`
- `EntraUsers_MAClicensing` tab automatically embedded in Excel workbooks when `-IncludeUserInfo` used

**4. Redesigned `-AppendFile` Parameter (Global Output Feature)**

> **⚡ BREAKING CHANGE:** `-AppendFile` redesigned from boolean switch to string parameter accepting filename or full path

**Overview:**
The `-AppendFile` parameter enables **incremental dataset building** across multiple script executions - a critical feature for enterprise customers managing continuous audit trails, multi-month datasets, and scheduled reporting workflows.

**What Changed:**
- **v1.7.4 and earlier:** `-AppendFile` was a switch parameter (boolean flag) with pattern-based file discovery
- **v1.8.0 and later:** `-AppendFile` accepts a **string value** (filename or full path) for explicit control

**Why This Matters:**
- **Fortune 500 use case:** Organizations building 90-day rolling audit datasets updated daily via scheduled tasks
- **Predictable behavior:** Explicit filename/path eliminates ambiguity in multi-file scenarios
- **Better automation:** Scheduled tasks can specify exact files without pattern-matching logic
- **Path flexibility:** Support both relative filenames (with `-OutputPath`) and absolute paths

**Core Capabilities:**

✅ **Dual Format Support:** Works with both CSV and Excel exports  
✅ **Live & Offline Modes:** Supports live API queries and offline replay (`-RAWInputCSV`)  
✅ **Smart Header Validation:** CSV exits on mismatch; Excel creates timestamped duplicate tabs  
✅ **File Lock Detection:** Pre-flight checks identify files open in Excel or with permission issues  
✅ **Multi-Tab Intelligence:** Excel mode handles multiple activity types independently  

**Usage Examples:**

```powershell
# Relative filename (uses -OutputPath directory)
-AppendFile "Report.csv"                    # → Appends to <OutputPath>\Report.csv
-AppendFile "Monthly_Audit.xlsx"            # → Appends to <OutputPath>\Monthly_Audit.xlsx

# Absolute path (ignores -OutputPath)
-AppendFile "C:\Data\Archive\Q4_Audit.xlsx"   # → Exact path specified
-AppendFile "\\FileShare\Reports\Audit.csv"   # → Network path supported
```

**Restrictions:**

| Restriction | Reason |
|-------------|--------|
| ❌ Cannot use with `-IncludeUserInfo` | EntraUsers data is point-in-time snapshots, not time-based activity |
| ❌ Cannot use with `-OnlyUserInfo` | Same reason (EntraUsers mode outputs user snapshots only) |
| ✅ Requires single-file output | Must use: `-ExportWorkbook`, `-CombineOutput`, or single activity type |
| ✅ File must exist first | Run once without `-AppendFile` to create initial file |

**Behavior by Format:**

**CSV Mode:**
- **Header Validation:** Reads first row, compares against new data (case-sensitive, order-sensitive)
- **Exact Match Required:** Column names must match exactly
- **Mismatch Handling:** Script exits with detailed diff showing missing/extra columns
- **Append Operation:** Opens in append mode, writes new rows without duplicate header
- **Safety:** Never overwrites existing data (exits cleanly on validation failure)

**Excel Mode:**
- **Sheet Discovery:** Reads all existing worksheet names
- **Header Validation:** Compares new data headers against each tab's first row
- **Matching Headers:** Appends rows directly to existing tabs
- **Mismatched Headers:** Creates timestamped duplicate tabs (e.g., `CopilotInteraction_20251110_143022`)
- **Multi-Tab Support:** Handles multiple activity types independently
- **Safety:** Never overwrites data (creates new tabs on schema mismatch)

**File Path Resolution:**

| Scenario | `-AppendFile` Value | `-OutputPath` Value | Result |
|----------|---------------------|---------------------|--------|
| Full path | `"C:\Data\Report.xlsx"` | (any/ignored) | Uses `C:\Data\Report.xlsx` |
| Filename only | `"Report.xlsx"` | `"C:\Data"` | Combines to `C:\Data\Report.xlsx` |
| Filename + default | `"Report.xlsx"` | (not specified) | Uses `.\output\Report.xlsx` |
| Conflicting paths | `"C:\Data\Report.xlsx"` | `"C:\Other"` | Uses `-AppendFile` path (warns) |

**Enterprise Use Cases:**

**1. Continuous 90-Day Audit Trail (Scheduled Task)**
```powershell
# Daily scheduled task: Append previous 24h to rolling dataset
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
    -StartDate (Get-Date).AddDays(-1) `
    -EndDate (Get-Date) `
    -ExportWorkbook `
    -CombineOutput `
    -AppendFile "C:\AuditArchive\Rolling_90Day_Audit.xlsx" `
    -Silent

# Result: Single workbook with continuous 90-day history, updated daily
```

**2. Multi-Phase Offline Transformation**
```powershell
# Phase 1: Fast export (no explosion)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
    -StartDate 2025-10-01 -EndDate 2025-10-31 -ExportWorkbook -CombineOutput
# Creates: Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx

# Phase 2: Offline replay with deep explosion for specific week
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
    -RAWInputCSV "C:\RawExports\Oct_Week2.csv" `
    -ExportWorkbook -ExplodeDeep `
    -AppendFile "Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx"
# Result: New tab with deep schema, original preserved
```

**3. MSP Multi-Tenant Consolidation**
```powershell
# Customer A - Multiple weekly batches to single workbook
$outputFile = "C:\Customers\CustomerA\Annual_Audit_2025.xlsx"

# Week 1 (initial)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
    -StartDate 2025-10-01 -EndDate 2025-10-08 -ExportWorkbook -CombineOutput

# Week 2+ (append)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
    -StartDate 2025-10-08 -EndDate 2025-10-15 -ExportWorkbook -CombineOutput `
    -AppendFile $outputFile
```

**Enhanced Error Diagnostics (v1.8.0):**

The script now includes **three-stage validation** for AppendFile operations:

1. **File Accessibility Check:**
   - Tests if file can be opened for reading
   - Detects: File locks, OneDrive sync issues, permission problems
   - Error: Clear guidance on Excel locks, network paths, permissions

2. **Excel Structure Validation (Excel mode only):**
   - Validates ZIP container structure (`.xlsx` files are ZIP archives)
   - Checks for required `xl/workbook.xml` entry
   - Detects: File corruption, renamed CSVs, invalid formats
   - Error: Specific root cause identification

3. **ImportExcel Module Compatibility (Excel mode only):**
   - Tests if ImportExcel can parse workbook structure
   - Detects: Version incompatibility, advanced features, module issues
   - Error: Shows current module version, suggests updates
   - Guidance: Specific steps to resolve (update module, re-save file, recreate export)

**Error Example (Enhanced Diagnostics):**
```
ERROR: Cannot read Excel workbook structure: The file is not a valid Package file
  File: C:\temp\Report.xlsx

Root cause: ImportExcel module cannot parse this workbook

Possible causes:
  • ImportExcel module version incompatibility
  • File created by different ImportExcel version
  • Workbook has features ImportExcel can't parse

Current ImportExcel version:
  7.8.4

Recommended solutions:
  1. Open file in Excel and verify it opens correctly
  2. If it opens: File > Save As > Excel Workbook (.xlsx) to 'clean' it
  3. Update ImportExcel: Update-Module ImportExcel -Force
  4. Recreate initial export without -AppendFile using current script
```

**Migration from v1.7.4:**

```powershell
# v1.7.4 (old syntax - boolean switch)
-AppendFile -OutputPath "C:\Data"
# Pattern-matched: Purview_Export_*.xlsx in C:\Data

# v1.8.0 (new syntax - explicit filename)
-AppendFile "Purview_Export_20251030_143022.xlsx" -OutputPath "C:\Data"
# Exact file: C:\Data\Purview_Export_20251030_143022.xlsx

# v1.8.0 (alternative - full path)
-AppendFile "C:\Data\Purview_Export_20251030_143022.xlsx"
# Exact file: C:\Data\Purview_Export_20251030_143022.xlsx
```

**Best Practices:**

✅ **Use descriptive names:** `Audit_2025_Q4.xlsx` instead of generic `Report.xlsx`  
✅ **Document parameters:** Keep notes of explosion modes used for consistency  
✅ **Test on copy first:** Copy file before testing append to prevent data loss  
✅ **Monitor file size:** Excel limit is 1,048,576 rows; use CSV for larger datasets  
✅ **Backup regularly:** Keep backups before each append operation  
✅ **Check exit codes:** `if ($LASTEXITCODE -ne 0) { Send-Alert }` in automation  

**Comprehensive Documentation:**
- **Full section in release documentation** (Section 15: "Incremental Data Collection")
- **80+ inline help examples** showing append scenarios
- **Troubleshooting guide** with file access, structure, and compatibility issues
- **Enterprise patterns** for scheduled tasks, MSP workflows, and multi-tenant scenarios

**5. DSPM for AI Improvements**
- Refined activity type lists (MIXED FREE/PAYG: `ConnectedAIAppInteraction`, `AIInteraction`; PAYG: `AIAppInteraction`)
- Enhanced `-Force` parameter support for bypassing interactive confirmations
- Improved conflict resolution when `-ExcludeCopilotInteraction` used with explicit `-ActivityTypes`

**6. Network Resilience Enhancement**
- New `-MaxNetworkOutageMinutes` parameter (default: 30 minutes)
- Automatic retry logic for network connectivity loss
- Progress preserved during transient outages
- Graceful error messaging with countdown timers

**7. Graph API Version Configuration**
- **Configurable endpoint version variables** for future-proofing API transitions
- Manual configuration at top of script (lines ~1519-1527):
  - `$script:GraphAuditApiVersion_Current = 'v1.0'` (try first, expected GA Q1 2026)
  - `$script:GraphAuditApiVersion_Previous = 'beta'` (fallback if current unavailable)
- **Automatic version detection** with session-cached result
- **Single-line terminal output** showing active version and fallback status
- **Easy manual updates** when Microsoft releases new API versions (e.g., v2.0)
- No command-line switches needed - pure internal configuration
- Example output:
  - Success: `Graph API: security/auditLog endpoint using version v1.0` (Green)
  - Fallback: `Graph API: security/auditLog endpoint using version beta (fallback from v1.0)` (Yellow)

**8. Operational Improvements**
- Graceful CTRL+C exit handling with cleanup
- Enhanced help documentation with 80+ examples
- Improved error messaging and troubleshooting guidance
- Updated parameter validation and conflict resolution

**Backward Compatible:** All commands from v1.7.4 work unchanged. Graph API becomes default, use `-UseEOM` for legacy EOM behavior.

---

## Key Improvements

---

### Microsoft Graph API Default Mode

**What It Means:**
Starting in v1.8.0, the script uses **Microsoft Graph API** for audit log queries by default, providing modern API capabilities, better performance, and foundation for advanced features like Entra enrichment.

**Benefits (Graph API Mode - Default):**

- **Modern API:** Future-proof integration with Microsoft 365 ecosystem
- **Entra Enrichment:** Unlocks `-IncludeUserInfo` and `-OnlyUserInfo` features (**Graph API exclusive**)
- **Better Performance:** Optimized data retrieval and caching
- **Unified Access:** Single API surface for audit logs and identity data
- **Simplified Query Model:** No 10K per-partition server limits to manage

**EOM Mode Features (Legacy - Use `-UseEOM`):**

- **Group Filtering:** `-GroupNames` parameter for filtering by distribution list membership (**EOM exclusive**)
- **10K Limit Detection:** Automatic detection when Microsoft 365 service cap (10,000 records per query partition) is reached, with recommendations for mitigation (**EOM exclusive**)
- **Legacy Compatibility:** Maintain existing workflows that depend on EOM-specific behavior

**Mode Comparison:**

| Feature | Graph API (Default) | EOM Mode (`-UseEOM`) |
|---------|---------------------|----------------------|
| Entra User Enrichment (`-IncludeUserInfo`) | ✅ Available | ❌ Not available |
| User-Only Export (`-OnlyUserInfo`) | ✅ Available | ❌ Not available |
| Group Filtering (`-GroupNames`) | ❌ Not available | ✅ Available |
| 10K Limit Detection | ❌ Not applicable (no 10K limit) | ✅ Automatic detection & warnings |
| All other features | ✅ Supported | ✅ Supported |

**When to Use EOM Mode:**

- You need `-GroupNames` filtering by distribution list membership
- You have existing workflows that depend on 10K limit detection behavior
- You need legacy EOM-specific compatibility

**Migration Path:**

```powershell
# Default (Graph API) - Recommended for most users
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# EOM mode - For -GroupNames or legacy compatibility
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -UseEOM -GroupNames "CopilotPilotGroup@contoso.com"
```

---

### Entra ID User Enrichment

**What It Delivers:**
Enrich audit data with organizational context: display name, given name, surname, department, job title, manager, M365 Copilot licenses, account status, and 30+ additional user attributes from Entra ID.

> **⚠️ Graph API Exclusive:** This feature requires Graph API mode (default). **Not available** when using `-UseEOM`.

**Business Value:**

- **Adoption Analysis:** Analyze Copilot usage by department, location, or reporting hierarchy
- **License Tracking:** Automatically detect M365 Copilot license holders and correlate with usage
- **Compliance Reporting:** Include user demographics for audit trails and regulatory compliance
- **Executive Dashboards:** Visualize adoption by business unit, geography, or manager

**Requirements:**

- **Graph API mode** (default) - Incompatible with `-UseEOM`
- **Permissions:** `User.Read.All`, `Organization.Read.All`
- **Performance:** Minimal impact (~1-5 seconds for typical datasets)

**Sample Use Case:**

```powershell
# Export Copilot usage with full user context (Graph API mode - default)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
    -StartDate 2025-10-01 `
    -EndDate 2025-10-02 `
    -IncludeUserInfo `
    -ExportWorkbook `
    -CombineOutput
# Output: Purview_Audit_CombinedUsageActivity_EntraUsers_MAClicensing_<timestamp>.xlsx
# Tabs: CombinedUsageActivity, EntraUsers_MAClicensing (with license detection)
```

---

### User-Only Export Mode (`-OnlyUserInfo`)

**What It Delivers:**
Export ONLY Entra user directory and M365 Copilot license data without querying audit logs. Perfect for quick license compliance snapshots and periodic user directory exports.

> **⚠️ Graph API Exclusive:** This feature requires Graph API mode (default). **Not available** when using `-UseEOM`.

**Key Benefits:**

- **Ultra-Fast Execution:** 5-15 seconds (vs. minutes/hours for audit queries)
- **License Compliance:** Instant snapshot of all M365 Copilot license holders
- **Minimal Network Traffic:** No audit log queries, only user directory + licenses
- **Standalone Output:** `EntraUsers_MAClicensing_<timestamp>.csv` with 37 columns

**Use Cases:**

1. **License Auditing:** Monthly exports to track Copilot license assignments over time
2. **Compliance Reporting:** Rapid licensing snapshots for compliance reviews
3. **User Directory Exports:** Standalone Entra data for cross-referencing with other systems
4. **Adoption Planning:** Identify licensed vs. unlicensed users before usage analysis

**Compatible Parameters:**

```powershell
-OutputPath         # Specify output directory
-Auth               # Choose authentication method (WebLogin, DeviceCode, etc.)
-ExportWorkbook     # Export to Excel instead of CSV
```

**NOT Compatible:**
- **`-AppendFile`** - EntraUsers data represents point-in-time snapshots (not time-based activity data)
- All audit-related parameters (dates, activity types, filtering, etc.)

**Incompatible Parameters:**  
All audit-related parameters are automatically disabled:

- Date filtering (StartDate, EndDate)
- Activity types (ActivityTypes, IncludeDSPMForAI, ExcludeCopilotInteraction)
- User/Agent filtering (UserIds, GroupNames, AgentId, AgentsOnly, PromptFilter)
- Processing modes (ExplodeArrays, ExplodeDeep, RAWInputCSV)
- Query tuning (BlockHours, PartitionHours, ResultSize, Parallelization settings)

**Examples:**

```powershell
# Basic user-only export (Graph API mode - default)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -OnlyUserInfo

# Export to Excel workbook
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -OnlyUserInfo -ExportWorkbook

# Custom output directory
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -OnlyUserInfo -OutputPath "D:\LicenseAudits\"

# Device code auth for automation
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -OnlyUserInfo -Auth DeviceCode
```

---

### Incremental Data Collection (`-AppendFile`)

**What It Delivers:**
Redesigned `-AppendFile` parameter transforms from boolean switch to intelligent string parameter, enabling enterprise-grade incremental dataset building across multiple script executions.

> **⚡ BREAKING CHANGE:** `-AppendFile` now accepts filename or full path (was: switch parameter in v1.7.4)

**Key Features:**

- **Dual Format Support:** Works with both CSV and Excel exports
- **Smart Path Resolution:** 
  - Relative filename: `-AppendFile "Report.xlsx"` uses `-OutputPath` directory
  - Absolute path: `-AppendFile "C:\Data\Report.xlsx"` uses exact location
- **Live & Offline:** Supports live API queries and offline replay (`-RAWInputCSV`)
- **Safe Header Validation:**
  - CSV: Exits with detailed diff on schema mismatch
  - Excel: Creates timestamped duplicate tabs on schema mismatch
- **Enhanced Diagnostics:** Three-stage validation (file access, ZIP structure, ImportExcel compatibility)

**Business Value:**

- **Fortune 500 Use Case:** Organizations building 90-day rolling audit datasets updated daily
- **Predictable Automation:** Explicit filename/path eliminates pattern-matching ambiguity
- **Zero Data Loss:** Never overwrites existing data (safe validation at every step)
- **Multi-Tenant Ready:** MSPs consolidating customer audit data into single workbooks
- **Schema Evolution:** Handles API changes gracefully (creates new tabs vs. errors)

**Enterprise Patterns:**

```powershell
# Pattern 1: Continuous 90-day rolling audit (scheduled task)
-AppendFile "C:\AuditArchive\Rolling_90Day_Audit.xlsx"

# Pattern 2: Multi-phase transformation (fast export + selective deep explosion)
-AppendFile "Purview_Audit_CombinedUsageActivity_20251110_080000.xlsx"

# Pattern 3: MSP multi-tenant consolidation
-AppendFile "C:\Customers\CustomerA\Annual_Audit_2025.xlsx"
```

**Restrictions:**
- ❌ Cannot use with `-IncludeUserInfo` or `-OnlyUserInfo` (EntraUsers data is point-in-time snapshots)
- ✅ Requires single-file output (Excel, `-CombineOutput`, or single activity type)
- ✅ File must exist first (run once without `-AppendFile` to create initial file)

**Enhanced Error Diagnostics:**
1. **File Accessibility:** Detects locks, OneDrive sync issues, permissions
2. **ZIP Structure Validation:** Confirms valid Excel format (`.xlsx` files are ZIP containers)
3. **ImportExcel Compatibility:** Checks module version, suggests updates/workarounds

**Migration from v1.7.4:**
```powershell
# Old (v1.7.4): Boolean switch with pattern matching
-AppendFile -OutputPath "C:\Data"

# New (v1.8.0): Explicit filename or full path
-AppendFile "Purview_Export_20251030_143022.xlsx" -OutputPath "C:\Data"
# OR
-AppendFile "C:\Data\Purview_Export_20251030_143022.xlsx"
```

> **📖 Full Documentation:** Section 15 in release documentation covers all scenarios, troubleshooting, and best practices

> **✅ Mode Independent:** AppendFile works identically in both Graph API (default) and EOM modes (`-UseEOM`).

---

### Enhanced Excel Export

**File Naming Improvements:**

- **Combined mode:** `Purview_Audit_CombinedUsageActivity_<timestamp>.xlsx` (clear, descriptive naming)
- **Combined + Entra:** `Purview_Audit_CombinedUsageActivity_EntraUsers_MAClicensing_<timestamp>.xlsx`
- **Multi-tab mode:** `Purview_MultiTab_Export_<timestamp>.xlsx` (unchanged)
- **DSPM multi-tab:** `Purview_DSPM_MultiTab_Export_<timestamp>.xlsx` (unchanged)

> **✅ Mode Independent:** Enhanced Excel export works identically in both Graph API (default) and EOM modes (`-UseEOM`).

**Entra Integration:**

- `EntraUsers_MAClicensing` tab automatically embedded as worksheet tab when `-IncludeUserInfo` used (**Graph API only**)
- No separate CSV file in Excel mode - all data in single workbook
- Professional formatting applied to `EntraUsers_MAClicensing` tab (frozen headers, auto-sizing)

---

### Graph API Version Configuration

**What It Delivers:**
Configurable Graph API endpoint version management with automatic detection and manual override capability for seamless API transitions.

**Key Features:**

- **Configurable Version Variables** (near top of script, ~lines 1519-1527):
  ```powershell
  $script:GraphAuditApiVersion_Current  = 'v1.0'  # Try this version first
  $script:GraphAuditApiVersion_Previous = 'beta'  # Fallback if unavailable
  ```

- **Automatic Version Detection:**
  - Tests current version (v1.0) on first API call
  - Falls back to previous version (beta) if current unavailable
  - Session-cached result prevents repeated checks
  - Zero configuration needed for users

- **Single-Line Terminal Output:**
  - Success: `Graph API: security/auditLog endpoint using version v1.0` (Green)
  - Fallback: `Graph API: security/auditLog endpoint using version beta (fallback from v1.0)` (Yellow)
  - Clear visibility into which API version is active

- **Manual Override Capability:**
  - Edit version variables at top of script for future API updates
  - Example for v2.0 release:
    ```powershell
    $script:GraphAuditApiVersion_Current  = 'v2.0'  # New version
    $script:GraphAuditApiVersion_Previous = 'v1.0'  # Previous stable
    ```

**Business Value:**

- **Future-Proof:** Seamless transition when Microsoft promotes beta→v1.0 (Q1 2026)
- **Zero-Downtime:** Automatic fallback ensures backward compatibility
- **Manual Control:** Override capability for testing or version pinning
- **Operational Transparency:** Clear logging shows active version
- **No User Action:** Fully automatic for standard deployments

**Use Cases:**

1. **API Transition Readiness:** Script automatically uses v1.0 when available (Q1 2026)
2. **Tenant Variability:** Handles tenants on different API versions automatically
3. **Future Versions:** Manual update path when Microsoft releases v2.0+
4. **Testing/Validation:** Pin to specific version for regression testing

> **✅ Mode Independent:** Version configuration works in both Graph API (default) and EOM modes (`-UseEOM`).

---

### Network Resilience

**New Capability:**
`-MaxNetworkOutageMinutes` parameter enables the script to tolerate temporary network connectivity loss without aborting the export.

> **✅ Mode Independent:** Network resilience works identically in both Graph API (default) and EOM modes (`-UseEOM`).

**How It Works:**

- Network failures trigger resilient retry loop
- Script waits up to specified minutes for connectivity restoration
- Progress preserved - no data loss during interruptions
- Exits cleanly if network unavailable beyond timeout

**Use Cases:**

- Unstable VPN connections
- Long-running queries with intermittent Wi-Fi
- Scheduled tasks on remote servers with network variability

**Default:** 30 minutes (configurable 1-120 minutes)

---

## Why This Release Matters

| Challenge | Prior State (≤1.7.4) | Improvement in 1.8.0 |
|-----------|----------------------|----------------------|
| Understanding who uses Copilot | Only UserID (email) in audit logs | Comprehensive user profiles with license detection |
| API modernization | EOM-only (legacy) | Graph API default with EOM fallback |
| Excel file naming clarity | Generic naming patterns | Descriptive names reflecting content & enrichment |
| Network interruptions | Script failure on connectivity loss | Automatic retry with 30-minute default tolerance |
| Organizational analysis | Manual joins with HR/IT systems | Built-in department, manager, location enrichment |
| License correlation | External systems required | Automatic M365 Copilot SKU detection |

---

## Detailed Changes

### Modified / Added Files

```text
PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 (new version - 7,509 lines)
PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 (historical reference - 2,044 lines)
release_documentation/.../PAX_Purview_Audit_Log_Processor_Documentation_v1.8.0.md (completely updated)
release_notes/.../PAX_Purview_Audit_Log_Processor_Release_Note_v1.8.0.md (this file)
versions.json (purview 1.8.0)
README.md (script download link updated)
```

### New Parameters

```powershell
-UseEOM                      # Enable Exchange Online Management mode (legacy)
-IncludeUserInfo           # Enrich with comprehensive Entra ID user profiles
-MaxNetworkOutageMinutes   # Network resilience timeout (default: 30)
```

### New Functions

```powershell
Connect-PurviewAudit()           # Dual-mode connection handler (Graph/EOM)
Get-UserLicenseData()            # Entra ID user profile retrieval
ConvertTo-FlatEntraUsers()       # User data flattening for CSV/Excel
Get-EntraUsersData()             # Main enrichment orchestration
```

### Enhanced Features

```text
- Graph API audit log querying (default mode)
- Configurable Graph API version detection (v1.0/beta with manual override capability)
- Entra ID user enrichment with license detection
- Network resilience with automatic retry logic
- Combined Excel naming convention updates
- EntraUsers tab embedding in Excel workbooks
- DSPM conflict resolution improvements
- Graceful CTRL+C exit handling
- Comprehensive partition retry system (up to 3 attempts per partition)
- Partition status tracking with QueryId and QueryName correlation
- End-of-run reconciliation summary (Complete/Incomplete/Failed breakdown)
- Unified concurrency control (MaxConcurrency parameter for both EOM and Graph API modes)
- Simplified query naming convention (PAX_Query_<DateRange>_PartX/Total - removed activity types for clarity)
- Single-line version detection logging for operational transparency
```

---

## Installation

### Download v1.8.0 (This Version)
Use the direct download link below to obtain this specific version:
- **Script v1.8.0**: [PAX_Purview_Audit_Log_Processor_v1.8.0.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.8.0/PAX_Purview_Audit_Log_Processor_v1.8.0.ps1)

### Related Assets

- **Documentation (v1.8.0)**: [PAX_Purview_Audit_Log_Processor_Documentation_v1.8.0.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.8.0.md)
- **Release Notes (v1.8.0)**: [PAX_Purview_Audit_Log_Processor_Release_Note_v1.8.0.md](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.8.0.md)

---

## Upgrading from v1.7.4

### Is Upgrade Recommended?

**Yes – strongly recommended** for users who need:
- Organizational adoption analysis (department, manager, location breakdowns)
- M365 Copilot license correlation with usage data
- Modern Graph API foundation for future features
- Enhanced Excel export with descriptive naming
- Network resilience for unstable connections

### Zero-Risk Adoption

**Backward Compatibility Guarantee:**
- All v1.7.4 commands work unchanged in v1.8.0
- Default behavior switches from EOM to Graph API (transparent for most users)
- Add `-UseEOM` if you specifically need EOM mode (e.g., for `-GroupNames`)

### Suggested Migration Path

**Phase 1: Drop-in Replacement**
1. Replace script file with v1.8.0
2. Run existing commands - Graph API now default
3. Verify output files match expected results

**Phase 2: Enable Entra Enrichment**
1. Add `-IncludeUserInfo` to your standard commands
2. Verify Graph API permissions: `User.Read.All`, `Organization.Read.All`
3. Join audit data with EntraUsers file/tab for organizational insights

**Phase 3: Excel Optimization (Optional)**
1. Switch to `-ExportWorkbook -CombineOutput` for business-ready reports
2. Use EntraUsers tab for pivot tables and organizational analysis
3. Leverage M365 Copilot license detection (`HasCopilotLicense` column)

**Phase 4: Network Resilience (If Needed)**
1. For unstable networks, add `-MaxNetworkOutageMinutes 60`
2. Monitor logs for network retry attempts
3. Adjust timeout based on typical outage durations

---

### Breaking Changes

**1. `-AppendFile` Parameter Redesign (Major Change)**

> **⚡ BREAKING CHANGE:** `-AppendFile` completely redesigned from boolean switch to string parameter for enterprise-grade control

**Previous Behavior (v1.7.4 and earlier):**
- `-AppendFile` was a **boolean switch** (just presence/absence)
- Used pattern matching to find existing files: `-AppendFile -OutputPath "C:\Data"` would search for `Purview_Export_*.xlsx`
- Ambiguous in multi-file scenarios
- No explicit filename control

**New Behavior (v1.8.0):**
- `-AppendFile` now accepts **filename or full path as string**: `-AppendFile "Report.xlsx"` or `-AppendFile "C:\Data\Report.xlsx"`
- **Explicit file targeting** eliminates pattern-matching ambiguity
- **Relative filename** uses `-OutputPath` directory
- **Absolute path** ignores `-OutputPath` (exact location)
- **Enhanced diagnostics:** Three-stage validation (file access, ZIP structure, ImportExcel compatibility)

**Why This Change:**
1. **Fortune 500 Requirements:** Predictable automation for 90-day rolling audit datasets
2. **Multi-Tenant MSPs:** Explicit file targeting for customer-specific workbooks
3. **Scheduled Tasks:** No ambiguity about which file receives appended data
4. **Schema Evolution:** Better error handling when API response schemas change

**Migration Examples:**

```powershell
# v1.7.4: Boolean switch with pattern matching
./PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 `
    -StartDate 2025-10-08 -EndDate 2025-10-09 `
    -ExportWorkbook -AppendFile -OutputPath "C:\Data"
# Pattern-matched: Purview_Export_*.xlsx in C:\Data

# v1.8.0: Explicit filename (relative path)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
    -StartDate 2025-10-08 -EndDate 2025-10-09 `
    -ExportWorkbook `
    -AppendFile "Purview_Export_20251030_143022.xlsx" `
    -OutputPath "C:\Data"
# Exact file: C:\Data\Purview_Export_20251030_143022.xlsx

# v1.8.0: Absolute path (ignores -OutputPath)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
    -StartDate 2025-10-08 -EndDate 2025-10-09 `
    -ExportWorkbook `
    -AppendFile "C:\Data\Purview_Export_20251030_143022.xlsx"
# Exact file: C:\Data\Purview_Export_20251030_143022.xlsx
```

**Impact Assessment:**
- ⚠️ **High:** All automation using `-AppendFile` must be updated to specify filename
- ✅ **Benefit:** Eliminates edge cases where wrong file was matched
- ✅ **Benefit:** Better error messages (DEBUG info shows hex bytes, ZIP validation)
- 📖 **Full Documentation:** Section 15 covers all scenarios, troubleshooting, patterns

---

**2. CSV Export Default Behavior Changed**

Version 1.8.0 changes the default CSV export behavior to better align with analysis workflows and Excel's multi-tab default:

**Previous Behavior (v1.7.4 and earlier):**
- CSV exports defaulted to **combined single file** with all activity types
- `-CombineOutput $false` explicitly required for separate files per activity type
- Complex nullable bool parameter: `-CombineOutput $true` (combine) or `-CombineOutput $false` (separate)

**New Behavior (v1.8.0):**
- CSV exports now default to **separate files per activity type** (e.g., `Purview_CopilotInteraction_Export_<timestamp>.csv`, `Purview_ConnectedAIAppInteraction_Export_<timestamp>.csv`)
- `-CombineOutput` is now a **simple switch** (no boolean value needed)
- Add `-CombineOutput` switch to merge all activity types into single `Purview_Audit_CombinedUsageActivity_<timestamp>.csv`
- Excel behavior unchanged: Still defaults to multi-tab workbook (one tab per activity type)

**Why This Change:**
1. **Parallel Processing:** Separate files enable parallel ingestion/processing pipelines
2. **Granular Analysis:** Easier to analyze specific activity types in isolation
3. **Consistency:** Aligns CSV default with Excel's multi-tab default behavior
4. **Simplified API:** Switch parameter is clearer than nullable bool

**Migration Guide:**

If your automation expects a **single combined CSV file**, add `-CombineOutput`:

```powershell
# v1.7.4 default (single combined CSV) - NO PARAMETERS NEEDED
./PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

# v1.8.0 default (separate CSV per activity type) - NEW DEFAULT
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
# Output: Purview_CopilotInteraction_Export_<timestamp>.csv
#         Purview_ConnectedAIAppInteraction_Export_<timestamp>.csv (if -IncludeDSPMForAI)

# v1.8.0 with -CombineOutput (MATCHES v1.7.4 BEHAVIOR)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -CombineOutput
# Output: Purview_Audit_CombinedUsageActivity_<timestamp>.csv (single file)
```

If your automation expects **separate files per activity type**, no changes needed:

```powershell
# v1.7.4 explicit separate files (required -CombineOutput $false)
./PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -CombineOutput $false

# v1.8.0 separate files (NEW DEFAULT - no parameter needed)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
# Output: Same as v1.7.4 with -CombineOutput $false
```

**Excel Unchanged:**
Excel exports continue to default to multi-tab workbooks. Use `-CombineOutput` for single combined tab:

```powershell
# Default: Multi-tab workbook (one tab per activity type)
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -ExportWorkbook

# Combined: Single tab with all activity types
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -ExportWorkbook -CombineOutput
```

---

### Feature Compatibility Matrix

| Feature | v1.7.4 | v1.8.0 Graph (Default) | v1.8.0 EOM (`-UseEOM`) |
|---------|--------|----------------------|----------------------|
| **Audit Log Query** | EOM only | ✅ Graph API (default) | ✅ EOM (with `-UseEOM`) |
| **`-GroupNames` Filtering** | ✅ Supported | ❌ Not supported | ✅ Supported |
| **`-IncludeUserInfo` (Entra)** | ❌ Not available | ✅ Supported | ❌ Not supported |
| **Excel Export** | ✅ Supported | ✅ Supported (enhanced naming) | ✅ Supported |
| **Network Resilience** | ❌ Not available | ✅ Supported | ✅ Supported |
| **DSPM for AI** | ✅ Supported | ✅ Supported | ✅ Supported |

---

## Common Migration Scenarios

### Scenario 1: Standard Copilot Export (No Changes Needed)

**v1.7.4 Command:**
```powershell
./PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
```

**v1.8.0 Equivalent (Works Unchanged):**
```powershell
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
# Now uses Graph API by default (transparent)
```

---

### Scenario 2: Using `-GroupNames` (Add `-UseEOM`)

**v1.7.4 Command:**
```powershell
./PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 `
    -StartDate 2025-10-01 `
    -EndDate 2025-10-02 `
    -GroupNames "Sales Team"
```

**v1.8.0 Migration:**
```powershell
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
    -StartDate 2025-10-01 `
    -EndDate 2025-10-02 `
    -UseEOM `
    -GroupNames "Sales Team"
# -UseEOM required for GroupNames filtering
```

---

### Scenario 3: Add Entra Enrichment (New Feature)

**v1.7.4 Command:**
```powershell
./PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 `
    -StartDate 2025-10-01 `
    -EndDate 2025-10-02 `
    -ExportWorkbook
```

**v1.8.0 Enhanced:**
```powershell
./PAX_Purview_Audit_Log_Processor_v1.8.0.ps1 `
    -StartDate 2025-10-01 `
    -EndDate 2025-10-02 `
    -IncludeUserInfo `
    -ExportWorkbook `
    -CombineOutput
# New: Adds EntraUsers_MAClicensing tab with comprehensive user profile data
# New: Combined naming: Purview_Audit_CombinedUsageActivity_EntraUsers_MAClicensing_<timestamp>.xlsx
```

---

## Critical Bug Fixes

### 1. **CRITICAL: Partition Cap Data Loss (Parallel Mode)**

**Issue:** When `-MaxActivePartitions` cap was applied (e.g., 14 partitions requested, capped to 12), the script was incorrectly **reducing the total number of partitions created** instead of only limiting concurrent execution. This resulted in **silent data loss** - approximately 14-17% of audit records were never queried.

**Example:**

- Date range: 7 days (168 hours)
- Partition size: 12 hours
- Expected: 14 partitions (queries)
- **Old behavior (BUG):** Only 12 partitions created → **24 hours of data lost**
- **New behavior (FIXED):** All 14 partitions created → 12 run concurrently, then remaining 2

**Impact:**

- Affects all v1.7.x and early v1.8.0 builds when partition count exceeds `-MaxActivePartitions` (default 12)
- Data loss was silent - no errors, warnings, or indication of missing data
- Most likely to occur with: longer date ranges, smaller partition sizes, or high activity volumes

**Resolution:**

- Separated partition creation (`$totalPartitions`) from concurrent execution limit (`$maxConcurrentPartitions`)
- All calculated partitions are now created and queued regardless of concurrency cap
- `-ThrottleLimit` properly controls concurrent execution without affecting total partition count
- Terminal output clarified: "requested 14 → capped to 12 concurrent (all 14 partitions will still be processed)"

**Action Required:**

- **Re-run any historical extracts** from v1.7.x or early v1.8.0 that showed partition capping messages
- Verify Purview audit log search history shows expected number of queries (matches partition count, not cap)

---

### 2. Network Error Retry and Error Display Improvements

**Issue:** Network errors (502/503/504 Bad Gateway, Service Unavailable, Gateway Timeout) during audit log query creation or record retrieval were not retried, resulting in incomplete data collection. Additionally, error output showed 20+ rows of HTML content, cluttering terminal during troubleshooting.

**Old Behavior:**

- Network error during query creation → Treated as "0 records", no retry
- Network error during record fetch → Continued with partial results
- Verbose HTML error pages displayed in terminal (20+ rows per error)
- Only 3 retry attempts (~3-5 minutes maximum tolerance)

**New Behavior:**

- **Query Creation:** Network errors retry for up to 30 minutes (configurable via `-MaxNetworkOutageMinutes`)
- **Record Fetch:** Network errors also retry for up to 30 minutes (prevents partial results)
- **Clean Terminal Output:** Single yellow line with error summary and retry countdown (Example: `[NETWORK] Partition 12/12 - 502 Bad Gateway (45.3s elapsed, 29m remaining) - Retrying in 52s`)
- **Verbose Logging:** Full HTML error details written to log file only for troubleshooting
- **Graceful Failure:** After 30-minute tolerance, clearly indicates network outage exceeded limits

**Impact:**

- Prevents data loss during Azure infrastructure issues or transient network problems
- Improved operational visibility during extended outages
- Cleaner terminal output for production monitoring

**Error Types Detected:**

- HTTP 502 (Bad Gateway)
- HTTP 503 (Service Unavailable)
- HTTP 504 (Gateway Timeout)
- Connection timeouts and DNS resolution failures

**Terminal Output Examples:**

**First Network Error:**

```text
[NETWORK] Partition 12/14 - 502 Bad Gateway - Starting retry window (max 30m)
```

**Subsequent Retries:**

```text
[NETWORK] Partition 12/14 - 502 Bad Gateway (45.3s elapsed, 29m remaining) - Retrying in 52s
[NETWORK] Partition 3/14 Page 5 - 503 Service Unavailable (12.7s elapsed, 30m remaining) - Retrying in 38s
```

**Exceeded Tolerance:**

```text
[ERROR] Partition 12/14 - Record fetch failed: Network outage exceeded 30 minute tolerance (31.2m elapsed)
```

**Unexpected Errors (Non-Network):**

```text
[ERROR] Partition 8/14 - Unexpected error during record processing - Continuing with partial results
```

---

### 3. Query Submission Reliability & Retry Logic (Parallel Mode)

**Issue:** In parallel execution mode, partition queries could fail due to transient API errors, throttling, or network issues without automatic recovery. Failed partitions resulted in incomplete data collection with no visibility into which queries succeeded or failed.

**Old Behavior:**

- Single attempt per partition query
- Failed queries resulted in 0 records with no retry
- No tracking of partition success/failure status
- No end-of-run summary showing which partitions completed
- Query names in Purview were inconsistent (used current timestamp instead of partition date range)

**New Behavior:**

- **Automatic Retry System:** Up to 3 total attempts per partition (initial + 2 retry passes)
- **Intelligent Cooldown:** 30-60 second randomized delay between retry passes to avoid cascading failures
- **Status Tracking:** Each partition tracked throughout execution with QueryId, QueryName, Status, RecordCount, and LastError
- **Partial Success Handling:** Script continues processing with successful partitions even if some fail (Option A behavior)
- **End-of-Run Summary:** Comprehensive report showing:
  - ✓ **Sent and Complete:** Partitions that successfully retrieved data
  - ⚠ **Sent but Incomplete:** Queries created but data retrieval incomplete (shows QueryName and QueryId)
  - ✗ **Never Sent:** Partitions that failed all 3 attempts (shows error details)
  - Missing/skipped partition detection
- **Unified Query Naming:** Queries now appear in Purview with format `PAX_Query_<DateRange>_PartX/Total`
  - Example: `PAX_Query_20241101_0000-20241101_0100_Part27/134`
  - Uses actual partition date boundaries (not current execution time)
  - Enables easy correlation between terminal output and Purview UI

**Terminal Output Examples:**

**Initial Execution:**
```text
[CREATED] [14:23:15] Partition 1/134 - Job created
[ATTEMPT] [14:23:15] Partition 1/134 - Starting query creation...
[SENT]    [14:23:17] Partition 1/134 - Query sent to Purview (QueryId: abc-123)
```

**Retry Pass:**
```text
[RETRY] Pass 2/3 - 5 partition(s) need retry
  Waiting 47 seconds before retry...
  [RETRY] Attempt 2/3 for Partition 12/134
  ✓ Retry successful for Partition 12/134: 8,542 records
```

**End-of-Run Summary:**
```text
═══════════════════════════════════════════════════════════════
  QUERY SUBMISSION SUMMARY
═══════════════════════════════════════════════════════════════
  Total Partitions: 134
  ✓ Sent and Complete: 131
  ⚠ Sent but Incomplete: 2
    - Partition 45/134: QueryName=PAX_Query_20241103_1200-20241103_1300_Part45/134, QueryId=def-456
    - Partition 89/134: QueryName=PAX_Query_20241105_0900-20241105_1000_Part89/134, QueryId=ghi-789
  ✗ Never Sent: 1
    - Partition 67/134: QueryName=PAX_Query_20241104_0300-20241104_0400_Part67/134 - Error: Network outage exceeded 30 minute tolerance
═══════════════════════════════════════════════════════════════
  ✓ Continuing with 131 successful partition(s)...
```

**Impact:**

- **Improved Reliability:** Automatic recovery from transient failures increases successful data collection
- **Operational Visibility:** Clear indication of which partitions succeeded/failed
- **Debuggability:** QueryName and QueryId correlation enables troubleshooting in Purview UI
- **Partial Success:** Script completes with available data rather than failing completely
- **Query Traceability:** Consistent naming enables finding queries in Purview audit log search history

**Resolution:**

- Comprehensive retry system with progressive cooldown
- Per-partition status tracking (`$script:partitionStatus` hashtable)
- End-of-run reconciliation and summary report
- ThreadJob scriptblock extraction for reusability (`$queryJobScriptBlock`)
- Unified query naming matching actual partition boundaries
- Continues processing even if some partitions fail permanently after 3 attempts

**Action Required:**

If you see partitions listed as "Sent but Incomplete" or "Never Sent" in the summary:
- Check Purview UI using the QueryName to investigate query status
- Review log file for detailed error messages
- Consider re-running with smaller partition sizes (`-PartitionHours`) if persistent failures occur

---

### 4. Unified Concurrency Control & Simplified Query Names

**Issue:** Script had two confusing and redundant concurrency parameters (`MaxConcurrency` and `MaxActivePartitions`) that capped each other. Query names in Purview included activity types even when multiple activities were combined in a single query, making names misleading and overly complex.

**Old Behavior:**

- Two overlapping parameters:
  - `MaxConcurrency` (default: 7) - legacy from EOM mode
  - `MaxActivePartitions` (default: 12) - added for Graph API mode
  - Effective limit was the **minimum** of both (confusing to users)
- Query names included activity types:
  - Serial: `PAX_Query_CopilotInteraction_20241101_0000-20241101_0100`
  - Parallel: `PAX_Query_CopilotInteraction+CopilotAgentInteraction_20241101_0000-20241101_0100_Part27/134`
  - Misleading when multiple activities combined in one query (Graph API mode)

**New Behavior:**

- **Single Parameter:** `MaxConcurrency` (default: 10, range: 1-10) controls both modes:
  - **EOM mode:** Limits concurrent serial queries
  - **Graph API mode:** Limits concurrent partition execution
  - **Maximum enforced by Microsoft Purview:** 10 concurrent search jobs per user account (platform limitation)
  - Clear, consistent behavior across both modes
- **Removed:** `MaxActivePartitions` parameter (eliminated redundancy)
- **Simplified Query Names:** Activity types removed from Purview query display names:
  - Serial: `PAX_Query_20241101_0000-20241101_0100`
  - Parallel: `PAX_Query_20241101_0000-20241101_0100_Part27/134`
  - Cleaner, more accurate (Graph API combines multiple activities in one query)

**Technical Details:**

- `MaxConcurrency` default set to 10 (maximum allowed by Microsoft Purview platform)
- Valid range: 1-10 (enforced by script validation)
- **Platform Limitation:** Microsoft Purview enforces a maximum of 10 concurrent search jobs per user account
- All internal references updated to use single concurrency control point
- Help documentation clarified to explain dual-mode behavior and platform limitation
- Diagnostic output simplified: `[CONCURRENCY] Partitions=134 MaxConcurrency=10 Effective=10`

**Migration Notes:**

- If you used `-MaxActivePartitions`, replace with `-MaxConcurrency` (same behavior)
- If you used `-MaxConcurrency` with values >10, script now enforces maximum of 10
- Script validates range (1-10) and displays error if value is outside this range

**Benefits:**

- **Reduced Complexity:** One parameter to understand and configure
- **Platform-Aligned Defaults:** 10 concurrent queries/partitions (matches Purview's documented limit)
- **Clearer Query Names:** Date ranges immediately visible in Purview UI
- **Mode-Agnostic:** Same parameter works for both EOM and Graph API modes

---

## Support

For questions or issues, refer to the documentation:

- **Documentation v1.8.0 (Markdown):** [PAX_Purview_Audit_Log_Processor_Documentation_v1.8.0.md](https://github.com/microsoft/PAX/releases/download/purview-v1.8.0/PAX_Purview_Audit_Log_Processor_Documentation_v1.8.0.md)

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com) with any feedback.*

---

## Summary

**v1.8.0 modernizes the Purview Audit Log Processor** with Microsoft Graph API as the new foundation, enabling rich organizational insights through Entra ID enrichment while maintaining full backward compatibility with Exchange Online Management mode.

**Key Takeaway:** Drop-in replacement for v1.7.4 with powerful new optional features for adoption analysis, license tracking, and network resilience.

---

**Enjoy the release and keep the feedback coming.**

