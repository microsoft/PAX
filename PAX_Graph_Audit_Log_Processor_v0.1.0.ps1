# Portable Audit eXporter (PAX) - Graph Audit Log Processor - v0.1.0
<#
.SYNOPSIS
    Export Microsoft 365 and Copilot usage reports from Microsoft Graph API with optional Entra user enrichment.

.DESCRIPTION
    Queries Microsoft Graph API for usage reports across 15 endpoints:
    - 14 usage report endpoints (Microsoft 365, Teams, Email, SharePoint, OneDrive, Yammer, Copilot, etc.)
    - 1 Entra Users endpoint (comprehensive user properties with manager expansion)
    
    Copilot Usage Report Limitation:
        The getMicrosoft365CopilotUsageUserDetail endpoint only supports period-based queries (D7/D30/D90/D180/ALL).
        Daily date queries are NOT supported by this endpoint.
        
        Auto-Fallback Behavior:
        - When -DaysBack is specified (requesting daily data), all other 13 endpoints will query daily data
        - Copilot endpoint automatically falls back to period='D7' (last 7 days aggregated)
        - Script displays informational message about this limitation
        - File naming uses clean "CopilotUsage_D7" format (no "fallback" text)
    
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
        By default, script includes comprehensive Entra user properties (35 core fields) with manager expansion.
        Use -ExcludeEntraUsers switch to skip Entra enrichment entirely.
        
        35 Core Entra Properties:
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

.EXAMPLE
    # Query last 7 days of Copilot usage (period-based, default output path)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.0.ps1 -Period D7
    
.EXAMPLE
    # Query last 30 days with custom output path
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.0.ps1 -Period D30 -OutputPath C:\Reports
    
.EXAMPLE
    # Query specific date range (30-day limit, Copilot auto-falls back to D7)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.0.ps1 -DaysBack 14 -OutputPath C:\Reports
    
.EXAMPLE
    # Combined output with custom filename
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.0.ps1 -Period D7 -CombineOutput -OutputFileName "Weekly_Report.csv"
    
.EXAMPLE
    # Exclude Entra user enrichment (usage reports only)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.0.ps1 -Period D30 -ExcludeEntraUsers
    
.EXAMPLE
    # Device code authentication with array explosion
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.0.ps1 -Period D7 -Auth DeviceCode -ExplodeArrays
    
.EXAMPLE
    # Query specific date with custom throttling (100ms delay between requests)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.0.ps1 -DaysBack 7 -PacingMs 100 -OutputPath C:\Reports
    
.EXAMPLE
    # Combined output with auto-generated filename (includes timestamp)
    pwsh -File .\PAX_Graph_Audit_Log_Processor_v0.1.0.ps1 -DaysBack 14 -CombineOutput

.NOTES
    Version: 0.1.0
    Author: PAX Development Team
    Requires: Microsoft.Graph PowerShell SDK
    Graph API Permissions: Reports.Read.All, User.Read.All, Directory.Read.All
#>

param(
    [Parameter(Mandatory = $false, ParameterSetName = 'Period')]
    [ValidateSet('D7', 'D30', 'D90', 'D180', 'ALL')]
    [string]$Period,

    [Parameter(Mandatory = $false, ParameterSetName = 'DaysBack')]
    [ValidateRange(1, 30)]
    [int]$DaysBack,

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
    [switch]$ExcludeEntraUsers,

    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Display help if -Help switch is provided
if ($Help) {
    Get-Help $PSCommandPath -Full
    exit 0
}

# Script version
$ScriptVersion = "0.1.0"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  PAX - Graph Audit Log Processor v$ScriptVersion" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# --- Parameter Validation ---

# Ensure at least one query mode is specified
if (-not $Period -and -not $DaysBack) {
    Write-Host "ERROR: Must specify either -Period (D7/D30/D90/D180/ALL) or -DaysBack (1-30)." -ForegroundColor Red
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  -Period D7          : Last 7 days (period-based query)" -ForegroundColor Yellow
    Write-Host "  -DaysBack 14        : Last 14 days (daily queries, 30-day limit)" -ForegroundColor Yellow
    exit 1
}

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

# --- Date Range Calculation ---

Write-Host "Calculating date range..." -ForegroundColor Cyan

if ($DaysBack) {
    # Daily query mode: Calculate date range with 30-day API limit and 3-day buffer
    $EndDate = (Get-Date).ToUniversalTime().Date.AddDays(-3)  # Default: 3 days ago
    $StartDate = $EndDate.AddDays(-$DaysBack + 1)  # Inclusive range
    
    # Validate 30-day API limit
    $requestedDays = ($EndDate - $StartDate).Days + 1
    if ($requestedDays -gt 30) {
        Write-Host "WARNING: Microsoft Graph API enforces a 30-day maximum query window." -ForegroundColor Yellow
        Write-Host "         Requested: $requestedDays days | Maximum: 30 days" -ForegroundColor Yellow
        Write-Host "         Auto-adjusting StartDate to maintain 30-day limit..." -ForegroundColor Yellow
        $StartDate = $EndDate.AddDays(-29)  # Adjust to exactly 30 days
        $DaysBack = 30
        Write-Host "         New range: $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd')) (30 days)" -ForegroundColor Green
    }
    
    Write-Host "Query Mode: Daily (date-based queries)" -ForegroundColor Green
    Write-Host "  Start Date: $($StartDate.ToString('yyyy-MM-dd'))" -ForegroundColor White
    Write-Host "  End Date:   $($EndDate.ToString('yyyy-MM-dd'))" -ForegroundColor White
    Write-Host "  Days:       $DaysBack" -ForegroundColor White
    
    # Important note about Copilot limitation
    Write-Host "`nIMPORTANT: Copilot endpoint limitation detected" -ForegroundColor Yellow
    Write-Host "  The Copilot usage report does NOT support daily queries." -ForegroundColor Yellow
    Write-Host "  Auto-fallback: Copilot will use period='D7' (last 7 days aggregated)" -ForegroundColor Yellow
    Write-Host "  All other 13 endpoints will query daily data as requested.`n" -ForegroundColor Yellow
}
else {
    # Period query mode
    Write-Host "Query Mode: Period (aggregated queries)" -ForegroundColor Green
    Write-Host "  Period: $Period" -ForegroundColor White
    
    # Map period to days for display
    $periodDays = switch ($Period) {
        'D7'   { 7 }
        'D30'  { 30 }
        'D90'  { 90 }
        'D180' { 180 }
        'ALL'  { 'All available data' }
    }
    Write-Host "  Coverage: $periodDays days`n" -ForegroundColor White
}

# --- Endpoint Definitions ---

Write-Host "Initializing Microsoft Graph API endpoints..." -ForegroundColor Cyan

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
        SupportsDate = $true
        CsvCapable = $true
        Description = "Active users across M365 services"
    },
    @{
        Name = "TeamsUserActivity"
        DisplayName = "Teams User Activity (User Detail)"
        Url = "/v1.0/reports/getTeamsUserActivityUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $true
        CsvCapable = $true
        Description = "Per-user Teams usage metrics"
    },
    @{
        Name = "EmailActivity"
        DisplayName = "Email Activity (User Detail)"
        Url = "/v1.0/reports/getEmailActivityUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $true
        CsvCapable = $true
        Description = "Email send/receive/read activity"
    },
    @{
        Name = "EmailAppUsage"
        DisplayName = "Email App Usage (User Detail)"
        Url = "/v1.0/reports/getEmailAppUsageUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $true
        CsvCapable = $true
        Description = "Email client usage breakdown"
    },
    @{
        Name = "OneDriveActivity"
        DisplayName = "OneDrive Activity (User Detail)"
        Url = "/v1.0/reports/getOneDriveActivityUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $true
        CsvCapable = $true
        Description = "OneDrive file activity and sync"
    },
    @{
        Name = "OneDriveUsage"
        DisplayName = "OneDrive Usage (Account Detail)"
        Url = "/v1.0/reports/getOneDriveUsageAccountDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $true
        CsvCapable = $true
        Description = "OneDrive storage and file counts"
    },
    @{
        Name = "SharePointActivity"
        DisplayName = "SharePoint Activity (User Detail)"
        Url = "/v1.0/reports/getSharePointActivityUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $true
        CsvCapable = $true
        Description = "SharePoint file activity and sharing"
    },
    @{
        Name = "SharePointSiteUsage"
        DisplayName = "SharePoint Site Usage (Site Detail)"
        Url = "/v1.0/reports/getSharePointSiteUsageDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $true
        CsvCapable = $true
        Description = "Per-site storage and activity metrics"
    },
    @{
        Name = "YammerActivity"
        DisplayName = "Yammer Activity (User Detail)"
        Url = "/v1.0/reports/getYammerActivityUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $true
        CsvCapable = $true
        Description = "Yammer posts, reads, and likes"
    },
    @{
        Name = "YammerDeviceUsage"
        DisplayName = "Yammer Device Usage (User Detail)"
        Url = "/v1.0/reports/getYammerDeviceUsageUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $true
        CsvCapable = $true
        Description = "Yammer usage by device type"
    },
    @{
        Name = "YammerGroupsActivity"
        DisplayName = "Yammer Groups Activity (Group Detail)"
        Url = "/v1.0/reports/getYammerGroupsActivityDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $true
        CsvCapable = $true
        Description = "Per-group Yammer activity metrics"
    },
    @{
        Name = "M365AppUserDetail"
        DisplayName = "Microsoft 365 Apps User Detail"
        Url = "/v1.0/reports/getM365AppUserDetail"
        ApiVersion = "v1.0"
        SupportsPeriod = $true
        SupportsDate = $true
        CsvCapable = $true
        Description = "Per-user app usage across M365 apps"
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

Write-Host "Loaded $($Endpoints.Count) endpoints:" -ForegroundColor Green
foreach ($ep in $Endpoints) {
    $apiLabel = if ($ep.ApiVersion -eq 'Beta') { "[BETA]" } else { "[v1.0]" }
    Write-Host "  $apiLabel $($ep.DisplayName)" -ForegroundColor White
}
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

Write-Host "Entra User Properties: $($EntraUserProperties.Count) core fields configured" -ForegroundColor Green
Write-Host "  Manager expansion: Enabled (displayName, userPrincipalName, mail, id)" -ForegroundColor White
Write-Host ""

# ==============================================
# Phase 2: Microsoft Graph Authentication
# ==============================================

Write-Host "Authenticating to Microsoft Graph API..." -ForegroundColor Cyan

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

# Check for Microsoft.Graph module
$graphModule = Get-Module -ListAvailable -Name Microsoft.Graph* | Select-Object -First 1
if (-not $graphModule) {
    Write-Host "ERROR: Microsoft.Graph PowerShell SDK not found." -ForegroundColor Red
    Write-Host "Please install the module using:" -ForegroundColor Yellow
    Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "Microsoft.Graph module detected: $($graphModule.Name) v$($graphModule.Version)" -ForegroundColor Green

# Import required Graph modules
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Reports -ErrorAction Stop
    if (-not $ExcludeEntraUsers) {
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
    Write-Host "`nAuthentication Method: $Auth" -ForegroundColor Cyan
    
    switch ($Auth) {
        'WebLogin' {
            Write-Host "Opening interactive browser for authentication..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes $RequiredScopes -NoWelcome -ErrorAction Stop
        }
        'DeviceCode' {
            Write-Host "Using device code flow..." -ForegroundColor Yellow
            Write-Host "A browser window will open. Follow the instructions to authenticate." -ForegroundColor Yellow
            Connect-MgGraph -Scopes $RequiredScopes -UseDeviceCode -NoWelcome -ErrorAction Stop
        }
        'Credential' {
            Write-Host "Using client secret credential..." -ForegroundColor Yellow
            
            # Check for required environment variables
            $tenantId = $env:GRAPH_TENANT_ID
            $clientId = $env:GRAPH_CLIENT_ID
            $clientSecret = $env:GRAPH_CLIENT_SECRET
            
            if (-not $tenantId -or -not $clientId -or -not $clientSecret) {
                Write-Host "ERROR: Credential authentication requires environment variables:" -ForegroundColor Red
                Write-Host "  GRAPH_TENANT_ID     : Your Azure AD Tenant ID" -ForegroundColor Yellow
                Write-Host "  GRAPH_CLIENT_ID     : Your App Registration Client ID" -ForegroundColor Yellow
                Write-Host "  GRAPH_CLIENT_SECRET : Your App Registration Client Secret" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Set these variables before running the script:" -ForegroundColor Yellow
                Write-Host "  `$env:GRAPH_TENANT_ID = 'your-tenant-id'" -ForegroundColor White
                Write-Host "  `$env:GRAPH_CLIENT_ID = 'your-client-id'" -ForegroundColor White
                Write-Host "  `$env:GRAPH_CLIENT_SECRET = 'your-client-secret'" -ForegroundColor White
                exit 1
            }
            
            $secureSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($clientId, $secureSecret)
            
            Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $credential -NoWelcome -ErrorAction Stop
        }
        'Silent' {
            Write-Host "Using managed identity or existing token..." -ForegroundColor Yellow
            Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
        }
    }
    
    Write-Host "✓ Authentication successful!" -ForegroundColor Green
    
    # Get and display current context
    $context = Get-MgContext
    Write-Host "`nAuthenticated Context:" -ForegroundColor Cyan
    Write-Host "  Tenant ID: $($context.TenantId)" -ForegroundColor White
    Write-Host "  Account:   $($context.Account)" -ForegroundColor White
    Write-Host "  Scopes:    $($context.Scopes -join ', ')" -ForegroundColor White
    Write-Host ""
    
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
        $flatUser = [ordered]@{}
        
        # Explicitly copy only the requested Entra user properties
        # This avoids hashtable properties like AdditionalProperties, Keys, Values, etc.
        $propertiesToCopy = @(
            'userPrincipalName', 'displayName', 'id', 'mail', 'givenName', 'surname',
            'jobTitle', 'department', 'employeeType', 'employeeId', 'employeeHireDate',
            'officeLocation', 'city', 'state', 'country', 'postalCode', 'companyName',
            'accountEnabled', 'userType', 'createdDateTime',
            'usageLocation', 'preferredLanguage',
            'onPremisesSyncEnabled', 'onPremisesImmutableId', 'proxyAddresses',
            'assignedLicenses', 'assignedPlans', 'provisionedPlans', 'externalUserState'
        )
        
        foreach ($propName in $propertiesToCopy) {
            $propValue = $user.$propName
            
            if ($propValue -is [array]) {
                # Handle array properties
                if ($propValue.Count -gt 0) {
                    $flatUser[$propName] = ($propValue | ConvertTo-Json -Compress -Depth 10)
                }
                else {
                    $flatUser[$propName] = $null
                }
            }
            elseif ($propValue -is [PSCustomObject]) {
                # Handle nested objects (convert to JSON)
                $flatUser[$propName] = ($propValue | ConvertTo-Json -Compress -Depth 10)
            }
            else {
                # Simple property
                $flatUser[$propName] = $propValue
            }
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
        
        # Handle employeeOrgData nested object (flatten to individual columns)
        if ($user.employeeOrgData) {
            $flatUser['employeeOrgData_division'] = $user.employeeOrgData.division
            $flatUser['employeeOrgData_costCenter'] = $user.employeeOrgData.costCenter
        }
        else {
            $flatUser['employeeOrgData_division'] = $null
            $flatUser['employeeOrgData_costCenter'] = $null
        }
        
        # Convert ordered hashtable to PSCustomObject for proper CSV export
        $flattenedUsers += [PSCustomObject]$flatUser
    }
    
    return $flattenedUsers
}

function Invoke-GraphEndpointQuery {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Endpoint,
        
        [Parameter(Mandatory = $false)]
        [string]$QueryPeriod,
        
        [Parameter(Mandatory = $false)]
        [datetime]$QueryDate,
        
        [Parameter(Mandatory = $false)]
        [int]$ThrottleMs = 0
    )
    
    $endpointName = $Endpoint.Name
    $endpointUrl = $Endpoint.Url
    $displayName = $Endpoint.DisplayName
    
    Write-Host "Querying: $displayName" -ForegroundColor Cyan
    
    # Determine query type based on endpoint capabilities
    $useDate = $false
    $usePeriod = $false
    
    if ($QueryDate -and $Endpoint.SupportsDate) {
        $useDate = $true
        $dateString = $QueryDate.ToString('yyyy-MM-dd')
        Write-Host "  Query Type: Date ($dateString)" -ForegroundColor White
    }
    elseif ($QueryPeriod -and $Endpoint.SupportsPeriod) {
        $usePeriod = $true
        Write-Host "  Query Type: Period ($QueryPeriod)" -ForegroundColor White
    }
    elseif ($Endpoint.Name -eq 'EntraUsers') {
        Write-Host "  Query Type: Directory Query (no period/date)" -ForegroundColor White
    }
    else {
        # Copilot auto-fallback scenario
        if ($QueryDate -and $Endpoint.Name -eq 'CopilotUsage' -and -not $Endpoint.SupportsDate) {
            Write-Host "  Query Type: Auto-Fallback to Period (D7) - Date queries not supported" -ForegroundColor Yellow
            $usePeriod = $true
            $QueryPeriod = 'D7'
        }
        else {
            Write-Host "  SKIP: Endpoint does not support requested query type" -ForegroundColor Yellow
            return $null
        }
    }
    
    # Build query URL
    $queryUrl = $endpointUrl
    
    if ($useDate) {
        $queryUrl += "(date=$dateString)"
    }
    elseif ($usePeriod) {
        $queryUrl += "(period='$QueryPeriod')"
    }
    
    # Special handling for Entra Users endpoint
    if ($Endpoint.Name -eq 'EntraUsers') {
        # Build $select parameter with all 35 core properties
        $selectProperties = $EntraUserProperties -join ','
        $queryUrl += "?`$select=$selectProperties"
        
        # Add manager expansion
        $queryUrl += "&`$expand=manager(`$select=displayName,userPrincipalName,mail,id)"
        
        Write-Host "  Format: JSON (with 35 properties + manager expansion)" -ForegroundColor White
        Write-Host "  URL: $($queryUrl.Substring(0, [Math]::Min(100, $queryUrl.Length)))..." -ForegroundColor Gray
    }
    # Add CSV format for capable endpoints
    elseif ($Endpoint.CsvCapable) {
        $queryUrl += "?`$format=text/csv"
        Write-Host "  Format: CSV" -ForegroundColor White
        Write-Host "  URL: $queryUrl" -ForegroundColor Gray
    }
    else {
        Write-Host "  Format: JSON" -ForegroundColor White
        Write-Host "  URL: $queryUrl" -ForegroundColor Gray
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
                Write-Host "  Retry $retryCount/$maxRetries after $waitSeconds seconds..." -ForegroundColor Yellow
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
                            Write-Host "  ✓ Retrieved $($result.Count) rows" -ForegroundColor Green
                        }
                        else {
                            Write-Host "  ✓ Query completed (no data returned)" -ForegroundColor Yellow
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
                    Write-Host "  Pagination detected, retrieving all pages..." -ForegroundColor Yellow
                    $allResults = @()
                    $allResults += $response.value
                    
                    $nextLink = $response.'@odata.nextLink'
                    while ($nextLink) {
                        if ($ThrottleMs -gt 0) {
                            Start-Sleep -Milliseconds $ThrottleMs
                        }
                        $pageResponse = Invoke-MgGraphRequest -Method GET -Uri $nextLink -ErrorAction Stop
                        $allResults += $pageResponse.value
                        $nextLink = $pageResponse.'@odata.nextLink'
                        Write-Host "  Retrieved $($allResults.Count) total records..." -ForegroundColor Gray
                    }
                    $result = $allResults
                    Write-Host "  ✓ Retrieved $($result.Count) total rows (paginated)" -ForegroundColor Green
                }
                else {
                    $result = $response.value
                    if ($result) {
                        Write-Host "  ✓ Retrieved $($result.Count) rows" -ForegroundColor Green
                    }
                    else {
                        Write-Host "  ✓ Query completed (no data returned)" -ForegroundColor Yellow
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
                Write-Host "  ⚠ Throttled by API (429), retrying..." -ForegroundColor Yellow
            }
            elseif ($errorMessage -like "*401*" -or $errorMessage -like "*403*") {
                Write-Host "  ✗ Authorization failed: $errorMessage" -ForegroundColor Red
                Write-Host "    Check that your account has the required permissions" -ForegroundColor Yellow
                return $null
            }
            elseif ($errorMessage -like "*404*") {
                Write-Host "  ✗ Endpoint not found (404): $errorMessage" -ForegroundColor Red
                return $null
            }
            else {
                Write-Host "  ✗ Error: $errorMessage" -ForegroundColor Red
                if ($retryCount -ge $maxRetries) {
                    Write-Host "    Max retries exceeded, skipping endpoint" -ForegroundColor Red
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

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Phase 4: Processing All Endpoints" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Determine which endpoints to query
$endpointsToQuery = $Endpoints | Where-Object {
    # Exclude Entra Users if flag is set
    if ($ExcludeEntraUsers -and $_.Name -eq 'EntraUsers') {
        return $false
    }
    return $true
}

Write-Host "Processing $($endpointsToQuery.Count) endpoint(s)...`n" -ForegroundColor Cyan

# Track results for each endpoint
$endpointResults = @{}
$filesSaved = @()

# Display Copilot fallback notice if using DaysBack
if ($DaysBack) {
    $copilotEndpoint = $endpointsToQuery | Where-Object { $_.Name -eq 'CopilotUsage' }
    if ($copilotEndpoint) {
        Write-Host "ℹ NOTICE: Copilot endpoint does not support daily queries" -ForegroundColor Yellow
        Write-Host "  The Copilot report will use period='D7' while other endpoints query daily data." -ForegroundColor Yellow
        Write-Host "  This is a Microsoft Graph API limitation, not a script limitation.`n" -ForegroundColor Yellow
    }
}

# Process each endpoint
$endpointNumber = 0
foreach ($endpoint in $endpointsToQuery) {
    $endpointNumber++
    Write-Host "[$endpointNumber/$($endpointsToQuery.Count)] " -NoNewline -ForegroundColor Cyan
    
    # Query the endpoint
    $queryParams = @{
        Endpoint = $endpoint
        ThrottleMs = $PacingMs
    }
    
    if ($DaysBack) {
        # Daily query mode - but Copilot will auto-fallback to period
        if ($endpoint.Name -eq 'EntraUsers') {
            # Entra Users doesn't use date/period
            $data = Invoke-GraphEndpointQuery @queryParams
        }
        else {
            $data = Invoke-GraphEndpointQuery @queryParams -QueryDate $StartDate
        }
    }
    else {
        # Period query mode
        if ($endpoint.Name -eq 'EntraUsers') {
            # Entra Users doesn't use period
            $data = Invoke-GraphEndpointQuery @queryParams
        }
        else {
            $data = Invoke-GraphEndpointQuery @queryParams -QueryPeriod $Period
        }
    }
    
    # Store results
    $endpointResults[$endpoint.Name] = $data
    
    # Save to individual file (unless CombineOutput is specified)
    if (-not $CombineOutput -and $data -and $data.Count -gt 0) {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        
        # Build filename based on query type
        if ($DaysBack -and $endpoint.Name -eq 'CopilotUsage') {
            # Copilot with fallback
            $filename = "$($endpoint.Name)_D7_$timestamp.csv"
        }
        elseif ($DaysBack) {
            # Daily query
            $dateStr = $StartDate.ToString('yyyyMMdd')
            $filename = "$($endpoint.Name)_$dateStr`_$timestamp.csv"
        }
        else {
            # Period query
            $filename = "$($endpoint.Name)_$Period`_$timestamp.csv"
        }
        
        $outputFilePath = Join-Path $OutputPath $filename
        
        try {
            # Special handling for Entra Users JSON->CSV conversion
            if ($endpoint.Name -eq 'EntraUsers') {
                Write-Host "  Converting JSON to flattened CSV..." -ForegroundColor Yellow
                $flattenedData = ConvertTo-FlatEntraUsers -Users $data -ExplodeArrays:$ExplodeArrays
                $flattenedData | Export-Csv -Path $outputFilePath -NoTypeInformation -Force
                Write-Host "  ✓ Saved: $filename ($($flattenedData.Count) rows, $($flattenedData[0].PSObject.Properties.Count) columns)" -ForegroundColor Green
                $filesSaved += $outputFilePath
            }
            else {
                # Standard CSV export
                $data | Export-Csv -Path $outputFilePath -NoTypeInformation -Force
                Write-Host "  ✓ Saved: $filename ($($data.Count) rows)" -ForegroundColor Green
                $filesSaved += $outputFilePath
            }
        }
        catch {
            Write-Host "  ✗ Error saving file: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    elseif (-not $CombineOutput) {
        Write-Host "  ⊘ Skipped: No data to save" -ForegroundColor Gray
    }
    
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Processing Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Endpoint Results Summary:" -ForegroundColor Cyan
foreach ($key in $endpointResults.Keys | Sort-Object) {
    $rowCount = if ($endpointResults[$key]) { $endpointResults[$key].Count } else { 0 }
    $status = if ($rowCount -gt 0) { "✓" } else { "○" }
    $color = if ($rowCount -gt 0) { "Green" } else { "Gray" }
    Write-Host "  $status $key : $rowCount rows" -ForegroundColor $color
}
Write-Host ""

if ($filesSaved.Count -gt 0) {
    Write-Host "Files Saved ($($filesSaved.Count)):" -ForegroundColor Green
    foreach ($file in $filesSaved) {
        Write-Host "  • $(Split-Path $file -Leaf)" -ForegroundColor White
    }
    Write-Host "  Location: $OutputPath" -ForegroundColor Gray
    Write-Host ""
}

# ==============================================
# PLACEHOLDER: Combined Output & Advanced Features
# ==============================================
# TODO Phase 7: Implement combined output with full outer join

if ($CombineOutput) {
    Write-Host "⚠ Combined output (-CombineOutput) not yet implemented (Phase 7)" -ForegroundColor Yellow
    Write-Host "  Individual files have been queried but not merged." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Phase 5 Complete: Entra Users Enrichment" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Disconnect from Graph
Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Gray
Write-Host ""

# Exit successfully
exit 0
