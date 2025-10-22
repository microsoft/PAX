# Portable Audit eXporter (PAX) - Graph Audit Log Processor - v0.1.1
<#
.SYNOPSIS
    Export Microsoft 365 usage analytics from Microsoft Graph API.
    By default, queries only the M365 App User Detail endpoint for focused usage reporting.

.DESCRIPTION
    The Portable Audit eXporter (PAX) - Graph Audit Log Processor retrieves M365 usage data
    from Microsoft Graph API and exports to CSV files.
    
    Default Behavior:
        Queries ONLY the Microsoft 365 App User Detail endpoint (most comprehensive single endpoint).
        Use switches to include additional endpoints:
            -IncludeCopilot   : Add Copilot Usage endpoint
            -IncludeCurated   : Add all 13 curated usage endpoints (includes Copilot)
            -IncludeEntraUsers: Add Entra Users directory data with 35 properties
    
    Total Available Endpoints: 15
        • M365 App User Detail (default, always included)
        • Copilot Usage (via -IncludeCopilot or -IncludeCurated)
        • 12 other usage endpoints (via -IncludeCurated): Teams, Email, OneDrive, SharePoint, Yammer, etc.
        • Entra Users (via -IncludeEntraUsers)
    
    Query Mode:
        All endpoints use period-based queries (D7, D30, D90, D180, ALL).
        Period queries are aggregated reports covering the specified time window.
        Default period: D7 (last 7 days)
    
    Output Management:
        -OutputPath <string>     : Directory for output files (default: C:\Temp\MS_Graph)
        -OutputFileName <string> : Custom filename for combined output (optional, only with -CombineOutput)
            • If specified: Used exactly as provided (no timestamp added)
            • If .csv extension missing: Automatically appended
            • If omitted: Auto-generated name with timestamp
        
        File Naming:
            • Individual files: Auto-generated with timestamps (e.g., "CopilotUsage_D7_20251017_143022.csv")
            • Combined output with custom name: Exact name used (e.g., "MyReport.csv")
            • Combined output auto-name: Includes timestamp (e.g., "CombinedUsage_20251017_143022.csv")
            • No timestamped subfolders created
            • No overwrite protection (existing files will be overwritten)
    
    Entra User Enrichment:
        Entra Users endpoint is NOT queried by default (keeps query focused and fast).
        Use -IncludeEntraUsers switch to add comprehensive user properties (35 core fields) with manager expansion.
        
        35 Core Entra Properties (when -IncludeEntraUsers is used):
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

.PARAMETER IncludeCopilot
    Include the Copilot Usage endpoint in addition to the default M365 App User Detail endpoint.
    
.PARAMETER IncludeCurated
    Include all curated usage endpoints (Copilot, Teams, Email, OneDrive, SharePoint, Yammer, etc.).
    This includes 13 additional endpoints beyond the default M365 App User Detail endpoint.
    Note: Copilot endpoint is included automatically when using this switch.

.PARAMETER IncludeEntraUsers
    Include Entra Users endpoint to enrich usage data with user properties.
    Adds 35 core user properties including department, manager, licenses, and location.

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

.EXAMPLE
    # Default: Query M365 App User Detail only (last 7 days, period-based)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1
    
.EXAMPLE
    # Specify period (last 30 days)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30
    
.EXAMPLE
    # Include Copilot Usage endpoint
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeCopilot
    
.EXAMPLE
    # Include all curated endpoints (Copilot + 12 others)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeCurated
    
.EXAMPLE
    # Include Entra user enrichment with default endpoint
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeEntraUsers
    
.EXAMPLE
    # Everything: All curated endpoints + Entra Users
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeCurated -IncludeEntraUsers
    
.EXAMPLE
    # Combined output with custom filename
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -CombineOutput -OutputFileName "Weekly_Report.csv"
    
.EXAMPLE
    # Custom output path with curated endpoints
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -IncludeCurated -OutputPath C:\Reports
    
.EXAMPLE
    # Device code authentication with array explosion and Entra enrichment
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -Auth DeviceCode -IncludeEntraUsers -ExplodeArrays
    
.EXAMPLE
    # Custom throttling (100ms delay between requests)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D7 -PacingMs 100 -OutputPath C:\Reports
    
.EXAMPLE
    # Combined output with auto-generated filename (includes timestamp)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.1.ps1 -Period D30 -CombineOutput

.NOTES
    Version: 0.1.1
    Author: PAX Development Team
    Requires: Microsoft.Graph PowerShell SDK (auto-installs if missing)
    Graph API Permissions: Reports.Read.All, User.Read.All, Directory.Read.All
    
    Prerequisites:
    - PowerShell 5.1 or PowerShell 7+
    - Microsoft.Graph PowerShell SDK (automatically installed if missing)
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
    [switch]$IncludeCopilot,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeCurated,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeEntraUsers,

    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Display help if -Help switch is provided
if ($Help) {
    Get-Help $PSCommandPath -Full
    exit 0
}

# Script version
$ScriptVersion = "0.1.1"

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

# Helper function to obfuscate email addresses for security
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
Write-Log ("  CombineOutput = $CombineOutput")
Write-Log ("  IncludeCopilot = $($IncludeCopilot.IsPresent)")
Write-Log ("  IncludeCurated = $($IncludeCurated.IsPresent)")
Write-Log ("  IncludeEntraUsers = $($IncludeEntraUsers.IsPresent)")
Write-Log ("  ExplodeArrays = $($ExplodeArrays.IsPresent)")
Write-Log ("  ExpandManager = " + $(if ($IncludeEntraUsers) { "Yes (manager expansion enabled)" } else { "N/A (Entra Users not included)" }))
Write-Log ("  Auth = $Auth")
Write-Log ("  PacingMs = $PacingMs")
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
# Phase 2: Microsoft Graph Authentication
# ==============================================

Write-LogHost "Authenticating to Microsoft Graph API..." -ForegroundColor Cyan
Write-Log "Required Permissions: Reports.Read.All, User.Read.All, Directory.Read.All"

# Required Graph API scopes
$RequiredScopes = @(
    'Reports.Read.All',      # Read all usage reports
    'User.Read.All',         # Read all user profiles
    'Directory.Read.All'     # Read directory data (for manager expansion)
)

Write-Host "Required Permissions:" -ForegroundColor Yellow
foreach ($scope in $RequiredScopes) {
    Write-Host "  • $scope" -ForegroundColor White
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

# Import required Graph modules
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Reports -ErrorAction Stop
    if ($IncludeEntraUsers) {
        Import-Module Microsoft.Graph.Users -ErrorAction Stop
    }
    Write-Host "Graph modules imported successfully" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to import Microsoft.Graph modules: $($_.Exception.Message)" -ForegroundColor Red
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
        Write-Host "Script may fail when accessing protected resources." -ForegroundColor Yellow
        Write-Host "Consider re-authenticating with full permissions." -ForegroundColor Yellow
        Write-Host ""
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
# Phase 3: Single Endpoint Query Function
# ==============================================

# Phase 5: Helper function to flatten Entra Users JSON
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
        # userType should be "Member" or "Guest", not null
        # Rooms typically have userType = null or specific patterns in mailNickname
        $userTypeValue = $user.userType
        
        # Skip if userType is null/empty (likely a room or resource)
        if ([string]::IsNullOrWhiteSpace($userTypeValue)) {
            continue
        }
        
        # Skip disabled accounts that look like service accounts or rooms
        # (optional - can be removed if you want disabled user accounts)
        if (-not $user.accountEnabled) {
            # Check if display name suggests it's a room/resource
            $displayName = $user.displayName
            if ($displayName -match '(?i)(room|conference|resource|equipment|shared)') {
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
        Write-LogHost "  Format: CSV" -ForegroundColor White
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
# Phase 4: Multi-Endpoint Processing Loop
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
Write-Host ("  Include Copilot:    {0}" -f $IncludeCopilot.IsPresent) -ForegroundColor White
Write-Host ("  Include Curated:    {0}" -f $IncludeCurated.IsPresent) -ForegroundColor White
Write-Host ("  Include Entra:      {0}" -f $IncludeEntraUsers.IsPresent) -ForegroundColor White

# Performance Settings
Write-Host ""
Write-Host "Performance Settings:" -ForegroundColor White
Write-Host ("  Authentication:     {0}" -f $Auth) -ForegroundColor White
Write-Host ("  Throttle Delay:     {0} ms" -f $PacingMs) -ForegroundColor White

# Endpoints to query
Write-Host ""
Write-Host "Endpoints to Query:" -ForegroundColor White
$endpointsToQueryPreview = @($Endpoints | Where-Object {
    $name = $_.Name
    
    # M365AppUserDetail is ALWAYS included (default endpoint)
    if ($name -eq 'M365AppUserDetail') { return $true }
    
    # Copilot: Include if -IncludeCopilot OR -IncludeCurated
    if ($name -eq 'CopilotUsage') {
        return ($IncludeCopilot -or $IncludeCurated)
    }
    
    # Entra Users: Include only if -IncludeEntraUsers
    if ($name -eq 'EntraUsers') {
        return $IncludeEntraUsers
    }
    
    # All other endpoints: Include only if -IncludeCurated
    return $IncludeCurated
})
Write-Host ("  Total Endpoints:    {0}" -f $endpointsToQueryPreview.Count) -ForegroundColor White
Write-Host "  Endpoint List:" -ForegroundColor Gray
foreach ($ep in $endpointsToQueryPreview) {
    Write-Host ("    • {0}" -f $ep.Name) -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Phase 4: Processing All Endpoints" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Data Source: Microsoft Graph API" -ForegroundColor Cyan
Write-Host ""

# Determine which endpoints to query
$endpointsToQuery = @($Endpoints | Where-Object {
    $name = $_.Name
    
    # M365AppUserDetail is ALWAYS included (default endpoint)
    if ($name -eq 'M365AppUserDetail') { return $true }
    
    # Copilot: Include if -IncludeCopilot OR -IncludeCurated
    if ($name -eq 'CopilotUsage') {
        return ($IncludeCopilot -or $IncludeCurated)
    }
    
    # Entra Users: Include only if -IncludeEntraUsers
    if ($name -eq 'EntraUsers') {
        return $IncludeEntraUsers
    }
    
    # All other endpoints: Include only if -IncludeCurated
    return $IncludeCurated
})

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
    elseif (-not $endpoint.SupportsPeriod) {
        # Snapshot endpoints (e.g., M365Activations): No period/date parameters
        $data = Invoke-GraphEndpointQuery @queryParams
    }
    else {
        # Period query mode: Use period parameter
        $data = Invoke-GraphEndpointQuery @queryParams -QueryPeriod $Period
    }
    
    # Check for obfuscation on first usage endpoint with data (skip Entra Users)
    if (-not $obfuscationChecked -and $endpoint.Name -ne 'EntraUsers' -and $data -and $data.Count -gt 0) {
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
    # Reorder columns for CSV endpoints (move Report Period after Report Refresh Date)
    elseif ($data -and $data.Count -gt 0 -and $endpoint.CsvCapable) {
        $data = Move-ReportPeriodColumn -Data $data
    }
    
    # Store results
    $endpointResults[$endpoint.Name] = $data
    
    # Check if Copilot endpoint returned no data - provide informational guidance
    if ($endpoint.Name -eq 'CopilotUsage' -and (-not $data -or $data.Count -eq 0)) {
        Write-LogHost ""
        Write-LogHost "  ℹ️  COPILOT USAGE: No data returned" -ForegroundColor Yellow
        Write-LogHost "     This is normal if:" -ForegroundColor Gray
        Write-LogHost "       • Copilot licenses not assigned to users in this tenant" -ForegroundColor Gray
        Write-LogHost "       • No Copilot usage during the selected time period" -ForegroundColor Gray
        Write-LogHost "       • Tenant does not have Microsoft 365 Copilot enabled" -ForegroundColor Gray
        Write-LogHost ""
        Write-LogHost "     Note: No Copilot CSV file will be exported (no data to save)." -ForegroundColor Gray
        Write-LogHost ""
    }
    
    # Save to individual file (unless CombineOutput is specified)
    if (-not $CombineOutput -and $data -and $data.Count -gt 0) {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        
        # Build filename based on period
        $filename = "$($endpoint.Name)_$Period`_$timestamp.csv"
        
        $outputFilePath = Join-Path $OutputPath $filename
        
        try {
            # Export to CSV (Entra Users already flattened above)
            $data | Export-Csv -Path $outputFilePath -NoTypeInformation -Force
            
            if ($endpoint.Name -eq 'EntraUsers' -and $data.Count -gt 0) {
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
    elseif (-not $CombineOutput) {
        Write-Host "  ⊘ Skipped: No data to save" -ForegroundColor Gray
    }
    
    Write-Host ""
}

# ==============================================
# Phase 7: Combined Output (Full Outer Join)
# ==============================================

if ($CombineOutput) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Phase 7: Creating Combined Output" -ForegroundColor Cyan
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

# Check if Copilot returned no data and add informational note (only if Copilot was queried)
if ($IncludeCopilot -or $IncludeCurated) {
    $copilotData = $endpointResults['CopilotUsage']
    if (-not $copilotData -or $copilotData.Count -eq 0) {
        Write-LogHost ""
        Write-LogHost "  Note: Copilot Usage returned no data. This is normal if:" -ForegroundColor Yellow
        Write-LogHost "    • No Copilot licenses assigned in this tenant" -ForegroundColor Gray
        Write-LogHost "    • No Copilot usage during the selected time period" -ForegroundColor Gray
        Write-LogHost "    • Microsoft 365 Copilot not enabled for this tenant" -ForegroundColor Gray
        Write-LogHost ""
        Write-LogHost "    (No Copilot CSV file was exported - no data to save)" -ForegroundColor Gray
    }
}

# Output Summary
Write-LogHost ""
Write-LogHost "Output Summary:" -ForegroundColor White
if ($CombineOutput) {
    $combinedFullPath = Join-Path $OutputPath $combinedFileName
    Write-LogHost ("  Combined Output File:") -ForegroundColor Gray
    Write-LogHost ("    {0}" -f $combinedFullPath) -ForegroundColor Cyan
    if (Test-Path $combinedFullPath) {
        $fileInfo = Get-Item $combinedFullPath
        Write-LogHost ("    Size: {0:N0} KB ({1:N0} rows)" -f ($fileInfo.Length / 1KB), ($combinedData.Count)) -ForegroundColor Gray
    }
}
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

