# PAX Graph Audit Log Processor - Release Notes v0.1.1

## Release Information
- **Version:** 0.1.1
- **Release Date:** October 22, 2025
- **Status:** Beta - Initial Public Release
- **Script:** `PAX_Graph_Audit_Log_Processor_v0.1.1.ps1`

---

## Overview

This is the initial public release of the **PAX Graph Audit Log Processor**, a PowerShell-based tool designed to retrieve and analyze Microsoft Graph audit logs. This script provides comprehensive audit log collection capabilities for Microsoft 365 services through the Graph API.

---

## Key Features

### Audit Log Collection
- **Graph API Integration:** Direct retrieval of audit logs via Microsoft Graph API
- **Service Coverage:** Supports multiple Microsoft 365 services including Exchange, SharePoint, OneDrive, Teams, and Azure AD
- **Flexible Time Ranges:** Query logs using Start/End dates with automatic period-based chunking
- **Activity Filtering:** Filter by specific activities or operation types

### Data Processing
- **Multiple Output Formats:** JSON and CSV export options
- **Rich Metadata:** Captures comprehensive audit details including user, operation, service, and timestamps
- **Efficient Processing:** Handles large datasets with automatic pagination and rate limiting

### Authentication & Security
- **Modern Authentication:** Uses Microsoft Graph API with OAuth 2.0
- **App Registration Support:** Supports both interactive and non-interactive authentication
- **Secure Credential Handling:** Follows security best practices for credential management

### Enterprise Features
- **Error Handling:** Robust error handling with detailed logging
- **Progress Tracking:** Real-time progress indicators for long-running operations
- **Resumability:** Support for interrupted operations and retry logic
- **Documentation:** Comprehensive inline help and parameter documentation

---

## Breaking Changes from Pre-Release Versions

⚠️ **Important:** This release includes breaking changes from earlier development versions:

- **Removed Parameters:**
  - `DaysBack` parameter has been removed
  - `EndDate` parameter has been removed
  
- **Required Parameters:**
  - `Start` parameter is now **required**
  - `End` parameter is now **required**

**Migration Guide:**
- **Old:** `.\PAX_Graph_Audit_Log_Processor.ps1 -DaysBack 7`
- **New:** `.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Start "2025-10-15" -End "2025-10-22"`

These changes provide more explicit control over date ranges and align with enterprise requirements for audit log retrieval.

---

## System Requirements

- **PowerShell:** 5.1 or later (PowerShell 7.x recommended)
- **Modules Required:**
  - Microsoft.Graph.Authentication
  - Microsoft.Graph.Reports
- **Permissions Required:**
  - AuditLog.Read.All
  - Directory.Read.All
- **Microsoft 365:** Valid tenant with audit logging enabled

---

## Installation

### 1. Download the Script
Download `PAX_Graph_Audit_Log_Processor_v0.1.1.ps1` from the [GitHub Releases](https://github.com/microsoft/PAX/releases/tag/graph-v0.1.1) page.

### 2. Install Required Modules
```powershell
Install-Module -Name Microsoft.Graph.Authentication -Force
Install-Module -Name Microsoft.Graph.Reports -Force
```

### 3. Configure Azure App Registration
1. Register an application in Azure AD
2. Grant required API permissions (AuditLog.Read.All, Directory.Read.All)
3. Create a client secret or certificate
4. Note the Tenant ID, Client ID, and Client Secret

### 4. Run the Script
```powershell
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Start "2025-10-01" -End "2025-10-22"
```

---

## Usage Examples

### Basic Audit Log Retrieval
```powershell
# Retrieve last 30 days of audit logs
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Start "2025-09-22" -End "2025-10-22"
```

### Export to Specific Location
```powershell
# Export to custom directory as CSV
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Start "2025-10-01" -End "2025-10-22" -OutputPath "C:\AuditLogs" -OutputFormat CSV
```

### Filter by Activity
```powershell
# Retrieve only file access events
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Start "2025-10-15" -End "2025-10-22" -Activities "FileAccessed","FileDownloaded"
```

### Non-Interactive Authentication
```powershell
# Use app registration credentials
.\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Start "2025-10-01" -End "2025-10-22" -TenantId "your-tenant-id" -ClientId "your-client-id" -ClientSecret "your-secret"
```

---

## Known Limitations (Beta)

- **Beta Status:** This is a beta release - features and parameters may change in future versions
- **Rate Limiting:** Microsoft Graph API rate limits may affect large data retrievals
- **Time Zones:** All timestamps are in UTC
- **Large Datasets:** Very large time ranges may require multiple runs

---

## Getting Help

### Documentation
- **Full Documentation:** [PAX_Graph_Audit_Log_Processor_Documentation_v0.1.1.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Graph_Audit_Log_Processor/PAX_Graph_Audit_Log_Processor_Documentation_v0.1.1.md)
- **Inline Help:** Run `Get-Help .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Full`

### Support Channels
- **Issues:** Report bugs or request features on [GitHub Issues](https://github.com/microsoft/PAX/issues)
- **Discussions:** Join the conversation in [GitHub Discussions](https://github.com/microsoft/PAX/discussions)

### Additional Resources
- [Microsoft Graph Audit Logs Documentation](https://learn.microsoft.com/en-us/graph/api/resources/azure-ad-auditlog-overview)
- [PAX Solution Set Overview](https://github.com/microsoft/PAX)

---

## Roadmap

Future releases may include:
- Additional service-specific filtering options
- Enhanced error recovery and resumability
- Performance optimizations for large datasets
- Integration with Azure Sentinel and other SIEM solutions
- Advanced analytics and reporting capabilities

---

## Acknowledgments

Thank you to the Microsoft community and early adopters who provided feedback during the development of this tool.

---

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/microsoft/PAX/blob/main/LICENSE) file for details.

---

**Note:** This is a beta release. Please review the documentation thoroughly and test in a non-production environment before deploying to production systems.
