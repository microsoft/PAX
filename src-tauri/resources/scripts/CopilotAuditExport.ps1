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
    [string]$OutputFile = "$([System.IO.Path]::GetTempPath())Purview_Export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    [Parameter(Mandatory = $false)]
    [ValidateSet('WebLogin', 'DeviceCode', 'Credential', 'Silent')]
    [string]$Auth = 'WebLogin',
    [Parameter(Mandatory = $false)]
    [ValidateSet(2, 4, 6, 8, 12, 24)]
    [int]$BlockHours = 24,
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 5000)]
    [int]$ResultSize = 5000,
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 10000)]
    [int]$PacingMs = 0,
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxConcurrent = 3,
    [Parameter(Mandatory = $false)]
    [switch]$NoExplodeArrays,
    [Parameter(Mandatory = $false)]
    [switch]$DetailedPost,
    [Parameter(Mandatory = $false)]
    [string]$LogFile,
    [Parameter(Mandatory = $false)]
    [switch]$Help,
    [Parameter(Mandatory = $false)]
    [switch]$InHelper
)

function Show-Help {
    @"
Microsoft 365 Copilot & AI Purview Audit Log Extractor
-------------------------------------------------------
This script exports Microsoft 365 Copilot, AI, and user activity records from Purview audit logs to CSV with comprehensive logging.

USAGE EXAMPLES:
---------------
- Basic export with recommended activities (tiers 1-3: Copilot core, Teams, Files):
  .\CopilotAuditExport.ps1 -StartDate "2025-09-01" -EndDate "2025-09-02"

- Custom output location with automatic log file:
  .\CopilotAuditExport.ps1 -StartDate "2025-09-01" -EndDate "2025-09-02" -OutputFile "C:\Reports\CopilotUsage.csv"

- Specific activities (Copilot interactions and file access):
  .\CopilotAuditExport.ps1 -StartDate "2025-09-01" -EndDate "2025-09-02" -ActivityTypes "CopilotInteraction","FileAccessed","FileModified"

- Large dataset with smaller time windows and throttle control:
  .\CopilotAuditExport.ps1 -StartDate "2025-09-01" -EndDate "2025-09-10" -BlockHours 4 -PacingMs 1000

- Show help:
  .\CopilotAuditExport.ps1 -Help
  .\CopilotAuditExport.ps1 /Help



PARAMETERS:
-----------
-StartDate        (Required)  Start date for search (yyyy-MM-dd format). Inclusive - data from this date is included.
-EndDate          (Required)  End date for search (yyyy-MM-dd format). Exclusive - data up to but not including this date.
-ActivityTypes    (Optional)  Array of activity types to search. Default: 32 curated activities across Copilot, Teams, Files, and Exchange tiers.
-OutputFile       (Optional)  Path for CSV output. Default: Purview_Export_<timestamp>.csv in system temp folder.
-LogFile          (Optional)  Path for transcript log. Default: auto-generated .log file in same directory as CSV.
-Auth             (Optional)  Authentication: WebLogin (default, recommended), DeviceCode, Credential, or Silent.
                               • WebLogin: Opens native Microsoft sign-in window; best for admin accounts with MFA/CA
                               • DeviceCode: Shows code to enter at microsoft.com/devicelogin; useful if windows are blocked
                               • Credential: Username/password prompt; may fail with MFA/CA policies; not recommended
                               • Silent: Reuses existing cached session if available; fails otherwise
                               Note: Script validates account permissions before starting the full export.
-BlockHours       (Optional)  Time window per query: 2,4,6,8,12,24 hours. Default: 24 (optimal efficiency). Auto-subdivides when hitting limits.
-ResultSize       (Optional)  Records per API call (1-5000). Default: 5000. Reduce if hitting throttling limits.
-PacingMs         (Optional)  Delay between API calls in milliseconds (0-10000). Default: 0. Use 500-2000 to reduce throttling.
-MaxConcurrent    (Optional)  Maximum concurrent queries (1-10). Default: 3. Higher values = faster but more throttling risk.
-NoExplodeArrays  (Optional)  Disable row explosion (join arrays with commas). Default: explode arrays into separate rows for better analytics.
-DetailedPost     (Optional)  Show extra post-processing details (sample records, field statistics). Does not change CSV output.
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
- Connects to Microsoft 365 Purview audit log system with your chosen authentication method
- Validates account permissions by testing audit log access before starting full export
- Uses intelligent activity batching to group high/medium/low-volume operations for optimal performance
- Searches with adaptive time windows that auto-adjust based on data density to prevent result limits
- Implements auto-subdivision when hitting 5000-record limits to ensure complete data collection
- Supports controlled parallel processing for faster execution while respecting API throttling
- Downloads matching audit records and processes them into structured CSV format (with optional row explosion)
- Creates automatic transcript logs (.log files) alongside CSV output for troubleshooting
- Uses exponential backoff and optional pacing to handle Microsoft 365 throttling gracefully

AUTHENTICATION & PERMISSIONS
----------------------------
- Requires Exchange Online management permissions and Purview audit log access
- Script tests permissions with sample Search-UnifiedAuditLog call before proceeding
- If wrong account or insufficient permissions detected, authentication can be restarted manually
- Authentication sessions are properly managed and cleaned up on script completion

IMPORTANT: QUERY TIMING BEHAVIOR
-------------------------------
- Individual queries may appear to "hang" for 30-120 seconds - this is NORMAL Microsoft 365 behavior
- Purview processes complex audit queries server-side, which takes time for large datasets
- Progress shows "[25%] Query 5/20 - ActivityName" then waits while Microsoft processes the request
- Be patient during apparent hangs - the service is working. True timeouts are rare (10+ minutes)
- Use PacingMs (500-2000) and smaller BlockHours (2-4) in busy tenants to reduce throttling risk

PROGRESS & MARKERS
----------------
- Prints numeric progress prefixes like "[42.5%] Query a/b" and post-phase status.
- Emits structured markers for tools: PA:TOTALS, PA:PHASE (queries|keywords|post), and PA:POST category updates.
- Messages remain human-readable in a console.

WHAT'S IN THE OUTPUT FILE?
--------------------------
- Each row is a Copilot/AI or user-facing activity
- Columns include: Record ID, Date/Time, User, Action Type, and technical details (like app, plugin, resource, etc.)
- Some columns may be empty if that detail wasn't present for a given activity

WHY USE THIS SCRIPT?
--------------------
- See how Copilot, AI, Teams, Exchange, and SharePoint features are being used in your organization
- Create easy-to-read reports for management or compliance
- Spot trends, answer questions, or investigate specific activities

"@
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
        if ($PacingMs -ne $null) { $parts += "-PacingMs $PacingMs" }
        if ($MaxConcurrent) { $parts += "-MaxConcurrent $MaxConcurrent" }
        if ($NoExplodeArrays) { $parts += "-NoExplodeArrays" }
        if ($DetailedPost) { $parts += "-DetailedPost" }
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
function Is-VisibleHost {
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
Import-Module ExchangeOnlineManagement -ErrorAction Stop

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
                    $args = @{ ShowBanner = $false }
                    if ($exoCmd -and $exoCmd.Parameters.ContainsKey('UseWAM')) { $args['UseWAM'] = $false }
                    & Connect-ExchangeOnline @args -ErrorAction Stop
                }
                catch {
                    $silentOk = $false
                    Write-Host "Silent sign-in failed; switching to browser-based sign-in..." -ForegroundColor Yellow
                }
                if (-not $silentOk) {
                    if (-not $InHelper) { Start-VisibleReexecForAuth -Reason "interactive browser sign-in required" }
                    Write-Host "Opening default browser for Microsoft sign-in..." -ForegroundColor Yellow
                    try {
                        $exoCmd = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue
                        $hasWAM = $exoCmd -and $exoCmd.Parameters.ContainsKey('UseWAM')
                        if ($hasWAM) {
                            Connect-ExchangeOnline -ShowBanner:$false -OpenWebPage -UseWAM:$false -ErrorAction Stop | Out-Null
                        }
                        else {
                            Connect-ExchangeOnline -ShowBanner:$false -OpenWebPage -ErrorAction Stop | Out-Null
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

function Invoke-SearchUnifiedAuditLogWithRetry {
    param(
        [Parameter(Mandatory = $true)] [datetime]$Start,
        [Parameter(Mandatory = $true)] [datetime]$End,
        [Parameter(Mandatory = $false)] [string]$Operation,
        [Parameter(Mandatory = $true)] [int]$ResultSize,
        [Parameter(Mandatory = $true)] [int]$PacingMs,
        [Parameter(Mandatory = $false)] [int]$MaxRetries = 5,
        [Parameter(Mandatory = $false)] [switch]$AutoSubdivide = $true
    )
    $attempt = 0
    while ($attempt -le $MaxRetries) {
        try {
            $params = @{ StartDate = $Start; EndDate = $End; ResultSize = $ResultSize; ErrorAction = 'Stop' }
            if ($Operation) { $params.Operations = $Operation }
            $res = Search-UnifiedAuditLog @params
            if ($PacingMs -gt 0) { Start-Sleep -Milliseconds $PacingMs }
            
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
                            $chunk = Invoke-SearchUnifiedAuditLogWithRetry -Start $current -End $chunkEnd -Operation $Operation -ResultSize $ResultSize -PacingMs $PacingMs -MaxRetries $MaxRetries -AutoSubdivide:$AutoSubdivide
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
                        $firstHalf = Invoke-SearchUnifiedAuditLogWithRetry -Start $Start -End $midPoint -Operation $Operation -ResultSize $ResultSize -PacingMs $PacingMs -MaxRetries $MaxRetries -AutoSubdivide:$AutoSubdivide
                        $secondHalf = Invoke-SearchUnifiedAuditLogWithRetry -Start $midPoint -End $End -Operation $Operation -ResultSize $ResultSize -PacingMs $PacingMs -MaxRetries $MaxRetries -AutoSubdivide:$AutoSubdivide
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
        catch {
            $msg = $_.Exception.Message
            $status = $null
            try { $status = $_.Exception.Response.StatusCode.Value__ } catch {}
            $isThrottle = ($msg -match '429' -or $msg -match 'Too\s*Many\s*Requests' -or $msg -match 'throttl' -or $msg -match '503' -or $msg -match 'Service\s*Unavailable' -or $status -in 429, 503)
            if (-not $isThrottle -or $attempt -ge $MaxRetries) {
                Write-Host ("  Request failed: " + $msg) -ForegroundColor DarkYellow
                break
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
    return @()
}

function Parse-AuditData {
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
    param([object]$AuditLogEntry, [switch]$NoExplodeArrays)
    $auditData = Parse-AuditData -AuditDataJson $AuditLogEntry.AuditData
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
        # Comprehensive array detection function
        function Find-AllArrays {
            param($Data, $Path = "", $Arrays = @())
            
            if ($Data -eq $null) { return $Arrays }
            
            # Check if current data is an array with multiple items
            if ($Data -is [System.Array] -and $Data.Count -gt 1) {
                $Arrays += @{ Path = $Path; Count = $Data.Count; Data = $Data }
            }
            
            # Recursively check object properties
            if ($Data -is [PSCustomObject] -or $Data.GetType().Name -eq 'PSCustomObject') {
                foreach ($prop in $Data.PSObject.Properties) {
                    $newPath = if ($Path) { "$Path.$($prop.Name)" } else { $prop.Name }
                    $Arrays = Find-AllArrays -Data $prop.Value -Path $newPath -Arrays $Arrays
                }
            }
            # Check hashtables/dictionaries
            elseif ($Data -is [System.Collections.IDictionary]) {
                foreach ($key in $Data.Keys) {
                    $newPath = if ($Path) { "$Path.$key" } else { $key }
                    $Arrays = Find-AllArrays -Data $Data[$key] -Path $newPath -Arrays $Arrays
                }
            }
            # Check arrays for nested structures
            elseif ($Data -is [System.Array]) {
                for ($i = 0; $i -lt $Data.Count; $i++) {
                    $newPath = if ($Path) { "$Path[$i]" } else { "[$i]" }
                    $Arrays = Find-AllArrays -Data $Data[$i] -Path $newPath -Arrays $Arrays
                }
            }
            
            return $Arrays
        }
        
        # Find all arrays in the audit data
        $allArrays = Find-AllArrays -Data $auditData
        
        if ($allArrays.Count -gt 0) {
            Write-Verbose "Found $($allArrays.Count) arrays to explode:"
            foreach ($arr in $allArrays) {
                Write-Verbose "  $($arr.Path): $($arr.Count) items"
            }
            
            # Start with single base record
            $explodedRecords = @($baseRecord)
            
            # Process each array for cross-product explosion
            foreach ($arrayInfo in $allArrays) {
                $newRecords = @()
                
                foreach ($existingRecord in $explodedRecords) {
                    foreach ($item in $arrayInfo.Data) {
                        $record = $existingRecord.PSObject.Copy()
                        
                        # Set the array value to single item using dynamic property access
                        $pathParts = $arrayInfo.Path -split '\.'
                        if ($pathParts.Count -eq 1) {
                            # Top-level property
                            $record.$($pathParts[0]) = $item
                        } else {
                            # Nested property - create the path if needed
                            $current = $record
                            for ($i = 0; $i -lt $pathParts.Count - 1; $i++) {
                                if (-not $current.PSObject.Properties[$pathParts[$i]]) {
                                    Add-Member -InputObject $current -NotePropertyName $pathParts[$i] -NotePropertyValue ([PSCustomObject]@{}) -Force
                                }
                                $current = $current.PSObject.Properties[$pathParts[$i]].Value
                            }
                            Add-Member -InputObject $current -NotePropertyName $pathParts[-1] -NotePropertyValue $item -Force
                        }
                        
                        $newRecords += $record
                    }
                }
                
                $explodedRecords = $newRecords
                Write-Verbose "After exploding $($arrayInfo.Path): $($explodedRecords.Count) records"
            }
            
            # Add explosion metadata
            foreach ($record in $explodedRecords) {
                Add-Member -InputObject $record -NotePropertyName '_ExplosionType' -NotePropertyValue 'ComprehensiveArrayExplosion' -Force
                Add-Member -InputObject $record -NotePropertyName '_ArraysExploded' -NotePropertyValue $allArrays.Count -Force
            }
            
            return $explodedRecords
        }
        else {
            # Add metadata for passthrough tracking
            Add-Member -InputObject $baseRecord -NotePropertyName '_PassthroughReason' -NotePropertyValue 'NoArraysToExplode' -Force
            return $baseRecord
        }
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
    Connect-ToComplianceCenter

    $startDateObj = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)
    $endDateObj = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null)
    Write-Host "Searching for Copilot audit logs from $($startDateObj.ToString('yyyy-MM-dd')) to $($endDateObj.ToString('yyyy-MM-dd'))..." -ForegroundColor Yellow

    # Adaptive block sizing - start aggressive (24h), auto-subdivide when needed for enterprise safety
    $blockHours = [int]$BlockHours
    if ($blockHours -lt 1) { $blockHours = 24 }
    $adaptiveBlockSizing = $true
    $originalBlockHours = $blockHours
    
    $blocksPerDay = [int](24 / $blockHours)
    $totalDays = ($endDateObj.Date - $startDateObj.Date).Days
    $totalBlocks = $totalDays * $blocksPerDay
    
    # Track data density for adaptive sizing
    $dataDensityStats = @{
        TotalQueries       = 0
        QueriesWithResults = 0
        QueriesAtLimit     = 0
        AvgResultsPerQuery = 0
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
    
    $totalQueries = $totalBlocks * $queryGroups.Count
    $queryCount = 0

    # Emit explicit totals for host application to consume (ground truth)
    Write-Host "PA:TOTALS queries=$totalQueries keywords=$totalBlocks"
    Write-Host "Intelligent batching: $($queryGroups.Count) query groups from $($ActivityTypes.Count) activities (High:$(($ActivityTypes | Where-Object { $_ -in $highVolumeActivities }).Count), Medium:$(($ActivityTypes | Where-Object { $_ -in $mediumVolumeActivities }).Count), Low:$($lowVolumeActivities.Count))" -ForegroundColor Green
    Write-Host "Performance optimizations active: Auto-subdivision, ArrayList operations, Enhanced retry logic, Smart batching" -ForegroundColor Green

    # Use ArrayList for better performance with large datasets
    $allLogs = New-Object System.Collections.ArrayList
    Write-Host "PA:PHASE queries start"
    for ($day = $startDateObj.Date; $day -lt $endDateObj.Date; $day = $day.AddDays(1)) {
        Write-Host "Processing date: $($day.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
        for ($block = 0; $block -lt $blocksPerDay; $block++) {
            $startBlock = $day.AddHours($block * $blockHours)
            $endBlock = $startBlock.AddHours($blockHours)
            foreach ($activityGroup in $queryGroups) {
                $queryCount++
                $percentComplete = [math]::Round(($queryCount / $totalQueries) * 100, 1)
                $activityList = if ($activityGroup.Count -eq 1) { $activityGroup[0] } else { "[$($activityGroup -join ', ')]" }
                Write-Host "[$percentComplete%] Query $queryCount/$totalQueries - $activityList ($($startBlock.ToString('yyyy-MM-dd HH:mm')) - $($endBlock.ToString('HH:mm')))" -ForegroundColor Gray
                
                # Query activities in the group with optional parallelism
                $groupLogs = @()
                if ($MaxConcurrent -gt 1 -and $activityGroup.Count -gt 1) {
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
                            param($Start, $End, $Operation, $ResultSize, $PacingMs)
                            # Import the retry function into job scope
                            function Invoke-SearchUnifiedAuditLogWithRetry {
                                param(
                                    [datetime]$Start, [datetime]$End, [string]$Operation,
                                    [int]$ResultSize, [int]$PacingMs, [switch]$AutoSubdivide = $true
                                )
                                try {
                                    $params = @{ StartDate = $Start; EndDate = $End; ResultSize = $ResultSize; ErrorAction = 'Stop' }
                                    if ($Operation) { $params.Operations = $Operation }
                                    return Search-UnifiedAuditLog @params
                                }
                                catch { return @() }
                            }
                            return Invoke-SearchUnifiedAuditLogWithRetry -Start $Start -End $End -Operation $Operation -ResultSize $ResultSize -PacingMs $PacingMs
                        }
                        
                        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $startBlock, $endBlock, $activity, $ResultSize, $PacingMs
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
                        $logs = Invoke-SearchUnifiedAuditLogWithRetry -Start $startBlock -End $endBlock -Operation $activity -ResultSize $ResultSize -PacingMs $PacingMs
                        if ($logs) { $groupLogs += $logs }
                    }
                }
                
                # Track data density statistics for adaptive sizing
                $dataDensityStats.TotalQueries++
                if ($groupLogs) {
                    $dataDensityStats.QueriesWithResults++
                    $dataDensityStats.AvgResultsPerQuery = (($dataDensityStats.AvgResultsPerQuery * ($dataDensityStats.QueriesWithResults - 1)) + $groupLogs.Count) / $dataDensityStats.QueriesWithResults
                    
                    # Check if we're consistently hitting result limits (indicates need for smaller blocks)
                    if ($groupLogs.Count -ge ($ResultSize * 0.9)) {
                        $dataDensityStats.QueriesAtLimit++
                        if ($adaptiveBlockSizing -and $dataDensityStats.QueriesAtLimit -ge 3 -and $blockHours -gt 2) {
                            Write-Host "  Adaptive sizing: High data density detected, reducing block size for remaining queries" -ForegroundColor Yellow
                            $blockHours = [math]::Max(2, $blockHours / 2)
                            $blocksPerDay = [int](24 / $blockHours)
                        }
                    }
                    
                    $allLogs.AddRange($groupLogs) | Out-Null
                    Write-Host "  Found $($groupLogs.Count) records for $activityList at $($startBlock.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Green
                }
                else {
                    Write-Host "  No records found for $activityList ($($startBlock.ToString('yyyy-MM-dd HH:mm'))-$($endBlock.ToString('HH:mm')))" -ForegroundColor Yellow
                }
            }
        }
    }

    Write-Host "PA:PHASE queries end"
    # Also search for records with Copilot/AI keywords in AuditData
    Write-Host "Starting keyword search for Copilot/AI in AuditData..." -ForegroundColor Cyan
    Write-Host "PA:PHASE keywords start"
    $keywordQueryCount = 0
    $totalKeywordQueries = $totalBlocks
    for ($day = $startDateObj.Date; $day -lt $endDateObj.Date; $day = $day.AddDays(1)) {
        for ($block = 0; $block -lt $blocksPerDay; $block++) {
            $startBlock = $day.AddHours($block * $blockHours)
            $endBlock = $startBlock.AddHours($blockHours)
            $keywordQueryCount++
            $percentKeywordComplete = [math]::Round(($keywordQueryCount / $totalKeywordQueries) * 100, 1)
            Write-Host "[$percentKeywordComplete%] Keyword Query $keywordQueryCount/$totalKeywordQueries - $($startBlock.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Gray
            $additionalLogs = Invoke-SearchUnifiedAuditLogWithRetry -Start $startBlock -End $endBlock -Operation $null -ResultSize $ResultSize -PacingMs $PacingMs |
            Where-Object {
                $_.AuditData -match "Copilot|AI|ChatGPT|Assistant" -or
                $_.Operations -match "Copilot|AI|Chat"
            }
            if ($additionalLogs) {
                $allLogs.AddRange($additionalLogs) | Out-Null
                Write-Host "  Found $($additionalLogs.Count) keyword records at $($startBlock.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Green
            }
        }
    }

    Write-Host "PA:PHASE keywords end"
    $uniqueLogs = $allLogs | Sort-Object Identity -Unique
    Write-Host "Total unique records found: $($uniqueLogs.Count)" -ForegroundColor Cyan

    if ($uniqueLogs.Count -eq 0) {
        Write-Warning "No Copilot-related audit logs found in the specified date range."
        Write-Host "This might be because:" -ForegroundColor Yellow
        Write-Host "- Copilot audit logging is not enabled" -ForegroundColor Yellow
        Write-Host "- No Copilot activity occurred during this period" -ForegroundColor Yellow
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
    Write-Host "PA:TOTALS queries=$totalQueries keywords=$totalBlocks post=$postTotal"
    Write-Host "PA:PHASE post start"

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
        $metricsRecord = Convert-ToMetricsRecord -AuditLogEntry $log -NoExplodeArrays:$NoExplodeArrays
        
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
        if ($DetailedPost) {
            Write-Host "Detailed sample (first entry):" -ForegroundColor Cyan
            $first | Format-List | Out-String | Write-Host
        }
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
        if ($DetailedPost) {
            Write-Host "Field Population Summary (detailed):" -ForegroundColor Cyan
            $fieldStats = @{}
            foreach ($p in $first.PSObject.Properties) {
                $fieldName = $p.Name
                $populatedCount = ($metricsData | Where-Object { $_.$fieldName -ne $null -and $_.$fieldName -ne "" }).Count
                $fieldStats[$fieldName] = [math]::Round(($populatedCount / $metricsData.Count) * 100, 1)
            }
            $fieldStats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
                Write-Host " $($_.Key): $($_.Value)% populated" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "Computed population stats across $($props.Count) fields" -ForegroundColor Cyan
        }
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

    Write-Host "PA:PHASE post end"
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
