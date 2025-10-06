# PAX Release v1.4.0 - Production Release
**Release Date**: October 6, 2025

## Overview
This release marks the production-ready milestone for the **CopilotInteraction_Purview_Export.ps1** enterprise audit export engine. All critical bugs have been resolved, and the script is now validated for customer deployment.

---

## 🎯 What's New in v1.4.0

### Production Validation & Hardening
- ✅ **All critical correctness bugs resolved** from previous development cycles
- ✅ **Security audit passed** - script meets enterprise security standards
- ✅ **Customer-facing documentation** cleaned and validated
- ✅ **Comprehensive error handling** with graceful degradation
- ✅ **Zero syntax errors** - fully validated PowerShell code

### Script Enhancements (CopilotInteraction_Purview_Export.ps1)
- **ISO 8601 Timestamp Normalization**: Both `CreationDate` and `CreationTime` now consistently output in UTC format (`yyyy-MM-ddTHH:mm:ss.fffZ`)
- **Late Column Discovery**: Tracks and reports columns discovered after schema freeze with first-25 enumeration
- **Fast CSV Writer**: Optimized UTF-8 streaming output bypassing `Export-Csv` overhead
- **Adaptive Chunk Sizing**: Automatically adjusts processing chunks based on schema width
  - Shrinks for wide schemas (>250 columns) to prevent memory pressure
  - Boosts to 15K rows for narrow schemas (≤60 columns) for optimal throughput
- **Parallel Replay Processing**: PowerShell 7+ users can leverage parallel explosion with dynamic throttle tuning
- **Deterministic Zero-Record Handling**: Produces header-only CSV files when no records match query

---

## 📋 System Requirements

### Minimum Requirements
- **PowerShell**: 5.1 or later (PowerShell 7+ **strongly recommended** for optimal performance)
- **ExchangeOnlineManagement Module**: Any reasonably current version
- **Permissions**: Exchange Online audit log read access
- **Operating System**: Windows, macOS, or Linux

### Recommended Configuration
- **PowerShell 7.4+** for best performance and parallel processing support
- **16 GB RAM** for large dataset processing (100K+ records)
- **Modern multi-core CPU** for parallel replay mode

---

## ⚠️ Known Limitations & Workarounds

### PowerShell 5.1 Responsiveness During Large Replays

**Symptom**: When processing large offline datasets (100K+ records) in replay mode (`-RAWInputCSV`), PowerShell 5.1 may experience 3-5 minute pauses during the explosion phase, typically around the 6,000-record mark. The script **will resume and complete successfully** - these are temporary processing pauses, not hangs.

**Root Cause**: Combination of aggressive chunk auto-boosting (15K rows for narrow schemas) and PowerShell 5.1's garbage collection behavior under memory pressure.

**Workarounds** (choose one):

1. **🔧 Recommended Solution**: Upgrade to **PowerShell 7+**
   - Install from: https://aka.ms/powershell
   - PowerShell 7 has significantly improved garbage collection and memory management
   - Enables parallel processing features for even faster performance
   - No script changes required

2. **⚙️ Alternative: Reduce Chunk Size**
   ```powershell
   .\CopilotInteraction_Purview_Export.ps1 -RAWInputCSV "input.csv" -StreamingChunkSize 3000
   ```
   - Manually sets chunk size to 3,000 rows (default auto-boost is 15,000)
   - Trades some throughput for more responsive processing
   - Eliminates long pauses in PowerShell 5.1

3. **📊 Alternative: Increase Schema Sample Size**
   ```powershell
   .\CopilotInteraction_Purview_Export.ps1 -RAWInputCSV "input.csv" -StreamingSchemaSample 5000
   ```
   - Delays schema freeze until 5,000 rows analyzed (default is 2,000)
   - Provides more column discovery time before auto-boost kicks in
   - May help with datasets that have evolving schemas

**Important Notes**:
- This is a **quality-of-life issue**, not a correctness or security problem
- The script **completes successfully** in PowerShell 5.1, just with extended pauses
- Ctrl-C may be unresponsive during pauses; if needed, use Task Manager/Activity Monitor to terminate
- Live query mode (non-replay) is **not affected** by this limitation

---

## 🚀 Quick Start Examples

### Example 1: Live Query - Previous Day (Default)
```powershell
.\CopilotInteraction_Purview_Export.ps1 -OutputFile "copilot_audit.csv"
```
Queries all `CopilotInteraction` events from the previous day (automatic window).

### Example 2: Live Query - Specific Date Range
```powershell
.\CopilotInteraction_Purview_Export.ps1 `
  -StartDate "2025-10-01" `
  -EndDate "2025-10-05" `
  -OutputFile "oct_copilot.csv"
```

### Example 3: Offline Replay with Deep Explosion
```powershell
.\CopilotInteraction_Purview_Export.ps1 `
  -RAWInputCSV "raw_audit_logs.csv" `
  -ExplodeDeep `
  -OutputFile "exploded_audit.csv"
```
Processes a previously exported CSV with full deep-flatten of nested JSON structures.

### Example 4: Array Explosion (Purview Schema)
```powershell
.\CopilotInteraction_Purview_Export.ps1 `
  -StartDate "2025-09-01" `
  -EndDate "2025-09-30" `
  -ExplodeArrays `
  -OutputFile "september_exploded.csv"
```
Exports with Purview's 29-column exploded schema (Context, Message, AccessedResource arrays).

### Example 5: PowerShell 7 with Parallel Processing
```powershell
pwsh  # Launch PowerShell 7
.\CopilotInteraction_Purview_Export.ps1 `
  -StartDate "2025-10-01" `
  -EndDate "2025-10-07" `
  -ParallelMode Auto `
  -OutputFile "weekly_fast.csv"
```
Leverages parallel query execution for multi-activity date ranges.

---

## 📊 Key Features

### Data Export Modes
- **Live Query Mode**: Connects to Exchange Online to retrieve audit logs
- **Replay Mode**: Processes previously exported CSV files offline
- **Standard Output**: One-to-one record transformation with aggregated metrics
- **Array Explosion**: Purview 29-column exploded schema (one row per Context/Message/AccessedResource)
- **Deep Flatten**: Recursive flattening of all nested JSON structures (hundreds of columns)

### Performance Optimizations
- **Streaming Architecture**: Processes records in chunks to minimize memory footprint
- **Adaptive Sizing**: Automatically adjusts chunk size based on schema complexity
- **Schema Sampling**: Analyzes first 2,000 rows to freeze column order before bulk processing
- **Parallel Execution** (PS7+): Concurrent query processing for multiple activity types
- **Fast CSV Writer**: Custom UTF-8 StreamWriter with manual RFC 4180 escaping

### Enterprise Features
- **Retry Logic**: Exponential backoff with automatic block subdivision on throttling
- **Progress Tracking**: Weighted phase progress (Query/Explosion/Export) with real-time updates
- **Activity Learning**: Adapts block sizes based on historical query patterns
- **Late Column Handling**: Tracks and reports schema drift during streaming
- **Comprehensive Metrics**: Query time, explosion time, export time, fanout statistics

---

## 🔧 Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-StartDate` | Query start date (yyyy-MM-dd) | Previous day |
| `-EndDate` | Query end date (yyyy-MM-dd) | Today |
| `-OutputFile` | Path to output CSV file | `CopilotInteraction_Export.csv` |
| `-RAWInputCSV` | Replay mode: process existing CSV | *(none - live query)* |
| `-ExplodeArrays` | Use Purview exploded schema | `$false` |
| `-ExplodeDeep` | Deep flatten all nested structures | `$false` |
| `-StreamingChunkSize` | Rows per chunk | `5000` (adaptive) |
| `-StreamingSchemaSample` | Rows to sample for schema | `2000` |
| `-ParallelMode` | Parallel execution: Auto/On/Off | `Off` |
| `-MaxConcurrency` | Max parallel threads (PS7+) | `4` |
| `-NoProgress` | Disable progress bar | `$false` |

For complete parameter documentation, run:
```powershell
Get-Help .\CopilotInteraction_Purview_Export.ps1 -Full
```

---

## 🛡️ Security & Compliance

- ✅ **No credential persistence** - uses secure Exchange Online authentication flows
- ✅ **CurrentUser module scope** - no system-wide installations
- ✅ **Read-only operations** - `Search-UnifiedAuditLog` is non-destructive
- ✅ **Certificate validation** - respects TLS/SSL security
- ✅ **Input validation** - proper parameter sanitization
- ✅ **Safe CSV escaping** - RFC 4180 compliant output

---

## 📚 Additional Resources

- **Script Location**: `scripts/CopilotInteraction_Purview_Export.ps1`
- **Documentation**: See `README.md` for detailed feature descriptions
- **Support**: Contact your administrator for enterprise deployment assistance

---

## 🐛 Bug Fixes from Previous Versions

### Critical Fixes (v1.3.11 → v1.3.12)
- ✅ CSV writer scope bug resolved (was using `$global:`, now correctly uses `$script:`)
- ✅ CreationTime timestamp normalization added (now matches CreationDate format)
- ✅ Late column discovery tracking implemented with enumeration preview
- ✅ Collection enumeration error fixed (removed experimental per-item nulling)
- ✅ Customer-facing comments cleaned (removed "experimental", "magic numbers", build notes)

### Validation Results
- **Syntax**: No errors detected
- **Security**: Passed enterprise security review
- **Performance**: Streaming architecture tested with 367K+ record datasets
- **Compatibility**: Validated on PowerShell 5.1 and 7.4

---

## 🎉 Getting Started

1. **Install PowerShell 7** (recommended):
   ```powershell
   winget install Microsoft.PowerShell
   # Or visit: https://aka.ms/powershell
   ```

2. **Install ExchangeOnlineManagement Module**:
   ```powershell
   Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
   ```

3. **Run Your First Export**:
   ```powershell
   pwsh  # Launch PowerShell 7
   cd "path\to\scripts"
   .\CopilotInteraction_Purview_Export.ps1 -OutputFile "my_first_export.csv"
   ```

4. **Review Results**:
   - Output CSV: `my_first_export.csv`
   - Log file: `CopilotInteraction_Export_<timestamp>.log`
   - Check metrics summary in console output

---

## 📞 Support & Feedback

This is a **pilot release** validated for customer testing. We welcome your feedback:

- **Performance**: How does it perform with your data volumes?
- **Compatibility**: Any issues with your PowerShell version or environment?
- **Features**: What additional capabilities would help your workflows?
- **Documentation**: Are the examples and guidance clear?

Contact your deployment team or administrator with questions or feedback.

---

**Release Version**: v1.3.12  
**Script Version**: v1.3.11  
**Build Date**: October 6, 2025  
**Status**: ✅ Production-Ready for Pilot Deployment
