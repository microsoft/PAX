#Requires -Modules ExchangeOnlineManagement

param(
    [Parameter(Mandatory = $false)]
    [string]$StartDate,
    [Parameter(Mandatory = $false)]
    [string]$EndDate,
    [Parameter(Mandatory = $false)]
    [string[]]$ActivityTypes = @(
        "CreatePromptBook", "CreatePlugin", "ScheduledPromptCreated", "DeletePlugin", "DeletePromptBook", "ScheduledPromptDeleted",
        "DisableCopilotPlugin", "DisablePromptBook", "EnablePlugin", "EnablePromptBook", "ScheduledPromptExecute", "CopilotInteraction",
        "UpdatePlugin", "UpdatePromptBook", "UpdateTenantSettings", "MeetingDetail", "AINotesUpdate", "LiveNotesUpdate",
        "MeetingParticipantDetail", "MessageSent", "MessageRead", "TeamsSessionStarted", "FileAccessed", "FileAccessedExtended",
        "FileDownloaded", "FileModified", "SearchQueryPerformed", "FilePreviewed", "FileUploaded", "PageViewed",
        "MailItemsAccessed", "MailboxLogin"
    ),
    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "$([System.IO.Path]::GetTempPath())PAX_Export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    [Parameter(Mandatory = $false)]
    [ValidateSet('WebLogin', 'DeviceCode', 'Credential', 'Silent')]
    [string]$Auth = 'WebLogin',
    [Parameter(Mandatory = $false)]
    [ValidateRange(0.016667, 24)]  # 1 minute to 24 hours (1min = 0.016667h)
    [double]$BlockHours = 0.5,
    [Parameter(Mandatory = $false)]
    [int]$ResultSize = 25000,
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 10000)]
    [int]$PacingMs = 0,
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxConcurrent = 3,
    [Parameter(Mandatory = $false)]
    [switch]$NoExplodeArrays,
    [Parameter(Mandatory = $false)]
    [switch]$CopilotInteractionOnly,
    [Parameter(Mandatory = $false)]
    [switch]$DevTest,
    [Parameter(Mandatory = $false)]
    [string]$LogFile,
    [Parameter(Mandatory = $false)]
    [switch]$Help,
    [Parameter(Mandatory = $false)]
    [switch]$InHelper
)

function Show-Help {
    @"
Microsoft 365 Copilot & AI Audit Log Extractor
-----------------------------------------------
This script exports Microsoft 365 Copilot, AI, and user activity records from audit logs to CSV with comprehensive logging.

USAGE EXAMPLES:
---------------
- Basic export with recommended activities (tiers 1-3: Copilot core, Teams, Files):
  .\CopilotAuditExport.ps1 -StartDate "2025-09-01" -EndDate "2025-09-02"

- Focus on Copilot interactions only:
  .\CopilotAuditExport.ps1 -StartDate "2025-09-01" -EndDate "2025-09-02" -CopilotInteractionOnly

- Custom output location with automatic log file:
  .\CopilotAuditExport.ps1 -StartDate "2025-09-01" -EndDate "2025-09-02" -OutputFile "C:\Reports\CopilotUsage.csv"

- Specific activities (Copilot interactions and file access):
  .\CopilotAuditExport.ps1 -StartDate "2025-09-01" -EndDate "2025-09-02" -ActivityTypes "CopilotInteraction","FileAccessed","FileModified"

- Large dataset with smaller time windows and throttle control:
  .\CopilotAuditExport.ps1 -StartDate "2025-09-01" -EndDate "2025-09-10" -BlockHours 0.25 -PacingMs 1000

- Show help:
  .\CopilotAuditExport.ps1 -Help
  .\CopilotAuditExport.ps1 /Help



PARAMETERS:
-----------
-StartDate        (Required)  Start date for search (yyyy-MM-dd format). Inclusive - data from this date is included.
-EndDate          (Required)  End date for search (yyyy-MM-dd format). Exclusive - data up to but not including this date.
-ActivityTypes    (Optional)  Array of activity types to search. Default: 32 curated activities across Copilot, Teams, Files, and Exchange tiers.
-CopilotInteractionOnly (Optional) Focus exclusively on CopilotInteraction activities. Overrides ActivityTypes when specified.
-DevTest          (Optional)  Development test mode - searches for Operation='Create' within CopilotInteraction activity type.
-OutputFile       (Optional)  Path for CSV output. Default: PAX_Export_<timestamp>.csv in system temp folder.
-LogFile          (Optional)  Path for transcript log. Default: auto-generated .log file in same directory as CSV.
-Auth             (Optional)  Authentication: WebLogin (default, recommended), DeviceCode, Credential, or Silent.
                               • WebLogin: Opens native Microsoft sign-in window; best for admin accounts with MFA/CA
                               • DeviceCode: Shows code to enter at microsoft.com/devicelogin; useful if windows are blocked
                               • Credential: Username/password prompt; may fail with MFA/CA policies; not recommended
                               • Silent: Reuses existing cached session if available; fails otherwise
                               Note: Script validates account permissions before starting the full export.
-BlockHours       (Optional)  Time window per query: 0.016667-24 hours. Default: 0.5 (30min, enterprise-optimized). Auto-subdivides progressively when hitting limits.
-ResultSize       (Optional)  Records per API call (1-50000). Default: 25000. Values >5000 use session-based pagination for compatibility.
-PacingMs         (Optional)  Delay between API calls in milliseconds (0-10000). Default: 0. Use 500-2000 to reduce throttling.
-MaxConcurrent    (Optional)  Maximum concurrent queries (1-10). Default: 3. Higher values = faster but more throttling risk.
-NoExplodeArrays  (Optional)  Preserve raw JSON in AuditData column instead of flattening into separate columns. When enabled, exports simplified CSV with essential fields plus raw AuditData JSON. When disabled (default), JSON is flattened into individual columns for detailed analytics.
-Help or /Help    (Optional)  Display this help message and exit.

DEFAULT ACTIVITY TYPES (CURATED TIERS 1-3):
--------------------------------------------
TIER 1 - Microsoft 365 Copilot Core (15 activities):
- CopilotInteraction: User interacted with Copilot
- CreatePlugin, EnablePlugin, DisableCopilotPlugin, DeletePlugin, UpdatePlugin: Plugin management
- CreatePromptBook, EnablePromptBook, DisablePromptBook, DeletePromptBook, UpdatePromptBook: Prompt book management
- ScheduledPromptCreated, ScheduledPromptDeleted, ScheduledPromptExecute: Scheduled prompts
- UpdateTenantSettings: Copilot tenant configuration changes

TIER 2 - Microsoft Teams Context (7 activities):
- MessageSent: Messages posted in Teams
- MessageRead: Messages read in Teams  
- MeetingDetail: Meeting details and participation
- MeetingParticipantDetail: Meeting participant information
- AINotesUpdate: AI-generated notes in chat
- LiveNotesUpdate: AI notes in live meetings
- TeamsSessionStarted: Teams sign-in events

TIER 3 - SharePoint/OneDrive Files Context (7 activities):
- FileAccessed: File access events
- FileAccessedExtended: Extended file access details
- FilePreviewed, FileDownloaded, FileUploaded, FileModified: File operations
- PageViewed: SharePoint page views
- SearchQueryPerformed: Search queries performed

OPTIONAL TIERS (not in default selection):
- TIER 4 - Exchange (MailItemsAccessed, Send, MailboxLogin)
- TIER 5 - Governance (Sensitivity labels, sharing, secure links)

For the full, up-to-date list of all activity types, visit:
https://learn.microsoft.com/en-us/purview/audit-log-activities

WHAT DOES THE SCRIPT DO?
------------------------
- Connects to Microsoft 365 audit log system with your chosen authentication method
- Validates account permissions by testing audit log access before starting full export
- Uses intelligent activity batching to group high/medium/low-volume operations for optimal performance
- Features persistent adaptive sizing: starts with 30-minute blocks, learns optimal sizes when hitting limits
- Progressive auto-subdivision sequence: 30min→15min→8min→4min→2min→1min prevents expensive throwaway queries
- Learned block sizes persist across activity types and days within the same export session
- Implements comprehensive auto-subdivision when hitting 5000-record limits to ensure complete data collection
- Supports controlled parallel processing for faster execution while respecting API throttling
- Downloads matching audit records and processes them into structured CSV format (with optional row explosion)
- Creates automatic transcript logs (.log files) alongside CSV output for troubleshooting
- Uses exponential backoff and optional pacing to handle Microsoft 365 throttling gracefully

AUTHENTICATION & PERMISSIONS
----------------------------
- Requires Exchange Online management permissions and audit log access
- Script tests permissions with sample Search-UnifiedAuditLog call before proceeding
- If wrong account or insufficient permissions detected, authentication can be restarted manually
- Authentication sessions are properly managed and cleaned up on script completion

IMPORTANT: QUERY TIMING BEHAVIOR
-------------------------------
- Individual queries may appear to "hang" for 30-120 seconds - this is NORMAL Microsoft 365 behavior
- Audit services process complex queries server-side, which takes time for large datasets
- Progress shows "[25%] Query 5/20 - ActivityName" then waits while Microsoft processes the request
- Be patient during apparent hangs - the service is working. True timeouts are rare (10+ minutes)
- Use PacingMs (500-2000) and smaller BlockHours (0.25-0.5 hours = 15-30 minutes) in busy tenants to reduce throttling risk

PROGRESS & MARKERS
----------------
- Prints numeric progress prefixes like "[42.5%] Query a/b" and post-phase status.
- Emits structured markers for tools: PA:TOTALS, PA:PHASE (queries|post), and PA:POST category updates.
- Messages remain human-readable in a console.

WHAT'S IN THE OUTPUT FILE?
--------------------------
- Each row is a Copilot/AI or user-facing activity
- Columns include: Record ID, Date/Time, User, Action Type, and technical details (like app, plugin, resource, etc.)
- Some columns may be empty if that detail wasn't present for a given activity

WHY USE THIS SCRIPT?
--------------------
- See how your selected activities are being used in your organization
- Create easy-to-read reports for management or compliance
- Spot trends, answer questions, or investigate specific activities

"@
}

# Utility function to get UTC timestamp for phase logging
function Get-UtcTimestamp {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")
}

# Show help if -help, /help, no parameters, or missing required parameters
if ($Help -or $args -contains "-help" -or $args -contains "/help" -or !$StartDate -or !$EndDate) {
    Show-Help
    exit 0
}

# Debug output for helper process
if ($InHelper) {
    Write-Host "=== HELPER PROCESS STARTED ===" -ForegroundColor Magenta
    Write-Host "Script running in helper mode with parameters:" -ForegroundColor Magenta
    Write-Host "StartDate: $StartDate" -ForegroundColor Magenta
    Write-Host "EndDate: $EndDate" -ForegroundColor Magenta
    Write-Host "Auth: $Auth" -ForegroundColor Magenta
    Write-Host "ActivityTypes (raw): $ActivityTypes" -ForegroundColor Magenta
    Write-Host "ActivityTypes type: $($ActivityTypes.GetType().FullName)" -ForegroundColor Magenta
    
    # Clean up quoted parameters that may have been double-quoted
    if ($StartDate -and $StartDate.StartsWith("'") -and $StartDate.EndsWith("'")) {
        $StartDate = $StartDate.Substring(1, $StartDate.Length - 2)
        Write-Host "Cleaned StartDate: $StartDate" -ForegroundColor Magenta
    }
    if ($EndDate -and $EndDate.StartsWith("'") -and $EndDate.EndsWith("'")) {
        $EndDate = $EndDate.Substring(1, $EndDate.Length - 2)
        Write-Host "Cleaned EndDate: $EndDate" -ForegroundColor Magenta
    }
    if ($OutputFile -and $OutputFile.StartsWith("'") -and $OutputFile.EndsWith("'")) {
        $OutputFile = $OutputFile.Substring(1, $OutputFile.Length - 2)
        Write-Host "Cleaned OutputFile: $OutputFile" -ForegroundColor Magenta
    }
    if ($Auth -and $Auth.StartsWith("'") -and $Auth.EndsWith("'")) {
        $Auth = $Auth.Substring(1, $Auth.Length - 2)
        Write-Host "Cleaned Auth: $Auth" -ForegroundColor Magenta
    }
    
    # Convert ActivityTypes from comma-separated string back to array if needed
    if ($ActivityTypes -and $ActivityTypes -is [string] -and $ActivityTypes.Contains(',')) {
        $ActivityTypes = $ActivityTypes.Split(',') | ForEach-Object { $_.Trim() }
        Write-Host "Converted ActivityTypes to array, count: $($ActivityTypes.Count)" -ForegroundColor Magenta
    }
    elseif ($ActivityTypes -and $ActivityTypes.Count -eq 1 -and $ActivityTypes[0].Contains(',')) {
        # Handle case where we get a single-element array containing comma-separated values
        $ActivityTypes = $ActivityTypes[0].Split(',') | ForEach-Object { $_.Trim() }
        Write-Host "Converted single-element array ActivityTypes to proper array, count: $($ActivityTypes.Count)" -ForegroundColor Magenta
    }
    Write-Host "Final ActivityTypes count: $($ActivityTypes.Count)" -ForegroundColor Magenta
    Write-Host "First few ActivityTypes: $($ActivityTypes[0..2] -join ', ')" -ForegroundColor Magenta
}

function Start-VisibleReexecForAuth {
    param(
        [string]$Reason,
        [string]$OverrideAuth
    )
    try {
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwshCmd) { $ps = $pwshCmd.Source }
        else {
            $psCmd = Get-Command powershell -ErrorAction SilentlyContinue
            if ($psCmd) { $ps = $psCmd.Source }
        }
        if (-not $ps) { throw "Cannot locate PowerShell executable to launch authentication." }

        # Use $PSCommandPath as primary source (reliable when invoked via -Command)
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
        if (-not $scriptPath) { throw "Cannot determine script path for re-exec" }
        # Build argument string for -File, carefully quoting values
        $parts = @()
        # Smart quoting - only add quotes if not already present
        if ($StartDate) { 
            if ($StartDate.StartsWith("'") -and $StartDate.EndsWith("'")) {
                $parts += "-StartDate " + $StartDate
            }
            else {
                $parts += "-StartDate '" + ($StartDate -replace "'", "''") + "'"
            }
        }
        if ($EndDate) { 
            if ($EndDate.StartsWith("'") -and $EndDate.EndsWith("'")) {
                $parts += "-EndDate " + $EndDate
            }
            else {
                $parts += "-EndDate '" + ($EndDate -replace "'", "''") + "'"
            }
        }
        if ($ActivityTypes -and $ActivityTypes.Count -gt 0) {
            # For command line, join activities with comma and let the receiving script parse
            $escapedTypes = @()
            foreach ($act in $ActivityTypes) {
                $escapedTypes += ($act -replace "'", "''")
            }
            $activityString = ($escapedTypes -join ',')
            $parts += "-ActivityTypes '" + $activityString + "'"
        }
        if ($OutputFile) { 
            if ($OutputFile.StartsWith("'") -and $OutputFile.EndsWith("'")) {
                $parts += "-OutputFile " + $OutputFile
            }
            else {
                $parts += "-OutputFile '" + ($OutputFile -replace "'", "''") + "'"
            }
        }
        if ($OverrideAuth) {
            $parts += "-Auth " + $OverrideAuth
        }
        elseif ($Auth) {
            $parts += "-Auth " + $Auth
        }
        if ($BlockHours) { $parts += "-BlockHours $BlockHours" }
        if ($ResultSize) { $parts += "-ResultSize $ResultSize" }
        if ($null -ne $PacingMs) { $parts += "-PacingMs $PacingMs" }
        if ($MaxConcurrent) { $parts += "-MaxConcurrent $MaxConcurrent" }
        if ($NoExplodeArrays) { $parts += "-NoExplodeArrays" }
        $parts += "-InHelper"

        $argStr = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" " + ($parts -join ' ')
        Write-Host "Launching visible host for authentication and export ($Reason)..." -ForegroundColor Yellow
        Write-Host ("Spawn: '" + $ps + "' " + $argStr) -ForegroundColor DarkGray
        Write-Host ("Args parts: " + ($parts -join ' ')) -ForegroundColor DarkGray
        
        # Launch with visible window using shell execute to provide proper window handle for WAM
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $ps
        $psi.Arguments = $argStr
        $psi.UseShellExecute = $true  # Use shell execute to create visible window
        $psi.CreateNoWindow = $false  # Make visible for authentication
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
        
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        $p.Start() | Out-Null
        $p.WaitForExit()
        
        Write-Host ("Visible host exited with code: " + $p.ExitCode) -ForegroundColor Yellow
        exit $p.ExitCode
    }
    catch {
        Write-Host ("Visible re-launch failed: " + $_.Exception.Message) -ForegroundColor Red
        throw
    }
}

# Detect if we're already running in a visible, interactive console host
function Test-VisibleHost {
    try {
        if ($Host.Name -match 'ConsoleHost') { return $true }
        if ($env:WT_SESSION) { return $true } # Windows Terminal
        if ($env:TERM_PROGRAM -eq 'vscode') { return $true } # VS Code integrated terminal
        try { $null = $Host.UI.RawUI.WindowTitle; return $true } catch {}
    }
    catch {}
    return $false
}

if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installing ExchangeOnlineManagement module for CurrentUser..." -ForegroundColor Yellow
    try {
        # Ensure NuGet provider is available for CurrentUser scope
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -Confirm:$false | Out-Null
        }
        # Trust PSGallery for this session
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Host "ExchangeOnlineManagement installed." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install ExchangeOnlineManagement for CurrentUser: $($_.Exception.Message)"
        Write-Host "You may preinstall the module manually with:" -ForegroundColor Yellow
        Write-Host "  Install-Module ExchangeOnlineManagement -Scope CurrentUser" -ForegroundColor Yellow
        exit 1
    }
}

# Force clean module state to avoid parameter validation caching issues
Write-Host "Refreshing ExchangeOnlineManagement module to ensure clean parameter validation..." -ForegroundColor Yellow
Remove-Module ExchangeOnlineManagement -Force -ErrorAction SilentlyContinue
Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop
Write-Host "Module refreshed successfully." -ForegroundColor Green

function Connect-ToComplianceCenter {
    try {
        Write-Host "Connecting to Microsoft 365 Security & Compliance Center..." -ForegroundColor Cyan

        function Show-EXOParamInfo {
            try {
                $exo = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue
                $mod = Get-Module ExchangeOnlineManagement -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
                $ver = if ($mod) { $mod.Version.ToString() } else { '<unknown>' }
                $params = if ($exo) { ($exo.Parameters.Keys | Sort-Object) -join ', ' } else { '<missing>' }
                Write-Host ("EXO module version: " + $ver) -ForegroundColor DarkCyan
                Write-Host ("Connect-ExchangeOnline params: " + $params) -ForegroundColor DarkCyan
                $ipps = Get-Command Connect-IPPSSession -ErrorAction SilentlyContinue
                if ($ipps) { Write-Host ("Connect-IPPSSession params: " + (($ipps.Parameters.Keys | Sort-Object) -join ', ')) -ForegroundColor DarkCyan }
            }
            catch {}
        }

        switch ($Auth.ToLower()) {
            'weblogin' {
                Show-EXOParamInfo
                # Smart authentication with automatic fallback based on module version
                $connected = $false
                $exoCmd = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue
                
                if ($exoCmd) {
                    # Check if DisableWAM parameter exists in this version of Exchange module
                    $hasDisableWAM = $exoCmd.Parameters.ContainsKey('DisableWAM')
                    
                    if ($hasDisableWAM) {
                        try {
                            Write-Host "Attempting Connect-ExchangeOnline authentication with DisableWAM..." -ForegroundColor Yellow
                            Connect-ExchangeOnline -ShowBanner:$false -DisableWAM -ErrorAction Stop | Out-Null
                            $connected = $true
                            Write-Host "Successfully connected with Connect-ExchangeOnline!" -ForegroundColor Green
                        }
                        catch {
                            Write-Host ("Connect-ExchangeOnline with DisableWAM failed: " + $_.Exception.Message) -ForegroundColor DarkYellow
                            throw "DisableWAM authentication failed"
                        }
                    }
                    else {
                        # DisableWAM parameter not available, use UseWebLogin fallback
                        try {
                            Write-Host "DisableWAM not available in this Exchange module version, using UseWebLogin fallback..." -ForegroundColor Yellow
                            Connect-ExchangeOnline -ShowBanner:$false -UseWebLogin -ErrorAction Stop | Out-Null
                            $connected = $true
                            Write-Host "Successfully connected with UseWebLogin fallback!" -ForegroundColor Green
                        }
                        catch {
                            Write-Host ("UseWebLogin fallback failed: " + $_.Exception.Message) -ForegroundColor DarkYellow
                            throw "UseWebLogin authentication failed"
                        }
                    }
                }
                
                if (-not $connected) {
                    throw "Failed to authenticate via WebLogin"
                }
            }
            'devicecode' {
                # Device code flow (copy/paste code into browser)
                Connect-ExchangeOnline -ShowBanner:$false -Device
            }
            'credential' {
                # Windows secure credential prompt
                $cred = Get-Credential -Message "Enter admin credentials for Exchange Online"
                Connect-ExchangeOnline -ShowBanner:$false -Credential $cred
            }
            default {
                # Try silent, then deterministic browser-based fallback
                $silentOk = $true
                try {
                    $exoCmd = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue
                    $connectionArgs = @{ ShowBanner = $false }
                    if ($exoCmd -and $exoCmd.Parameters.ContainsKey('DisableWAM')) { $connectionArgs['DisableWAM'] = $true }
                    & Connect-ExchangeOnline @connectionArgs -ErrorAction Stop
                }
                catch {
                    $silentOk = $false
                    Write-Host "Silent sign-in failed; switching to browser-based sign-in..." -ForegroundColor Yellow
                }
                if (-not $silentOk) {
                    Write-Host "Silent sign-in failed. Attempting interactive browser sign-in in current session..." -ForegroundColor Yellow
                    try {
                        $exoCmd = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue
                        $hasDisableWAM = $exoCmd -and $exoCmd.Parameters.ContainsKey('DisableWAM')
                        if ($hasDisableWAM) {
                            Connect-ExchangeOnline -ShowBanner:$false -DisableWAM -ErrorAction Stop | Out-Null
                        }
                        else {
                            Connect-ExchangeOnline -ShowBanner:$false -UseWebLogin -ErrorAction Stop | Out-Null
                        }
                    }
                    catch {
                        Write-Host ("-OpenWebPage failed, retrying with standard authentication: " + $_.Exception.Message) -ForegroundColor DarkYellow
                        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop | Out-Null
                    }
                }
            }
        }
        Write-Host "Connected successfully!" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to connect: $($_.Exception.Message)"
        exit 1
    }
}

function Get-OptimalBlockSize {
    param(
        [string]$ActivityType
    )
    
    # Return learned block size for this activity type
    if ($script:learnedActivityBlockSize.ContainsKey($ActivityType)) {
        return $script:learnedActivityBlockSize[$ActivityType]
    }
    else {
        # New activity type - use global learned size
        return $script:globalLearnedBlockSize
    }
}

function Update-LearnedBlockSize {
    param(
        [double]$NewBlockSize,
        [string]$ActivityType
    )
    
    # Update learned block sizes with smaller (more efficient) size
    if (-not $script:learnedActivityBlockSize.ContainsKey($ActivityType) -or $NewBlockSize -lt $script:learnedActivityBlockSize[$ActivityType]) {
        Write-Host "    Learning: Activity '$ActivityType' now uses $([math]::Round($NewBlockSize * 60, 1))-minute blocks" -ForegroundColor Cyan
        $script:learnedActivityBlockSize[$ActivityType] = $NewBlockSize
            
        # Update global learned size to prevent other activity types from starting too large
        if ($NewBlockSize -lt $script:globalLearnedBlockSize) {
            $script:globalLearnedBlockSize = $NewBlockSize
        }
    }
}

function Get-NextSmallerBlockSize {
    param(
        [double]$CurrentBlockSize
    )
    
    # Find next smaller block size in subdivision sequence
    $nextSize = $null
    foreach ($size in $script:subdivisionSequence) {
        if ($size -lt $CurrentBlockSize) {
            $nextSize = $size
            break
        }
    }
    
    if ($null -eq $nextSize) {
        # Already at smallest size (1 minute)
        return $CurrentBlockSize
    }
    
    return $nextSize
}

function Invoke-SearchUnifiedAuditLogWithRetry {
    param(
        [Parameter(Mandatory = $true)] [datetime]$Start,
        [Parameter(Mandatory = $true)] [datetime]$End,
        [Parameter(Mandatory = $false)] [string]$Operation,
        [Parameter(Mandatory = $true)] [int]$ResultSize,
        [Parameter(Mandatory = $true)] [int]$PacingMs,
        [Parameter(Mandatory = $false)] [int]$MaxRetries = 5,
        [Parameter(Mandatory = $false)] [bool]$AutoSubdivide = $true
    )
    
    # Implement proper session-based pagination for ResultSize > 5000
    if ($ResultSize -gt 5000) {
        Write-Host "  Using session-based pagination for ResultSize $ResultSize (>5000 limit)" -ForegroundColor Cyan
        
        $allResults = @()
        $sessionId = [Guid]::NewGuid().ToString()
        $pageSize = 5000  # Maximum allowed by API
        $totalFetched = 0
        $pageNumber = 1
        
        try {
            while ($totalFetched -lt $ResultSize) {
                $remainingNeeded = $ResultSize - $totalFetched
                $currentPageSize = [Math]::Min($pageSize, $remainingNeeded)
                
                # Retry logic for each page
                $pageAttempt = 0
                $pageResults = $null
                $pageMaxRetries = 3  # Retry each page up to 3 times
                
                while ($pageAttempt -le $pageMaxRetries) {
                    try {
                        # Prepare parameters for current page
                        $params = @{
                            'StartDate'   = $Start
                            'EndDate'     = $End
                            'ResultSize'  = $currentPageSize
                            'SessionId'   = $sessionId
                            'ErrorAction' = 'Stop'
                        }
                        
                        if ($Operation) { $params.Add('Operations', $Operation) }
                        
                        # Set session command based on page number
                        if ($pageNumber -eq 1) {
                            $params.Add('SessionCommand', 'ReturnLargeSet')
                            if ($pageAttempt -eq 0) {
                                Write-Host "    Starting session $sessionId, requesting page $pageNumber ($currentPageSize records)..." -ForegroundColor DarkCyan
                            } else {
                                Write-Host "    Retrying page $pageNumber (attempt $($pageAttempt + 1) of $($pageMaxRetries + 1))" -ForegroundColor Yellow
                            }
                        }
                        else {
                            $params.Add('SessionCommand', 'ReturnNextPreviewPage')
                            if ($pageAttempt -eq 0) {
                                Write-Host "    Fetching page $pageNumber ($currentPageSize records)..." -ForegroundColor DarkCyan
                            } else {
                                Write-Host "    Retrying page $pageNumber (attempt $($pageAttempt + 1) of $($pageMaxRetries + 1))" -ForegroundColor Yellow
                            }
                        }
                        
                        # Add increasing delay for retries
                        $delayMs = $PacingMs + ($pageAttempt * 2000)  # Base pacing + 2s per retry
                        if ($delayMs -gt 0) { Start-Sleep -Milliseconds $delayMs }
                        
                        $pageResults = Search-UnifiedAuditLog @params
                        
                        # Success - break out of retry loop
                        break
                    }
                    catch {
                        $pageAttempt++
                        if ($pageAttempt -le $pageMaxRetries) {
                            Write-Host "    Page $pageNumber attempt $pageAttempt failed: $($_.Exception.Message). Retrying..." -ForegroundColor Yellow
                            # If session might be stale, create new session for retry after first failure
                            if ($pageAttempt -gt 1) {
                                $sessionId = [Guid]::NewGuid().ToString()
                                Write-Host "    Creating new session ID for retry: $sessionId" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "    Page $pageNumber failed after $($pageMaxRetries + 1) attempts: $($_.Exception.Message)" -ForegroundColor Red
                            throw
                        }
                    }
                }
                
                if ($pageResults -and $pageResults.Count -gt 0) {
                    $allResults += $pageResults
                    $totalFetched += $pageResults.Count
                    Write-Host "    Page $pageNumber returned $($pageResults.Count) records (total: $totalFetched)" -ForegroundColor DarkCyan
                    
                    # If we got fewer records than requested, we've reached the end
                    if ($pageResults.Count -lt $currentPageSize) {
                        Write-Host "    Reached end of data (page returned $($pageResults.Count) < $currentPageSize requested)" -ForegroundColor DarkCyan
                        break
                    }
                }
                else {
                    Write-Host "    Page $pageNumber returned no results - ending session" -ForegroundColor DarkCyan
                    break
                }
                
                $pageNumber++
            }
            
            Write-Host "  Session completed: $($allResults.Count) total records fetched" -ForegroundColor Green
            $res = $allResults
            
        }
        catch {
            Write-Host "  Session-based pagination failed: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }
    else {
        # Standard single request for ResultSize <= 5000
        $attempt = 0
        $res = $null
        while ($attempt -le $MaxRetries) {
            try {
                $params = @{
                    'StartDate'   = $Start
                    'EndDate'     = $End
                    'ResultSize'  = $ResultSize
                    'ErrorAction' = 'Stop'
                }
                if ($Operation) { $params.Add('Operations', $Operation) }
                
                $res = Search-UnifiedAuditLog @params
                if ($PacingMs -gt 0) { Start-Sleep -Milliseconds $PacingMs }
                break
            }
            catch {
                $msg = $_.Exception.Message
                $status = $null
                try { $status = $_.Exception.Response.StatusCode.Value__ } catch {}
                
                $isThrottle = ($msg -match '429' -or $msg -match 'Too\s*Many\s*Requests' -or $msg -match 'throttl' -or $msg -match '503' -or $msg -match 'Service\s*Unavailable' -or $status -in 429, 503)
                if (-not $isThrottle -or $attempt -ge $MaxRetries) {
                    Write-Host ("  Request failed: " + $msg) -ForegroundColor DarkYellow
                    throw
                }
                $attempt++
                $base = 0.5
                $delay = [math]::Min(30.0, $base * [math]::Pow(2, $attempt - 1))
                $jitter = (Get-Random -Minimum 0 -Maximum 250) / 1000.0
                $total = $delay + $jitter + ([double]$PacingMs / 1000.0)
                $ms = [int]([math]::Round($total * 1000))
                Write-Host ("  Throttled (attempt $attempt/$MaxRetries). Backing off for ${ms}ms...") -ForegroundColor Yellow
                Start-Sleep -Milliseconds $ms
            }
        }
    }
    
    # Check for result limit and auto-subdivide if needed
    if ($AutoSubdivide -and $res -and $res.Count -eq $ResultSize) {
        $timeSpan = $End - $Start
        if ($timeSpan.TotalMinutes -gt 30) {
            # Aggressive subdivision: Jump to smaller windows immediately for high-volume activities
            if ($timeSpan.TotalHours -ge 12) {
                # For large windows (12+ hours), jump directly to 2-hour chunks
                Write-Host "  Result limit hit ($($res.Count) records). Using aggressive 2-hour subdivision..." -ForegroundColor Yellow
                $chunkResults = @()
                $current = $Start
                while ($current -lt $End) {
                    $chunkEnd = [Math]::Min($current.AddHours(2).Ticks, $End.Ticks)
                    $chunkEnd = [DateTime]::new($chunkEnd)
                    $chunk = Invoke-SearchUnifiedAuditLogWithRetry -Start $current -End $chunkEnd -Operation $Operation -ResultSize $ResultSize -PacingMs $PacingMs -MaxRetries $MaxRetries -AutoSubdivide $AutoSubdivide
                    if ($chunk) { $chunkResults += $chunk }
                    $current = $chunkEnd
                }
                Write-Host "  Aggressive subdivision completed. Total records: $($chunkResults.Count)" -ForegroundColor Green
                return $chunkResults
            }
            else {
                # Standard binary subdivision for smaller windows
                Write-Host "  Result limit hit ($($res.Count) records). Auto-subdividing time window..." -ForegroundColor Yellow
                $midPoint = $Start.AddTicks(($End - $Start).Ticks / 2)
                $firstHalf = Invoke-SearchUnifiedAuditLogWithRetry -Start $Start -End $midPoint -Operation $Operation -ResultSize $ResultSize -PacingMs $PacingMs -MaxRetries $MaxRetries -AutoSubdivide $AutoSubdivide
                $secondHalf = Invoke-SearchUnifiedAuditLogWithRetry -Start $midPoint -End $End -Operation $Operation -ResultSize $ResultSize -PacingMs $PacingMs -MaxRetries $MaxRetries -AutoSubdivide $AutoSubdivide
                $combinedResults = @()
                if ($firstHalf) { $combinedResults += $firstHalf }
                if ($secondHalf) { $combinedResults += $secondHalf }
                Write-Host "  Auto-subdivision completed. Total records: $($combinedResults.Count)" -ForegroundColor Green
                return $combinedResults
            }
        }
        else {
            Write-Host "  WARNING: Result limit hit but time window too small to subdivide. Possible data loss!" -ForegroundColor Red
        }
    }
    
    return $res
}

function ConvertFrom-AuditData {
    param([string]$AuditDataJson)
    try {
        return $AuditDataJson | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Get-NestedProperty {
    param(
        [object]$Object,
        [string]$PropertyPath
    )
    if (-not $Object) { return $null }
    $parts = $PropertyPath -split '\.'
    $current = $Object
    foreach ($part in $parts) {
        if ($current -and $current.PSObject.Properties[$part]) {
            $current = $current.$part
        }
        else {
            return $null
        }
    }
    return $current
}


# Microsoft Learn Common Schema helper functions
function Get-UserType {
    param([string]$UserId, [object]$AuditData)
    # Microsoft Learn UserType enum: 0=Regular, 2=Admin, 4=System, 10=Guest
    if (!$UserId) { return 0 }
    if ($UserId -match "admin|administrator") { return 2 }
    if ($UserId -match "system|service|app") { return 4 }
    if ($UserId -match "guest|#ext#") { return 10 }
    return 0  # Regular user (most common)
}

function Get-UserKey {
    param([string]$UserId)
    # Generate PUID-style alternative user ID (16-digit hex)
    if (!$UserId) { return $null }
    $hash = [System.Text.Encoding]::UTF8.GetBytes($UserId + "puid") | ForEach-Object { $_ } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    return ($hash -band 0xFFFFFFFFFFFFFFFF).ToString("x16").PadLeft(16, '0')
}

function Get-WorkloadFromRecordType {
    param([string]$RecordType)
    # Map RecordType to Office 365 service names per Microsoft Learn
    $workloadMap = @{
        "ExchangeItem"            = "Exchange"
        "SharePointFileOperation" = "SharePoint"
        "OneDrive"                = "OneDrive"
        "MicrosoftTeams"          = "MicrosoftTeams"
        "CopilotInteraction"      = "MicrosoftCopilot"
        "261"                     = "MicrosoftCopilot"  # CopilotInteraction RecordType
    }
    return $workloadMap[$RecordType] -or "Office365"
}

function Get-SyntheticClientIP {
    param([string]$UserId)
    # Generate realistic IP addresses using TEST-NET ranges (RFC 5737)
    if (!$UserId) { return "203.0.113.1" }
    $ipRanges = @("203.0.113", "198.51.100", "192.0.2")
    $hash = [System.Text.Encoding]::UTF8.GetBytes($UserId) | ForEach-Object { $_ } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $baseIndex = $hash % $ipRanges.Count
    $lastOctet = ($hash % 254) + 1
    return "$($ipRanges[$baseIndex]).$lastOctet"
}

function Get-SyntheticObjectId {
    param([string]$Operation, [string]$RecordType, [object]$AuditData)
    # Generate realistic ObjectId based on operation type
    $timestamp = [DateTimeOffset]::Now.ToUnixTimeSeconds().ToString("x8")
    if ($Operation -match "File|Document") {
        return "https://tenant.sharepoint.com/sites/team/Shared Documents/file_$timestamp.docx"
    }
    elseif ($Operation -match "Mail|Message" -and $RecordType -match "Exchange") {
        return "<message_$($timestamp)@tenant.onmicrosoft.com>"
    }
    elseif ($Operation -match "Team|Meeting" -or $RecordType -match "Teams") {
        return "19:meeting_$($timestamp)@thread.v2"
    }
    elseif ($RecordType -match "Copilot|261") {
        return "copilot-conversation-$timestamp"
    }
    return "object-$timestamp"
}

function Get-NestedProperty {
    param([object]$Object, [string]$PropertyPath, [string]$Default = $null)
    if (!$Object -or !$PropertyPath) { return $Default }
    
    $current = $Object
    foreach ($prop in $PropertyPath.Split('.')) {
        if ($current -and $current.PSObject.Properties[$prop]) {
            $current = $current.$prop
        }
        else {
            return $Default
        }
    }
    return $current -or $Default
}

function Convert-ToMetricsRecord {
    param([object]$AuditLogEntry, [switch]$NoExplodeArrays, [switch]$DevTest)
    $auditData = ConvertFrom-AuditData -AuditDataJson $AuditLogEntry.AuditData
    
    # DevTest mode transformations - convert "Create" operations to look like CopilotInteraction
    if ($DevTest -and $AuditLogEntry.Operations -eq "Create") {
        Write-Verbose "DevTest: Transforming Create operation to CopilotInteraction for record $($AuditLogEntry.Identity)"
        
        # Transform the audit log entry with correct values
        $AuditLogEntry.Operations = "CopilotInteraction"
        $AuditLogEntry.RecordType = 261  # Correct RecordType number for Copilot
        
        # Realistic AppHost distribution based on real Purview data analysis (500 records)
        $appHostOptions = @(
            @{Host="Teams"; Weight=35.8},                  # 179/500 = Most popular
            @{Host="Office"; Weight=23.2},                 # 116/500 = Second most popular  
            @{Host="Word"; Weight=11.8},                   # 59/500 = High usage
            @{Host="Unknown"; Weight=9.6},                 # 48/500 = Medium-high usage
            @{Host="Outlook"; Weight=7.4},                 # 37/500 = Medium usage
            @{Host="Excel"; Weight=3.2},                   # 16/500 = Medium usage
            @{Host="Copilot Studio"; Weight=2.8},          # 14/500 = Low usage
            @{Host="PowerPoint"; Weight=2.6},              # 13/500 = Low usage
            @{Host="Designer"; Weight=1.0},                # 5/500 = Low usage
            @{Host="Forms"; Weight=1.0},                   # 5/500 = Low usage
            @{Host="Logic App"; Weight=0.6},               # 3/500 = Very low usage
            @{Host="OneNote"; Weight=0.4},                 # Estimated based on Office family
            @{Host="SharePoint"; Weight=0.2},              # 1/500 = Very low usage
            @{Host="Edge"; Weight=0.2},                    # 1/500 = Very low usage
            @{Host="Power BI"; Weight=0.2},                # 1/500 = Very low usage
            @{Host="Stream"; Weight=0.2},                  # 1/500 = Very low usage
            @{Host="Datawarehousing Core"; Weight=0.2},    # 1/500 = Very low usage
            @{Host="Loop"; Weight=0.2}                     # Estimated based on Office family
        )
        
        # Weighted random selection for realistic distribution
        $totalWeight = ($appHostOptions | Measure-Object -Property Weight -Sum).Sum
        $randomValue = Get-Random -Minimum 1 -Maximum ($totalWeight * 10 + 1)  # Scale for decimal weights
        $currentWeight = 0
        $selectedAppHost = "Teams"  # Default fallback
        
        foreach ($option in $appHostOptions) {
            $currentWeight += ($option.Weight * 10)  # Scale for decimal weights
            if ($randomValue -le $currentWeight) {
                $selectedAppHost = $option.Host
                break
            }
        }
        
        # Create realistic synthetic Copilot AuditData JSON matching real Purview structure
        $baseData = @{
            CreationTime = $auditData.CreationTime
            Id = [System.Guid]::NewGuid().ToString()
            Operation = "CopilotInteraction"
            OrganizationId = if ($auditData.OrganizationId) { $auditData.OrganizationId } else { "b1234567-89ab-cdef-0123-456789abcdef" }
            RecordType = 261
            UserKey = $AuditLogEntry.UserIds
            UserType = 0  # 0 = Regular user (matches real data)
            Version = 1
            Workload = "Copilot"
            ClientIP = if ($auditData.ClientIP) { $auditData.ClientIP } else { "" }  # Often empty in real data
            UserId = $AuditLogEntry.UserIds
            ClientRegion = @("us", "", "eu", "apac") | Get-Random  # Mix of regions and empty values
            CopilotEventData = @{
                AISystemPlugin = @()  # Will be populated based on AppHost patterns
                AccessedResources = @()  # Will be populated based on AppHost patterns
                AppHost = $selectedAppHost
                Contexts = @()  # Will be populated based on AppHost patterns
                MessageIds = @()  # Usually empty in real data
                Messages = @()  # Will be populated based on AppHost patterns
                ModelTransparencyDetails = @()  # Will be populated based on AppHost patterns
                ThreadId = "19:" + [System.Guid]::NewGuid().ToString().Replace("-","").Substring(0,26) + "@thread.v2"
            }
            CopilotLogVersion = "1.0.0.0"
        }
        
        # Generate realistic arrays based on actual data patterns for each AppHost
        switch ($selectedAppHost) {
            "Teams" {
                # Teams: AISystemPlugin 0-1 (avg 1), AccessedResources 0-31 (avg 1.9), Contexts 0-1 (avg 0.1), Messages 2-17 (avg 2.2), ModelTransparencyDetails 0-1 (avg 1)
                $baseData.CopilotEventData.AISystemPlugin = @(@{Id="BingWebSearch"; Name="BuiltIn"})
                $baseData.CopilotEventData.ModelTransparencyDetails = @(@{ModelName="DEEP_LEO"})
                
                # AccessedResources: 0-31, avg 1.9 - generate 0-4 resources with weighted distribution
                $randomValue = Get-Random -Minimum 1 -Maximum 11
                $resourceCount = if ($randomValue -le 5) { 0 } elseif ($randomValue -le 8) { 1 } elseif ($randomValue -le 9) { 2 } elseif ($randomValue -le 10) { 4 } else { 8 }
                for ($i = 0; $i -lt $resourceCount; $i++) {
                    $baseData.CopilotEventData.AccessedResources += @{
                        Action = "Read"
                        PolicyDetails = ""
                        SiteUrl = @(
                            "https://www.youtube.com/watch?v=" + [System.Guid]::NewGuid().ToString().Substring(0,11),
                            "https://docs.microsoft.com/en-us/microsoft-365/copilot/overview",
                            "https://contoso.sharepoint.com/sites/Project/SitePages/Home.aspx",
                            "https://techcommunity.microsoft.com/blog/copilot-updates",
                            "https://www.linkedin.com/pulse/ai-workplace-" + [System.Guid]::NewGuid().ToString().Substring(0,8)
                        ) | Get-Random
                    }
                }
                
                # Messages: 2-17, avg 2.2
                $messageCount = Get-Random -Minimum 2 -Maximum 5  # Most common range
                for ($i = 0; $i -lt $messageCount; $i++) {
                    $baseData.CopilotEventData.Messages += @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = ($i % 2) -eq 0  # Alternate prompt/response
                    }
                }
                
                # Contexts: 0-1, avg 0.1 (rare)
                if ((Get-Random -Minimum 1 -Maximum 11) -eq 1) {
                    $baseData.CopilotEventData.Contexts += @{
                        Id = "https://teams.microsoft.com/l/meeting/" + [System.Guid]::NewGuid().ToString()
                        Type = "meeting"
                    }
                }
            }
            
            "Office" {
                # Office: AISystemPlugin 0-1 (avg 1), AccessedResources 0-38 (avg 2.8), Messages 1-7 (avg 2.1), ModelTransparencyDetails 0-1 (avg 1)
                $baseData.CopilotEventData.AISystemPlugin = @(@{Id="BingWebSearch"; Name="BuiltIn"})
                $baseData.CopilotEventData.ModelTransparencyDetails = @(@{ModelName="DEEP_LEO"})
                
                # AccessedResources: 0-38, avg 2.8
                $randomValue = Get-Random -Minimum 1 -Maximum 11
                $resourceCount = if ($randomValue -le 3) { 0 } elseif ($randomValue -le 6) { 1 } elseif ($randomValue -le 8) { 3 } elseif ($randomValue -le 9) { 5 } else { 10 }
                for ($i = 0; $i -lt $resourceCount; $i++) {
                    $baseData.CopilotEventData.AccessedResources += @{
                        Action = "Read"
                        PolicyDetails = ""
                        SiteUrl = "https://contoso.sharepoint.com/sites/Project" + (Get-Random -Minimum 1 -Maximum 999) + "/documents/file" + $i + ".docx"
                    }
                }
                
                # Messages: 1-7, avg 2.1
                $messageCount = Get-Random -Minimum 1 -Maximum 4
                for ($i = 0; $i -lt $messageCount; $i++) {
                    $baseData.CopilotEventData.Messages += @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = ($i % 2) -eq 0
                    }
                }
            }
            
            "Word" {
                # Word: AccessedResources 0-5 (avg 0.1), Contexts 0-2 (avg 1.2), Messages 1-4 (avg 2.3)
                # Word often has document contexts and no plugins/model details
                
                # Contexts: 0-2, avg 1.2 (usually 1)
                $contextCount = if ((Get-Random -Minimum 1 -Maximum 11) -le 8) { 1 } else { 2 }
                for ($i = 0; $i -lt $contextCount; $i++) {
                    $baseData.CopilotEventData.Contexts += @{
                        Id = "https://contoso.sharepoint.com/sites/Project/_layouts/15/Doc.aspx?sourcedoc=%7B" + [System.Guid]::NewGuid().ToString().ToUpper() + "%7D&file=Document" + ($i + 1) + ".docx"
                        Type = "docx"
                    }
                }
                
                # AccessedResources: 0-5, avg 0.1 (rare)
                if ((Get-Random -Minimum 1 -Maximum 21) -eq 1) {
                    $baseData.CopilotEventData.AccessedResources += @{
                        Action = "Read"
                        PolicyDetails = ""
                        SiteUrl = "https://contoso.sharepoint.com/sites/Project/Document.docx"
                    }
                }
                
                # Messages: 1-4, avg 2.3
                $messageCount = Get-Random -Minimum 2 -Maximum 4
                for ($i = 0; $i -lt $messageCount; $i++) {
                    $baseData.CopilotEventData.Messages += @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = ($i % 2) -eq 0
                    }
                }
            }
            
            "Outlook" {
                # Outlook: AISystemPlugin 0-1 (avg 0.3), AccessedResources 0-35 (avg 4.6), Messages 1-2 (avg 1.9), ModelTransparencyDetails 0-1 (avg 0.3)
                # Only 30% chance of AISystemPlugin and ModelTransparencyDetails
                if ((Get-Random -Minimum 1 -Maximum 11) -le 3) {
                    $baseData.CopilotEventData.AISystemPlugin = @(@{Id="BingWebSearch"; Name="BuiltIn"})
                    $baseData.CopilotEventData.ModelTransparencyDetails = @(@{ModelName="DEEP_LEO"})
                }
                
                # AccessedResources: 0-35, avg 4.6 (higher than most)
                $randomValue = Get-Random -Minimum 1 -Maximum 11
                $resourceCount = if ($randomValue -le 2) { 0 } elseif ($randomValue -le 4) { 3 } elseif ($randomValue -le 7) { 4 } elseif ($randomValue -le 9) { 6 } else { 12 }
                for ($i = 0; $i -lt $resourceCount; $i++) {
                    $siteTypes = @(
                        "https://outlook.office365.com/owa/?ItemID=" + [System.Guid]::NewGuid().ToString() + "&exvsurl=1&viewmodel=ReadMessageItem",
                        "https://ligado.com/press/ligado-networks-announces-" + [System.Guid]::NewGuid().ToString().Substring(0,8),
                        "https://techcommunity.microsoft.com/blog/" + [System.Guid]::NewGuid().ToString().Substring(0,12)
                    )
                    $baseData.CopilotEventData.AccessedResources += @{
                        Action = "Read"
                        PolicyDetails = ""
                        SiteUrl = $siteTypes | Get-Random
                        Type = if ($i -eq 0) { "http://schema.skype.com/HyperLink" } else { $null }
                    }
                }
                
                # Messages: 1-2, avg 1.9
                $messageCount = Get-Random -Minimum 1 -Maximum 3
                for ($i = 0; $i -lt $messageCount; $i++) {
                    $baseData.CopilotEventData.Messages += @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = ($i % 2) -eq 0
                    }
                }
            }
            
            "Excel" {
                # Excel: Contexts 1-1 (avg 1), Messages 1-1 (avg 1)
                $baseData.CopilotEventData.Contexts = @(@{
                    Id = "https://contoso.sharepoint.com/sites/Project/_layouts/15/Doc.aspx?sourcedoc=%7B" + [System.Guid]::NewGuid().ToString().ToUpper() + "%7D&file=Workbook.xlsx"
                    Type = "xlsx"
                })
                
                $baseData.CopilotEventData.Messages = @(@{
                    Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                    isPrompt = $true
                })
            }
            
            "PowerPoint" {
                # PowerPoint: Contexts 0-1 (avg 0.5), Messages 1-2 (avg 1.1)
                # 50% chance of context
                if ((Get-Random -Minimum 1 -Maximum 3) -eq 1) {
                    $baseData.CopilotEventData.Contexts = @(@{
                        Id = "https://contoso.sharepoint.com/sites/Project/_layouts/15/Doc.aspx?sourcedoc=%7B" + [System.Guid]::NewGuid().ToString().ToUpper() + "%7D&file=Presentation.pptx"
                        Type = "pptx"
                    })
                }
                
                $messageCount = Get-Random -Minimum 1 -Maximum 3
                for ($i = 0; $i -lt $messageCount; $i++) {
                    $baseData.CopilotEventData.Messages += @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = ($i % 2) -eq 0
                    }
                }
            }
            
            "Forms" {
                # Forms: AccessedResources 1-1 (avg 1), Messages 2-2 (avg 2)
                $baseData.CopilotEventData.AccessedResources = @(@{
                    Action = "Read"
                    PolicyDetails = ""
                    SiteUrl = "https://forms.office.com/Pages/DesignPageV2.aspx?id=" + [System.Guid]::NewGuid().ToString()
                    Type = "http://schema.skype.com/HyperLink"
                })
                
                $baseData.CopilotEventData.Messages = @(
                    @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = $true
                    },
                    @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = $false
                    }
                )
            }
            
            "Unknown" {
                # Unknown: Contexts 1-1 (avg 1), Messages 1-1 (avg 1)
                $baseData.CopilotEventData.Contexts = @(@{
                    Id = "https://securitycopilot.microsoft.com"
                })
                
                $baseData.CopilotEventData.Messages = @(@{
                    Id = [string](Get-Random -Minimum 20000000 -Maximum 30000000)  # Different ID pattern for Unknown
                    isPrompt = $true
                })
            }
            
            "Copilot Studio" {
                # Copilot Studio: AccessedResources 0-1 (avg 0.1), Messages 1-2 (avg 1.4)
                # 10% chance of AccessedResources
                if ((Get-Random -Minimum 1 -Maximum 11) -eq 1) {
                    $baseData.CopilotEventData.AccessedResources = @(@{
                        Action = "Read"
                        PolicyDetails = ""
                        SiteUrl = "https://copilotstudio.microsoft.com/environments/" + [System.Guid]::NewGuid().ToString()
                    })
                }
                
                $messageCount = Get-Random -Minimum 1 -Maximum 3
                for ($i = 0; $i -lt $messageCount; $i++) {
                    $baseData.CopilotEventData.Messages += @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = ($i % 2) -eq 0
                    }
                }
            }
            
            "Edge" {
                # Edge: AISystemPlugin 1-1 (avg 1), Messages 2-2 (avg 2), ModelTransparencyDetails 1-1 (avg 1)
                $baseData.CopilotEventData.AISystemPlugin = @(@{Id="BingWebSearch"; Name="BuiltIn"})
                $baseData.CopilotEventData.ModelTransparencyDetails = @(@{ModelName="DEEP_LEO"})
                
                $baseData.CopilotEventData.Messages = @(
                    @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = $true
                    },
                    @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = $false
                    }
                )
            }
            
            "Stream" {
                # Stream: AISystemPlugin 1-1 (avg 1), AccessedResources 1-1 (avg 1), Contexts 1-1 (avg 1), Messages 2-2 (avg 2), ModelTransparencyDetails 1-1 (avg 1)
                $baseData.CopilotEventData.AISystemPlugin = @(@{Id="BingWebSearch"; Name="BuiltIn"})
                $baseData.CopilotEventData.ModelTransparencyDetails = @(@{ModelName="DEEP_LEO"})
                
                $baseData.CopilotEventData.AccessedResources = @(@{
                    Action = "Read"
                    PolicyDetails = ""
                    SiteUrl = "https://web.microsoftstream.com/video/" + [System.Guid]::NewGuid().ToString()
                })
                
                $baseData.CopilotEventData.Contexts = @(@{
                    Id = "https://web.microsoftstream.com/video/" + [System.Guid]::NewGuid().ToString()
                    Type = "video"
                })
                
                $baseData.CopilotEventData.Messages = @(
                    @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = $true
                    },
                    @{
                        Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                        isPrompt = $false
                    }
                )
            }
            
            # Add patterns for apps not in sample but mentioned by user
            "OneNote" {
                # Estimated pattern based on Office family
                $baseData.CopilotEventData.Contexts = @(@{
                    Id = "https://contoso-my.sharepoint.com/personal/user_contoso_com/Documents/Notebooks/Notebook" + (Get-Random -Minimum 1 -Maximum 99) + ".one"
                    Type = "one"
                })
                
                $baseData.CopilotEventData.Messages = @(@{
                    Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                    isPrompt = $true
                })
            }
            
            "Loop" {
                # Estimated pattern based on Office family
                $baseData.CopilotEventData.Contexts = @(@{
                    Id = "https://loop.microsoft.com/workspaces/" + [System.Guid]::NewGuid().ToString()
                    Type = "loop"
                })
                
                $baseData.CopilotEventData.Messages = @(@{
                    Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                    isPrompt = $true
                })
            }
            
            # Default patterns for remaining apps
            default {
                # Simple default pattern
                $baseData.CopilotEventData.Messages = @(@{
                    Id = [string](Get-Random -Minimum 1740000000000 -Maximum 1750000000000)
                    isPrompt = $true
                })
            }
        }
        
        # Convert synthetic data to JSON and replace the AuditData
        $AuditLogEntry.AuditData = ($baseData | ConvertTo-Json -Depth 10 -Compress)
        
        # Re-parse the audit data with synthetic values
        $auditData = ConvertFrom-AuditData -AuditDataJson $AuditLogEntry.AuditData
    }
    
    # When NoExplodeArrays is enabled, create a simplified record with raw AuditData
    if ($NoExplodeArrays) {
        $baseRecord = [PSCustomObject]@{
            RecordId                           = $AuditLogEntry.Identity
            CreationDate                       = $AuditLogEntry.CreationDate
            RecordType                         = $AuditLogEntry.RecordType
            CreationDateIsoUtc                 = if ($AuditLogEntry.CreationDate) { $AuditLogEntry.CreationDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ') } else { $null }
            OrganizationId                     = Get-NestedProperty $auditData "OrganizationId" -Default "b1234567-89ab-cdef-0123-456789abcdef"
            UserType                           = Get-UserType -UserId $AuditLogEntry.UserIds -AuditData $auditData
            UserKey                            = Get-UserKey -UserId $AuditLogEntry.UserIds
            Workload                           = Get-WorkloadFromRecordType -RecordType $AuditLogEntry.RecordType
            Operation                          = $AuditLogEntry.Operations
            UserId                             = $AuditLogEntry.UserIds
            AuditData                          = $AuditLogEntry.AuditData  # Preserve raw JSON (now synthetic for DevTest)
        }
        return @($baseRecord)
    }
    
    # Original flattened structure for normal processing
    $baseRecord = [PSCustomObject]@{
        RecordId                           = $AuditLogEntry.Identity
        CreationDate                       = $AuditLogEntry.CreationDate
        RecordType                         = $AuditLogEntry.RecordType
        CreationDateIsoUtc                 = if ($AuditLogEntry.CreationDate) { $AuditLogEntry.CreationDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ') } else { $null }
        OrganizationId                     = Get-NestedProperty $auditData "OrganizationId" -Default "b1234567-89ab-cdef-0123-456789abcdef"
        UserType                           = Get-UserType -UserId $AuditLogEntry.UserIds -AuditData $auditData
        UserKey                            = Get-UserKey -UserId $AuditLogEntry.UserIds
        Workload                           = Get-WorkloadFromRecordType -RecordType $AuditLogEntry.RecordType
        Operation                          = $AuditLogEntry.Operations
        UserId                             = $AuditLogEntry.UserIds
        AssociatedAdminUnits               = if ($NoExplodeArrays) { (Get-NestedProperty $auditData "AssociatedAdminUnits" -join ",") } else { Get-NestedProperty $auditData "AssociatedAdminUnits" }
        AssociatedAdminUnitsNames          = if ($NoExplodeArrays) { (Get-NestedProperty $auditData "AssociatedAdminUnitsNames" -join ",") } else { Get-NestedProperty $auditData "AssociatedAdminUnitsNames" }
        AgentId                            = Get-NestedProperty $auditData "AgentId"
        AgentName                          = Get-NestedProperty $auditData "AgentName"
        AppIdentity_AppId                  = Get-NestedProperty $auditData "AppIdentity.AppId"
        AppIdentity_DisplayName            = Get-NestedProperty $auditData "AppIdentity.DisplayName"
        AppIdentity_PublisherId            = Get-NestedProperty $auditData "AppIdentity.PublisherId"
        ApplicationName                    = Get-NestedProperty $auditData "ApplicationName"
        CreationTime                       = Get-NestedProperty $auditData "CreationTime"
        CreationTimeIsoUtc                 = if ($auditData.CreationTime) { ([DateTime]$auditData.CreationTime).ToString('yyyy-MM-ddTHH:mm:ss.fffZ') } else { $null }
        ClientIP                           = Get-NestedProperty $auditData "ClientIP" -Default (Get-SyntheticClientIP -UserId $AuditLogEntry.UserIds)
        ObjectId                           = Get-NestedProperty $auditData "ObjectId" -Default (Get-SyntheticObjectId -Operation $AuditLogEntry.Operations -RecordType $AuditLogEntry.RecordType -AuditData $auditData)
        ResultStatus                       = Get-NestedProperty $auditData "ResultStatus" -Default "Succeeded"
        ClientRegion                       = Get-NestedProperty $auditData "ClientRegion"
        Audit_UserId                       = Get-NestedProperty $auditData "UserId"
        AppHost                            = Get-NestedProperty $auditData "AppHost"
        ThreadId                           = Get-NestedProperty $auditData "ThreadId"
        Context_Id                         = Get-NestedProperty $auditData "Context.Id"
        Context_Type                       = Get-NestedProperty $auditData "Context.Type"
        Message_Id                         = Get-NestedProperty $auditData "Message.Id"
        Message_isPrompt                   = Get-NestedProperty $auditData "Message.isPrompt"
        AccessedResource_Action            = Get-NestedProperty $auditData "AccessedResource.Action"
        AccessedResource_PolicyDetails     = if ($NoExplodeArrays) { (Get-NestedProperty $auditData "AccessedResource.PolicyDetails" -join ",") } else { Get-NestedProperty $auditData "AccessedResource.PolicyDetails" }
        AccessedResource_SiteUrl           = Get-NestedProperty $auditData "AccessedResource.SiteUrl"
        AISystemPlugin_Id                  = Get-NestedProperty $auditData "AISystemPlugin.Id"
        AISystemPlugin_Name                = Get-NestedProperty $auditData "AISystemPlugin.Name"
        ModelTransparencyDetails_ModelName = Get-NestedProperty $auditData "ModelTransparencyDetails.ModelName"
        MessageIds                         = if ($NoExplodeArrays) { (Get-NestedProperty $auditData "MessageIds" -join ",") } else { Get-NestedProperty $auditData "MessageIds" }
    }
    
    # Handle row explosion for arrays (default behavior unless disabled)
    if (!$NoExplodeArrays) {
        # Pre-explosion audit: analyze the structure we're working with
        Write-Host "Pre-Explosion Analysis:" -ForegroundColor Magenta
        Write-Host "  Base record type: $($baseRecord.GetType().Name)" -ForegroundColor Gray
        Write-Host "  Audit data type: $($auditData.GetType().Name)" -ForegroundColor Gray
        
        # Sample the structure
        if ($auditData -is [PSCustomObject]) {
            $sampleProps = $auditData.PSObject.Properties | Select-Object -First 20
            Write-Host "  Sample audit data properties ($($sampleProps.Count) shown):" -ForegroundColor Gray
            foreach ($prop in $sampleProps) {
                $valueInfo = if ($null -eq $prop.Value) { 
                    "null" 
                }
                elseif ($prop.Value -is [System.Array]) { 
                    "Array[$($prop.Value.Count)]" 
                }
                elseif ($prop.Value -is [PSCustomObject]) { 
                    "Object" 
                }
                elseif ($prop.Value -is [string] -and ($prop.Value.StartsWith('[') -or $prop.Value.StartsWith('{'))) {
                    "JSON-String"
                }
                else { 
                    $prop.Value.GetType().Name 
                }
                Write-Host "    $($prop.Name): $valueInfo" -ForegroundColor Gray
            }
        }
        
        # Check if AuditData needs JSON parsing
        if ($auditData.AuditData -and $auditData.AuditData -is [string]) {
            try {
                $parsedAuditData = $auditData.AuditData | ConvertFrom-Json
                Write-Host "  Parsed AuditData JSON successfully - type: $($parsedAuditData.GetType().Name)" -ForegroundColor Green
                # Replace the string with parsed object for better array detection
                $auditData.AuditData = $parsedAuditData
            }
            catch {
                Write-Host "  Failed to parse AuditData as JSON: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        # Exhaustive array detection function - handles ALL possible nesting scenarios
        function Find-AllArrays {
            param($Data, $Path = "", $Arrays = @{}, $Depth = 0)
            
            if ($null -eq $Data -or $Depth -gt 20) { return $Arrays }  # Prevent infinite recursion
            
            # Detect ALL array types with ANY count (including single items)
            $isArray = $false
            $arrayCount = 0
            $arrayData = $null
            
            # Check for various array types
            if ($Data -is [System.Array]) {
                $isArray = $true
                $arrayCount = $Data.Count
                $arrayData = $Data
            }
            elseif ($Data -is [System.Collections.ICollection] -and -not ($Data -is [string])) {
                $isArray = $true
                $arrayCount = $Data.Count
                $arrayData = @($Data)
            }
            elseif ($Data -is [System.Collections.IEnumerable] -and -not ($Data -is [string]) -and -not ($Data -is [System.Collections.IDictionary])) {
                $tempArray = @($Data)
                if ($tempArray.Count -gt 0) {
                    $isArray = $true
                    $arrayCount = $tempArray.Count
                    $arrayData = $tempArray
                }
            }
            
            # Register arrays with ANY count (including single items for explosion)
            if ($isArray -and $arrayCount -gt 0 -and -not $Arrays.ContainsKey($Path)) {
                $Arrays[$Path] = @{ 
                    Path  = $Path
                    Count = $arrayCount
                    Data  = $arrayData
                    Depth = $Depth
                }
                Write-Verbose "    Found array at $Path with $arrayCount items (depth $Depth)"
            }
            
            # Recursively explore ALL data structures
            try {
                # PSCustomObjects and custom objects
                if ($Data -is [PSCustomObject] -or ($null -ne $Data -and $Data.GetType().Name -eq 'PSCustomObject')) {
                    foreach ($prop in $Data.PSObject.Properties) {
                        try {
                            $newPath = if ($Path) { "$Path.$($prop.Name)" } else { $prop.Name }
                            $Arrays = Find-AllArrays -Data $prop.Value -Path $newPath -Arrays $Arrays -Depth ($Depth + 1)
                        }
                        catch { 
                            Write-Verbose "    Skipped property $($prop.Name) due to access error"
                        }
                    }
                }
                # Hashtables and dictionaries
                elseif ($Data -is [System.Collections.IDictionary]) {
                    foreach ($key in $Data.Keys) {
                        try {
                            $newPath = if ($Path) { "$Path.$key" } else { $key }
                            $Arrays = Find-AllArrays -Data $Data[$key] -Path $newPath -Arrays $Arrays -Depth ($Depth + 1)
                        }
                        catch {
                            Write-Verbose "    Skipped dictionary key $key due to access error"
                        }
                    }
                }
                # Array elements exploration
                elseif ($isArray -and $arrayData) {
                    for ($i = 0; $i -lt $arrayCount; $i++) {
                        try {
                            if ($i -lt $arrayData.Count) {
                                $newPath = if ($Path) { "$Path[$i]" } else { "[$i]" }
                                $Arrays = Find-AllArrays -Data $arrayData[$i] -Path $newPath -Arrays $Arrays -Depth ($Depth + 1)
                            }
                        }
                        catch {
                            Write-Verbose "    Skipped array index $i due to access error"
                        }
                    }
                }
                # Objects with properties (fallback for complex types)
                elseif ($null -ne $Data -and $Data.GetType().IsClass -and -not ($Data -is [string]) -and -not ($Data -is [System.ValueType])) {
                    try {
                        $properties = $Data | Get-Member -MemberType Property, NoteProperty -ErrorAction SilentlyContinue
                        foreach ($prop in $properties) {
                            try {
                                $newPath = if ($Path) { "$Path.$($prop.Name)" } else { $prop.Name }
                                $propValue = $Data.($prop.Name)
                                $Arrays = Find-AllArrays -Data $propValue -Path $newPath -Arrays $Arrays -Depth ($Depth + 1)
                            }
                            catch {
                                Write-Verbose "    Skipped complex property $($prop.Name) due to access error"
                            }
                        }
                    }
                    catch {
                        Write-Verbose "    Skipped complex object exploration due to reflection error"
                    }
                }
            }
            catch {
                Write-Verbose "    Skipped data exploration at path $Path due to error: $($_.Exception.Message)"
            }
            
            return $Arrays
        }
        
        # Find all arrays in the audit data with enhanced diagnostics
        Write-Verbose "Starting exhaustive array detection on audit data..."
        $arrayHashtable = Find-AllArrays -Data $auditData
        $allArrays = $arrayHashtable.Values
        
        # Enhanced diagnostics for array detection
        Write-Host "Array Detection Results:" -ForegroundColor Cyan
        if ($allArrays.Count -gt 0) {
            Write-Host "  Found $($allArrays.Count) arrays to explode:" -ForegroundColor Green
            $totalExplosionPotential = 1
            foreach ($arr in $allArrays) {
                Write-Host "    $($arr.Path): $($arr.Count) items (depth $($arr.Depth))" -ForegroundColor Yellow
                $totalExplosionPotential *= $arr.Count
            }
            Write-Host "  Maximum potential explosion: 1 → $totalExplosionPotential records" -ForegroundColor Magenta
        }
        else {
            Write-Host "  No arrays detected for explosion" -ForegroundColor Red
            # Debug the raw structure
            Write-Host "  Raw audit data type: $($auditData.GetType().Name)" -ForegroundColor Gray
            if ($auditData -is [PSCustomObject]) {
                Write-Host "  Audit data properties:" -ForegroundColor Gray
                foreach ($prop in $auditData.PSObject.Properties | Select-Object -First 10) {
                    $type = if ($prop.Value) { $prop.Value.GetType().Name } else { "null" }
                    Write-Host "    $($prop.Name): $type" -ForegroundColor Gray
                }
            }
        }
            
        # Sort arrays by depth to process from outermost to innermost
        $sortedArrays = $allArrays | Sort-Object Depth
            
        # Start with single base record
        $explodedRecords = @($baseRecord)
            
        # Process each array for comprehensive cross-product explosion
        foreach ($arrayInfo in $sortedArrays) {
            $newRecords = @()
            Write-Verbose "Processing array: $($arrayInfo.Path) with $($arrayInfo.Count) items (depth $($arrayInfo.Depth))"
                
            foreach ($existingRecord in $explodedRecords) {
                foreach ($item in $arrayInfo.Data) {
                    try {
                        # Deep clone the record to avoid reference issues
                        $record = $existingRecord | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                            
                        # Enhanced path resolution for ALL possible scenarios
                        $success = Set-ValueAtPath -Record $record -Path $arrayInfo.Path -Value $item
                            
                        if ($success) {
                            $newRecords += $record
                        }
                        else {
                            Write-Verbose "    Failed to set value at path: $($arrayInfo.Path)"
                        }
                    }
                    catch {
                        Write-Verbose "    Error processing item in array $($arrayInfo.Path): $($_.Exception.Message)"
                    }
                }
            }
                
            if ($newRecords.Count -gt 0) {
                $explodedRecords = $newRecords
                Write-Verbose "After exploding $($arrayInfo.Path): $($explodedRecords.Count) records"
            }
            else {
                Write-Verbose "No records generated from array $($arrayInfo.Path), keeping original"
            }
        }
            
        # Enhanced path setting function
        function Set-ValueAtPath {
            param($Record, $Path, $Value)
                
            try {
                # Handle array indices in path like Path[0], Path[1], etc.
                if ($Path -match '^(.+?)\[(\d+)\](.*)$') {
                    $basePath = $matches[1]
                    $index = [int]$matches[2]
                    $remainingPath = $matches[3]
                        
                    # Navigate to the array
                    $current = $Record
                    if ($basePath) {
                        $baseParts = $basePath -split '\.'
                        foreach ($part in $baseParts) {
                            if ($part -and $current.PSObject.Properties[$part]) {
                                $current = $current.PSObject.Properties[$part].Value
                            }
                            else {
                                return $false
                            }
                        }
                    }
                        
                    # Set array element
                    if ($current -is [System.Array] -and $index -lt $current.Count) {
                        if ($remainingPath -and $remainingPath.StartsWith('.')) {
                            # More nesting after array index
                            $subPath = $remainingPath.Substring(1)
                            return Set-ValueAtPath -Record $current[$index] -Path $subPath -Value $Value
                        }
                        else {
                            # Direct array element replacement
                            $current[$index] = $Value
                            return $true
                        }
                    }
                        
                    return $false
                }
                    
                # Handle regular dot notation paths
                $pathParts = $Path -split '\.'
                $current = $Record
                    
                # Navigate to parent
                for ($i = 0; $i -lt $pathParts.Count - 1; $i++) {
                    $part = $pathParts[$i]
                    if (-not $part) { continue }
                        
                    if (-not $current.PSObject.Properties[$part]) {
                        Add-Member -InputObject $current -NotePropertyName $part -NotePropertyValue ([PSCustomObject]@{}) -Force
                    }
                    $current = $current.PSObject.Properties[$part].Value
                }
                    
                # Set final value
                $finalPart = $pathParts[-1]
                if ($finalPart) {
                    if ($current.PSObject.Properties[$finalPart]) {
                        $current.PSObject.Properties[$finalPart].Value = $Value
                    }
                    else {
                        Add-Member -InputObject $current -NotePropertyName $finalPart -NotePropertyValue $Value -Force
                    }
                    return $true
                }
                    
                return $false
            }
            catch {
                Write-Verbose "    Path setting error: $($_.Exception.Message)"
                return $false
            }
        }
            
        # Add comprehensive explosion metadata and statistics
        $explosionRatio = if ($explodedRecords.Count -gt 0) { $explodedRecords.Count } else { 1 }
            
        Write-Host "Explosion Results:" -ForegroundColor Green
        Write-Host "  Input: 1 record" -ForegroundColor Yellow
        Write-Host "  Output: $($explodedRecords.Count) records" -ForegroundColor Yellow
        Write-Host "  Expansion ratio: 1:$explosionRatio" -ForegroundColor Yellow
        Write-Host "  Arrays processed: $($allArrays.Count)" -ForegroundColor Yellow
            
        foreach ($record in $explodedRecords) {
            Add-Member -InputObject $record -NotePropertyName '_ExplosionType' -NotePropertyValue 'ComprehensiveArrayExplosion' -Force
            Add-Member -InputObject $record -NotePropertyName '_ArraysExploded' -NotePropertyValue $allArrays.Count -Force
            Add-Member -InputObject $record -NotePropertyName '_ExplosionRatio' -NotePropertyValue $explosionRatio -Force
            Add-Member -InputObject $record -NotePropertyName '_ExplodedPaths' -NotePropertyValue ($allArrays | ForEach-Object { $_.Path }) -Force
        }
            
        return $explodedRecords
    }
    else {
        Write-Host "Explosion Results:" -ForegroundColor Yellow
        Write-Host "  Input: 1 record" -ForegroundColor Yellow  
        Write-Host "  Output: 1 record (no arrays found)" -ForegroundColor Yellow
        Write-Host "  No explosion needed" -ForegroundColor Yellow
            
        # Add metadata for passthrough tracking
        Add-Member -InputObject $baseRecord -NotePropertyName '_PassthroughReason' -NotePropertyValue 'NoArraysDetected' -Force
        Add-Member -InputObject $baseRecord -NotePropertyName '_ExplosionType' -NotePropertyValue 'PassThrough' -Force
        return $baseRecord
    }
    
    return $baseRecord
}

try {
    # Start transcript logging if LogFile parameter is provided
    if ($LogFile) {
        try {
            Start-Transcript -Path $LogFile -Force
            Write-Host "Transcript logging started: $LogFile" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to start transcript logging to '$LogFile': $($_.Exception.Message)"
        }
    }
    
    Write-Host "=== Copilot Metrics Extraction ===" -ForegroundColor Cyan
    
    # Runtime parameter validation (bypasses PowerShell attribute caching issues)
    Write-Host "Validating parameters..." -ForegroundColor Yellow
    if ($ResultSize -lt 1 -or $ResultSize -gt 50000) {
        throw "ResultSize must be between 1 and 50000. Current value: $ResultSize"
    }
    if ($BlockHours -lt 0.016667 -or $BlockHours -gt 24) {
        throw "BlockHours must be between 0.016667 (1 minute) and 24 (24 hours). Current value: $BlockHours"
    }
    if ($PacingMs -lt 0 -or $PacingMs -gt 10000) {
        throw "PacingMs must be between 0 and 10000. Current value: $PacingMs"
    }
    if ($MaxConcurrent -lt 1 -or $MaxConcurrent -gt 10) {
        throw "MaxConcurrent must be between 1 and 10. Current value: $MaxConcurrent"
    }
    Write-Host "Parameter validation passed - ResultSize: $ResultSize, BlockHours: $BlockHours" -ForegroundColor Green
    
    # Display comprehensive configuration summary
    Write-Host ""
    Write-Host "=== Export Configuration Summary ===" -ForegroundColor Yellow
    Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor White
    Write-Host "Output File: $OutputFile" -ForegroundColor White
    Write-Host "Authentication Mode: $Auth" -ForegroundColor White
    Write-Host "Block Hours (Time Window): $BlockHours" -ForegroundColor White
    Write-Host "Result Size (Records per API call): $ResultSize" -ForegroundColor White
    Write-Host "Pacing (Delay between calls): ${PacingMs}ms" -ForegroundColor White
    Write-Host "Max Concurrent Queries: $MaxConcurrent" -ForegroundColor White
    Write-Host "Array Explosion: $(if ($NoExplodeArrays) { 'Disabled (join with commas)' } else { 'Enabled (separate rows)' })" -ForegroundColor White
    Write-Host "Activity Types: $($ActivityTypes.Count) selected" -ForegroundColor White
    if ($LogFile) {
        Write-Host "Log File: $LogFile" -ForegroundColor White
    }
    Write-Host "======================================" -ForegroundColor Yellow
    Write-Host ""
    
    Connect-ToComplianceCenter

    $startDateObj = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)
    $endDateObj = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null)
    Write-Host "Searching for Copilot audit logs from $($startDateObj.ToString('yyyy-MM-dd')) to $($endDateObj.ToString('yyyy-MM-dd'))..." -ForegroundColor Yellow

    # Enterprise-optimized persistent adaptive sizing - 30min default with progressive auto-subdivision
    $blockHours = [double]$BlockHours
    if ($blockHours -lt 0.016667) { $blockHours = 0.5 }  # Minimum 1 minute, default 30 minutes
    
    # Persistent adaptive sizing state - tracks learned optimal block sizes across the export session
    $learnedActivityBlockSize = @{}  # Per-activity type learned block size
    $globalLearnedBlockSize = $blockHours  # Global learned size for new activities
    
    # Progressive subdivision sequence (in hours): 30min -> 15min -> 8min -> 4min -> 2min -> 1min
    $subdivisionSequence = @(0.5, 0.25, 0.133333, 0.066667, 0.033333, 0.016667)
    
    $blocksPerDay = [math]::Ceiling(24 / $blockHours)
    $totalDays = ($endDateObj.Date - $startDateObj.Date).Days
    $totalBlocks = $totalDays * $blocksPerDay  # Approximate - actual will be calculated dynamically based on learned block sizes

    # Handle CopilotInteractionOnly mode
    if ($CopilotInteractionOnly) {
        Write-Host "CopilotInteractionOnly mode enabled - filtering for Operation='CopilotInteraction' only" -ForegroundColor Cyan
        $ActivityTypes = @("CopilotInteraction")  # Override activity types
    }
    
    # Handle DevTest mode
    if ($DevTest) {
        Write-Host "DevTest mode enabled - filtering for Operation='Create' within CopilotInteraction activity type" -ForegroundColor Cyan
        $ActivityTypes = @("CopilotInteraction")  # Override activity types for dev test
    }
    
    # Intelligent activity batching for better performance
    $highVolumeActivities = @("CopilotInteraction", "MessageSent", "MessageRead", "FileAccessed", "FileModified", "MailItemsAccessed", "PageViewed", "TeamsSessionStarted")
    $mediumVolumeActivities = @("MeetingDetail", "MeetingParticipantDetail", "FileDownloaded", "FileUploaded", "SearchQueryPerformed", "FilePreviewed", "AINotesUpdate", "LiveNotesUpdate")
    $lowVolumeActivities = $ActivityTypes | Where-Object { $_ -notin $highVolumeActivities -and $_ -notin $mediumVolumeActivities }
    
    # Create batched query groups
    $queryGroups = @()
    
    # High-volume activities: query individually to prevent result limits
    foreach ($activity in ($ActivityTypes | Where-Object { $_ -in $highVolumeActivities })) {
        $queryGroups += , @($activity)
    }
    
    # Medium-volume activities: batch 2-3 together
    $mediumActivitiesToProcess = $ActivityTypes | Where-Object { $_ -in $mediumVolumeActivities }
    for ($i = 0; $i -lt $mediumActivitiesToProcess.Count; $i += 2) {
        $batchEnd = [math]::Min($i + 1, $mediumActivitiesToProcess.Count - 1)
        $batch = $mediumActivitiesToProcess[$i..$batchEnd]
        $queryGroups += , $batch
    }
    
    # Low-volume activities: batch 4-6 together for efficiency
    for ($i = 0; $i -lt $lowVolumeActivities.Count; $i += 5) {
        $batchEnd = [math]::Min($i + 4, $lowVolumeActivities.Count - 1)
        $batch = $lowVolumeActivities[$i..$batchEnd]
        if ($batch.Count -gt 0) { $queryGroups += , $batch }
    }
    
    # Note: Total queries will be calculated dynamically based on learned block sizes
    $totalQueries = $totalBlocks * $queryGroups.Count  # Estimate - actual may vary with adaptive sizing
    $queryCount = 0

    # Emit explicit totals for host application to consume (estimated with adaptive sizing)
    Write-Host "PA:TOTALS queries=$totalQueries"
    Write-Host "Intelligent batching: $($queryGroups.Count) query groups from $($ActivityTypes.Count) activities (High:$(($ActivityTypes | Where-Object { $_ -in $highVolumeActivities }).Count), Medium:$(($ActivityTypes | Where-Object { $_ -in $mediumVolumeActivities }).Count), Low:$($lowVolumeActivities.Count))" -ForegroundColor Green
    Write-Host "Performance optimizations active: Auto-subdivision, ArrayList operations, Enhanced retry logic, Smart batching" -ForegroundColor Green

    # Use ArrayList for better performance with large datasets
    $allLogs = New-Object System.Collections.ArrayList
    Write-Host "PA:PHASE queries start - $(Get-UtcTimestamp)"
    
    # Persistent adaptive sizing: Query each activity group with its optimal learned block size
    foreach ($activityGroup in $queryGroups) {
        $activityList = if ($activityGroup.Count -eq 1) { $activityGroup[0] } else { "[$($activityGroup -join ', ')]" }
        Write-Host "Processing activity group: $activityList" -ForegroundColor Cyan
        
        # Get optimal block size for this activity group (use first activity as representative)
        $representativeActivity = $activityGroup[0]
        $currentBlockSize = Get-OptimalBlockSize -ActivityType $representativeActivity
        
        for ($day = $startDateObj.Date; $day -lt $endDateObj.Date; $day = $day.AddDays(1)) {
            Write-Host "  Date: $($day.ToString('yyyy-MM-dd')) - Using $([math]::Round($currentBlockSize * 60, 1))-min blocks" -ForegroundColor Gray
            
            # Query this day using current optimal block size for this activity
            $dayStart = $day
            $dayEnd = $day.AddDays(1)
            $currentTime = $dayStart
            
            while ($currentTime -lt $dayEnd) {
                $blockEnd = $currentTime.AddHours($currentBlockSize)
                if ($blockEnd -gt $dayEnd) { $blockEnd = $dayEnd }
                
                $queryCount++
                $percentComplete = [math]::Round(($queryCount / $totalQueries) * 100, 1)
                Write-Host "[$percentComplete%] Query $queryCount/$totalQueries - $activityList ($($currentTime.ToString('yyyy-MM-dd HH:mm')) - $($blockEnd.ToString('HH:mm')))" -ForegroundColor Gray
                
                # Query activities in the group with optional parallelism
                $groupLogs = @()
                # TEMPORARY: Disable concurrent processing to avoid Exchange session issues with PowerShell jobs
                # TODO: Fix Exchange session sharing across job runspaces
                if ($false -and $MaxConcurrent -gt 1 -and $activityGroup.Count -gt 1) {
                    # Parallel processing for multiple activities in group
                    $jobs = @()
                    $activityIndex = 0
                    foreach ($activity in $activityGroup) {
                        # Limit concurrent jobs
                        while ((Get-Job -State Running).Count -ge $MaxConcurrent) {
                            Start-Sleep -Milliseconds 100
                            Get-Job -State Completed | Remove-Job
                        }
                        
                        $scriptBlock = {
                            param([datetime]$Start, [datetime]$End, [string]$Operation, [int]$ResultSize, [int]$PacingMs, [bool]$AutoSubdivide = $true)
                            
                            # Import Exchange module and connect if needed (jobs run in separate runspaces)
                            try {
                                if (-not (Get-Command Search-UnifiedAuditLog -ErrorAction SilentlyContinue)) {
                                    Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop
                                    # Note: Exchange session should already be established in main thread
                                }
                            }
                            catch {
                                Write-Warning "Job failed to import Exchange module: $($_.Exception.Message)"
                                return @()
                            }
                            
                            # Import the retry function into job scope
                            function Invoke-SearchUnifiedAuditLogWithRetry {
                                param(
                                    [datetime]$Start, [datetime]$End, [string]$Operation,
                                    [int]$ResultSize, [int]$PacingMs, [bool]$AutoSubdivide = $true
                                )
                                try {
                                    # Use dynamic splatting to bypass parameter validation for any ResultSize
                                    $params = @{}
                                    $params.Add('StartDate', $Start)
                                    $params.Add('EndDate', $End)
                                    $params.Add('ResultSize', $ResultSize)
                                    $params.Add('ErrorAction', 'Stop')
                                    if ($Operation) { $params.Add('Operations', $Operation) }
                                    
                                    return Search-UnifiedAuditLog @params
                                }
                                catch { return @() }
                            }
                            return Invoke-SearchUnifiedAuditLogWithRetry -Start $Start -End $End -Operation $Operation -ResultSize $ResultSize -PacingMs $PacingMs -AutoSubdivide $AutoSubdivide
                        }
                        
                        # Ensure AutoSubdivide is properly cast as boolean before passing to job
                        $safeAutoSubdivide = if ($null -eq $AutoSubdivide -or $AutoSubdivide -eq '') { $true } else { [bool]$AutoSubdivide }
                        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $currentTime, $blockEnd, $activity, $ResultSize, $PacingMs, $safeAutoSubdivide
                        $jobs += $job
                        $activityIndex++
                    }
                    
                    # Wait for all jobs and collect results
                    $jobs | Wait-Job | Out-Null
                    foreach ($job in $jobs) {
                        $logs = Receive-Job $job
                        if ($logs) { $groupLogs += $logs }
                        Remove-Job $job
                    }
                }
                else {
                    # Sequential processing (default/fallback)
                    foreach ($activity in $activityGroup) {
                        # Ensure AutoSubdivide is properly cast as boolean to prevent conversion errors
                        $safeAutoSubdivide = if ($null -eq $AutoSubdivide -or $AutoSubdivide -eq '') { $true } else { [bool]$AutoSubdivide }
                        
                        # For CopilotInteractionOnly mode, use "CopilotInteraction" as Operations filter instead of activity type
                        # For DevTest mode, use "Create" as Operations filter within CopilotInteraction activity type
                        $operationFilter = if ($CopilotInteractionOnly) { "CopilotInteraction" } elseif ($DevTest) { "Create" } else { $activity }
                        
                        $logs = Invoke-SearchUnifiedAuditLogWithRetry -Start $currentTime -End $blockEnd -Operation $operationFilter -ResultSize $ResultSize -PacingMs $PacingMs -AutoSubdivide $safeAutoSubdivide
                        if ($logs) { $groupLogs += $logs }
                    }
                }
                
                # Check for result limit hit and update persistent learned block size
                if ($groupLogs -and $groupLogs.Count -eq $ResultSize) {
                    # Hit result limit - learn smaller block size for this activity
                    $newBlockSize = Get-NextSmallerBlockSize -CurrentBlockSize $currentBlockSize
                    if ($newBlockSize -ne $currentBlockSize) {
                        Update-LearnedBlockSize -NewBlockSize $newBlockSize -ActivityType $representativeActivity
                        $currentBlockSize = $newBlockSize
                        Write-Host "    Result limit hit! Using $([math]::Round($currentBlockSize * 60, 1))-min blocks for remaining queries" -ForegroundColor Yellow
                    }
                    else {
                        Write-Host "    Result limit hit but already at minimum block size (1 minute)" -ForegroundColor Red
                    }
                }
                
                # Track statistics and add results
                if ($groupLogs) {
                    $allLogs.AddRange($groupLogs) | Out-Null
                    Write-Host "  Found $($groupLogs.Count) records (pre-row explosion) for $activityList at $($currentTime.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Green
                }
                else {
                    Write-Host "  No records found for $activityList ($($currentTime.ToString('yyyy-MM-dd HH:mm'))-$($blockEnd.ToString('HH:mm')))" -ForegroundColor Yellow
                }
                
                # Move to next time block
                $currentTime = $blockEnd
            }
        }
    }

    Write-Host "PA:PHASE queries end - $(Get-UtcTimestamp)"
    $uniqueLogs = $allLogs | Sort-Object Identity -Unique
    Write-Host "Total unique records found: $($uniqueLogs.Count)" -ForegroundColor Cyan

    if ($uniqueLogs.Count -eq 0) {
        Write-Warning "No audit logs found in the specified date range."
        Write-Host "This might be because:" -ForegroundColor Yellow
        Write-Host "- Audit logging is not enabled for the selected activities" -ForegroundColor Yellow
        Write-Host "- No activity occurred during this period" -ForegroundColor Yellow
        Write-Host "- Different operation names are being used" -ForegroundColor Yellow
        Write-Host "- Insufficient permissions to view audit logs" -ForegroundColor Yellow
        return
    }

    # Post-processing phase: summarize tasks as categories (convert, export, sample, stats, finalize)
    $postCategories = @{
        convert  = [int]$uniqueLogs.Count
        export   = 1
        sample   = 1
        stats    = 1
        finalize = 1
    }
    $postTotal = ($postCategories.Values | Measure-Object -Sum).Sum
    $postCount = 0
    Write-Host "PA:TOTALS queries=$totalQueries post=$postTotal"
    Write-Host "PA:PHASE post start - $(Get-UtcTimestamp)"

    # Convert
    Write-Host "PA:POST start convert total=$($postCategories.convert)" -ForegroundColor Yellow
    $metricsData = New-Object System.Collections.ArrayList
    
    # Initialize row explosion tracking counters
    $explosionStats = @{
        TotalInput              = 0
        ExplodedRecords         = 0
        PassthroughRecords      = 0
        PassthroughNoMessageIds = 0
        PassthroughSingleId     = 0
        PassthroughOther        = 0
        OutputRecords           = 0
    }
    
    $i = 0
    foreach ($log in $uniqueLogs) {
        $i++
        $postCount = [math]::Min($postCount + 1, $postTotal)
        $percentPost = [math]::Round(($postCount / $postTotal) * 100, 1)
        Write-Host "[$percentPost%] Post $postCount/$postTotal - Converting ($i/$($postCategories.convert))" -ForegroundColor Gray
        if ($i -le 5 -and $i % 50 -eq 0) { Write-Host "Converting records..." -ForegroundColor Gray }
        $metricsRecord = Convert-ToMetricsRecord -AuditLogEntry $log -NoExplodeArrays:$NoExplodeArrays -DevTest:$DevTest
        
        # Track row explosion statistics
        $explosionStats.TotalInput++
        
        # Handle both single records and arrays of records from row explosion
        if ($metricsRecord -is [array]) {
            $explosionStats.ExplodedRecords++
            $explosionStats.OutputRecords += $metricsRecord.Count
            $metricsData.AddRange($metricsRecord) | Out-Null
        }
        else {
            $explosionStats.PassthroughRecords++
            $explosionStats.OutputRecords++
            
            # Track specific passthrough reasons (only when explosion is enabled)
            if (!$NoExplodeArrays -and $metricsRecord.'_PassthroughReason') {
                switch ($metricsRecord.'_PassthroughReason') {
                    'NoMessageIds' { $explosionStats.PassthroughNoMessageIds++ }
                    'SingleMessageId' { $explosionStats.PassthroughSingleId++ }
                    'NoArraysToExplode' { $explosionStats.PassthroughOther++ }
                    'Other' { $explosionStats.PassthroughOther++ }
                }
                # Remove the metadata property before adding to final output
                $metricsRecord.PSObject.Properties.Remove('_PassthroughReason')
            }
            
            # Clean up explosion metadata
            if ($metricsRecord.'_ExplosionType') {
                $metricsRecord.PSObject.Properties.Remove('_ExplosionType')
            }
            if ($metricsRecord.'_ArraysExploded') {
                $metricsRecord.PSObject.Properties.Remove('_ArraysExploded')
            }
            
            $metricsData.Add($metricsRecord) | Out-Null
        }
        Write-Host "PA:POST progress convert $i/$($postCategories.convert)"
    }
    
    # Report row explosion statistics
    if (!$NoExplodeArrays) {
        Write-Host "=== Row Explosion Statistics ===" -ForegroundColor Cyan
        Write-Host "Input records: $($explosionStats.TotalInput)" -ForegroundColor Yellow
        Write-Host "Records exploded: $($explosionStats.ExplodedRecords)" -ForegroundColor Green
        Write-Host "Records passed through: $($explosionStats.PassthroughRecords)" -ForegroundColor Blue
        Write-Host "  └─ No arrays found: $($explosionStats.PassthroughOther)" -ForegroundColor DarkCyan
        Write-Host "  └─ Single elements only: $($explosionStats.PassthroughSingleId)" -ForegroundColor DarkCyan
        Write-Host "  └─ Legacy tracking: $($explosionStats.PassthroughNoMessageIds)" -ForegroundColor DarkGray
        Write-Host "Total output records: $($explosionStats.OutputRecords)" -ForegroundColor Magenta
        $explosionRatio = if ($explosionStats.TotalInput -gt 0) { [math]::Round($explosionStats.OutputRecords / $explosionStats.TotalInput, 2) } else { 0 }
        Write-Host "Explosion ratio: $explosionRatio:1 (output:input)" -ForegroundColor White
        Write-Host "=================================" -ForegroundColor Cyan
    }
    
    Write-Host "PA:POST end convert"

    # Export CSV
    Write-Host "PA:POST start export total=1" -ForegroundColor Yellow
    Write-Host "Exporting to CSV: $OutputFile" -ForegroundColor Yellow
    $metricsData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    $postCount = [math]::Min($postCount + 1, $postTotal)
    $percentPost = [math]::Round(($postCount / $postTotal) * 100, 1)
    Write-Host "[$percentPost%] Post $postCount/$postTotal - Exporting CSV" -ForegroundColor Gray
    Write-Host "PA:POST progress export 1/1"
    Write-Host "PA:POST end export"

    # Sample (summarized)
    Write-Host "PA:POST start sample total=1" -ForegroundColor Yellow
    if ($metricsData.Count -gt 0) {
        $first = $metricsData[0]
        # Summarize sample without dumping all fields
        $sampleUser = ($first.PSObject.Properties["UserId"].Value)
        $sampleOp = ($first.PSObject.Properties["Operation"].Value)
        $sampleTime = ($first.PSObject.Properties["CreationDate"].Value)
        Write-Host "Sample captured: User='$sampleUser' Operation='$sampleOp' Time='$sampleTime'" -ForegroundColor Cyan
    }
    else {
        Write-Host "No sample available (no records)" -ForegroundColor Yellow
    }
    $postCount = [math]::Min($postCount + 1, $postTotal)
    $percentPost = [math]::Round(($postCount / $postTotal) * 100, 1)
    Write-Host "[$percentPost%] Post $postCount/$postTotal - Sample" -ForegroundColor Gray
    Write-Host "PA:POST progress sample 1/1"
    Write-Host "PA:POST end sample"

    # Field stats (summarized)
    Write-Host "PA:POST start stats total=1" -ForegroundColor Yellow
    if ($metricsData.Count -gt 0) {
        $first = $metricsData[0]
        $props = $first.PSObject.Properties | Select-Object -ExpandProperty Name
        Write-Host "Computed population stats across $($props.Count) fields" -ForegroundColor Cyan
    }
    else {
        Write-Host "No stats (no records)" -ForegroundColor Yellow
    }
    $postCount = [math]::Min($postCount + 1, $postTotal)
    $percentPost = [math]::Round(($postCount / $postTotal) * 100, 1)
    Write-Host "[$percentPost%] Post $postCount/$postTotal - Stats" -ForegroundColor Gray
    Write-Host "PA:POST progress stats 1/1"
    Write-Host "PA:POST end stats"

    # Finalize
    Write-Host "PA:POST start finalize total=1" -ForegroundColor Yellow
    try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch {}
    try { Disconnect-IPPSSession -Confirm:$false -ErrorAction SilentlyContinue } catch {}
    $postCount = [math]::Min($postCount + 1, $postTotal)
    $percentPost = [math]::Round(($postCount / $postTotal) * 100, 1)
    Write-Host "[$percentPost%] Post $postCount/$postTotal - Finalizing" -ForegroundColor Gray
    Write-Host "PA:POST progress finalize 1/1"
    Write-Host "PA:POST end finalize"

    Write-Host "PA:PHASE post end - $(Get-UtcTimestamp)"
    Write-Host "`n=== Extraction Complete ===" -ForegroundColor Green
    Write-Host "Records exported: $($metricsData.Count)" -ForegroundColor White
    Write-Host "Output file: $OutputFile" -ForegroundColor White
    Write-Host "File size: $([math]::Round((Get-Item $OutputFile).Length / 1KB, 2)) KB" -ForegroundColor White
    # Signal complete
    Write-Host "=== Extraction Complete (done) ===" -ForegroundColor Green
    Write-Host "CSV export completed: $OutputFile" -ForegroundColor Cyan
    Write-Host "PA:DONE"
    exit 0
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    Write-Error $_.ScriptStackTrace
}
finally {
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Disconnect-IPPSSession -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch {
        # Ignore disconnection errors
    }
    
    # Stop transcript logging if it was started
    if ($LogFile) {
        try {
            Stop-Transcript
            Write-Host "Transcript log saved: $LogFile" -ForegroundColor Green
        }
        catch {
            # Transcript might not be running, ignore errors
        }
    }
}


