# PAX Graph Audit Log Processor - Release Note v1.0.1

## Overview

**PAX Graph Audit Log Processor v1.0.1** is a major feature release that expands the capabilities of the Microsoft Graph-based usage data collection tool. Building on v0.1.2's foundation, this release introduces **Excel workbook export**, **MAC (Microsoft Admin Center) licensing endpoints**, **granular endpoint selection**, and substantial usability enhancements—transforming the tool from a basic CSV exporter into a comprehensive M365 analytics platform.

## Key Improvements in v1.0.1

This release delivers **5 major feature categories** focused on **usability**, **data breadth**, and **output flexibility**:

1. **Excel Workbook Export with Append Mode**
   - New `-ExportWorkbook` switch creates multi-sheet Excel workbooks with formatted tables and auto-fit columns
   - `-AppendWorkbook` mode adds new data to existing workbooks without overwriting previous sheets
   - Automatic ImportExcel module installation and validation
   - Workbook conflict detection with `-Force` override
   - Ideal for recurring exports, trend analysis, and executive dashboards

2. **MAC Licensing Endpoints (2 New Endpoints)**
   - **MACCopilotLicensing**: Per-user Copilot license assignments with three-tier SKU detection
   - **MACLicenseSummary**: Tenant-wide license capacity summary with enabled/consumed/available counts
   - Comprehensive service plan expansion showing granular license components
   - Purpose-built for license optimization, compliance audits, and usage-to-license correlation

3. **Granular Endpoint Selection (10 New Parameters)**
   - Individual switches for each major endpoint category
   - Exclusion controls for fine-tuned data collection
   - `-IncludeCustomEndpoints` for advanced scenarios
   - Replaces `-IncludeCurated` all-or-nothing approach with precise control

4. **Enhanced Data Processing**
   - Improved obfuscation detection with SHA-256 hash pattern recognition
   - Better array flattening for multi-value license and service plan fields
   - Expanded Entra user attribute collection (35+ properties)
   - Optimized CSV parsing with UTF-8 BOM handling and comma-in-field robustness

5. **Usability & Reliability Improvements**
   - Automatic Graph API disconnection on script exit
   - Better parameter validation with detailed error messages
   - Enhanced logging with endpoint-by-endpoint progress tracking
   - Script size optimization: 1785 → 3182 lines (78% increase due to new features)

## Why This Release Matters

v1.0.1 transforms the Graph Audit Log Processor from a **data collection tool** into an **analytics platform**. Key business impacts:

- **Excel Integration**: Eliminates CSV → Excel manual conversion; workbooks are dashboard-ready with formatted tables
- **Append Workflow**: Supports recurring exports (weekly, monthly) with historical trend tracking in single workbooks
- **License Optimization**: MAC licensing endpoints enable cost analysis by correlating active users with assigned licenses
- **Selective Data Collection**: Granular switches reduce API calls, improve performance, and enable scenario-specific exports
- **Automation-Ready**: Append mode + certificate auth + ImportExcel auto-install = fully hands-off recurring pipelines

Organizations can now:

✅ Build **executive dashboards** with multi-period trend analysis  
✅ Perform **license audits** with MACCopilotLicensing + MACLicenseSummary correlation  
✅ Optimize **API performance** by querying only required endpoints (vs. all 17)  
✅ Eliminate **manual Excel formatting** (workbooks have formatted tables, auto-fit columns, sheet names)

---

## Detailed Changes in v1.0.1

### 🎯 New Features

#### 1. Excel Workbook Export

**Parameters**:
- `-ExportWorkbook`: Creates Excel workbook with each endpoint as a separate sheet
- `-AppendWorkbook`: Adds data to existing workbook without overwriting existing sheets
- `-Force`: Overrides workbook conflict warnings (use with `-ExportWorkbook`)

**Example**:
```powershell
# Initial export
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -OutputPath "C:\Reports" -OutputFileName "M365_Usage.xlsx" -Auth DeviceCode -IncludeCopilotUsage -ExportWorkbook

# Next week: Append new data
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -OutputPath "C:\Reports" -OutputFileName "M365_Usage.xlsx" -Auth DeviceCode -IncludeCopilotUsage -AppendWorkbook
```

---

#### 2. MAC Licensing Endpoints

**MACCopilotLicensing**: Per-user Copilot license assignments with three-tier SKU detection (Standard, Pro, Developer/Testing)

**MACLicenseSummary**: Tenant-wide license capacity summary across all SKUs

**Example**:
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -OutputPath "C:\Reports" -Auth DeviceCode -IncludeCopilotUsage -IncludeMACCopilotLicensing -IncludeMACLicenseSummary -ExportWorkbook
```

---

#### 3. Granular Endpoint Selection

**New Parameters**:
- `-IncludeCopilotUsage`: Explicitly include Copilot usage endpoint
- `-IncludeM365AppUserDetail`: Include M365 Apps user detail (default endpoint)
- `-IncludeOutlookActivity`: Include Email Activity + Email App Usage
- `-IncludeTeamsActivity`: Include Teams User Activity
- `-IncludeSharePointActivity`: Include SharePoint Activity + SharePoint Site Usage
- `-IncludeOneDriveActivity`: Include OneDrive Activity + OneDrive Usage
- `-IncludeMACCopilotLicensing`: Include per-user Copilot license assignments
- `-IncludeMACLicenseSummary`: Include tenant-wide license capacity summary

**Example**:
```powershell
# Copilot-focused export
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -OutputPath "C:\Reports" -Auth DeviceCode -IncludeCopilotUsage -IncludeMACCopilotLicensing -IncludeMACLicenseSummary -ExportWorkbook

# Collaboration workloads only
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -OutputPath "C:\Reports" -Auth DeviceCode -IncludeTeamsActivity -IncludeSharePointActivity -IncludeOneDriveActivity -ExportWorkbook
```

---

### 🔧 Enhancements

1. **Automatic Graph Disconnection**: Script automatically disconnects from Microsoft Graph on exit
2. **Improved Obfuscation Detection**: SHA-256 hash pattern recognition
3. **Enhanced Logging**: Endpoint-by-endpoint progress tracking with record counts
4. **Parameter Validation**: Workbook conflict detection prevents accidental overwrites
5. **ImportExcel Module Management**: Auto-install with CurrentUser scope

---

### 📊 Endpoint Summary Changes

**Total Endpoints**:
- **v0.1.2**: 15 endpoints
- **v1.0.1**: 17 endpoints (added MACCopilotLicensing, MACLicenseSummary)

**Endpoint Categories** (v1.0.1):
1. **Copilot**: CopilotUsage, MACCopilotLicensing (2 endpoints)
2. **M365 Apps**: M365AppUserDetail, M365Activations, M365ActiveUsers (3 endpoints)
3. **Teams**: TeamsUserActivity (1 endpoint)
4. **Outlook**: EmailActivity, EmailAppUsage (2 endpoints)
5. **OneDrive**: OneDriveActivity, OneDriveUsage (2 endpoints)
6. **SharePoint**: SharePointActivity, SharePointSiteUsage (2 endpoints)
7. **Yammer**: YammerActivity, YammerDeviceUsage, YammerGroupsActivity (3 endpoints)
8. **Licensing**: MACLicenseSummary (1 endpoint)
9. **Entra**: EntraUsers (1 endpoint)

---

### 🐛 Bug Fixes

1. **Workbook Overwrite Protection**: Added conflict detection; requires `-Force` to overwrite
2. **ImportExcel Missing Dependency**: Automatic installation with CurrentUser scope
3. **Parameter Conflict Handling**: Added validation; displays error if both `-ExportWorkbook` and `-AppendWorkbook` used
4. **Excel Filename Extension**: Automatic .xlsx enforcement
5. **Graph Session Cleanup**: `try/finally` block ensures `Disconnect-MgGraph` on all exit paths

---

### 📋 Known Limitations

1. **Period Queries Only**: v1.0.1 supports period queries only (D7/D30/D90/D180/ALL)
2. **Graph Endpoint Limitation**: Graph API constraint - only supports period queries
3. **Entra User Snapshot**: Retrieves current attributes (not historical)
4. **Append Mode Sheet Conflicts**: Will fail if sheet name already exists

---

## Installation & Upgrade Instructions

### 📥 Download Script

**Direct Download**:  
[PAX_Graph_Audit_Log_Processor_v1.0.1.ps1](https://github.com/microsoft/PAX/releases/download/graph-v1.0.1/PAX_Graph_Audit_Log_Processor_v1.0.1.ps1)

### 🔧 Prerequisites

1. **PowerShell**: Version 7.0 or later (Windows, macOS, Linux)
2. **Microsoft.Graph.Authentication Module**:  
   ```powershell
   Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
   ```
3. **ImportExcel Module** (auto-installs if `-ExportWorkbook` used):  
   ```powershell
   Install-Module ImportExcel -Scope CurrentUser -Force
   ```
4. **Graph API Permissions**: `Reports.Read.All`, `User.Read.All`, `AuditLog.Read.All` (optional)

### ⬆️ Upgrading from v0.1.2

**Breaking Changes**: None (v1.0.1 is fully backward-compatible)

**Parameter Changes**:
- `-IncludeCopilot` renamed to `-IncludeCopilotUsage` (old name still works via alias)
- `-IncludeCurated` now includes 17 endpoints (was 15)

**Migration Example**:
```powershell
# v0.1.2 command
.\PAX_Graph_Audit_Log_Processor_v0.1.2.ps1 -Period D30 -OutputPath "C:\Reports" -Auth DeviceCode -IncludeCopilot

# v1.0.1 equivalent with Excel output
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -OutputPath "C:\Reports" -Auth DeviceCode -IncludeCopilotUsage -ExportWorkbook
```

---

## Quick Start Examples

### Example 1: Basic Copilot Usage Export (Excel)
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -OutputPath "C:\Reports" -Auth DeviceCode -IncludeCopilotUsage -ExportWorkbook
```
**Result**: Excel workbook with 2 sheets (CopilotUsage, M365AppUserDetail)

---

### Example 2: Copilot + Licensing Analysis
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -OutputPath "C:\Reports" -Auth DeviceCode -IncludeCopilotUsage -IncludeMACCopilotLicensing -IncludeMACLicenseSummary -ExportWorkbook
```
**Result**: Excel workbook with 4 sheets

---

### Example 3: Recurring Weekly Append
```powershell
# Week 1
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -OutputPath "C:\Reports" -OutputFileName "Weekly_Usage.xlsx" -Auth DeviceCode -IncludeCopilotUsage -ExportWorkbook

# Week 2
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D7 -OutputPath "C:\Reports" -OutputFileName "Weekly_Usage.xlsx" -Auth DeviceCode -IncludeCopilotUsage -AppendWorkbook
```
**Result**: Single workbook with multi-week trend data

---

### Example 4: Comprehensive Data Collection
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D90 -OutputPath "C:\Reports" -Auth DeviceCode -ExportWorkbook
```
**Result**: Excel workbook with 17 sheets (all endpoints)

---

### Example 5: Selective Export (Collaboration Workloads)
```powershell
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -OutputPath "C:\Reports" -Auth DeviceCode -IncludeTeamsActivity -IncludeSharePointActivity -IncludeOneDriveActivity -ExportWorkbook
```
**Result**: Excel workbook with 6 sheets

---

## Documentation

**Full Documentation**:  
[PAX_Graph_Audit_Log_Processor_Documentation_v1.0.1.md](https://github.com/microsoft/PAX/blob/main/release_documentation/Graph_Audit_Log_Processor/PAX_Graph_Audit_Log_Processor_Documentation_v1.0.1.md)

**Topics Covered**:
- Excel workbook export and append workflows
- MAC licensing endpoint usage and SKU detection
- Granular endpoint selection strategies
- Authentication setup (Device Code + Certificate)
- Parameter reference and usage examples
- Troubleshooting common errors

---

## Summary

**PAX Graph Audit Log Processor v1.0.1** represents a **major evolution** from v0.1.2's CSV-centric approach to a comprehensive M365 analytics platform. With Excel workbook export, MAC licensing endpoints, and granular endpoint selection, this release empowers organizations to:

✅ **Build executive dashboards** with pre-formatted Excel tables and multi-period trend analysis  
✅ **Optimize license costs** by correlating active usage with assigned Copilot licenses  
✅ **Automate recurring reports** with append mode for historical tracking  
✅ **Improve performance** by querying only required endpoints (vs. all 17)  
✅ **Simplify data workflows** with automatic Graph disconnection and ImportExcel management  

This release transforms the tool from a **data collector** into an **analytics enabler**—critical for organizations scaling Microsoft 365 Copilot deployments and requiring actionable insights from usage and licensing data.

---

## Support & Feedback

For questions, feedback, or assistance with the PAX Graph Audit Log Processor, please refer to the comprehensive documentation included with this release.

**License**: MIT

---

**Release Date**: October 30, 2025  
**Script Version**: 1.0.1  
**Author**: Microsoft Copilot ROI Advisory Team ([copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com?subject=PAX%20Graph%20Audit%20Log%20Processor%20Feedback))
