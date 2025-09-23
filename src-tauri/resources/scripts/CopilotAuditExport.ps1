#Requires -Modules ExchangeOnlineManagement

param(
    [Parameter(Mandatory = $false)]
    [string]$StartDate,
    [Parameter(Mandatory = $false)]
    [string]$EndDate,
    [Parameter(Mandatory = $false)]
    [string[]]$ActivityTypes = @(
        "CopilotChatAccessed",                # User accessed Copilot chat
        "CopilotPromptUsed",                  # User submitted a prompt to Copilot
        "CopilotQuerySentToBing",             # Copilot sent a query to Bing
        "CopilotInteractionSummaryViewed",    # User viewed Copilot interaction summary
        "MessageSent",                        # Message sent (Teams, Exchange)
        "MessageRead",                        # Message read (Teams, Exchange)
        "FileAccessed",                       # File accessed (SharePoint, OneDrive)
        "FileModified",                       # File modified (SharePoint, OneDrive)
        "FileDeleted",                        # File deleted (SharePoint, OneDrive)
        "UserLoggedIn",                       # User signed in (all products)
        "MeetingJoined",                      # User joined a Teams meeting
        "MeetingCreated",                     # User created a Teams meeting
        "ChannelMessageSent",                 # Message sent in a Teams channel
        "TeamCreated",                        # New Team created
        "SiteAccessed",                       # SharePoint site accessed
        "MailboxLogin",                       # User logged into mailbox (Exchange)
        "MailItemsAccessed",                  # Mail item accessed (Exchange)
        "MailItemsDeleted",                   # Mail item deleted (Exchange)
        "MailItemsSent",                      # Mail item sent (Exchange)
        "DocumentShared",                     # Document shared (SharePoint, OneDrive)
        "DocumentDownloaded"                  # Document downloaded (SharePoint, OneDrive)
        # ...add more as needed
    ),
    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "CopilotMetrics_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    [Parameter(Mandatory = $false)]
    [ValidateSet('WebLogin','DeviceCode','Credential','Silent')]
    [string]$Auth = 'WebLogin',
    [Parameter(Mandatory = $false)]
    [ValidateSet(2,4,6,8,12,24)]
    [int]$BlockHours = 8,
    [Parameter(Mandatory = $false)]
    [ValidateRange(1,5000)]
    [int]$ResultSize = 5000,
    [Parameter(Mandatory = $false)]
    [ValidateRange(0,10000)]
    [int]$PacingMs = 0,
    [Parameter(Mandatory = $false)]
    [switch]$DetailedPost,
    [Parameter(Mandatory = $false)]
    [switch]$Help,
    [Parameter(Mandatory = $false)]
    [switch]$InHelper
)

function Show-Help {
@"
Copilot/AI Purview Audit Log Extractor
--------------------------------------
This script exports Copilot/AI and user-facing activity records from Microsoft Purview (M365) audit logs and saves them to CSV for analysis.

USAGE EXAMPLES:
---------------
- Default (all Copilot/AI activities, default output file):
  .\YourScriptName.ps1 -StartDate "2025-09-01" -EndDate "2025-09-02"

- Custom output file location:
  .\YourScriptName.ps1 -StartDate "2025-09-01" -EndDate "2025-09-02" -OutputFile "C:\Reports\CopilotUsage.csv"

- Custom activity types (e.g., only CopilotChatAccessed and CopilotPromptUsed):
  .\YourScriptName.ps1 -StartDate "2025-09-01" -EndDate "2025-09-02" -ActivityTypes "CopilotChatAccessed","CopilotPromptUsed"

- Show help:
  .\YourScriptName.ps1 -help
  .\YourScriptName.ps1 /help



OPTIONS:
--------
-StartDate        (Required)  Start date for the search (format: yyyy-MM-dd)
-EndDate          (Required)  End date for the search (format: yyyy-MM-dd, exclusive)
-ActivityTypes    (Optional)  List of activity types to search for (default: most relevant Copilot/AI and user-facing actions)
-OutputFile       (Optional)  Path for the output CSV file (default: CopilotMetrics_<timestamp>.csv)
-Auth             (Optional)  Authentication mode: WebLogin (recommended), DeviceCode, Credential, or Silent. Default: WebLogin
-BlockHours       (Optional)  Hours per query window (choose 2,4,6,8,12,24). Default: 8 hours
-ResultSize       (Optional)  Max rows per API call to Purview audit. Range 1–5000. Default: 5000
-PacingMs         (Optional)  Milliseconds to sleep between API calls (0–10000). Default: 0 (no delay)
-DetailedPost     (Optional)  Show additional post-processing details (sample entry, field stats). Toggle does not change CSV contents.
-Help or /Help    (Optional)  Show this help message and exit

MOST RELEVANT ACTIVITY TYPES (not a complete list):
---------------------------------------------------
- CopilotChatAccessed: User accessed Copilot chat
- CopilotPromptUsed: User submitted a prompt to Copilot
- CopilotQuerySentToBing: Copilot sent a query to Bing
- CopilotInteractionSummaryViewed: User viewed Copilot interaction summary
- MessageSent: Message sent (Teams, Exchange)
- MessageRead: Message read (Teams, Exchange)
- FileAccessed: File accessed (SharePoint, OneDrive)
- FileModified: File modified (SharePoint, OneDrive)
- FileDeleted: File deleted (SharePoint, OneDrive)
- UserLoggedIn: User signed in (all products)
- MeetingJoined: User joined a Teams meeting
- MeetingCreated: User created a Teams meeting
- ChannelMessageSent: Message sent in a Teams channel
- TeamCreated: New Team created
- SiteAccessed: SharePoint site accessed
- MailboxLogin: User logged into mailbox (Exchange)
- MailItemsAccessed: Mail item accessed (Exchange)
- MailItemsDeleted: Mail item deleted (Exchange)
- MailItemsSent: Mail item sent (Exchange)
- DocumentShared: Document shared (SharePoint, OneDrive)
- DocumentDownloaded: Document downloaded (SharePoint, OneDrive)

For the full, up-to-date list of all activity types, visit:
https://learn.microsoft.com/en-us/purview/audit-log-activities

WHAT DOES THE SCRIPT DO?
------------------------
- Checks for and installs the ExchangeOnlineManagement module if needed
- Connects to Microsoft Purview (the official Microsoft 365 audit log system)
- Searches for Copilot, AI, and other user-facing activities in your organization, checking every $BlockHours hours in the date range you choose (EndDate is exclusive)
- Collects all relevant records and organizes them into a simple spreadsheet
- Saves the results as a CSV file in the location you specify

RESILIENCE & THROTTLING
-----------------------
- Applies exponential backoff with jitter on transient errors (429/503) and supports optional pacing between calls via -PacingMs.
- Tip: Add a small pacing value (e.g., 150–300ms) in busy tenants to reduce throttling.

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
    } elseif ($ActivityTypes -and $ActivityTypes.Count -eq 1 -and $ActivityTypes[0].Contains(',')) {
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
        $ps = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
        if (-not $ps) { $ps = (Get-Command powershell -ErrorAction SilentlyContinue)?.Source }
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
            } else {
                $parts += "-StartDate '" + ($StartDate -replace "'","''") + "'"
            }
        }
        if ($EndDate) { 
            if ($EndDate.StartsWith("'") -and $EndDate.EndsWith("'")) {
                $parts += "-EndDate " + $EndDate
            } else {
                $parts += "-EndDate '" + ($EndDate -replace "'","''") + "'"
            }
        }
        if ($ActivityTypes -and $ActivityTypes.Count -gt 0) {
            # For command line, join activities with comma and let the receiving script parse
            $escapedTypes = @()
            foreach ($act in $ActivityTypes) {
                $escapedTypes += ($act -replace "'","''")
            }
            $activityString = ($escapedTypes -join ',')
            $parts += "-ActivityTypes '" + $activityString + "'"
        }
        if ($OutputFile) { 
            if ($OutputFile.StartsWith("'") -and $OutputFile.EndsWith("'")) {
                $parts += "-OutputFile " + $OutputFile
            } else {
                $parts += "-OutputFile '" + ($OutputFile -replace "'","''") + "'"
            }
        }
        if ($OverrideAuth) {
            $parts += "-Auth " + $OverrideAuth
        } elseif ($Auth) {
            $parts += "-Auth " + $Auth
        }
        if ($BlockHours) { $parts += "-BlockHours $BlockHours" }
        if ($ResultSize) { $parts += "-ResultSize $ResultSize" }
        if ($PacingMs -ne $null) { $parts += "-PacingMs $PacingMs" }
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
    } catch {
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
    } catch {}
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
    } catch {
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
        # Clean up any stale sessions that can block new web logins
        try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch {}
        try { Get-PSSession | Where-Object { $_.ConfigurationName -like 'IPPS*' } | Remove-PSSession -ErrorAction SilentlyContinue } catch {}

        function Invoke-WebAuth {
            param()
            function Test-Param($cmd, $param) {
                try {
                    $c = Get-Command $cmd -ErrorAction SilentlyContinue
                    if (-not $c) { return $false }
                    return $c.Parameters.ContainsKey($param)
                } catch { return $false }
            }
            $exoCmd = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue
            $hasOpenWebPage = $false
            $hasUseWAM = $false
            if ($exoCmd) {
                $hasOpenWebPage = $exoCmd.Parameters.ContainsKey('OpenWebPage')
                $hasUseWAM = $exoCmd.Parameters.ContainsKey('UseWAM')
            }
            $useWamArgs = @{}
            if ($hasUseWAM) { $useWamArgs['UseWAM'] = $false }
            $attempts = @()
            if ($exoCmd) {
                if ($hasOpenWebPage) { 
                    $args = @{ ShowBanner = $false; OpenWebPage = $true }
                    foreach ($k in $useWamArgs.Keys) { $args[$k] = $useWamArgs[$k] }
                    $attempts += @{ Cmd = 'Connect-ExchangeOnline'; Args = $args; Name = 'EXO OpenWebPage' } 
                } elseif (Test-Param 'Connect-ExchangeOnline' 'UseWebLogin') {
                    $args = @{ ShowBanner = $false; UseWebLogin = $true }
                    foreach ($k in $useWamArgs.Keys) { $args[$k] = $useWamArgs[$k] }
                    $attempts += @{ Cmd = 'Connect-ExchangeOnline'; Args = $args; Name = 'EXO UseWebLogin' }
                }
            }
            foreach ($a in $attempts) {
                try {
                    $cmdName = [string]$a.Cmd
                    $args = [hashtable]$a.Args
                    Write-Host ("Opening web authentication (" + $a.Name + ")...") -ForegroundColor Yellow
                    & $cmdName @args -ErrorAction Stop | Out-Null
                    return $true
                } catch {
                    $msg = $_.Exception.Message
                    Write-Host ("Attempt '" + $a.Name + "' failed: " + $msg) -ForegroundColor DarkYellow
                }
            }
            return $false
        }

        function Ensure-ModernEXOModule {
            # Update only if neither '-OpenWebPage' nor '-UseWebLogin' is available
            $exo = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue
            $hasOpenWebPage = $exo -and $exo.Parameters.ContainsKey('OpenWebPage')
            $hasUseWebLogin = $exo -and $exo.Parameters.ContainsKey('UseWebLogin')
            if ($hasOpenWebPage -or $hasUseWebLogin) { return }
            Write-Host "Updating ExchangeOnlineManagement module to enable modern auth switches..." -ForegroundColor Yellow
            try {
                # Attempt to unload in-use modules to avoid update locks
                try { Remove-Module ExchangeOnlineManagement -Force -ErrorAction SilentlyContinue } catch {}
                try { Remove-Module PackageManagement -Force -ErrorAction SilentlyContinue } catch {}
                if (Get-Command Update-Module -ErrorAction SilentlyContinue) {
                    Update-Module ExchangeOnlineManagement -Scope CurrentUser -Force -ErrorAction Stop
                } else {
                    Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                }
                Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop
            } catch {
                Write-Host ("Module update failed: " + $_.Exception.Message) -ForegroundColor DarkYellow
            }
        }
            # Note: Using Connect-IPPSSession for interactive web auth to SCC.

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
            } catch {}
        }

        switch ($Auth.ToLower()) {
            'weblogin' {
                Show-EXOParamInfo
                # Try authentication in hidden process first with DisableWAM
                $connected = $false
                $exoCmd = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue
                
                if ($exoCmd) {
                    try {
                        Write-Host "Attempting Connect-ExchangeOnline authentication with DisableWAM..." -ForegroundColor Yellow
                        Connect-ExchangeOnline -ShowBanner:$false -DisableWAM -ErrorAction Stop | Out-Null
                        $connected = $true
                        Write-Host "Successfully connected with Connect-ExchangeOnline!" -ForegroundColor Green
                    } catch {
                        Write-Host ("Connect-ExchangeOnline with DisableWAM failed: " + $_.Exception.Message) -ForegroundColor DarkYellow
                        
                        # If DisableWAM fails, only then launch visible helper for authentication
                        if (-not $InHelper) { 
                            Write-Host "Launching visible helper for browser authentication..." -ForegroundColor Yellow
                            Start-VisibleReexecForAuth -Reason "browser authentication required" 
                        }
                        
                        # In helper process, try standard browser auth
                        try {
                            Write-Host "Attempting browser authentication in visible window..." -ForegroundColor Yellow
                            Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop | Out-Null
                            $connected = $true
                            Write-Host "Successfully connected with browser authentication!" -ForegroundColor Green
                        } catch {
                            Write-Host ("Browser authentication failed: " + $_.Exception.Message) -ForegroundColor Red
                            throw "WebLogin authentication failed"
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
                } catch {
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
                        } else {
                            Connect-ExchangeOnline -ShowBanner:$false -OpenWebPage -ErrorAction Stop | Out-Null
                        }
                    } catch {
                        Write-Host ("-OpenWebPage failed, retrying with -UseWebLogin: " + $_.Exception.Message) -ForegroundColor DarkYellow
                        Connect-ExchangeOnline -ShowBanner:$false -UseWebLogin -ErrorAction Stop | Out-Null
                    }
                }
            }
        }
        Write-Host "Connected successfully!" -ForegroundColor Green
        
        # If this is a helper process, exit after successful authentication
        if ($InHelper) {
            Write-Host "=== HELPER AUTHENTICATION COMPLETE ===" -ForegroundColor Green
            Write-Host "Authentication successful. Helper process exiting..." -ForegroundColor Green
            exit 0
        }
    } catch {
        Write-Error "Failed to connect: $($_.Exception.Message)"
        exit 1
    }
}

function Invoke-SearchUnifiedAuditLogWithRetry {
    param(
        [Parameter(Mandatory=$true)] [datetime]$Start,
        [Parameter(Mandatory=$true)] [datetime]$End,
        [Parameter(Mandatory=$false)] [string]$Operation,
        [Parameter(Mandatory=$true)] [int]$ResultSize,
        [Parameter(Mandatory=$true)] [int]$PacingMs,
        [Parameter(Mandatory=$false)] [int]$MaxRetries = 5
    )
    $attempt = 0
    while ($attempt -le $MaxRetries) {
        try {
            $params = @{ StartDate = $Start; EndDate = $End; ResultSize = $ResultSize; ErrorAction = 'Stop' }
            if ($Operation) { $params.Operations = $Operation }
            $res = Search-UnifiedAuditLog @params
            if ($PacingMs -gt 0) { Start-Sleep -Milliseconds $PacingMs }
            return $res
        } catch {
            $msg = $_.Exception.Message
            $status = $null
            try { $status = $_.Exception.Response.StatusCode.Value__ } catch {}
            $isThrottle = ($msg -match '429' -or $msg -match 'Too\s*Many\s*Requests' -or $msg -match 'throttl' -or $msg -match '503' -or $msg -match 'Service\s*Unavailable' -or $status -in 429,503)
            if (-not $isThrottle -or $attempt -ge $MaxRetries) {
                Write-Host ("  Request failed: " + $msg) -ForegroundColor DarkYellow
                break
            }
            $attempt++
            $base = 0.5
            $delay = [math]::Min(30.0, $base * [math]::Pow(2, $attempt - 1))
            $jitter = (Get-Random -Minimum 0 -Maximum 250) / 1000.0
            $total = $delay + $jitter + ([double]$PacingMs/1000.0)
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
    } catch {
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
        } else {
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
        "ExchangeItem" = "Exchange"
        "SharePointFileOperation" = "SharePoint"
        "OneDrive" = "OneDrive"
        "MicrosoftTeams" = "MicrosoftTeams"
        "CopilotInteraction" = "MicrosoftCopilot"
        "261" = "MicrosoftCopilot"  # CopilotInteraction RecordType
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
    } elseif ($Operation -match "Mail|Message" -and $RecordType -match "Exchange") {
        return "<message_$($timestamp)@tenant.onmicrosoft.com>"
    } elseif ($Operation -match "Team|Meeting" -or $RecordType -match "Teams") {
        return "19:meeting_$($timestamp)@thread.v2"
    } elseif ($RecordType -match "Copilot|261") {
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
        } else {
            return $Default
        }
    }
    return $current -or $Default
}

function Convert-ToMetricsRecord {
    param([object]$AuditLogEntry)
    $auditData = Parse-AuditData -AuditDataJson $AuditLogEntry.AuditData
    return [PSCustomObject]@{
        RecordId                             = $AuditLogEntry.Identity
        CreationDate                         = $AuditLogEntry.CreationDate
        RecordType                           = $AuditLogEntry.RecordType
        CreationDateIsoUtc                   = if ($AuditLogEntry.CreationDate) { $AuditLogEntry.CreationDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ') } else { $null }
        OrganizationId                       = Get-NestedProperty $auditData "OrganizationId" -Default "b1234567-89ab-cdef-0123-456789abcdef"
        UserType                             = Get-UserType -UserId $AuditLogEntry.UserIds -AuditData $auditData
        UserKey                              = Get-UserKey -UserId $AuditLogEntry.UserIds
        Workload                             = Get-WorkloadFromRecordType -RecordType $AuditLogEntry.RecordType
        Operation                            = $AuditLogEntry.Operations
        UserId                               = $AuditLogEntry.UserIds
        AssociatedAdminUnits                 = Get-NestedProperty $auditData "AssociatedAdminUnits"
        AssociatedAdminUnitsNames            = Get-NestedProperty $auditData "AssociatedAdminUnitsNames"
        AgentId                              = Get-NestedProperty $auditData "AgentId"
        AgentName                            = Get-NestedProperty $auditData "AgentName"
        AppIdentity_AppId                    = Get-NestedProperty $auditData "AppIdentity.AppId"
        AppIdentity_DisplayName              = Get-NestedProperty $auditData "AppIdentity.DisplayName"
        AppIdentity_PublisherId              = Get-NestedProperty $auditData "AppIdentity.PublisherId"
        ApplicationName                      = Get-NestedProperty $auditData "ApplicationName"
        CreationTime                         = Get-NestedProperty $auditData "CreationTime"
        CreationTimeIsoUtc                   = if ($auditData.CreationTime) { ([DateTime]$auditData.CreationTime).ToString('yyyy-MM-ddTHH:mm:ss.fffZ') } else { $null }
        ClientIP                             = Get-NestedProperty $auditData "ClientIP" -Default (Get-SyntheticClientIP -UserId $AuditLogEntry.UserIds)
        ObjectId                             = Get-NestedProperty $auditData "ObjectId" -Default (Get-SyntheticObjectId -Operation $AuditLogEntry.Operations -RecordType $AuditLogEntry.RecordType -AuditData $auditData)
        ResultStatus                         = Get-NestedProperty $auditData "ResultStatus" -Default "Succeeded"
        ClientRegion                         = Get-NestedProperty $auditData "ClientRegion"
        Audit_UserId                         = Get-NestedProperty $auditData "UserId"
        AppHost                              = Get-NestedProperty $auditData "AppHost"
        ThreadId                             = Get-NestedProperty $auditData "ThreadId"
        Context_Id                           = Get-NestedProperty $auditData "Context.Id"
        Context_Type                         = Get-NestedProperty $auditData "Context.Type"
        Message_Id                           = Get-NestedProperty $auditData "Message.Id"
        Message_isPrompt                     = Get-NestedProperty $auditData "Message.isPrompt"
        AccessedResource_Action              = Get-NestedProperty $auditData "AccessedResource.Action"
        AccessedResource_PolicyDetails       = Get-NestedProperty $auditData "AccessedResource.PolicyDetails"
        AccessedResource_SiteUrl             = Get-NestedProperty $auditData "AccessedResource.SiteUrl"
        AISystemPlugin_Id                    = Get-NestedProperty $auditData "AISystemPlugin.Id"
        AISystemPlugin_Name                  = Get-NestedProperty $auditData "AISystemPlugin.Name"
        ModelTransparencyDetails_ModelName   = Get-NestedProperty $auditData "ModelTransparencyDetails.ModelName"
        MessageIds                           = (Get-NestedProperty $auditData "MessageIds" -join ",")
    }
}

try {
    Write-Host "=== Copilot Metrics Extraction ===" -ForegroundColor Cyan
    Connect-ToComplianceCenter

    $startDateObj = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)
    $endDateObj = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null)
    Write-Host "Searching for Copilot audit logs from $($startDateObj.ToString('yyyy-MM-dd')) to $($endDateObj.ToString('yyyy-MM-dd'))..." -ForegroundColor Yellow

    $blockHours = [int]$BlockHours
    if ($blockHours -lt 1) { $blockHours = 12 }
    $blocksPerDay = [int](24 / $blockHours)
    $totalDays = ($endDateObj.Date - $startDateObj.Date).Days
    $totalBlocks = $totalDays * $blocksPerDay
    $totalActivities = $ActivityTypes.Count
    $totalQueries = $totalBlocks * $totalActivities
    $queryCount = 0

    # Emit explicit totals for host application to consume (ground truth)
    Write-Host "PA:TOTALS queries=$totalQueries keywords=$totalBlocks"

    $allLogs = @()
    Write-Host "PA:PHASE queries start"
    for ($day = $startDateObj.Date; $day -lt $endDateObj.Date; $day = $day.AddDays(1)) {
        Write-Host "Processing date: $($day.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
        for ($block = 0; $block -lt $blocksPerDay; $block++) {
            $startBlock = $day.AddHours($block * $blockHours)
            $endBlock = $startBlock.AddHours($blockHours)
            foreach ($activity in $ActivityTypes) {
                $queryCount++
                $percentComplete = [math]::Round(($queryCount / $totalQueries) * 100, 1)
                Write-Host "[$percentComplete%] Query $queryCount/$totalQueries - $($activity) ($($startBlock.ToString('yyyy-MM-dd HH:mm')) - $($endBlock.ToString('HH:mm')))" -ForegroundColor Gray
                $logs = Invoke-SearchUnifiedAuditLogWithRetry -Start $startBlock -End $endBlock -Operation $activity -ResultSize $ResultSize -PacingMs $PacingMs
                if ($logs) {
                    $allLogs += $logs
                    Write-Host "  Found $($logs.Count) records for $($activity) at $($startBlock.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Green
                } else {
                    Write-Host "  No records found for $($activity) ($($startBlock.ToString('yyyy-MM-dd HH:mm'))-$($endBlock.ToString('HH:mm')))" -ForegroundColor Yellow
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
                $allLogs += $additionalLogs
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
        convert = [int]$uniqueLogs.Count
        export  = 1
        sample  = 1
        stats   = 1
        finalize= 1
    }
    $postTotal = ($postCategories.Values | Measure-Object -Sum).Sum
    $postCount = 0
    Write-Host "PA:TOTALS queries=$totalQueries keywords=$totalBlocks post=$postTotal"
    Write-Host "PA:PHASE post start"

    # Convert
    Write-Host "PA:POST start convert total=$($postCategories.convert)" -ForegroundColor Yellow
    $metricsData = @()
    $i = 0
    foreach ($log in $uniqueLogs) {
        $i++
        $postCount = [math]::Min($postCount + 1, $postTotal)
        $percentPost = [math]::Round(($postCount / $postTotal) * 100, 1)
        Write-Host "[$percentPost%] Post $postCount/$postTotal - Converting ($i/$($postCategories.convert))" -ForegroundColor Gray
        if ($i -le 5 -and $i % 50 -eq 0) { Write-Host "Converting records..." -ForegroundColor Gray }
        $metricsRecord = Convert-ToMetricsRecord -AuditLogEntry $log
        $metricsData += $metricsRecord
        Write-Host "PA:POST progress convert $i/$($postCategories.convert)"
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
        $sampleUser   = ($first.PSObject.Properties["UserId"].Value)
        $sampleOp     = ($first.PSObject.Properties["Operation"].Value)
        $sampleTime   = ($first.PSObject.Properties["CreationDate"].Value)
        Write-Host "Sample captured: User='$sampleUser' Operation='$sampleOp' Time='$sampleTime'" -ForegroundColor Cyan
        if ($DetailedPost) {
            Write-Host "Detailed sample (first entry):" -ForegroundColor Cyan
            $first | Format-List | Out-String | Write-Host
        }
    } else {
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
        } else {
            Write-Host "Computed population stats across $($props.Count) fields" -ForegroundColor Cyan
        }
    } else {
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
    Write-Host "PA:DONE"
    exit 0
} catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    Write-Error $_.ScriptStackTrace
} finally {
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    } catch {
        # Ignore disconnection errors
    }
}
