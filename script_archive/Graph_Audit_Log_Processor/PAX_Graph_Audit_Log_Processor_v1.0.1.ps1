# Portable Audit eXporter (PAX) - Graph Audit Log Processor
# Version: v1.0.1
<#
.SYNOPSIS
    Export Microsoft 365 usage analytics and license data from Microsoft Graph API.
    By default, queries a curated set of 9 endpoints for comprehensive usage and licensing reporting.

.DESCRIPTION
    The Portable Audit eXporter (PAX) - Graph Audit Log Processor retrieves M365 usage data,
    Copilot license assignments, and tenant-wide license capacity from Microsoft Graph API.
    Exports to CSV or Excel files with professional formatting.
    
    Default Behavior (no parameters):
        Queries 9 curated endpoints for comprehensive tenant analysis:
            • M365 App User Detail - Application usage per user
            • Teams User Activity - Teams usage metrics
            • Email Activity - Outlook/email usage
            • SharePoint Activity - SharePoint site activity
            • OneDrive Activity - OneDrive usage per user
            • Copilot Usage - Microsoft 365 Copilot usage (if licensed)
            • MAC Copilot Licensing - Per-user Copilot license assignments with SKU details
            • MAC Copilot License Summary - Tenant-wide Copilot and M365 license capacity
            • Entra Users - User directory information with 35 properties
    
    Endpoint Selection:
        • No parameters: Use default curated set (9 endpoints)
        • -Include* parameters: Replace default with specified endpoints (additive)
        • -Exclude* parameters: Start with default, remove specified endpoints
        • -IncludeCurated: Explicitly include all 9 curated endpoints (combinable)
        • -IncludeCustomEndpoints: Specify array of endpoint names to query
    
    Total Available Endpoints: 17
        • CopilotUsage, M365AppUserDetail, M365ActiveUsers, M365Activations
        • TeamsUserActivity, EmailActivity, EmailAppUsage
        • OneDriveActivity, OneDriveUsage
        • SharePointActivity, SharePointSiteUsage
        • YammerActivity, YammerDeviceUsage, YammerGroupsActivity
        • MACCopilotLicensing (per-user license assignments)
        • MACLicenseSummary (tenant-wide license capacity)
        • EntraUsers
    
    Query Mode:
        All endpoints use period-based queries (D7, D30, D90, D180, ALL).
        Period queries are aggregated reports covering the specified time window.
        Default period: D7 (last 7 days)
    
    Output Management:
        -OutputPath <string>     : Directory for output files (default: C:\Temp\MS_Graph)
        -OutputFileName <string> : Custom filename for output (with -CombineOutput or -ExportWorkbook)
        -CombineOutput           : Combine all endpoints into single CSV file
        -ExportWorkbook          : Export to Excel workbook with multi-sheet layout
        -AppendWorkbook          : Append data to existing Excel workbook
        
        File Naming:
            • Individual CSV files: Auto-generated with timestamps
            • Combined CSV: Custom name or auto-generated with timestamp
            • Excel workbook: Custom name or auto-generated with timestamp
            • No timestamped subfolders created
    
    Excel Export Features:
        • Multi-sheet workbook with one tab per endpoint
        • Professional formatting (frozen headers, auto-sized columns, bold headers)
        • Ordered tabs (Entra Users → Copilot → M365 → Teams → Email → SharePoint → OneDrive)
        • Append mode with column validation and timestamped duplicate tabs
        • Automatic ImportExcel module installation
    
    Entra User Enrichment:
        35 Core Entra Properties (included in default curated set):
            Identity (6): userPrincipalName, displayName, id, mail, givenName, surname
            Job (5): jobTitle, department, employeeType, employeeId, employeeHireDate
            Location (6): officeLocation, city, state, country, postalCode, companyName
            Organization (1): employeeOrgData (division, costCenter nested)
            Status (3): accountEnabled, userType, createdDateTime
            Usage (2): usageLocation, preferredLanguage
            Manager (4): manager_displayName, manager_userPrincipalName, manager_mail, manager_id
            Administrative (7): additional fields for tenant admins
    
    Authentication Methods:
        -Auth WebLogin    : Interactive browser authentication (default)
        -Auth DeviceCode  : Device code flow for limited browsers
        -Auth Credential  : Client secret credential (requires environment variables)
        -Auth Silent      : Managed identity or existing token
    
    PowerShell 5.1 & 7+ supported.

.PARAMETER Period
    Time period for aggregated queries: D7 (7 days), D30 (30 days), D90 (90 days), D180 (180 days), or ALL.
    Uses period-based Graph API queries for all endpoints.
    Default: D7 (last 7 days).

.PARAMETER OutputPath
    Directory for output files (default: C:\Temp\MS_Graph).
    Created automatically if it doesn't exist.

.PARAMETER OutputFileName
    Custom filename for combined output (only used with -CombineOutput).
    If .csv extension missing, it will be added automatically.

.PARAMETER Auth
    Authentication method: WebLogin (default), DeviceCode, Credential, Silent.

.PARAMETER PacingMs
    Delay in milliseconds between API requests (0-10000, default: 0).
    Use for rate limiting with large tenants.

.PARAMETER ExplodeArrays
    Expand array properties (e.g., assignedLicenses, proxyAddresses) into separate columns.
    Creates assignedLicenses_1, assignedLicenses_2, etc.

.PARAMETER CombineOutput
    Combine all endpoint results into a single CSV file.
    If -OutputFileName not specified, auto-generates timestamped filename.
    Note: Ignored when -ExportWorkbook is specified (Excel always combines).

.PARAMETER IncludeCopilotUsage
    Include the Copilot Usage endpoint. Can be combined with other -Include* parameters.
    When any -Include* parameter is used, it replaces the default curated set.
    
.PARAMETER IncludeM365AppUserDetail
    Include the M365 App User Detail endpoint. Can be combined with other -Include* parameters.

.PARAMETER IncludeOutlookActivity
    Include the Email Activity endpoint. Can be combined with other -Include* parameters.

.PARAMETER IncludeTeamsActivity
    Include the Teams User Activity endpoint. Can be combined with other -Include* parameters.

.PARAMETER IncludeSharePointActivity
    Include the SharePoint Activity endpoint. Can be combined with other -Include* parameters.

.PARAMETER IncludeOneDriveActivity
    Include the OneDrive Activity endpoint. Can be combined with other -Include* parameters.

.PARAMETER IncludeMACCopilotLicensing
    Include the MAC Copilot Licensing endpoint (retrieves per-user Copilot license assignments).
    Returns user-level license data with SKU details, service plans, and assignment status.
    Can be combined with other -Include* parameters.
    
    Uses two-tier Copilot license detection:
    • Checks known Copilot SKU IDs (hardcoded list)
    • Pattern matches SKU names containing "Copilot" (catches new/promotional variants)
    
    Troubleshooting: If no licenses found but you have Copilot licenses assigned:
    • Check the debug output showing all SKU IDs detected
    • Review MACLicenseSummary output to identify your Copilot SKU names
    • Add missing SKU IDs to $script:CopilotSkuIds hashtable (search for "Known Microsoft 365 Copilot SKU IDs" in the source code)
    • Reference: https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference

.PARAMETER IncludeMACLicenseSummary
    Include the MAC Copilot License Summary endpoint (retrieves tenant-wide license capacity).
    Returns all Copilot and M365 SKUs with purchased, consumed, and available license counts.
    Includes utilization percentages and capacity planning metrics.
    Can be combined with other -Include* parameters.

.PARAMETER IncludeCustomEndpoints
    Specify custom array of endpoint names to query. Validates names against available endpoints.
    Example: -IncludeCustomEndpoints @('CopilotUsage', 'M365AppUserDetail', 'EntraUsers')

.PARAMETER IncludeCurated
    Include all curated usage endpoints (Copilot, M365AppUserDetail, Teams, Email, OneDrive, SharePoint, MACCopilotLicensing, MACLicenseSummary, EntraUsers).
    Can be combined with other -Include* parameters to add additional endpoints.
    
.PARAMETER IncludeEntraUsers
    Include Entra Users endpoint to enrich usage data with user properties.
    Adds 35 core user properties including department, manager, licenses, and location.

.PARAMETER ExcludeEntraUsers
    Exclude Entra Users from the default curated set. Only effective when no -Include* parameters are specified.
    If conflicts with -IncludeEntraUsers, prompts for resolution unless -Force is specified.

.PARAMETER ExcludeMACCopilotLicensing
    Exclude MAC Copilot Licensing from the default curated set.
    If conflicts with -IncludeMACCopilotLicensing, prompts for resolution unless -Force is specified.

.PARAMETER ExcludeMACLicenseSummary
    Exclude MAC Copilot License Summary from the default curated set.
    If conflicts with -IncludeMACLicenseSummary, prompts for resolution unless -Force is specified.

.PARAMETER ExportWorkbook
    Export data to Excel workbook (.xlsx) with multi-sheet layout instead of CSV files.
    Each endpoint gets its own worksheet with professional formatting.
    Requires ImportExcel module (auto-installs if missing).

.PARAMETER AppendWorkbook
    Append data to an existing Excel workbook. Requires -ExportWorkbook.
    Validates column headers match existing tabs. Creates timestamped duplicate tabs if mismatch detected.

.PARAMETER Force
    Auto-resolve conflicts between -Include* and -Exclude* parameters without prompting.
    Include parameters take precedence (exclude is ignored for conflicting endpoints).

.PARAMETER Help
    Display this help information.

.NOTES
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
    
    The script will detect obfuscation automatically and provide detailed instructions
    if hashed data is encountered.
    
    ⚠️ SIGN-IN ACTIVITY DATA (MAC Copilot Licensing):
    
    When querying MAC Copilot Licensing endpoint with -IncludeMACCopilotLicensing or
    -IncludeCurated, the script includes lastSignInDateTime data for license analysis.
    
    ADDITIONAL REQUIREMENTS:
      • Azure AD Premium P1 or P2 license (tenant-wide)
      • AuditLog.Read.All Graph API permission (requires admin consent)
      • Permission will be requested automatically when needed
    
    If AuditLog.Read.All permission is missing, the script will:
      1. Display a warning about the missing permission
      2. Offer options to either:
         - Continue without sign-in activity data (columns will be null)
         - Exit to re-authenticate with proper permissions
    
    Sign-in activity columns in MAC Copilot Licensing output:
      • lastSignInDateTime - Last interactive user sign-in
      • lastNonInteractiveSignInDateTime - Last automated/background sign-in
    
    COPILOT LICENSE DETECTION (Two-Tier System):
    
    The MAC Copilot Licensing endpoint uses dual detection methods to identify Copilot licenses:
      1. Known SKU IDs - Checks hardcoded list of Microsoft 365 Copilot SKU GUIDs
      2. Pattern Matching - Searches SKU names for "Copilot" (catches promotional/new variants)
    
    This ensures compatibility with promotional licenses, regional variations, and new SKU types.
    
    TROUBLESHOOTING - "No licenses found" but you have Copilot licenses assigned:
      • Review debug output showing all detected SKU IDs during script execution
      • Check MACLicenseSummary output file to identify your Copilot SKU names/IDs
      • If your SKU isn't detected, add the SKU ID to $script:CopilotSkuIds hashtable in script
      • Search script for: "Known Microsoft 365 Copilot SKU IDs"
      • Microsoft SKU Reference: https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference

.EXAMPLE
    # Default: Query 7 curated endpoints (last 7 days, period-based)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1
    
.EXAMPLE
    # Specify period (last 30 days)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30
    
.EXAMPLE
    # Query only Copilot Usage endpoint
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCopilotUsage
    
.EXAMPLE
    # Query Copilot + Teams + Email endpoints
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCopilotUsage -IncludeTeamsActivity -IncludeOutlookActivity
    
.EXAMPLE
    # Use default curated set but exclude Entra Users
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -ExcludeEntraUsers
    
.EXAMPLE
    # Query custom set of endpoints by name
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCustomEndpoints @('CopilotUsage', 'M365AppUserDetail', 'EntraUsers')
    
.EXAMPLE
    # Export to Excel workbook with multi-sheet layout
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -ExportWorkbook
    
.EXAMPLE
    # Export to Excel with custom filename
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -ExportWorkbook -OutputFileName "Usage_Report.xlsx"
    
.EXAMPLE
    # Append data to existing Excel workbook
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -ExportWorkbook -AppendWorkbook -OutputFileName "Usage_Report.xlsx"
    
.EXAMPLE
    # Auto-resolve conflicts with -Force
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeEntraUsers -ExcludeEntraUsers -Force
    
.EXAMPLE
    # Combined CSV output with custom filename
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -CombineOutput -OutputFileName "Weekly_Report.csv"
    
.EXAMPLE
    # Custom output path with Excel export
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -ExportWorkbook -OutputPath C:\Reports
    
.EXAMPLE
    # Device code authentication with array explosion
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Auth DeviceCode -ExplodeArrays
    
.EXAMPLE
    # Custom throttling (100ms delay between requests)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -PacingMs 100
    
.EXAMPLE
    # Everything: All curated + Excel export + custom path
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -IncludeCurated -ExportWorkbook -OutputPath C:\Reports

.EXAMPLE
    # Copilot license assignments (user-level)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeMACCopilotLicensing

.EXAMPLE
    # License capacity summary (tenant-level)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeMACLicenseSummary

.EXAMPLE
    # Complete licensing analysis: Usage + Assignments + Capacity
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCopilotUsage -IncludeMACCopilotLicensing -IncludeMACLicenseSummary

.EXAMPLE
    # Full licensing + user attribution in Excel workbook
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -IncludeCopilotUsage -IncludeMACCopilotLicensing -IncludeMACLicenseSummary -IncludeEntraUsers -ExportWorkbook -OutputPath C:\Reports

.NOTES
    Version: 1.0.1
    Author: PAX Development Team
    Requires: Microsoft.Graph PowerShell SDK (auto-installs if missing)
              ImportExcel module (auto-installs if -ExportWorkbook used)
    Graph API Permissions: Reports.Read.All, User.Read.All, Directory.Read.All
    
    Prerequisites:
    - PowerShell 5.1 or PowerShell 7+
    - Microsoft.Graph PowerShell SDK (automatically installed if missing)
    - ImportExcel module (automatically installed if -ExportWorkbook used)
    - Internet connectivity to Microsoft Graph API and PowerShell Gallery
    - Appropriate Graph API permissions in your tenant
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('D7', 'D30', 'D90', 'D180', 'ALL')]
    [string]$Period = 'D7',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "C:\Temp\MS_Graph",

    [Parameter(Mandatory = $false)]
    [string]$OutputFileName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('WebLogin', 'DeviceCode', 'Credential', 'Silent')]
    [string]$Auth = 'WebLogin',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 10000)]
    [int]$PacingMs = 0,

    [Parameter(Mandatory = $false)]
    [switch]$ExplodeArrays,

    [Parameter(Mandatory = $false)]
    [switch]$CombineOutput,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeCopilotUsage,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeM365AppUserDetail,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeOutlookActivity,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeTeamsActivity,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeSharePointActivity,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeOneDriveActivity,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeCurated,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeEntraUsers,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeMACCopilotLicensing,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeMACLicenseSummary,

    [Parameter(Mandatory = $false)]
    [string[]]$IncludeCustomEndpoints,

    [Parameter(Mandatory = $false)]
    [switch]$ExcludeEntraUsers,

    [Parameter(Mandatory = $false)]
    [switch]$ExcludeMACCopilotLicensing,

    [Parameter(Mandatory = $false)]
    [switch]$ExcludeMACLicenseSummary,

    [Parameter(Mandatory = $false)]
    [switch]$ExportWorkbook,

    [Parameter(Mandatory = $false)]
    [switch]$AppendWorkbook,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Display help if -Help switch is provided
if ($Help) {
    Get-Help $PSCommandPath -Full
    exit 0
}

# Script version constant (must appear after param/help to keep param() valid as first executable block)
$ScriptVersion = "1.0.1"

# Suppress verbose progress messages from Invoke-MgGraphRequest
$ProgressPreference = 'SilentlyContinue'

# Initialize metrics object with start time
$script:metrics = @{
    StartTime = (Get-Date).ToUniversalTime()
}

# Create log file path (same name as output, but .log extension)
if ($CombineOutput -and $OutputFileName) {
    $LogFile = Join-Path $OutputPath ($OutputFileName -replace '\.csv$', '.log')
}
elseif ($CombineOutput) {
    $LogFile = Join-Path $OutputPath "GraphUsageLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}
else {
    $LogFile = Join-Path $OutputPath "GraphUsageLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}

# Logging functions (writes to both console and log file)
function Write-Log { 
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message, 
        [string]$Level = "INFO"
    ) 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $Message
    try { 
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue 
    } catch {}
}

function Write-LogHost { 
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message, 
        [string]$ForegroundColor = "White"
    ) 
    Write-Host $Message -ForegroundColor $ForegroundColor
    try { 
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [INFO] $Message"
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue 
    } catch {}
}

# Obfuscates email addresses for security and privacy
function Hide-EmailAddress {
    param([string]$Email)
    
    if ([string]::IsNullOrWhiteSpace($Email) -or $Email -notmatch '@') {
        return $Email
    }
    
    $parts = $Email.Split('@')
    $username = $parts[0]
    $domain = $parts[1]
    
    if ($username.Length -le 2) {
        # Very short username: show first char + asterisks
        return "$($username[0])******@$domain"
    }
    else {
        # Normal case: first char + 7 asterisks + last char
        return "$($username[0])*******$($username[-1])@$domain"
    }
}

# Create log file directory if needed
$logDir = Split-Path $LogFile -Parent
if (-not (Test-Path $logDir)) { 
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null 
}

# Initialize log file with header
$startTimeStamp = $script:metrics.StartTime.ToString('yyyy-MM-dd HH:mm:ss')
@"
=== Portable Audit eXporter (PAX) - Graph Audit Log Processor ===
Script Start Time (UTC): $startTimeStamp UTC
Script Version: v$ScriptVersion
Output Path: $OutputPath
Log File: $LogFile
========================================================

"@ | Out-File -FilePath $LogFile -Encoding UTF8

# Display header
Write-LogHost "`n=== Portable Audit eXporter (PAX) - Graph Audit Log Processor ===" -ForegroundColor Cyan
Write-LogHost ("Script Version: v$ScriptVersion") -ForegroundColor White
Write-LogHost ("Script execution started at $startTimeStamp UTC") -ForegroundColor White
Write-Log "============================================="
Write-Log ""

# Log parameter snapshot
Write-Log "Parameter Snapshot:"
Write-Log ("  Period = $Period")
Write-Log ("  OutputPath = $OutputPath")
Write-Log ("  OutputFileName = " + $(if ($OutputFileName) { $OutputFileName } else { "<auto-generated>" }))
Write-Log ("  Auth = $Auth")
Write-Log ("  PacingMs = $PacingMs")
Write-Log ""
Write-Log "Endpoint Selection Parameters:"
Write-Log ("  IncludeCopilotUsage = $($IncludeCopilotUsage.IsPresent)")
Write-Log ("  IncludeM365AppUserDetail = $($IncludeM365AppUserDetail.IsPresent)")
Write-Log ("  IncludeOutlookActivity = $($IncludeOutlookActivity.IsPresent)")
Write-Log ("  IncludeTeamsActivity = $($IncludeTeamsActivity.IsPresent)")
Write-Log ("  IncludeSharePointActivity = $($IncludeSharePointActivity.IsPresent)")
Write-Log ("  IncludeOneDriveActivity = $($IncludeOneDriveActivity.IsPresent)")
Write-Log ("  IncludeMACCopilotLicensing = $($IncludeMACCopilotLicensing.IsPresent)")
Write-Log ("  IncludeMACLicenseSummary = $($IncludeMACLicenseSummary.IsPresent)")
Write-Log ("  IncludeCurated = $($IncludeCurated.IsPresent)")
Write-Log ("  IncludeEntraUsers = $($IncludeEntraUsers.IsPresent)")
Write-Log ("  IncludeCustomEndpoints = " + $(if ($IncludeCustomEndpoints -and $IncludeCustomEndpoints.Count -gt 0) { "[$($IncludeCustomEndpoints -join ', ')]" } else { "<none>" }))
Write-Log ("  ExcludeEntraUsers = $($ExcludeEntraUsers.IsPresent)")
Write-Log ("  ExcludeMACCopilotLicensing = $($ExcludeMACCopilotLicensing.IsPresent)")
Write-Log ("  ExcludeMACLicenseSummary = $($ExcludeMACLicenseSummary.IsPresent)")
Write-Log ""
Write-Log "Export Options:"
Write-Log ("  CombineOutput = $CombineOutput")
Write-Log ("  ExportWorkbook = $($ExportWorkbook.IsPresent)")
Write-Log ("  AppendWorkbook = $($AppendWorkbook.IsPresent)")
Write-Log ("  ExplodeArrays = $($ExplodeArrays.IsPresent)")
Write-Log ("  Force = $($Force.IsPresent)")
Write-Log ""
Write-Log "System Information:"
Write-Log ("  ExpandManager = " + $(if ($IncludeEntraUsers) { "Yes (manager expansion enabled)" } else { "N/A (Entra Users not included)" }))
Write-Log ("  PSVersion = $($PSVersionTable.PSVersion.ToString())")
Write-Log ("  PSEdition = $($PSVersionTable.PSEdition)")
Write-Log ("  HostName = $($Host.Name)")
Write-Log ("  HostVersion = $($Host.Version.ToString())")
Write-Log ""

# --- Parameter Validation ---

# OutputFileName only valid with CombineOutput
if ($OutputFileName -and -not $CombineOutput) {
    Write-Host "ERROR: -OutputFileName can only be used with -CombineOutput switch." -ForegroundColor Red
    Write-Host "Use -CombineOutput to merge all usage reports into a single file." -ForegroundColor Yellow
    exit 1
}

# Excel workbook parameter validation
if ($AppendWorkbook -and -not $ExportWorkbook) {
    Write-Host "ERROR: -AppendWorkbook requires -ExportWorkbook to be specified." -ForegroundColor Red
    Write-Host "Use -ExportWorkbook with -AppendWorkbook to append data to an existing Excel workbook." -ForegroundColor Yellow
    exit 1
}

# Warn if both CombineOutput and ExportWorkbook are specified
if ($CombineOutput -and $ExportWorkbook) {
    Write-Host "WARNING: -CombineOutput is ignored when -ExportWorkbook is specified." -ForegroundColor Yellow
    Write-Host "  Excel workbooks automatically combine all endpoints into a multi-sheet workbook." -ForegroundColor Yellow
    Write-Host ""
}

# Build the output file path for Excel validation
$outputFile = $null
if ($ExportWorkbook) {
    if ($OutputFileName) {
        $outputFile = Join-Path $OutputPath $OutputFileName
    } else {
        # Default filename will be generated later, but we can estimate it for validation
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $outputFile = Join-Path $OutputPath "Graph_Usage_Export_$timestamp.xlsx"
    }
    
    # Ensure .xlsx extension
    if ($outputFile -notmatch '\.xlsx$') {
        $outputFile = $outputFile -replace '\.[^.]+$', '.xlsx'
        if ($outputFile -notmatch '\.xlsx$') {
            $outputFile += '.xlsx'
        }
    }
}

# AppendWorkbook pre-flight validation
if ($AppendWorkbook) {
    Write-LogHost "Excel Append Mode: Pre-flight validation..." -ForegroundColor Cyan
    
    # Check if target file exists
    if (-not (Test-Path $outputFile)) {
        Write-Host "ERROR: Cannot append to workbook - file does not exist: $outputFile" -ForegroundColor Red
        Write-Host "  Create the workbook first by running without -AppendWorkbook, or check the file path." -ForegroundColor Yellow
        exit 1
    }
    
    Write-LogHost "  Target workbook exists: $outputFile" -ForegroundColor Green
    
    # Try to load the workbook to validate it's a valid Excel file
    try {
        # Check if ImportExcel module is available (we'll do a full check later, but need it now for validation)
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Host "ERROR: ImportExcel module is required for -AppendWorkbook but is not installed." -ForegroundColor Red
            Write-Host "  Installing ImportExcel module..." -ForegroundColor Yellow
            try {
                Install-Module -Name ImportExcel -Scope CurrentUser -Force -AllowClobber -Repository PSGallery
                Write-Host "  ImportExcel module installed successfully." -ForegroundColor Green
            }
            catch {
                Write-Host "  ERROR: Failed to install ImportExcel module: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "  Please install manually: Install-Module -Name ImportExcel -Scope CurrentUser" -ForegroundColor Yellow
                exit 1
            }
        }
        
        Import-Module ImportExcel -ErrorAction Stop
        
        # Read existing workbook to get sheet names
        $existingWorkbook = Import-Excel -Path $outputFile -WorksheetName (Get-ExcelSheetInfo -Path $outputFile | Select-Object -First 1 -ExpandProperty Name) -StartRow 1 -EndRow 1
        $existingSheets = Get-ExcelSheetInfo -Path $outputFile | Select-Object -ExpandProperty Name
        
        Write-LogHost "  Existing sheets found: $($existingSheets.Count)" -ForegroundColor White
        foreach ($sheet in $existingSheets) {
            Write-LogHost "    • $sheet" -ForegroundColor DarkGray
        }
        
        # Store existing sheets for later validation
        $script:ExistingExcelSheets = $existingSheets
        
        Write-LogHost "  Pre-flight validation passed." -ForegroundColor Green
        Write-LogHost ""
    }
    catch {
        Write-Host "ERROR: Failed to read existing workbook: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  The file may be open in Excel, corrupted, or not a valid .xlsx file." -ForegroundColor Yellow
        exit 1
    }
}

# Ensure OutputPath exists
if (-not (Test-Path $OutputPath)) {
    Write-Host "Creating output directory: $OutputPath" -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    catch {
        Write-Host "ERROR: Failed to create output directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# --- Query Configuration ---

# Period query mode
Write-LogHost "Query Mode: Period (aggregated queries)" -ForegroundColor Green
Write-LogHost "  Period: $Period" -ForegroundColor White

# Map period to days for display
$periodDays = switch ($Period) {
    'D7'   { 7 }
    'D30'  { 30 }
    'D90'  { 90 }
    'D180' { 180 }
    'ALL'  { 'All available data' }
}
Write-LogHost "  Coverage: $periodDays days`n" -ForegroundColor White

# --- Endpoint Definitions ---

# Define 15 curated endpoints with metadata
$Endpoints = @(
    @{
        Name = "CopilotUsage"
        DisplayName = "Microsoft 365 Copilot Usage (User Detail)"
        Url = "/beta/reports/getMicrosoft365CopilotUsageUserDetail"
        ApiVersion = "Beta"
        SupportsPeriod = $true
        SupportsDate = $false  # LIMITATION: Copilot endpoint does NOT support date queries
        CsvCapable = $true
        Description = "Per-user Copilot activity across apps (period-based only, no daily queries)"
    },
    @{
        Name = "M365Activations"
        DisplayName = "Microsoft 365 Activations (User Detail)"
        Url = "/v1.0/reports/getOffice365ActivationsUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $false
        SupportsDate = $false  # Snapshot endpoint (no period/date)
        CsvCapable = $true
        Description = "Office activation counts per user"
    },
    @{
        Name = "M365ActiveUsers"
        DisplayName = "Microsoft 365 Active Users (User Detail)"
        Url = "/v1.0/reports/getOffice365ActiveUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "Active users across M365 services (period-based only)"
    },
    @{
        Name = "TeamsUserActivity"
        DisplayName = "Teams User Activity (User Detail)"
        Url = "/v1.0/reports/getTeamsUserActivityUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "Per-user Teams usage metrics (period-based only)"
    },
    @{
        Name = "EmailActivity"
        DisplayName = "Email Activity (User Detail)"
        Url = "/v1.0/reports/getEmailActivityUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "Email send/receive/read activity (period-based only)"
    },
    @{
        Name = "EmailAppUsage"
        DisplayName = "Email App Usage (User Detail)"
        Url = "/v1.0/reports/getEmailAppUsageUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "Email client usage breakdown (period-based only)"
    },
    @{
        Name = "OneDriveActivity"
        DisplayName = "OneDrive Activity (User Detail)"
        Url = "/v1.0/reports/getOneDriveActivityUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "OneDrive file activity and sync (period-based only)"
    },
    @{
        Name = "OneDriveUsage"
        DisplayName = "OneDrive Usage (Account Detail)"
        Url = "/v1.0/reports/getOneDriveUsageAccountDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "OneDrive storage and file counts (period-based only)"
    },
    @{
        Name = "SharePointActivity"
        DisplayName = "SharePoint Activity (User Detail)"
        Url = "/v1.0/reports/getSharePointActivityUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "SharePoint file activity and sharing (period-based only)"
    },
    @{
        Name = "SharePointSiteUsage"
        DisplayName = "SharePoint Site Usage (Site Detail)"
        Url = "/v1.0/reports/getSharePointSiteUsageDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "Per-site storage and activity metrics (period-based only)"
    },
    @{
        Name = "YammerActivity"
        DisplayName = "Yammer Activity (User Detail)"
        Url = "/v1.0/reports/getYammerActivityUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "Yammer posts, reads, and likes (period-based only)"
    },
    @{
        Name = "YammerDeviceUsage"
        DisplayName = "Yammer Device Usage (User Detail)"
        Url = "/v1.0/reports/getYammerDeviceUsageUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "Yammer usage by device type (period-based only)"
    },
    @{
        Name = "YammerGroupsActivity"
        DisplayName = "Yammer Groups Activity (Group Detail)"
        Url = "/v1.0/reports/getYammerGroupsActivityDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "Per-group Yammer activity metrics (period-based only)"
    },
    @{
        Name = "M365AppUserDetail"
        DisplayName = "Microsoft 365 Apps User Detail"
        Url = "/v1.0/reports/getM365AppUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $false  # API LIMITATION: Only supports period queries (D7/D30/D90/D180)
        CsvCapable = $true
        Description = "Per-user app usage across M365 apps (period-based only)"
    },
    @{
        Name = "EntraUsers"
        DisplayName = "Entra Users (Comprehensive Properties)"
        Url = "/v1.0/users"
        ApiVersion = "v1.0"
        SupportsPeriod = $false
        SupportsDate = $false
        CsvCapable = $false  # JSON only, requires transformation
        Description = "User directory with 35 core properties + manager expansion"
    },
    @{
        Name = "MACCopilotLicensing"
        DisplayName = "Microsoft 365 Copilot License Assignments"
        Url = "/v1.0/users"
        ApiVersion = "v1.0"
        SupportsPeriod = $false
        SupportsDate = $false
        CsvCapable = $false  # JSON only, requires transformation
        Description = "Per-user Copilot license assignments with SKU details and service plans"
    },
    @{
        Name = "MACLicenseSummary"
        DisplayName = "Microsoft 365 License Capacity Summary"
        Url = "/v1.0/subscribedSkus"
        ApiVersion = "v1.0"
        SupportsPeriod = $false
        SupportsDate = $false
        CsvCapable = $false  # JSON only, requires transformation
        Description = "Tenant-wide Copilot and M365 license capacity, consumption, and availability"
    }
)

Write-Host "Initializing Microsoft Graph API endpoints..." -ForegroundColor Cyan
Write-Host ""

# --- Entra User Properties Definition (35 Core Fields) ---

$EntraUserProperties = @(
    # Identity (6)
    'userPrincipalName', 'displayName', 'id', 'mail', 'givenName', 'surname',
    
    # Job (5)
    'jobTitle', 'department', 'employeeType', 'employeeId', 'employeeHireDate',
    
    # Location (6)
    'officeLocation', 'city', 'state', 'country', 'postalCode', 'companyName',
    
    # Organization (1 - nested object)
    'employeeOrgData',
    
    # Status (3)
    'accountEnabled', 'userType', 'createdDateTime',
    
    # Usage (2)
    'usageLocation', 'preferredLanguage',
    
    # Administrative (7 - optional advanced fields)
    'onPremisesSyncEnabled', 'onPremisesImmutableId', 'proxyAddresses',
    'assignedLicenses', 'assignedPlans', 'provisionedPlans', 'externalUserState'
)

# Only show Entra configuration if it's being used
if ($IncludeEntraUsers) {
    Write-Host "Entra User Properties: Configured" -ForegroundColor Green
    Write-Host "  Manager expansion: Enabled (displayName, userPrincipalName, mail, id)" -ForegroundColor White
    Write-Host ""
}

# ==============================================
# Microsoft Graph Authentication
# ==============================================

Write-LogHost "Authenticating to Microsoft Graph API..." -ForegroundColor Cyan
Write-Log "Required Permissions: Reports.Read.All, User.Read.All, Directory.Read.All"

# Base required Graph API scopes (always needed)
$RequiredScopes = @(
    'Reports.Read.All',      # Read all usage reports
    'User.Read.All',         # Read all user profiles
    'Directory.Read.All'     # Read directory data (for manager expansion)
)

# Conditionally add AuditLog.Read.All if MAC Copilot Licensing endpoint is included
# This scope provides access to signInActivity data (requires Azure AD Premium P1/P2)
if ($IncludeMACCopilotLicensing -or $IncludeCurated) {
    $RequiredScopes += 'AuditLog.Read.All'  # Read sign-in activity logs
}

Write-Host "Required Permissions:" -ForegroundColor Yellow
foreach ($scope in $RequiredScopes) {
    Write-Host "  • $scope" -ForegroundColor White
}

# Display additional requirements for AuditLog.Read.All if needed
if ($RequiredScopes -contains 'AuditLog.Read.All') {
    Write-Host ""
    Write-Host "⚠️  Additional Requirements for Sign-In Activity Data:" -ForegroundColor Yellow
    Write-Host "  • Azure AD Premium P1 or P2 license required" -ForegroundColor Gray
    Write-Host "  • AuditLog.Read.All permission (requires admin consent)" -ForegroundColor Gray
    Write-Host "  • Used to retrieve lastSignInDateTime for MAC Copilot Licensing data" -ForegroundColor Gray
}
Write-Host ""

# Check for Microsoft.Graph module and auto-install if needed
Write-Host "`nChecking prerequisites..." -ForegroundColor Cyan

$graphModule = Get-Module -ListAvailable -Name Microsoft.Graph.Authentication | Select-Object -First 1
if (-not $graphModule) {
    Write-Host "Microsoft.Graph PowerShell SDK not found." -ForegroundColor Yellow
    Write-Host "Installing Microsoft.Graph module (this may take a few minutes)..." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Host "✓ Microsoft.Graph module installed successfully!" -ForegroundColor Green
        Write-Host ""
        
        # Re-check for the module
        $graphModule = Get-Module -ListAvailable -Name Microsoft.Graph.Authentication | Select-Object -First 1
        if (-not $graphModule) {
            Write-Host "ERROR: Module installation completed but module not found. Try restarting PowerShell." -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "ERROR: Failed to install Microsoft.Graph module: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please install manually using:" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}
else {
    Write-Host "✓ Microsoft.Graph module detected: $($graphModule.Name) v$($graphModule.Version)" -ForegroundColor Green
}

# Check for ImportExcel module if Excel export is requested
if ($ExportWorkbook -and -not $AppendWorkbook) {
    # AppendWorkbook validation was performed during pre-flight checks
    $importExcelModule = Get-Module -ListAvailable -Name ImportExcel | Select-Object -First 1
    if (-not $importExcelModule) {
        Write-Host "ImportExcel module not found (required for -ExportWorkbook)." -ForegroundColor Yellow
        Write-Host "Installing ImportExcel module..." -ForegroundColor Yellow
        Write-Host ""
        
        try {
            Install-Module ImportExcel -Scope CurrentUser -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
            Write-Host "✓ ImportExcel module installed successfully!" -ForegroundColor Green
            Write-Host ""
            
            # Re-check for the module
            $importExcelModule = Get-Module -ListAvailable -Name ImportExcel | Select-Object -First 1
            if (-not $importExcelModule) {
                Write-Host "ERROR: Module installation completed but module not found. Try restarting PowerShell." -ForegroundColor Red
                exit 1
            }
        }
        catch {
            Write-Host "ERROR: Failed to install ImportExcel module: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please install manually using:" -ForegroundColor Yellow
            Write-Host "  Install-Module ImportExcel -Scope CurrentUser" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Falling back to CSV export..." -ForegroundColor Yellow
            $script:ExportWorkbook = $false
        }
    }
    else {
        Write-Host "✓ ImportExcel module detected: $($importExcelModule.Name) v$($importExcelModule.Version)" -ForegroundColor Green
    }
}

# Import required Graph modules
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Reports -ErrorAction Stop
    if ($IncludeEntraUsers) {
        Import-Module Microsoft.Graph.Users -ErrorAction Stop
    }
    if ($ExportWorkbook) {
        Import-Module ImportExcel -ErrorAction Stop
    }
    Write-Host "Graph modules imported successfully" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to import required modules: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Authenticate based on -Auth parameter
try {
    Write-LogHost "`nAuthentication Method: $Auth" -ForegroundColor Cyan
    
    switch ($Auth) {
        'WebLogin' {
            Write-LogHost "Opening interactive browser for authentication..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes $RequiredScopes -NoWelcome -ErrorAction Stop
        }
        'DeviceCode' {
            Write-LogHost "Using device code flow..." -ForegroundColor Yellow
            Write-LogHost "A browser window will open. Follow the instructions to authenticate." -ForegroundColor Yellow
            Connect-MgGraph -Scopes $RequiredScopes -UseDeviceCode -NoWelcome -ErrorAction Stop
        }
        'Credential' {
            Write-LogHost "Using client secret credential..." -ForegroundColor Yellow
            
            # Check for required environment variables
            $tenantId = $env:GRAPH_TENANT_ID
            $clientId = $env:GRAPH_CLIENT_ID
            $clientSecret = $env:GRAPH_CLIENT_SECRET
            
            if (-not $tenantId -or -not $clientId -or -not $clientSecret) {
                Write-LogHost "ERROR: Credential authentication requires environment variables:" -ForegroundColor Red
                Write-LogHost "  GRAPH_TENANT_ID     : Your Azure AD Tenant ID" -ForegroundColor Yellow
                Write-LogHost "  GRAPH_CLIENT_ID     : Your App Registration Client ID" -ForegroundColor Yellow
                Write-LogHost "  GRAPH_CLIENT_SECRET : Your App Registration Client Secret" -ForegroundColor Yellow
                Write-LogHost ""
                Write-LogHost "Set these variables before running the script:" -ForegroundColor Yellow
                Write-LogHost "  `$env:GRAPH_TENANT_ID = 'your-tenant-id'" -ForegroundColor White
                Write-LogHost "  `$env:GRAPH_CLIENT_ID = 'your-client-id'" -ForegroundColor White
                Write-LogHost "  `$env:GRAPH_CLIENT_SECRET = 'your-client-secret'" -ForegroundColor White
                exit 1
            }
            
            $secureSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($clientId, $secureSecret)
            
            # Clear plain-text secret from memory immediately after use
            Clear-Variable -Name clientSecret -Force -ErrorAction SilentlyContinue
            
            Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $credential -NoWelcome -ErrorAction Stop
        }
        'Silent' {
            Write-LogHost "Using managed identity or existing token..." -ForegroundColor Yellow
            Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
        }
    }
    
    Write-LogHost "✓ Authentication successful!" -ForegroundColor Green
    Write-Log "Connected successfully to Microsoft Graph API"
    
    # Get and display current context
    $context = Get-MgContext
    Write-LogHost "`nAuthenticated Context:" -ForegroundColor Cyan
    Write-LogHost "  Tenant ID: $($context.TenantId)" -ForegroundColor White
    Write-LogHost "  Account:   $(Hide-EmailAddress $context.Account)" -ForegroundColor White
    Write-LogHost "  Scopes:    $($context.Scopes -join ', ')" -ForegroundColor White
    Write-LogHost ""
    Write-Log ("Tenant context: TenantId=$($context.TenantId) | Account=$(Hide-EmailAddress $context.Account)")
    
    # Validate required scopes are present
    $missingScopes = @()
    foreach ($scope in $RequiredScopes) {
        if ($context.Scopes -notcontains $scope) {
            $missingScopes += $scope
        }
    }
    
    if ($missingScopes.Count -gt 0) {
        Write-Host "WARNING: Missing required scope(s):" -ForegroundColor Yellow
        foreach ($scope in $missingScopes) {
            Write-Host "  • $scope" -ForegroundColor Yellow
        }
        Write-Host ""
        
        # Special handling for AuditLog.Read.All - offer graceful degradation
        if ($missingScopes -contains 'AuditLog.Read.All' -and ($IncludeMACCopilotLicensing -or $IncludeCurated)) {
            Write-Host "⚠️  AuditLog.Read.All Permission Missing" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "This permission is required to retrieve sign-in activity data for MAC Copilot Licensing." -ForegroundColor White
            Write-Host "Without it, the lastSignInDateTime columns will be unavailable." -ForegroundColor White
            Write-Host ""
            Write-Host "Requirements:" -ForegroundColor Cyan
            Write-Host "  • Azure AD Premium P1 or P2 license" -ForegroundColor Gray
            Write-Host "  • Admin consent for AuditLog.Read.All scope" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Options:" -ForegroundColor Cyan
            Write-Host "  [C] Continue without sign-in activity data" -ForegroundColor White
            Write-Host "  [E] Exit and re-authenticate with proper permissions" -ForegroundColor White
            Write-Host ""
            
            $choice = Read-Host "Enter your choice (C/E)"
            
            if ($choice -eq 'E' -or $choice -eq 'e') {
                Write-Host ""
                Write-Host "Exiting script. Please re-run with proper AuditLog.Read.All permissions." -ForegroundColor Yellow
                Write-Host "Hint: Ensure your account has Azure AD Premium P1/P2 and admin has consented to the scope." -ForegroundColor Gray
                Write-Host ""
                Disconnect-MgGraph | Out-Null
                exit 0
            }
            else {
                Write-Host ""
                Write-Host "Continuing without sign-in activity data..." -ForegroundColor Yellow
                Write-Host "MAC Copilot Licensing will exclude lastSignInDateTime columns." -ForegroundColor Gray
                Write-Host ""
                
                # Set flag to skip signInActivity in MAC Copilot Licensing query
                $script:SkipSignInActivity = $true
            }
        }
        else {
            Write-Host "Script may fail when accessing protected resources." -ForegroundColor Yellow
            Write-Host "Consider re-authenticating with full permissions." -ForegroundColor Yellow
            Write-Host ""
        }
    }
    else {
        # All scopes present - enable full functionality
        $script:SkipSignInActivity = $false
    }
}
catch {
    Write-Host "ERROR: Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure you have the required permissions in your tenant" -ForegroundColor White
    Write-Host "  2. Check if Multi-Factor Authentication is required" -ForegroundColor White
    Write-Host "  3. Verify network connectivity to Microsoft Graph API" -ForegroundColor White
    Write-Host "  4. Try a different authentication method (-Auth parameter)" -ForegroundColor White
    Write-Host ""
    exit 1
}

# ==============================================
# Endpoint Query Function
# ==============================================

# Entra Users Data Processing
function ConvertTo-FlatEntraUsers {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Users,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExplodeArrays
    )
    
    $flattenedUsers = @()
    
    foreach ($user in $Users) {
        # Filter: Only include real user accounts (exclude rooms, resources, shared mailboxes)
        # Room and resource mailboxes have specific characteristics:
        # - userType is often null or not "Member"/"Guest"
        # - They typically lack givenName and surname
        # - They often have mail but no userPrincipalName with typical user format
        
        $userTypeValue = $user.userType
        
        # Skip if userType is null/empty (likely a room or resource)
        if ([string]::IsNullOrWhiteSpace($userTypeValue)) {
            continue
        }
        
        # Only include users with userType = "Member" or "Guest"
        # Rooms/resources typically have different userType values or null
        if ($userTypeValue -ne 'Member' -and $userTypeValue -ne 'Guest') {
            continue
        }
        
        # Additional heuristic: Real users typically have either givenName or surname
        # Room mailboxes typically have neither (only displayName)
        # This is not foolproof but combined with userType check, it's quite reliable
        $hasGivenName = -not [string]::IsNullOrWhiteSpace($user.givenName)
        $hasSurname = -not [string]::IsNullOrWhiteSpace($user.surname)
        
        # If user has Member/Guest type but no name components, might be a shared resource
        # Allow through if they have at least givenName OR surname OR if account is enabled
        # (most room mailboxes are enabled but lack name components)
        if (-not $hasGivenName -and -not $hasSurname -and $user.accountEnabled) {
            # Additional check: if they have licenses assigned, likely a real user
            if (-not $user.assignedLicenses -or $user.assignedLicenses.Count -eq 0) {
                # No licenses and no name components - likely a room/resource
                continue
            }
        }
        
        $flatUser = [ordered]@{}
        
        # Core Identity Properties (simple strings)
        $flatUser['userPrincipalName'] = $user.userPrincipalName
        $flatUser['displayName'] = $user.displayName
        $flatUser['id'] = $user.id
        $flatUser['mail'] = $user.mail
        $flatUser['givenName'] = $user.givenName
        $flatUser['surname'] = $user.surname
        
        # Job Properties
        $flatUser['jobTitle'] = $user.jobTitle
        $flatUser['department'] = $user.department
        $flatUser['employeeType'] = $user.employeeType
        $flatUser['employeeId'] = $user.employeeId
        $flatUser['employeeHireDate'] = $user.employeeHireDate
        
        # Location Properties
        $flatUser['officeLocation'] = $user.officeLocation
        $flatUser['city'] = $user.city
        $flatUser['state'] = $user.state
        $flatUser['country'] = $user.country
        $flatUser['postalCode'] = $user.postalCode
        $flatUser['companyName'] = $user.companyName
        
        # Status Properties
        $flatUser['accountEnabled'] = $user.accountEnabled
        $flatUser['userType'] = $user.userType
        $flatUser['createdDateTime'] = $user.createdDateTime
        
        # Usage Properties
        $flatUser['usageLocation'] = $user.usageLocation
        $flatUser['preferredLanguage'] = $user.preferredLanguage
        
        # Sync Properties
        $flatUser['onPremisesSyncEnabled'] = $user.onPremisesSyncEnabled
        $flatUser['onPremisesImmutableId'] = $user.onPremisesImmutableId
        $flatUser['externalUserState'] = $user.externalUserState
        
        # Explode proxyAddresses array (Email aliases)
        # Extract primary SMTP and count of aliases
        if ($user.proxyAddresses -and $user.proxyAddresses.Count -gt 0) {
            $primarySMTP = $user.proxyAddresses | Where-Object { $_ -like 'SMTP:*' } | Select-Object -First 1
            $flatUser['proxyAddresses_Primary'] = if ($primarySMTP) { $primarySMTP -replace '^SMTP:', '' } else { $null }
            $flatUser['proxyAddresses_Count'] = $user.proxyAddresses.Count
            $flatUser['proxyAddresses_All'] = ($user.proxyAddresses -join '; ')
        }
        else {
            $flatUser['proxyAddresses_Primary'] = $null
            $flatUser['proxyAddresses_Count'] = 0
            $flatUser['proxyAddresses_All'] = $null
        }
        
        # Explode assignedLicenses array (SKU IDs and names)
        if ($user.assignedLicenses -and $user.assignedLicenses.Count -gt 0) {
            $flatUser['assignedLicenses_Count'] = $user.assignedLicenses.Count
            $skuIds = $user.assignedLicenses | ForEach-Object { $_.skuId } | Where-Object { $_ }
            $flatUser['assignedLicenses_SkuIds'] = if ($skuIds) { ($skuIds -join '; ') } else { $null }
        }
        else {
            $flatUser['assignedLicenses_Count'] = 0
            $flatUser['assignedLicenses_SkuIds'] = $null
        }
        
        # Explode assignedPlans array (Service plans)
        if ($user.assignedPlans -and $user.assignedPlans.Count -gt 0) {
            $flatUser['assignedPlans_Count'] = $user.assignedPlans.Count
            # Get enabled plans
            $enabledPlans = $user.assignedPlans | Where-Object { $_.capabilityStatus -eq 'Enabled' } | ForEach-Object { $_.servicePlanId }
            $flatUser['assignedPlans_EnabledCount'] = if ($enabledPlans) { $enabledPlans.Count } else { 0 }
            $flatUser['assignedPlans_ServicePlanIds'] = if ($enabledPlans) { ($enabledPlans -join '; ') } else { $null }
        }
        else {
            $flatUser['assignedPlans_Count'] = 0
            $flatUser['assignedPlans_EnabledCount'] = 0
            $flatUser['assignedPlans_ServicePlanIds'] = $null
        }
        
        # Explode provisionedPlans array (Provisioned services)
        if ($user.provisionedPlans -and $user.provisionedPlans.Count -gt 0) {
            $flatUser['provisionedPlans_Count'] = $user.provisionedPlans.Count
            # Get successfully provisioned plans
            $successPlans = $user.provisionedPlans | Where-Object { $_.provisioningStatus -eq 'Success' } | ForEach-Object { $_.service }
            $flatUser['provisionedPlans_SuccessCount'] = if ($successPlans) { $successPlans.Count } else { 0 }
            $flatUser['provisionedPlans_Services'] = if ($successPlans) { ($successPlans -join '; ') } else { $null }
        }
        else {
            $flatUser['provisionedPlans_Count'] = 0
            $flatUser['provisionedPlans_SuccessCount'] = 0
            $flatUser['provisionedPlans_Services'] = $null
        }
        
        # Handle employeeOrgData nested object (flatten to individual columns)
        if ($user.employeeOrgData) {
            $flatUser['employeeOrgData_division'] = $user.employeeOrgData.division
            $flatUser['employeeOrgData_costCenter'] = $user.employeeOrgData.costCenter
        }
        else {
            $flatUser['employeeOrgData_division'] = $null
            $flatUser['employeeOrgData_costCenter'] = $null
        }
        
        # Handle manager object separately (flatten to individual columns)
        if ($user.manager) {
            $flatUser['manager_displayName'] = $user.manager.displayName
            $flatUser['manager_userPrincipalName'] = $user.manager.userPrincipalName
            $flatUser['manager_mail'] = $user.manager.mail
            $flatUser['manager_id'] = $user.manager.id
        }
        else {
            $flatUser['manager_displayName'] = $null
            $flatUser['manager_userPrincipalName'] = $null
            $flatUser['manager_mail'] = $null
            $flatUser['manager_id'] = $null
        }
        
        # Convert ordered hashtable to PSCustomObject for proper CSV export
        $flattenedUsers += [PSCustomObject]$flatUser
    }
    
    return $flattenedUsers
}

# ==============================================
# MAC Licensing Functions
# ==============================================

# Known Microsoft 365 Copilot SKU IDs and names
# Source: https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference
# IMPORTANT: This is the single source of truth for Copilot SKU detection.
#            Update this list if you need to add new Copilot SKU IDs.
$script:CopilotSkuIds = @{
    'c815c93d-0759-4bb8-b857-bc921a71be83' = 'Microsoft 365 Copilot'           # M365 Copilot
    '06ebc4ee-1bb5-47dd-8120-11324bc54e06' = 'Microsoft 365 Copilot'           # M365 Copilot (alternative)
    'a1c5e422-7c00-4433-a276-0f5b5f02e952' = 'Copilot Pro'                     # Copilot Pro
    '4a51bca5-1eff-43f5-878c-177680f191af' = 'Microsoft Copilot for Microsoft 365' # Another variant
    'f841e8a7-8d86-4eae-af8c-d14b2a4c7228' = 'Microsoft 365 Copilot'           # Additional variant
    'd814ea5e-2d90-455a-8b9e-2e5e4f3e8e8d' = 'Microsoft Copilot for M365'      # Additional variant
    '440eaaa8-b3e0-484b-a8be-62870b9ba70a' = 'Microsoft 365 Copilot'           # Detected from tenant usage
}

# Known Microsoft 365 and Office 365 SKU IDs for MAC License Summary reporting
# Source: https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference
# IMPORTANT: This is the single source of truth for M365/O365 SKU detection.
#            Update this list if you need to add new M365/O365 SKU IDs.
$script:M365SkuIds = @{
    # Microsoft 365 Business Plans
    'cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46' = 'Microsoft 365 Business Basic'
    'f245ecc8-75af-4f8e-b61f-27d8114de5f3' = 'Microsoft 365 Business Standard / Office 365 E3 / Business'
    'ac5cef5d-921b-4f97-9ef3-c99076e5470f' = 'Microsoft 365 Business Premium'
    'cdd28e44-67e3-425e-be4c-737fab2899d3' = 'Microsoft 365 Business Basic (EEA)'
    
    # Microsoft 365 Enterprise Plans
    '18181a46-0d4e-45cd-891e-60aabd171b4e' = 'Microsoft 365 E1'
    '06ebc4ee-1bb5-47dd-8120-11324bc54e06' = 'Microsoft 365 E3 / E5'
    '1392051d-0cb9-4b7a-88d5-621fee5e8711' = 'Microsoft 365 E4 / Office 365 E4'
    'd61d61cc-f992-433f-a577-5bd016037eeb' = 'Microsoft 365 E3 (EEA)'
    '3271cf8e-2be5-4a09-a24f-0ec0c456456b' = 'Microsoft 365 E5 (EEA)'
    
    # Microsoft 365 F Plans (Frontline Workers)
    '66b55226-6b4f-492c-910c-a3b7a3c9d993' = 'Microsoft 365 F1'
    '274ef0f8-7b51-4903-82a7-8c6a95a17e83' = 'Microsoft 365 F3'
    '8f0c5670-4e56-4892-b06d-91c085d7004f' = 'Microsoft 365 F3 (EEA)'
    
    # Office 365 Enterprise Plans
    '6fd2c87f-b296-42f0-b197-1e91e994b900' = 'Office 365 E1'
    '6634e0ce-1a9f-428c-a498-f84ec7b8aa2e' = 'Office 365 E2'
    'c7df2760-2c81-4ef7-b578-5b5392b571df' = 'Office 365 E5'
    
    # Office 365 Business Plans  
    '3b555118-da6a-4418-894f-7df1e2096870' = 'Office 365 Business Essentials'
    'dab7782e-93b2-4333-8c5c-4af482f936b0' = 'Office 365 Business Premium'
    
    # Office 365 F Plans
    '4b585984-651b-448a-9e53-3b10f069cf7f' = 'Office 365 F1'
    'a4585165-0533-458a-97e3-c400570268c4' = 'Office 365 F3'
}

function Get-MACCopilotLicensing {
    <#
    .SYNOPSIS
        Queries Microsoft Graph API for users with Microsoft 365 Copilot licenses
    
    .DESCRIPTION
        Retrieves user license data from Graph API /v1.0/users endpoint.
        Returns all users with their assigned licenses (filtering for Copilot licenses happens in ConvertTo-FlatMACLicensing).
        Uses pagination to handle large result sets.
    
    .PARAMETER SelectProperties
        Array of user properties to retrieve. Defaults to essential identity and license fields.
    
    .OUTPUTS
        Array of user objects with license assignments
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$SelectProperties = @(
            'id',
            'userPrincipalName', 
            'displayName',
            'mail',
            'accountEnabled',
            'userType',
            'jobTitle',
            'department',
            'companyName',
            'officeLocation',
            'usageLocation',
            'createdDateTime',
            'assignedLicenses',
            'assignedPlans',
            'signInActivity'  # Requires AuditLog.Read.All and Azure AD Premium P1/P2
        )
    )
    
    # Check if we should skip signInActivity due to missing permissions
    if ($script:SkipSignInActivity) {
        Write-Host "  ⚠️  Skipping signInActivity (AuditLog.Read.All permission not available)" -ForegroundColor Yellow
        Write-Log "Excluding signInActivity from query due to missing AuditLog.Read.All permission"
        $SelectProperties = $SelectProperties | Where-Object { $_ -ne 'signInActivity' }
    }
    
    Write-Host "  Querying Microsoft Graph API for user licenses..." -ForegroundColor Gray
    Write-Log "Retrieving user license data from /v1.0/users"
    
    $allUsers = @()
    $batchSize = 999  # Graph API max per page
    
    try {
        # Build select parameter
        $selectParam = $SelectProperties -join ','
        
        # Initial query - get all users with license data
        # Retrieves all users; Copilot license filtering happens in ConvertTo-FlatMACLicensing
        # This is more efficient than complex $filter queries on assignedLicenses
        $uri = "https://graph.microsoft.com/v1.0/users?`$select=$selectParam&`$top=$batchSize"
        
        Write-Log "Initial query URI: $uri"
        
        $pageCount = 0
        do {
            $pageCount++
            Write-Host "    Fetching page $pageCount..." -ForegroundColor Gray
            
            # Query Graph API
            $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
            
            if ($response.value) {
                $batchUsers = $response.value
                $allUsers += $batchUsers
                Write-Host "      Retrieved $($batchUsers.Count) users (Total: $($allUsers.Count))" -ForegroundColor Gray
                Write-Log "  Page $pageCount : Retrieved $($batchUsers.Count) users"
            }
            
            # Check for next page
            $uri = $response.'@odata.nextLink'
            
        } while ($uri)  # Continue while nextLink exists
        
        Write-Host "  ✓ Retrieved $($allUsers.Count) total users from Graph API" -ForegroundColor Green
        Write-Log "Successfully retrieved $($allUsers.Count) users with license data"
        
        return $allUsers
    }
    catch {
        Write-Host "    ERROR: Failed to retrieve user license data" -ForegroundColor Red
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERROR retrieving MAC Copilot licensing data: $($_.Exception.Message)"
        
        # Check for specific permission errors
        if ($_.Exception.Message -match '(Forbidden|Insufficient privileges|Authorization_RequestDenied)') {
            Write-Host ""
            Write-Host "    This error typically indicates missing API permissions." -ForegroundColor Yellow
            Write-Host "    Required permissions for license queries:" -ForegroundColor Yellow
            Write-Host "      • User.Read.All" -ForegroundColor White
            Write-Host "      • Directory.Read.All" -ForegroundColor White
            Write-Host ""
        }
        
        return @()  # Return empty array on error
    }
}

function ConvertTo-FlatMACLicensing {
    <#
    .SYNOPSIS
        Flattens user license data focusing on Microsoft 365 Copilot licenses
    
    .DESCRIPTION
        Extracts and flattens Copilot license assignments from user objects.
        Returns only users with Copilot licenses assigned.
        
        Uses two-tier detection for Copilot licenses:
        1. Checks against known Copilot SKU IDs (fast, explicit)
        2. Checks if SKU name contains "Copilot" (catches new variants, promotional SKUs, etc.)
    
    .PARAMETER Users
        Array of user objects from Microsoft Graph API (/v1.0/users)
    
    .PARAMETER TenantSKUs
        Optional. Array of subscribedSku objects from tenant. Used to map SKU IDs to names for pattern matching.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Users,
        
        [Parameter(Mandatory = $false)]
        [array]$TenantSkus
    )
    
    # Use script-level Copilot SKU list (single source of truth)
    $copilotSkus = $script:CopilotSkuIds
    
    # Build SKU ID to name lookup from tenant data (for pattern matching)
    $skuIdToName = @{}
    if ($TenantSkus) {
        foreach ($sku in $TenantSkus) {
            if ($sku.skuId -and $sku.skuPartNumber) {
                $skuIdToName[$sku.skuId] = $sku.skuPartNumber
            }
        }
    }
    
    $flattenedLicenses = @()
    
    foreach ($user in $Users) {
        # Filter: Only include users with assigned licenses
        if (-not $user.assignedLicenses -or $user.assignedLicenses.Count -eq 0) {
            continue
        }
        
        # Check if user has any Copilot licenses (two-tier detection)
        $copilotLicenses = @()
        foreach ($license in $user.assignedLicenses) {
            $skuId = $license.skuId
            $isCopilot = $false
            $detectedName = $null
            
            # Tier 1: Check known SKU IDs (explicit list)
            if ($copilotSkus.ContainsKey($skuId)) {
                $isCopilot = $true
                $detectedName = $copilotSkus[$skuId]
            }
            # Tier 2: Pattern matching on SKU name (catches new variants)
            elseif ($skuIdToName.ContainsKey($skuId)) {
                $skuName = $skuIdToName[$skuId]
                if ($skuName -match 'Copilot') {
                    $isCopilot = $true
                    $detectedName = $skuName  # Use actual SKU name from tenant
                }
            }
            
            if ($isCopilot) {
                $copilotLicenses += @{
                    SkuId = $skuId
                    SkuName = $detectedName
                }
            }
        }
        
        # Skip users without Copilot licenses
        if ($copilotLicenses.Count -eq 0) {
            continue
        }
        
        # Create flattened record for each user with Copilot license
        $flatLicense = [ordered]@{}
        
        # Core Identity
        $flatLicense['userPrincipalName'] = $user.userPrincipalName
        $flatLicense['displayName'] = $user.displayName
        $flatLicense['id'] = $user.id
        $flatLicense['mail'] = $user.mail
        
        # Account Status
        $flatLicense['accountEnabled'] = $user.accountEnabled
        $flatLicense['userType'] = $user.userType
        
        # Job Information
        $flatLicense['jobTitle'] = $user.jobTitle
        $flatLicense['department'] = $user.department
        $flatLicense['companyName'] = $user.companyName
        $flatLicense['officeLocation'] = $user.officeLocation
        
        # Copilot License Details
        $flatLicense['copilotLicenseCount'] = $copilotLicenses.Count
        $flatLicense['copilotLicenseNames'] = ($copilotLicenses | ForEach-Object { $_.SkuName }) -join '; '
        $flatLicense['copilotLicenseSkuIds'] = ($copilotLicenses | ForEach-Object { $_.SkuId }) -join '; '
        
        # Total License Count
        $flatLicense['totalLicenseCount'] = $user.assignedLicenses.Count
        
        # Assigned Plans (Service Plans)
        if ($user.assignedPlans -and $user.assignedPlans.Count -gt 0) {
            $flatLicense['assignedPlans_Count'] = $user.assignedPlans.Count
            $enabledPlans = $user.assignedPlans | Where-Object { $_.capabilityStatus -eq 'Enabled' }
            $flatLicense['assignedPlans_EnabledCount'] = if ($enabledPlans) { $enabledPlans.Count } else { 0 }
            
            # Extract Copilot-specific service plans
            $copilotPlans = $enabledPlans | Where-Object { 
                $_.servicePlanName -match '(?i)(copilot|ai)' 
            } | ForEach-Object { $_.servicePlanName }
            $flatLicense['copilotServicePlans'] = if ($copilotPlans) { ($copilotPlans -join '; ') } else { 'None' }
        }
        else {
            $flatLicense['assignedPlans_Count'] = 0
            $flatLicense['assignedPlans_EnabledCount'] = 0
            $flatLicense['copilotServicePlans'] = 'None'
        }
        
        # Usage Location
        $flatLicense['usageLocation'] = $user.usageLocation
        
        # Creation Date
        $flatLicense['createdDateTime'] = $user.createdDateTime
        
        # Sign-In Activity (requires AuditLog.Read.All and Azure AD Premium P1/P2)
        if ($user.signInActivity) {
            $flatLicense['lastSignInDateTime'] = $user.signInActivity.lastSignInDateTime
            $flatLicense['lastNonInteractiveSignInDateTime'] = $user.signInActivity.lastNonInteractiveSignInDateTime
        }
        else {
            $flatLicense['lastSignInDateTime'] = $null
            $flatLicense['lastNonInteractiveSignInDateTime'] = $null
        }
        
        # Convert to PSCustomObject and add to results
        $flattenedLicenses += [PSCustomObject]$flatLicense
    }
    
    return $flattenedLicenses
}

function Get-MACLicenseSummary {
    <#
    .SYNOPSIS
        Queries Microsoft Graph API for tenant-wide license capacity and utilization
    
    .DESCRIPTION
        Retrieves all subscribed SKUs from /v1.0/subscribedSkus endpoint.
        Returns complete license inventory including Copilot and all M365 licenses.
        No pagination needed - single response contains all SKUs.
    
    .OUTPUTS
        Array of subscribedSku objects with license capacity and consumption details
    #>
    
    Write-Host "  Querying Microsoft Graph API for license summary..." -ForegroundColor Gray
    Write-Log "Retrieving license summary from /v1.0/subscribedSkus"
    
    try {
        # Query subscribedSkus endpoint - returns all SKUs in single response
        $uri = "https://graph.microsoft.com/v1.0/subscribedSkus"
        
        Write-Log "Query URI: $uri"
        
        # Execute Graph API query
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        
        if ($response.value) {
            $skus = $response.value
            Write-Host "  ✓ Retrieved $($skus.Count) subscribed SKUs" -ForegroundColor Green
            Write-Log "Successfully retrieved $($skus.Count) subscribed SKUs"
            
            return $skus
        }
        else {
            Write-Host "  ⚠️  No subscribed SKUs found" -ForegroundColor Yellow
            Write-Log "No subscribed SKUs returned from tenant"
            return @()
        }
    }
    catch {
        Write-Host "    ERROR: Failed to retrieve license summary" -ForegroundColor Red
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERROR retrieving MAC Copilot License Summary: $($_.Exception.Message)"
        
        # Check for specific permission errors
        if ($_.Exception.Message -match '(Forbidden|Insufficient privileges|Authorization_RequestDenied)') {
            Write-Host ""
            Write-Host "    This error typically indicates missing API permissions." -ForegroundColor Yellow
            Write-Host "    Required permissions for license summary queries:" -ForegroundColor Yellow
            Write-Host "      • Organization.Read.All (or Directory.Read.All)" -ForegroundColor White
            Write-Host ""
        }
        
        return @()  # Return empty array on error
    }
}

function ConvertTo-FlatMACLicenseSummary {
    <#
    .SYNOPSIS
        Flattens license summary data for Copilot and M365 SKUs
    
    .DESCRIPTION
        Extracts and flattens license capacity and utilization data from subscribedSkus.
        Returns all Copilot and M365 SKUs with calculated availability and utilization metrics.
        Uses $script:CopilotSkuIds and $script:M365SkuIds for SKU detection.
        Also includes pattern matching as fallback to catch unlisted M365/O365 SKUs.
    
    .PARAMETER Skus
        Array of subscribedSku objects from Microsoft Graph API
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Skus
    )
    
    # Use script-level Copilot and M365 SKU lists (single source of truth)
    $copilotSkuIds = $script:CopilotSkuIds.Keys
    $m365SkuIds = $script:M365SkuIds.Keys
    
    $flattenedSkus = @()
    
    # Process Copilot and M365 SKUs
    foreach ($sku in $Skus) {
        $skuId = $sku.skuId
        
        # Check if this is a Copilot SKU or M365 SKU
        $isCopilotSku = $copilotSkuIds -contains $skuId
        $isM365Sku = $m365SkuIds -contains $skuId
        
        # Include Copilot SKUs and M365 SKUs (using defined lists)
        # Also include any SKU with M365/O365 in the name as fallback (catches new/unlisted SKUs)
        if ($isCopilotSku -or $isM365Sku -or $sku.skuPartNumber -match '(?i)(Microsoft_365|Office_365|M365|O365)') {
            $flatSku = [ordered]@{}
            
            # License Type Indicator
            $flatSku['licenseType'] = if ($isCopilotSku) { 'Copilot' } else { 'M365' }
            
            # SKU Identity
            $flatSku['skuId'] = $skuId
            $flatSku['skuPartNumber'] = $sku.skuPartNumber
            
            # Capacity Status
            $flatSku['capabilityStatus'] = $sku.capabilityStatus
            
            # License Capacity (prepaidUnits)
            $prepaidUnits = $sku.prepaidUnits
            $enabled = if ($prepaidUnits.enabled) { $prepaidUnits.enabled } else { 0 }
            $suspended = if ($prepaidUnits.suspended) { $prepaidUnits.suspended } else { 0 }
            $warning = if ($prepaidUnits.warning) { $prepaidUnits.warning } else { 0 }
            
            $flatSku['totalPurchased'] = $enabled
            $flatSku['suspendedUnits'] = $suspended
            $flatSku['warningUnits'] = $warning
            
            # License Consumption
            $consumed = if ($sku.consumedUnits) { $sku.consumedUnits } else { 0 }
            $flatSku['consumedUnits'] = $consumed
            
            # Calculate Available Licenses
            $available = $enabled - $consumed
            $flatSku['availableUnits'] = if ($available -lt 0) { 0 } else { $available }
            
            # Calculate Utilization Percentage
            if ($enabled -gt 0) {
                $utilization = [math]::Round(($consumed / $enabled) * 100, 2)
                $flatSku['utilizationPercent'] = $utilization
            }
            else {
                $flatSku['utilizationPercent'] = 0
            }
            
            # Service Plans Count
            if ($sku.servicePlans -and $sku.servicePlans.Count -gt 0) {
                $flatSku['servicePlansCount'] = $sku.servicePlans.Count
                
                # Extract service plan names (first 5 for brevity)
                $planNames = $sku.servicePlans | Select-Object -First 5 -ExpandProperty servicePlanName
                $flatSku['servicePlans_Sample'] = ($planNames -join '; ')
                
                if ($sku.servicePlans.Count -gt 5) {
                    $flatSku['servicePlans_Sample'] += " (+ $($sku.servicePlans.Count - 5) more)"
                }
            }
            else {
                $flatSku['servicePlansCount'] = 0
                $flatSku['servicePlans_Sample'] = 'None'
            }
            
            # Applies To (user vs organization)
            $flatSku['appliesTo'] = $sku.appliesTo
            
            # Convert to PSCustomObject and add to results
            $flattenedSkus += [PSCustomObject]$flatSku
        }
    }
    
    # Sort: Copilot SKUs first, then M365 SKUs, then by skuPartNumber
    $flattenedSkus = $flattenedSkus | Sort-Object -Property @{Expression={$_.licenseType}; Descending=$true}, skuPartNumber
    
    return $flattenedSkus
}

function Move-ReportPeriodColumn {
    <#
    .SYNOPSIS
        Reorders CSV data columns to place "Report Period" immediately after "Report Refresh Date".
    
    .DESCRIPTION
        Microsoft Graph API returns "Report Period" as the last column.
        This function moves it to position 2 (right after "Report Refresh Date") for better readability.
    
    .PARAMETER Data
        Array of PSCustomObjects from CSV data
    
    .EXAMPLE
        $reorderedData = Move-ReportPeriodColumn -Data $csvData
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data
    )
    
    if (-not $Data -or $Data.Count -eq 0) {
        return $Data
    }
    
    # Get all property names from first object
    $firstObject = $Data[0]
    $allProperties = @($firstObject.PSObject.Properties.Name)
    
    # Check if both columns exist
    $hasRefreshDate = $allProperties -contains 'Report Refresh Date'
    $hasPeriod = $allProperties -contains 'Report Period'
    
    if (-not $hasRefreshDate -or -not $hasPeriod) {
        # Columns don't exist, return data unchanged
        return $Data
    }
    
    # Create new column order: Report Refresh Date, Report Period, then everything else
    $newOrder = @('Report Refresh Date', 'Report Period')
    foreach ($prop in $allProperties) {
        if ($prop -ne 'Report Refresh Date' -and $prop -ne 'Report Period') {
            $newOrder += $prop
        }
    }
    
    # Reorder all objects
    $reorderedData = @()
    foreach ($item in $Data) {
        $reorderedItem = [ordered]@{}
        foreach ($propName in $newOrder) {
            $reorderedItem[$propName] = $item.$propName
        }
        $reorderedData += [PSCustomObject]$reorderedItem
    }
    
    return $reorderedData
}

function Test-ObfuscatedData {
    <#
    .SYNOPSIS
        Detects if Graph API usage report data is obfuscated (hashed identifiers).
    
    .DESCRIPTION
        Analyzes User Principal Name and Display Name fields to determine if data is obfuscated.
        Obfuscated data appears as 32-character hexadecimal hashes instead of real identifiers.
        
        Returns $true if obfuscation is detected, $false if data is clear.
    
    .PARAMETER Data
        Array of usage report records to analyze
    
    .EXAMPLE
        $isObfuscated = Test-ObfuscatedData -Data $usageData
        if ($isObfuscated) { Write-Host "Data is hashed!" }
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data
    )
    
    if (-not $Data -or $Data.Count -eq 0) {
        return $false  # No data to test
    }
    
    # Sample first 5 records to check for obfuscation
    $sampleSize = [Math]::Min(5, $Data.Count)
    $obfuscatedCount = 0
    
    for ($i = 0; $i -lt $sampleSize; $i++) {
        $record = $Data[$i]
        
        # Check User Principal Name field (various field names across endpoints)
        $upnValue = $null
        if ($record.'User Principal Name') {
            $upnValue = $record.'User Principal Name'
        }
        elseif ($record.'userPrincipalName') {
            $upnValue = $record.'userPrincipalName'
        }
        elseif ($record.'UPN') {
            $upnValue = $record.'UPN'
        }
        
        # Check Display Name field
        $displayNameValue = $null
        if ($record.'Display Name') {
            $displayNameValue = $record.'Display Name'
        }
        elseif ($record.'displayName') {
            $displayNameValue = $record.'displayName'
        }
        
        # Obfuscation pattern: 32-character hexadecimal string (MD5 hash)
        # Example: "1609C1ECD4107D22F41A96C5962177E4"
        $hashPattern = '^[A-F0-9]{32}$'
        
        if ($upnValue -and $upnValue -match $hashPattern) {
            $obfuscatedCount++
        }
        elseif ($displayNameValue -and $displayNameValue -match $hashPattern) {
            $obfuscatedCount++
        }
    }
    
    # If majority of sampled records are obfuscated, consider data obfuscated
    $obfuscationThreshold = [Math]::Ceiling($sampleSize / 2)
    return ($obfuscatedCount -ge $obfuscationThreshold)
}

function Invoke-GraphEndpointQuery {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Endpoint,
        
        [Parameter(Mandatory = $false)]
        [string]$QueryPeriod,
        
        [Parameter(Mandatory = $false)]
        [int]$ThrottleMs = 0
    )
    
    $endpointName = $Endpoint.Name
    $endpointUrl = $Endpoint.Url
    $displayName = $Endpoint.DisplayName
    
    Write-LogHost "Querying: $displayName" -ForegroundColor Cyan
    Write-Log ("Querying endpoint: $displayName ($endpointName)")
    
    # Determine query type based on endpoint capabilities
    if ($QueryPeriod -and $Endpoint.SupportsPeriod) {
        Write-LogHost "  Query Type: Period ($QueryPeriod)" -ForegroundColor White
        Write-Log ("  Query type: Period ($QueryPeriod)")
        $queryUrl = $endpointUrl + "(period='$QueryPeriod')"
    }
    elseif ($Endpoint.Name -eq 'EntraUsers') {
        Write-LogHost "  Query Type: Directory Query (no period/date)" -ForegroundColor White
        Write-Log ("  Query type: Directory Query (no period/date)")
        $queryUrl = $endpointUrl
    }
    elseif (-not $Endpoint.SupportsPeriod) {
        # Snapshot endpoints (e.g., M365Activations) - no period/date parameters
        Write-LogHost "  Query Type: Snapshot (no period/date parameters)" -ForegroundColor White
        Write-Log ("  Query type: Snapshot (no period/date parameters)")
        $queryUrl = $endpointUrl
    }
    else {
        Write-LogHost "  SKIP: Endpoint does not support requested query type" -ForegroundColor Yellow
        Write-Log ("  SKIP: Endpoint does not support requested query type")
        return $null
    }
    
    # Special handling for Entra Users endpoint
    if ($Endpoint.Name -eq 'EntraUsers') {
        # Build $select parameter with all 35 core properties
        $selectProperties = $EntraUserProperties -join ','
        $queryUrl += "?`$select=$selectProperties"
        
        # Add manager expansion
        $queryUrl += "&`$expand=manager(`$select=displayName,userPrincipalName,mail,id)"
        
        Write-LogHost "  Format: JSON (with 35 properties + manager expansion)" -ForegroundColor White
        Write-LogHost "  URL: $($queryUrl.Substring(0, [Math]::Min(100, $queryUrl.Length)))..." -ForegroundColor Gray
    }
    # Add CSV format for capable endpoints
    elseif ($Endpoint.CsvCapable) {
        $queryUrl += "?`$format=text/csv"
        Write-LogHost "  API Format: CSV" -ForegroundColor White
        Write-LogHost "  URL: $queryUrl" -ForegroundColor Gray
    }
    else {
        Write-LogHost "  Format: JSON" -ForegroundColor White
        Write-LogHost "  URL: $queryUrl" -ForegroundColor Gray
    }
    
    # Execute query with retry logic
    $maxRetries = 3
    $retryCount = 0
    $success = $false
    $result = $null
    
    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            if ($retryCount -gt 0) {
                $waitSeconds = [Math]::Pow(2, $retryCount)
                Write-LogHost "  Retry $retryCount/$maxRetries after $waitSeconds seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $waitSeconds
            }
            
            # CSV endpoints require special handling (download to temp file then parse)
            if ($Endpoint.CsvCapable) {
                $tempCsvFile = [System.IO.Path]::GetTempFileName() + ".csv"
                
                try {
                    # Download CSV to temp file
                    Invoke-MgGraphRequest -Method GET -Uri $queryUrl -OutputFilePath $tempCsvFile -ErrorAction Stop | Out-Null
                    
                    # Read and parse CSV
                    if (Test-Path $tempCsvFile) {
                        $csvContent = Get-Content -Path $tempCsvFile -Raw
                        if ($csvContent -and $csvContent.Trim().Length -gt 0) {
                            $result = $csvContent | ConvertFrom-Csv
                            Write-LogHost "  ✓ Retrieved $($result.Count) rows" -ForegroundColor Green
                            Write-Log ("  Retrieved $($result.Count) rows from $displayName")
                        }
                        else {
                            Write-LogHost "  ✓ Query completed (no data returned)" -ForegroundColor Yellow
                            Write-Log ("  Query completed with no data for $displayName")
                            $result = @()
                        }
                    }
                }
                finally {
                    # Cleanup temp file
                    if (Test-Path $tempCsvFile) {
                        Remove-Item -Path $tempCsvFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            # Handle JSON response
            else {
                $response = Invoke-MgGraphRequest -Method GET -Uri $queryUrl -ErrorAction Stop
                
                if ($response.'@odata.nextLink') {
                    Write-LogHost "  Pagination detected, retrieving all pages..." -ForegroundColor Yellow
                    $allResults = @()
                    $allResults += $response.value
                    
                    $nextLink = $response.'@odata.nextLink'
                    $pageCount = 1
                    while ($nextLink) {
                        if ($ThrottleMs -gt 0) {
                            Start-Sleep -Milliseconds $ThrottleMs
                        }
                        $pageResponse = Invoke-MgGraphRequest -Method GET -Uri $nextLink -ErrorAction Stop
                        $allResults += $pageResponse.value
                        $nextLink = $pageResponse.'@odata.nextLink'
                        $pageCount++
                        Write-LogHost "  Retrieved $($allResults.Count) total records..." -ForegroundColor Gray
                        Write-Log ("    Page $pageCount retrieved: $($pageResponse.value.Count) records (total: $($allResults.Count))")
                    }
                    $result = $allResults
                    Write-LogHost "  ✓ Retrieved $($result.Count) total rows (paginated)" -ForegroundColor Green
                    Write-Log ("  Pagination complete: $($result.Count) total rows across $pageCount pages")
                }
                else {
                    $result = $response.value
                    if ($result) {
                        Write-LogHost "  ✓ Retrieved $($result.Count) rows" -ForegroundColor Green
                        Write-Log ("  Retrieved $($result.Count) rows from $displayName")
                    }
                    else {
                        Write-LogHost "  ✓ Query completed (no data returned)" -ForegroundColor Yellow
                        Write-Log ("  Query completed with no data for $displayName")
                        $result = @()
                    }
                }
            }
            
            $success = $true
        }
        catch {
            $retryCount++
            $errorMessage = $_.Exception.Message
            
            # Check for specific error types
            if ($errorMessage -like "*429*" -or $errorMessage -like "*throttle*") {
                Write-LogHost "  ⚠ Throttled by API (429), retrying..." -ForegroundColor Yellow
            }
            elseif ($errorMessage -like "*401*" -or $errorMessage -like "*403*") {
                Write-LogHost "  ✗ Authorization failed: $errorMessage" -ForegroundColor Red
                Write-LogHost "    Check that your account has the required permissions" -ForegroundColor Yellow
                return $null
            }
            elseif ($errorMessage -like "*404*") {
                Write-LogHost "  ✗ Endpoint not found (404): $errorMessage" -ForegroundColor Red
                return $null
            }
            else {
                Write-LogHost "  ✗ Error: $errorMessage" -ForegroundColor Red
                if ($retryCount -ge $maxRetries) {
                    Write-LogHost "    Max retries exceeded, skipping endpoint" -ForegroundColor Red
                    return $null
                }
            }
        }
    }
    
    # Apply throttling if configured
    if ($ThrottleMs -gt 0 -and $success) {
        Start-Sleep -Milliseconds $ThrottleMs
    }
    
    return $result
}

# ==============================================
# Multi-Endpoint Processing Loop
# ==============================================

# Display query configuration summary
Write-Host "=== Query Configuration Summary ===" -ForegroundColor Cyan
Write-Host ""

# Query Mode
Write-Host "Query Mode: Period (aggregated)" -ForegroundColor White
Write-Host ("  Period:     {0}" -f $Period) -ForegroundColor White

# Map period to days for display
$periodDays = switch ($Period) {
    'D7'   { '7 days' }
    'D30'  { '30 days' }
    'D90'  { '90 days' }
    'D180' { '180 days' }
    'ALL'  { 'All available data' }
}
Write-Host ("  Coverage:   {0}" -f $periodDays) -ForegroundColor White
Write-Log ("Query Mode: Period | Period: $Period | Coverage: $periodDays")

# Output Configuration
Write-Host ""
Write-Host "Output Configuration:" -ForegroundColor White
Write-Host ("  Output Path:        {0}" -f $OutputPath) -ForegroundColor White
if ($CombineOutput) {
    $combinedFileName = if ($OutputFileName) { $OutputFileName } else { 
        "Combined_GraphUsage_${Period}_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    }
    Write-Host ("  Mode:               Combined (single file)") -ForegroundColor White
    Write-Host ("  Filename:           {0}" -f $combinedFileName) -ForegroundColor White
}
else {
    Write-Host ("  Mode:               Individual files (one per endpoint)") -ForegroundColor White
}

# Processing Options
Write-Host ""
Write-Host "Processing Options:" -ForegroundColor White
Write-Host ("  Explode Arrays:     {0}" -f $ExplodeArrays.IsPresent) -ForegroundColor White
Write-Host ("  Include Copilot:    {0}" -f $IncludeCopilotUsage.IsPresent) -ForegroundColor White
Write-Host ("  Include Curated:    {0}" -f $IncludeCurated.IsPresent) -ForegroundColor White
Write-Host ("  Include Entra:      {0}" -f $IncludeEntraUsers.IsPresent) -ForegroundColor White

# Performance Settings
Write-Host ""
Write-Host "Performance Settings:" -ForegroundColor White
Write-Host ("  Authentication:     {0}" -f $Auth) -ForegroundColor White
Write-Host ("  Throttle Delay:     {0} ms" -f $PacingMs) -ForegroundColor White

# Define the curated default endpoint set
# This is the default selection when no explicit -Include* or -Exclude* parameters are provided
$DefaultCuratedEndpoints = @(
    'M365AppUserDetail',
    'TeamsUserActivity',
    'EmailActivity',
    'SharePointActivity',
    'OneDriveActivity',
    'CopilotUsage',
    'MACCopilotLicensing',
    'MACLicenseSummary',
    'EntraUsers'
)

# Endpoints to query
Write-Host ""
Write-Host "Endpoints to Query:" -ForegroundColor White
# Determine which endpoints to include based on parameters
$endpointsToInclude = @()
$explicitIncludesProvided = $false

# Check if any explicit -Include* parameters were provided
if ($IncludeCopilotUsage -or $IncludeM365AppUserDetail -or $IncludeOutlookActivity -or 
    $IncludeTeamsActivity -or $IncludeSharePointActivity -or $IncludeOneDriveActivity -or 
    $IncludeMACCopilotLicensing -or $IncludeCurated -or $IncludeEntraUsers -or 
    ($IncludeCustomEndpoints -and $IncludeCustomEndpoints.Count -gt 0)) {
    $explicitIncludesProvided = $true
}

# Build the initial endpoint selection list
if ($explicitIncludesProvided) {
    # Explicit includes replace the default - build list additively
    if ($IncludeCopilotUsage) { $endpointsToInclude += 'CopilotUsage' }
    if ($IncludeM365AppUserDetail) { $endpointsToInclude += 'M365AppUserDetail' }
    if ($IncludeOutlookActivity) { $endpointsToInclude += 'EmailActivity' }
    if ($IncludeTeamsActivity) { $endpointsToInclude += 'TeamsUserActivity' }
    if ($IncludeSharePointActivity) { $endpointsToInclude += 'SharePointActivity' }
    if ($IncludeOneDriveActivity) { $endpointsToInclude += 'OneDriveActivity' }
    if ($IncludeMACCopilotLicensing) { $endpointsToInclude += 'MACCopilotLicensing' }
    if ($IncludeMACLicenseSummary) { $endpointsToInclude += 'MACLicenseSummary' }
    if ($IncludeEntraUsers) { $endpointsToInclude += 'EntraUsers' }
    if ($IncludeCurated) { 
        # -IncludeCurated adds all endpoints from the curated default set
        $endpointsToInclude += $DefaultCuratedEndpoints 
    }
    if ($IncludeCustomEndpoints -and $IncludeCustomEndpoints.Count -gt 0) {
        # Validate custom endpoint names exist in $Endpoints array
        $validEndpointNames = $Endpoints | Select-Object -ExpandProperty Name
        foreach ($customName in $IncludeCustomEndpoints) {
            if ($validEndpointNames -contains $customName) {
                $endpointsToInclude += $customName
            } else {
                Write-Warning "Custom endpoint name '$customName' not found in available endpoints. Skipping."
            }
        }
    }
    # Remove duplicates
    $endpointsToInclude = $endpointsToInclude | Select-Object -Unique
} else {
    # No explicit includes - use the curated default set
    $endpointsToInclude = $DefaultCuratedEndpoints
}

# Apply exclusions if any -Exclude* parameters were provided
$exclusionsToApply = @()
if ($ExcludeEntraUsers) { $exclusionsToApply += 'EntraUsers' }
if ($ExcludeMACCopilotLicensing) { $exclusionsToApply += 'MACCopilotLicensing' }
if ($ExcludeMACLicenseSummary) { $exclusionsToApply += 'MACLicenseSummary' }

# Detect conflicts: Same endpoint in both include and exclude
$conflicts = @()
foreach ($endpoint in $endpointsToInclude) {
    if ($exclusionsToApply -contains $endpoint) {
        $conflicts += $endpoint
    }
}

# Handle conflicts
if ($conflicts.Count -gt 0) {
    Write-Log "Conflict detected: Endpoints in both Include and Exclude lists: $($conflicts -join ', ')"
    if ($Force) {
        # Auto-resolve: Include wins (remove from exclusions)
        Write-Host "Conflicts detected between -Include* and -Exclude* parameters for: $($conflicts -join ', ')" -ForegroundColor Yellow
        Write-Host "  -Force parameter provided: Include parameters take precedence. Excluding conflicts from exclusion list." -ForegroundColor Yellow
        Write-Log "Conflict resolution: -Force parameter used, Include takes precedence"
        $exclusionsToApply = $exclusionsToApply | Where-Object { $conflicts -notcontains $_ }
    } else {
        # Interactive prompt
        Write-Host ""
        Write-Host "Conflict Detected:" -ForegroundColor Yellow
        Write-Host "  The following endpoints are specified in both -Include* and -Exclude* parameters:" -ForegroundColor Yellow
        foreach ($conflict in $conflicts) {
            Write-Host "    • $conflict" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "  Resolution Options:" -ForegroundColor White
        Write-Host "    [I] Include - Include these endpoints (exclude is ignored)" -ForegroundColor White
        Write-Host "    [E] Exclude - Exclude these endpoints (include is ignored)" -ForegroundColor White
        Write-Host "    [C] Cancel - Exit script" -ForegroundColor White
        Write-Host ""
        $choice = Read-Host "  Choose resolution (I/E/C)"
        Write-Log "User conflict resolution choice: $choice"
        switch ($choice.ToUpper()) {
            'I' {
                # Include wins - remove conflicts from exclusions
                $exclusionsToApply = $exclusionsToApply | Where-Object { $conflicts -notcontains $_ }
                Write-Host "  Resolved: Including endpoints." -ForegroundColor Green
                Write-Log "Conflict resolved: User chose Include (conflicts: $($conflicts -join ', '))"
            }
            'E' {
                # Exclude wins - remove conflicts from includes
                $endpointsToInclude = $endpointsToInclude | Where-Object { $conflicts -notcontains $_ }
                Write-Host "  Resolved: Excluding endpoints." -ForegroundColor Green
                Write-Log "Conflict resolved: User chose Exclude (conflicts: $($conflicts -join ', '))"
            }
            'C' {
                Write-Host "  Script execution cancelled by user." -ForegroundColor Red
                Write-Log "Script cancelled by user during conflict resolution"
                exit 1
            }
            default {
                Write-Host "  Invalid choice. Exiting." -ForegroundColor Red
                Write-Log "Script cancelled: Invalid conflict resolution choice '$choice'"
                exit 1
            }
        }
    }
}
else {
    Write-Log "No conflicts detected between Include and Exclude parameters"
}

# Apply exclusions to final list
if ($exclusionsToApply.Count -gt 0) {
    $endpointsToInclude = $endpointsToInclude | Where-Object { $exclusionsToApply -notcontains $_ }
}

# Filter $Endpoints array to only those in $endpointsToInclude
$endpointsToQueryPreview = @($Endpoints | Where-Object { $endpointsToInclude -contains $_.Name })
Write-Host ("  Total Endpoints:    {0}" -f $endpointsToQueryPreview.Count) -ForegroundColor White
Write-Host "  Endpoint List:" -ForegroundColor Gray
foreach ($ep in $endpointsToQueryPreview) {
    Write-Host ("    • {0}" -f $ep.Name) -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Processing All Endpoints" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Data Source: Microsoft Graph API" -ForegroundColor Cyan
Write-Host ""

# Determine which endpoints to query (use the same endpoint inclusion list)
# Endpoint selection and conflict resolution was completed during initialization
$endpointsToQuery = @($Endpoints | Where-Object { $endpointsToInclude -contains $_.Name })

Write-Host "Processing $($endpointsToQuery.Count) endpoint(s)...`n" -ForegroundColor Cyan
Write-Log ("Processing $($endpointsToQuery.Count) endpoints")
Write-Log ""

# Track results for each endpoint
$endpointResults = @{}
$filesSaved = @()

# Process each endpoint
$endpointNumber = 0
$obfuscationChecked = $false
$dataIsObfuscated = $false

foreach ($endpoint in $endpointsToQuery) {
    $endpointNumber++
    Write-Host "[$endpointNumber/$($endpointsToQuery.Count)] " -NoNewline -ForegroundColor Cyan
    
    # Query the endpoint
    $queryParams = @{
        Endpoint = $endpoint
        ThrottleMs = $PacingMs
    }
    
    # Determine query type based on endpoint capabilities
    if ($endpoint.Name -eq 'EntraUsers') {
        # Entra Users: No period/date parameters
        $data = Invoke-GraphEndpointQuery @queryParams
    }
    elseif ($endpoint.Name -eq 'MACCopilotLicensing') {
        # MAC Copilot Licensing: Direct Graph API query (not CSV-based)
        # Data will be processed in the flattening section below
        $data = @()  # Placeholder - actual query happens in processing section
    }
    elseif ($endpoint.Name -eq 'MACLicenseSummary') {
        # MAC Copilot License Summary: Direct Graph API query (not CSV-based)
        # Data will be processed in the flattening section below
        $data = @()  # Placeholder - actual query happens in processing section
    }
    elseif (-not $endpoint.SupportsPeriod) {
        # Snapshot endpoints (e.g., M365Activations): No period/date parameters
        $data = Invoke-GraphEndpointQuery @queryParams
    }
    else {
        # Period query mode: Use period parameter
        $data = Invoke-GraphEndpointQuery @queryParams -QueryPeriod $Period
    }
    
    # Check for obfuscation on first usage endpoint with data (skip Entra Users, MAC Licensing, and MAC Summary)
    if (-not $obfuscationChecked -and $endpoint.Name -ne 'EntraUsers' -and $endpoint.Name -ne 'MACCopilotLicensing' -and $endpoint.Name -ne 'MACLicenseSummary' -and $data -and $data.Count -gt 0) {
        $obfuscationChecked = $true
        $dataIsObfuscated = Test-ObfuscatedData -Data $data
        
        if ($dataIsObfuscated) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Red
            Write-Host "⚠️  OBFUSCATED DATA DETECTED" -ForegroundColor Red
            Write-Host "========================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "The usage report data contains HASHED identifiers instead of real User Principal Names." -ForegroundColor Yellow
            Write-Host "Example: '1609C1ECD4107D22F41A96C5962177E4' instead of 'john.doe@contoso.com'" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "This makes the data UNUSABLE for:" -ForegroundColor Yellow
            Write-Host "  • Joining with Entra user attributes" -ForegroundColor Gray
            Write-Host "  • Copilot usage analysis with user attribution" -ForegroundColor Gray
            Write-Host "  • M365 app usage analysis in conjunction with Copilot data" -ForegroundColor Gray
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "SOLUTION: Disable Obfuscation Setting" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Follow these steps to get real identifiers:" -ForegroundColor White
            Write-Host ""
            Write-Host "  1. Open Microsoft 365 Admin Center" -ForegroundColor White
            Write-Host "     Direct link: https://admin.microsoft.com/#/Settings/Services/:/Settings/L1/Reports" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  2. Navigate to: Settings → Org Settings → Reports" -ForegroundColor White
            Write-Host ""
            Write-Host "  3. UNCHECK the box:" -ForegroundColor White
            Write-Host "     ☐ Display concealed user, group, and site names in all reports" -ForegroundColor Red
            Write-Host ""
            Write-Host "  4. Click 'Save' (takes effect in a few minutes)" -ForegroundColor White
            Write-Host ""
            Write-Host "  5. Re-run this script to get de-obfuscated data" -ForegroundColor White
            Write-Host ""
            Write-Host "  NOTE: When CHECKED = Hashed data | When UNCHECKED = Real identifiers" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Red
            Write-Host ""
            
            # Prompt user for action
            Write-Host "How would you like to proceed?" -ForegroundColor Cyan
            Write-Host "  [1] Exit script (fix privacy setting, then re-run)" -ForegroundColor White
            Write-Host "  [2] Continue anyway (export obfuscated/hashed data)" -ForegroundColor Yellow
            Write-Host ""
            $userChoice = Read-Host "Enter choice (1 or 2)"
            
            if ($userChoice -ne '2') {
                Write-Host ""
                Write-Host "Exiting script. Please disable obfuscation setting and re-run." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Quick Link: https://admin.microsoft.com/#/Settings/Services/:/Settings/L1/Reports" -ForegroundColor Cyan
                Write-Host "Action: UNCHECK the 'Display concealed...' box" -ForegroundColor Cyan
                Write-Host ""
                
                # Disconnect Graph API
                Disconnect-MgGraph | Out-Null
                exit 1
            }
            else {
                Write-Host ""
                Write-Host "⚠️  Continuing with OBFUSCATED data..." -ForegroundColor Yellow
                Write-Host "    User Principal Names will be hashed (32-character hex strings)" -ForegroundColor Yellow
                Write-Host "    Data cannot be used for Copilot + M365 app usage analysis" -ForegroundColor Yellow
                Write-Host "    Entra user enrichment will not be possible" -ForegroundColor Yellow
                Write-Host ""
            }
        }
        else {
            Write-Host ""
            Write-Host "✓ Data obfuscation check: PASSED (real identifiers detected)" -ForegroundColor Green
            Write-Host ""
        }
    }
    
    # Flatten Entra Users data (for both individual and combined output)
    if ($endpoint.Name -eq 'EntraUsers' -and $data -and $data.Count -gt 0) {
        Write-Log ("Processing Entra Users data: $($data.Count) users")
        $flattenedEntraData = ConvertTo-FlatEntraUsers -Users $data -ExplodeArrays:$ExplodeArrays
        $data = $flattenedEntraData  # Use flattened data for individual file save too
        $columnCount = @($flattenedEntraData[0].PSObject.Properties).Count
        Write-Host "  Processed $($data.Count) user accounts ($columnCount columns)" -ForegroundColor Gray
        Write-Log ("  Filtered to $($data.Count) real users (excluded rooms/resources), flattened to $columnCount columns")
    }
    # Retrieve MAC Copilot Licensing data from Graph API
    elseif ($endpoint.Name -eq 'MACCopilotLicensing') {
        Write-Log "Processing MAC Copilot Licensing endpoint"
        
        # Retrieve tenant SKUs for Copilot license pattern matching
        Write-Host "  Querying tenant license SKUs for pattern matching..." -ForegroundColor Gray
        Write-Log "  Querying subscribedSkus for SKU name lookup"
        $tenantSkus = Get-MACLicenseSummary
        
        # Retrieve all users with license assignments
        $allUsers = Get-MACCopilotLicensing
        
        if ($allUsers -and $allUsers.Count -gt 0) {
            Write-Host "  Retrieved $($allUsers.Count) users from Graph API" -ForegroundColor Gray
            Write-Log ("  Retrieved $($allUsers.Count) users with license data")
            
            # Flatten and filter for Copilot licenses only (pass tenant SKUs for pattern matching)
            $flattenedLicenseData = ConvertTo-FlatMACLicensing -Users $allUsers -TenantSkus $tenantSkus
            $data = $flattenedLicenseData
            
            if ($data -and $data.Count -gt 0) {
                $columnCount = @($data[0].PSObject.Properties).Count
                Write-Host "  Processed $($data.Count) Copilot-licensed users ($columnCount columns)" -ForegroundColor Gray
                Write-Log ("  Filtered to $($data.Count) users with Copilot licenses, flattened to $columnCount columns")
            }
            else {
                Write-Host "  ⚠️  No users with Copilot licenses found" -ForegroundColor Yellow
                Write-Host "     If you have Copilot licenses, check the debug output above for unrecognized SKU IDs" -ForegroundColor Gray
                Write-Host "     See MACLicenseSummary output or end-of-run summary for troubleshooting steps" -ForegroundColor Gray
                Write-Log "  No Copilot licenses detected in tenant"
            }
        }
        else {
            Write-Host "  ⚠️  No user data retrieved from Graph API" -ForegroundColor Yellow
            Write-Log "  MAC Copilot Licensing query returned no data"
            $data = @()
        }
    }
    # Retrieve MAC Copilot License Summary data from Graph API
    elseif ($endpoint.Name -eq 'MACLicenseSummary') {
        Write-Log "Processing MAC License Summary endpoint (Copilot + M365/O365 SKUs)"
        
        # Retrieve all subscribed license SKUs
        $allSkus = Get-MACLicenseSummary
        
        if ($allSkus -and $allSkus.Count -gt 0) {
            Write-Host "  Retrieved $($allSkus.Count) subscribed SKUs from Graph API" -ForegroundColor Gray
            Write-Log ("  Retrieved $($allSkus.Count) subscribed SKUs")
            
            # Flatten and filter for Copilot + M365 SKUs
            $flattenedSummary = ConvertTo-FlatMACLicenseSummary -Skus $allSkus
            $data = $flattenedSummary
            
            if ($data -and $data.Count -gt 0) {
                $columnCount = @($data[0].PSObject.Properties).Count
                $copilotSkuCount = ($data | Where-Object { $_.licenseType -eq 'Copilot' }).Count
                $m365SkuCount = ($data | Where-Object { $_.licenseType -eq 'M365' }).Count
                Write-Host "  Processed $($data.Count) SKUs: $copilotSkuCount Copilot, $m365SkuCount M365 ($columnCount columns)" -ForegroundColor Gray
                Write-Log ("  Flattened $($data.Count) SKUs ($copilotSkuCount Copilot, $m365SkuCount M365) to $columnCount columns")
            }
            else {
                Write-Host "  ⚠️  No Copilot or M365/Office 365 SKUs found in tenant" -ForegroundColor Yellow
                Write-Log "  No Copilot or M365/Office 365 SKUs detected in tenant"
            }
        }
        else {
            Write-Host "  ⚠️  No SKU data retrieved from Graph API" -ForegroundColor Yellow
            Write-Log "  MAC License Summary query returned no data"
            $data = @()
        }
    }
    # Reorder columns for CSV endpoints (move Report Period after Report Refresh Date)
    elseif ($data -and $data.Count -gt 0 -and $endpoint.CsvCapable) {
        $data = Move-ReportPeriodColumn -Data $data
    }
    
    # Store results
    $endpointResults[$endpoint.Name] = $data
    
    # Provide informational messages for endpoints that return no data
    if (-not $data -or $data.Count -eq 0) {
        Write-LogHost ""
        
        # Customize message based on endpoint type
        switch ($endpoint.Name) {
            'CopilotUsage' {
                Write-LogHost "  ℹ️  COPILOT USAGE: No data returned" -ForegroundColor Yellow
                Write-LogHost "     This is normal if:" -ForegroundColor Gray
                Write-LogHost "       • Copilot licenses not assigned to users in this tenant" -ForegroundColor Gray
                Write-LogHost "       • No Copilot usage during the selected time period ($Period)" -ForegroundColor Gray
                Write-LogHost "       • Tenant does not have Microsoft 365 Copilot enabled" -ForegroundColor Gray
            }
            'MACCopilotLicensing' {
                Write-LogHost "  ℹ️  COPILOT LICENSING: No licenses found" -ForegroundColor Yellow
                Write-LogHost "     This is normal if:" -ForegroundColor Gray
                Write-LogHost "       • No Microsoft 365 Copilot licenses assigned in this tenant" -ForegroundColor Gray
                Write-LogHost "       • Users have other Microsoft 365 licenses but not Copilot" -ForegroundColor Gray
                Write-LogHost "       • Tenant does not have Copilot SKUs purchased" -ForegroundColor Gray
                Write-LogHost "" -ForegroundColor Gray
                Write-LogHost "     ⚠️  If you KNOW you have Copilot licenses assigned:" -ForegroundColor Yellow
                Write-LogHost "       • Your Copilot SKU ID may not be in the script's detection list" -ForegroundColor Gray
                Write-LogHost "       • Check the 'MACLicenseSummary' output to see all your tenant's SKUs" -ForegroundColor Gray
                Write-LogHost "       • Look for SKU names containing 'Copilot' in that file" -ForegroundColor Gray
                Write-LogHost "       • Add any missing Copilot SKU IDs to the `$script:CopilotSkuIds hashtable" -ForegroundColor Gray
                Write-LogHost "       • Location in script: Search for 'Known Microsoft 365 Copilot SKU IDs'" -ForegroundColor Gray
                Write-LogHost "       • Reference: https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference" -ForegroundColor Gray
            }
            'MACLicenseSummary' {
                Write-LogHost "  ℹ️  LICENSE SUMMARY: No SKUs found" -ForegroundColor Yellow
                Write-LogHost "     This endpoint reports on both Copilot and M365/Office 365 licenses." -ForegroundColor Gray
                Write-LogHost "" -ForegroundColor Gray
                Write-LogHost "     This is normal if:" -ForegroundColor Gray
                Write-LogHost "       • No Copilot licenses purchased in this tenant" -ForegroundColor Gray
                Write-LogHost "       • No Microsoft 365 or Office 365 licenses purchased" -ForegroundColor Gray
                Write-LogHost "       • Tenant only has other license types (Azure, Dynamics, etc.)" -ForegroundColor Gray
                Write-LogHost "" -ForegroundColor Gray
                Write-LogHost "     ℹ️  What this endpoint tracks:" -ForegroundColor Cyan
                Write-LogHost "       • All Microsoft 365 Copilot SKUs" -ForegroundColor Gray
                Write-LogHost "       • All Microsoft 365 Business/Enterprise/Frontline SKUs" -ForegroundColor Gray
                Write-LogHost "       • All Office 365 Business/Enterprise SKUs" -ForegroundColor Gray
                Write-LogHost "" -ForegroundColor Gray
                Write-LogHost "     📊 Each license shows: capacity, consumed, available, utilization %" -ForegroundColor Gray
            }
            'EntraUsers' {
                Write-LogHost "  ℹ️  ENTRA USERS: No user accounts found" -ForegroundColor Yellow
                Write-LogHost "     This is unexpected - most tenants have user accounts." -ForegroundColor Gray
                Write-LogHost "     Possible causes:" -ForegroundColor Gray
                Write-LogHost "       • Permission issue with Directory.Read.All scope" -ForegroundColor Gray
                Write-LogHost "       • All user accounts filtered out (rooms/resources only)" -ForegroundColor Gray
            }
            default {
                # Generic message for all other endpoints
                Write-LogHost "  ℹ️  NO DATA: $($endpoint.DisplayName)" -ForegroundColor Yellow
                Write-LogHost "     No records found for the selected period ($Period)." -ForegroundColor Gray
                Write-LogHost "     This could mean:" -ForegroundColor Gray
                Write-LogHost "       • No user activity for this service during the time period" -ForegroundColor Gray
                Write-LogHost "       • Service not enabled or licensed in this tenant" -ForegroundColor Gray
                Write-LogHost "       • Users may not have access to this service" -ForegroundColor Gray
            }
        }
        
        Write-LogHost ""
        Write-LogHost "     Note: No CSV file or Excel worksheet will be created (no data)." -ForegroundColor Gray
        Write-LogHost ""
    }
    
    # Save to individual file (unless CombineOutput or ExportWorkbook is specified)
    # When ExportWorkbook is enabled, data is only exported to Excel, not individual CSVs
    if (-not $CombineOutput -and -not $ExportWorkbook -and $data -and $data.Count -gt 0) {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        
        # Build filename based on period
        $filename = "$($endpoint.Name)_$Period`_$timestamp.csv"
        
        $outputFilePath = Join-Path $OutputPath $filename
        
        try {
            # Export to CSV (Entra Users, MAC Licensing, and MAC Summary already flattened above)
            $data | Export-Csv -Path $outputFilePath -NoTypeInformation -Force
            
            if (($endpoint.Name -eq 'EntraUsers' -or $endpoint.Name -eq 'MACCopilotLicensing' -or $endpoint.Name -eq 'MACLicenseSummary') -and $data.Count -gt 0) {
                $columnCount = @($data[0].PSObject.Properties).Count
                Write-Host "  ✓ Saved: $filename ($($data.Count) rows, $columnCount columns)" -ForegroundColor Green
                Write-Log ("  Saved individual file: $outputFilePath ($($data.Count) rows, $columnCount columns)")
            }
            else {
                Write-Host "  ✓ Saved: $filename ($($data.Count) rows)" -ForegroundColor Green
                Write-Log ("  Saved individual file: $outputFilePath ($($data.Count) rows)")
            }
            $filesSaved += $outputFilePath
        }
        catch {
            Write-Host "  ✗ Error saving file: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log ("  ERROR saving file: $($_.Exception.Message)")
        }
    }
    elseif (-not $CombineOutput -and -not $ExportWorkbook) {
        Write-Host "  ⊘ Skipped: No data to save" -ForegroundColor Gray
    }
    elseif ($ExportWorkbook -and $data -and $data.Count -gt 0) {
        # In ExportWorkbook mode, just show data will be added to workbook
        if (($endpoint.Name -eq 'EntraUsers' -or $endpoint.Name -eq 'MACCopilotLicensing' -or $endpoint.Name -eq 'MACLicenseSummary') -and $data.Count -gt 0) {
            $columnCount = @($data[0].PSObject.Properties).Count
            Write-Host "  ✓ Prepared for workbook: $($data.Count) rows, $columnCount columns" -ForegroundColor Green
            Write-Log ("  Prepared for workbook: $($data.Count) rows, $columnCount columns")
        }
        else {
            Write-Host "  ✓ Prepared for workbook: $($data.Count) rows" -ForegroundColor Green
            Write-Log ("  Prepared for workbook: $($data.Count) rows")
        }
    }
    
    Write-Host ""
}

# ==============================================
# Combined Output (Full Outer Join)
# ==============================================

if ($CombineOutput) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Creating Combined Output" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Log "Creating combined output file..."
    
    # Determine output filename
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    
    if ($OutputFileName) {
        # Use custom filename exactly as specified
        $combinedFileName = $OutputFileName
        # Ensure .csv extension
        if (-not $combinedFileName.EndsWith('.csv')) {
            $combinedFileName += '.csv'
        }
    }
    else {
        # Auto-generate filename with timestamp
        $combinedFileName = "CombinedUsage_$Period`_$timestamp.csv"
    }
    
    $combinedFilePath = Join-Path $OutputPath $combinedFileName
    
    Write-Host "Combining all endpoint data into single file..." -ForegroundColor Cyan
    Write-Host "  Target: $combinedFileName`n" -ForegroundColor White
    Write-Log ("  Target file: $combinedFilePath")
    
    # Collect all unique users across all endpoints
    $allUsers = @{}
    
    # Process each endpoint's data
    foreach ($endpointName in $endpointResults.Keys) {
        $data = $endpointResults[$endpointName]
        
        if (-not $data -or $data.Count -eq 0) {
            Write-Host "  ⊘ Skipping $endpointName (no data)" -ForegroundColor Gray
            continue
        }
        
        Write-Host "  Processing $endpointName ($($data.Count) rows)..." -ForegroundColor White
        
        # Determine the user identifier column for this endpoint
        $userIdColumn = $null
        $firstRow = $data[0]
        
        # Try different possible user identifier columns (order matters - try most common first)
        $possibleUserColumns = @('User Principal Name', 'userPrincipalName', 'Owner Principal Name')
        foreach ($col in $possibleUserColumns) {
            $matchingProp = $firstRow.PSObject.Properties | Where-Object { $_.Name -eq $col }
            if ($matchingProp) {
                $userIdColumn = $matchingProp.Name
                break
            }
        }
        
        # For Entra Users, use userPrincipalName directly
        if ($endpointName -eq 'EntraUsers' -and -not $userIdColumn) {
            if ($firstRow.userPrincipalName) {
                $userIdColumn = 'userPrincipalName'
            }
        }
        
        if (-not $userIdColumn) {
            # Skip non-user reports (like SharePoint sites, Yammer groups)
            Write-Host "    ⊘ Skipping (no user identifier column)" -ForegroundColor Gray
            Write-Host "      Available columns: $($firstRow.PSObject.Properties.Name -join ', ')" -ForegroundColor Gray
            continue
        }
        
        Write-Host "    Join column: $userIdColumn" -ForegroundColor Gray
        
        # Add endpoint data to user records
        $userCount = 0
        foreach ($row in $data) {
            $userId = $row.$userIdColumn
            if (-not $userId) {
                continue
            }
            
            # Normalize user ID (remove spaces, lowercase for matching)
            $normalizedUserId = $userId.Trim().ToLower()
            
            # Initialize user record if not exists
            if (-not $allUsers.ContainsKey($normalizedUserId)) {
                $allUsers[$normalizedUserId] = [ordered]@{
                    'UserPrincipalName' = $userId
                }
            }
            
            # Add all columns from this endpoint with prefix
            foreach ($prop in $row.PSObject.Properties) {
                if ($prop.Name -eq $userIdColumn) {
                    # Skip the join column
                    continue
                }
                
                # Add prefixed column
                $prefixedName = "$endpointName`_$($prop.Name)"
                $allUsers[$normalizedUserId][$prefixedName] = $prop.Value
            }
            $userCount++
        }
        Write-Host "    Added $userCount user records" -ForegroundColor Gray
    }
    
    Write-Host "`n  Collected $($allUsers.Count) unique users" -ForegroundColor Green
    Write-Log ("  Collected $($allUsers.Count) unique users across all endpoints")
    
    # Detect obfuscation and provide comprehensive guidance
    $sampleUserId = $allUsers.Keys | Select-Object -First 1
    if ($sampleUserId -and $sampleUserId -notmatch '@') {
        Write-Host "`n  ⚠️  OBFUSCATION DETECTED: Usage report data is hashed (privacy mode enabled)" -ForegroundColor Yellow
        Write-Host "`n    IMPACT:" -ForegroundColor Cyan
        Write-Host "      • User identifiers show as hashes (e.g., 8CFD2BC454A8B192B39EB6F4CC85ED1D)" -ForegroundColor Gray
        Write-Host "      • Cannot join with Entra Users data using standard methods" -ForegroundColor Gray
        Write-Host "      • Combined output will show separate rows for obfuscated and real data" -ForegroundColor Gray
        
        Write-Host "`n    SOLUTION - Disable Obfuscation Setting:" -ForegroundColor Cyan
        Write-Host "      1. Microsoft 365 Admin Center → Settings → Org Settings → Reports" -ForegroundColor Gray
        Write-Host "      2. UNCHECK: ☐ 'Display concealed user, group, and site names in all reports'" -ForegroundColor Gray
        Write-Host "      3. Save and re-run this script (takes effect in a few minutes)" -ForegroundColor Gray
        Write-Host "`n      Direct Link: https://admin.microsoft.com/#/Settings/Services/:/Settings/L1/Reports" -ForegroundColor Cyan
        Write-Host "      NOTE: UNCHECKED = Real identifiers | CHECKED = Hashed data" -ForegroundColor Yellow
        Write-Host "`n    📚 Documentation: https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/activity-reports`n" -ForegroundColor DarkCyan
    }
    
    # Collect all unique column names across all users
    Write-Host "  Collecting all unique columns..." -ForegroundColor White
    $allColumnNamesHash = @{}
    foreach ($userId in $allUsers.Keys) {
        foreach ($colName in $allUsers[$userId].Keys) {
            $allColumnNamesHash[$colName] = $true
        }
    }
    $allColumnNames = $allColumnNamesHash.Keys | Sort-Object
    Write-Host "    Found $($allColumnNames.Count) total columns across all endpoints" -ForegroundColor Gray
    
    # Convert to array of PSCustomObjects with consistent columns
    Write-Host "  Building combined dataset..." -ForegroundColor White
    $combinedData = @()
    foreach ($userId in $allUsers.Keys) {
        # Create object with all columns (defaults to null for missing values)
        $userObj = [ordered]@{}
        foreach ($colName in $allColumnNames) {
            if ($allUsers[$userId].Contains($colName)) {
                $userObj[$colName] = $allUsers[$userId][$colName]
            }
            else {
                $userObj[$colName] = $null
            }
        }
        $combinedData += [PSCustomObject]$userObj
    }
    
    # Export combined file
    try {
        Write-Host "  Exporting to CSV..." -ForegroundColor White
        $combinedData | Export-Csv -Path $combinedFilePath -NoTypeInformation -Force
        
        $columnCount = @($combinedData[0].PSObject.Properties).Count
        Write-Host "`n  ✓ Combined file saved!" -ForegroundColor Green
        Write-Host "    File: $combinedFileName" -ForegroundColor White
        Write-Host "    Rows: $($combinedData.Count)" -ForegroundColor White
        Write-Host "    Columns: $columnCount" -ForegroundColor White
        Write-Host "    Location: $OutputPath" -ForegroundColor Gray
        Write-Host ""
        Write-Log ("  Combined file saved: $combinedFilePath ($($combinedData.Count) rows, $columnCount columns)")
    }
    catch {
        Write-Host "  ✗ Error saving combined file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Log ("  ERROR saving combined file: $($_.Exception.Message)")
    }
}

# ==============================================
# Excel Workbook Export
# ==============================================

if ($ExportWorkbook) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Creating Excel Workbook" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Log "Creating Excel workbook export..."
    Write-Log ("Excel export mode: " + $(if ($AppendWorkbook) { "Append" } else { "Create new" }))
    
    # Define Excel tab ordering (priority tabs first, then alphabetically)
    $tabOrdering = @(
        'EntraUsers',
        'MACCopilotLicensing',
        'MACLicenseSummary',
        'CopilotUsage',
        'M365AppUserDetail',
        'TeamsUserActivity',
        'EmailActivity',
        'SharePointActivity',
        'OneDriveActivity'
    )
    
    # Determine output filename
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    
    if ($OutputFileName) {
        # Use custom filename
        $excelFileName = $OutputFileName
        # Ensure .xlsx extension
        if ($excelFileName -notmatch '\.xlsx$') {
            $excelFileName = $excelFileName -replace '\.[^.]+$', ''
            $excelFileName += '.xlsx'
        }
    }
    else {
        # Auto-generate filename with timestamp
        $excelFileName = "Graph_Usage_Export_$Period`_$timestamp.xlsx"
    }
    
    $excelFilePath = Join-Path $OutputPath $excelFileName
    
    Write-Host "Exporting to Excel workbook..." -ForegroundColor Cyan
    Write-Host "  Target: $excelFileName`n" -ForegroundColor White
    Write-Log ("  Target file: $excelFilePath")
    
    # Sort endpoints by tab ordering
    $sortedEndpoints = @()
    
    # Add endpoints in priority order
    foreach ($priorityName in $tabOrdering) {
        if ($endpointResults.ContainsKey($priorityName) -and $endpointResults[$priorityName] -and $endpointResults[$priorityName].Count -gt 0) {
            $sortedEndpoints += $priorityName
        }
    }
    
    # Add remaining endpoints alphabetically
    $remainingEndpoints = $endpointResults.Keys | Where-Object { $sortedEndpoints -notcontains $_ } | Sort-Object
    foreach ($endpointName in $remainingEndpoints) {
        if ($endpointResults[$endpointName] -and $endpointResults[$endpointName].Count -gt 0) {
            $sortedEndpoints += $endpointName
        }
    }
    
    Write-Host "  Processing $($sortedEndpoints.Count) endpoint(s) for Excel export...`n" -ForegroundColor White
    
    # Track successful exports
    $exportedSheets = @()
    $totalRowsExported = 0
    
    try {
        # Export each endpoint to a separate worksheet
        foreach ($endpointName in $sortedEndpoints) {
            $data = $endpointResults[$endpointName]
            
            if (-not $data -or $data.Count -eq 0) {
                continue
            }
            
            Write-Host "  [$($sortedEndpoints.IndexOf($endpointName) + 1)/$($sortedEndpoints.Count)] $endpointName ($($data.Count) rows)..." -ForegroundColor White
            
            # Determine worksheet name
            $worksheetName = $endpointName
            
            # Check if appending and tab already exists
            if ($AppendWorkbook -and $script:ExistingExcelSheets -contains $worksheetName) {
                # Check if column headers match
                $existingHeaders = $null
                try {
                    $existingData = Import-Excel -Path $excelFilePath -WorksheetName $worksheetName -StartRow 1 -EndRow 1
                    if ($existingData) {
                        $existingHeaders = $existingData[0].PSObject.Properties.Name | Sort-Object
                    }
                }
                catch {
                    # If we can't read headers, treat as mismatch
                    Write-Host "    ⚠️  Cannot read existing headers - treating as mismatch" -ForegroundColor Yellow
                }
                
                # Get new data headers
                $newHeaders = $data[0].PSObject.Properties.Name | Sort-Object
                
                # Compare headers
                $headersMatch = $false
                if ($existingHeaders) {
                    $headersDiff = Compare-Object -ReferenceObject $existingHeaders -DifferenceObject $newHeaders
                    $headersMatch = ($null -eq $headersDiff)
                }
                
                if (-not $headersMatch) {
                    # Headers don't match - create timestamped tab name
                    $tabTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                    $worksheetName = "$endpointName-$tabTimestamp"
                    Write-Host "    ⚠️  Column headers mismatch - creating new tab: $worksheetName" -ForegroundColor Yellow
                    Write-Log ("    Headers mismatch for $endpointName - creating timestamped tab: $worksheetName")
                }
                else {
                    Write-Host "    ✓ Headers match - appending to existing tab" -ForegroundColor Green
                }
            }
            
            try {
                # Export to Excel with formatting
                $exportParams = @{
                    Path = $excelFilePath
                    WorksheetName = $worksheetName
                    AutoSize = $true
                    FreezeTopRow = $true
                    BoldTopRow = $true
                    NoNumberConversion = '*'  # Prevent Excel from auto-converting numeric strings, dates, phone numbers
                }
                
                # Add -Append if appending to existing workbook
                if ($AppendWorkbook -and (Test-Path $excelFilePath)) {
                    $exportParams.Append = $true
                }
                
                $data | Export-Excel @exportParams
                
                $exportedSheets += $worksheetName
                $totalRowsExported += $data.Count
                
                Write-Host "    ✓ Exported to worksheet: $worksheetName" -ForegroundColor Green
                Write-Log ("    Exported $($data.Count) rows to worksheet: $worksheetName")
            }
            catch {
                Write-Host "    ✗ Error exporting $endpointName`: $($_.Exception.Message)" -ForegroundColor Red
                Write-Log ("    ERROR exporting $endpointName to Excel: $($_.Exception.Message)")
            }
        }
        
        # Summary
        Write-Host "`n  ✓ Excel workbook created successfully!" -ForegroundColor Green
        Write-Host "    File: $excelFileName" -ForegroundColor White
        Write-Host "    Worksheets: $($exportedSheets.Count)" -ForegroundColor White
        Write-Host "    Total Rows: $totalRowsExported" -ForegroundColor White
        Write-Host "    Location: $OutputPath" -ForegroundColor Gray
        Write-Host ""
        
        # List all worksheets
        Write-Host "  Worksheets Created:" -ForegroundColor White
        foreach ($sheetName in $exportedSheets) {
            $sheetData = $endpointResults[$sheetName -replace '-\d{8}-\d{6}$', '']
            $rowCount = if ($sheetData) { $sheetData.Count } else { 0 }
            Write-Host ("    • {0,-30} : {1,6} rows" -f $sheetName, $rowCount) -ForegroundColor Gray
        }
        Write-Host ""
        
        Write-Log ("  Excel workbook saved: $excelFilePath ($($exportedSheets.Count) worksheets, $totalRowsExported total rows)")
    }
    catch {
        Write-Host "`n  ✗ Error creating Excel workbook: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "    Falling back to CSV export..." -ForegroundColor Yellow
        Write-Log ("  ERROR creating Excel workbook: $($_.Exception.Message)")
        Write-Log ("  Falling back to CSV export")
        
        # Fall back to individual CSV exports (already done in the main loop)
        Write-Host "    CSV files already saved in: $OutputPath" -ForegroundColor Yellow
        Write-Host ""
    }
}

# ==============================================
# Script Execution Summary
# ==============================================

$endUtc = (Get-Date).ToUniversalTime()

Write-LogHost "========================================" -ForegroundColor Cyan
Write-LogHost "Script Execution Summary" -ForegroundColor Cyan
Write-LogHost "========================================" -ForegroundColor Cyan
Write-LogHost ""

# Timing Information
Write-LogHost "Timing Information:" -ForegroundColor White
$startFormatted = $script:metrics.StartTime.ToString('yyyy-MM-dd HH:mm:ss')
$endFormatted = $endUtc.ToString('yyyy-MM-dd HH:mm:ss')
Write-LogHost ("  Script Started:   {0} UTC" -f $startFormatted) -ForegroundColor Gray
Write-LogHost ("  Script Completed: {0} UTC" -f $endFormatted) -ForegroundColor Gray

# Calculate elapsed time
$elapsed = $endUtc - $script:metrics.StartTime
$totalHours = [math]::Floor($elapsed.TotalHours)
$remainder = $elapsed - [TimeSpan]::FromHours($totalHours)
$elapsedFormatted = "{0}:{1:00}:{2:00}.{3:000}" -f $totalHours, $remainder.Minutes, $remainder.Seconds, $remainder.Milliseconds
Write-LogHost ("  Total Elapsed:    {0} (hours:minutes:seconds.milliseconds)" -f $elapsedFormatted) -ForegroundColor Gray

# Endpoint Results Summary
Write-LogHost ""
Write-LogHost "Endpoint Results:" -ForegroundColor White
foreach ($key in $endpointResults.Keys | Sort-Object) {
    $rowCount = if ($endpointResults[$key]) { $endpointResults[$key].Count } else { 0 }
    $status = if ($rowCount -gt 0) { "✓" } else { "○" }
    $color = if ($rowCount -gt 0) { "Green" } else { "Gray" }
    Write-LogHost ("  $status {0,-25} : {1,3} rows" -f $key, $rowCount) -ForegroundColor $color
}

# Collect and report all endpoints with no data
$endpointsWithNoData = @()
foreach ($key in $endpointResults.Keys | Sort-Object) {
    $rowCount = if ($endpointResults[$key]) { $endpointResults[$key].Count } else { 0 }
    if ($rowCount -eq 0) {
        $endpointsWithNoData += $key
    }
}

# Display informational notes about endpoints with no data
if ($endpointsWithNoData.Count -gt 0) {
    Write-LogHost ""
    Write-LogHost "Endpoints with No Data ($($endpointsWithNoData.Count)):" -ForegroundColor Yellow
    
    foreach ($endpointName in $endpointsWithNoData) {
        switch ($endpointName) {
            'CopilotUsage' {
                Write-LogHost "  • Copilot Usage: No Copilot usage detected during $Period period" -ForegroundColor Gray
            }
            'MACCopilotLicensing' {
                Write-LogHost "  • Copilot Licensing: No Copilot licenses assigned to users" -ForegroundColor Gray
            }
            'MACLicenseSummary' {
                Write-LogHost "  • License Summary: No Copilot/M365 SKUs found in tenant" -ForegroundColor Gray
            }
            'EntraUsers' {
                Write-LogHost "  • Entra Users: No user accounts found (check permissions)" -ForegroundColor Gray
            }
            'M365AppUserDetail' {
                Write-LogHost "  • M365 Apps: No Microsoft 365 app usage during $Period period" -ForegroundColor Gray
            }
            'TeamsUserActivity' {
                Write-LogHost "  • Teams Activity: No Teams usage during $Period period" -ForegroundColor Gray
            }
            'EmailActivity' {
                Write-LogHost "  • Email Activity: No email/Outlook usage during $Period period" -ForegroundColor Gray
            }
            'OneDriveActivity' {
                Write-LogHost "  • OneDrive Activity: No OneDrive usage during $Period period" -ForegroundColor Gray
            }
            'SharePointActivity' {
                Write-LogHost "  • SharePoint Activity: No SharePoint usage during $Period period" -ForegroundColor Gray
            }
            default {
                Write-LogHost "  • $endpointName`: No data found for $Period period" -ForegroundColor Gray
            }
        }
    }
    
    Write-LogHost ""
    Write-LogHost "  Note: Endpoints with no data were not exported (no CSV file or Excel tab created)." -ForegroundColor Gray
}

# Output Summary
Write-LogHost ""
Write-LogHost "Output Summary:" -ForegroundColor White

# Excel Workbook Output
if ($ExportWorkbook -and (Test-Path $excelFilePath)) {
    Write-LogHost ("  Excel Workbook:") -ForegroundColor Gray
    Write-LogHost ("    {0}" -f $excelFilePath) -ForegroundColor Cyan
    $fileInfo = Get-Item $excelFilePath
    Write-LogHost ("    Size: {0:N0} KB" -f ($fileInfo.Length / 1KB)) -ForegroundColor Gray
    Write-LogHost ("    Worksheets: {0}" -f $exportedSheets.Count) -ForegroundColor Gray
    Write-LogHost ("    Total Rows: {0:N0}" -f $totalRowsExported) -ForegroundColor Gray
    if ($AppendWorkbook) {
        Write-LogHost ("    Mode: Append") -ForegroundColor Gray
    }
}
# CSV Combined Output
elseif ($CombineOutput) {
    $combinedFullPath = Join-Path $OutputPath $combinedFileName
    Write-LogHost ("  Combined Output File:") -ForegroundColor Gray
    Write-LogHost ("    {0}" -f $combinedFullPath) -ForegroundColor Cyan
    if (Test-Path $combinedFullPath) {
        $fileInfo = Get-Item $combinedFullPath
        Write-LogHost ("    Size: {0:N0} KB ({1:N0} rows)" -f ($fileInfo.Length / 1KB), ($combinedData.Count)) -ForegroundColor Gray
    }
}
# CSV Individual Files
else {
    Write-LogHost ("  Individual Files ({0} total):" -f $filesSaved.Count) -ForegroundColor Gray
    if ($filesSaved.Count -gt 0) {
        $totalSize = ($filesSaved | ForEach-Object { (Get-Item $_).Length } | Measure-Object -Sum).Sum
        Write-LogHost ("  Total Size: {0:N0} KB" -f ($totalSize / 1KB)) -ForegroundColor Gray
        Write-LogHost ""
        Write-LogHost "  Files:" -ForegroundColor Gray
        foreach ($file in $filesSaved) {
            $fileSize = (Get-Item $file).Length
            Write-LogHost ("    {0}" -f $file) -ForegroundColor Cyan
            Write-LogHost ("      Size: {0:N0} KB" -f ($fileSize / 1KB)) -ForegroundColor Gray
        }
    }
}

Write-LogHost ""
Write-LogHost "  Log File:" -ForegroundColor White
Write-LogHost ("    {0}" -f $LogFile) -ForegroundColor Cyan
if (Test-Path $LogFile) {
    $logSize = (Get-Item $LogFile).Length
    Write-LogHost ("    Size: {0:N0} KB" -f ($logSize / 1KB)) -ForegroundColor Gray
}

Write-LogHost ""
Write-LogHost "=====================================" -ForegroundColor Cyan
Write-LogHost ""

# Disconnect from Graph
Disconnect-MgGraph | Out-Null
Write-LogHost "Disconnected from Microsoft Graph" -ForegroundColor Gray
Write-LogHost ""

# Exit successfully
exit 0


