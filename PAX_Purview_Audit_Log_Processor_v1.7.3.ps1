# Portable Audit eXporter (PAX) - Purview Audit Log Processor - v1.7.2
<#
.SYNOPSIS
    Export Microsoft Purview audit logs for Microsoft 365 Copilot and related activities with optional Purview-aligned row explosion and deep flattening.

.DESCRIPTION
    Modes:
        Standard       - One row per audit record (raw CopilotEventData JSON preserved)
        -ExplodeArrays - Produces canonical Purview exploded schema (35 fixed columns)
        -ExplodeDeep   - Same 35-column Purview schema + appended deep-flattened CopilotEventData.* columns
    
    Offline Replay (-RAWInputCSV):
        * Ingest a previously exported raw Purview audit CSV (must contain AuditData JSON column)
        * Skips authentication & live Search-UnifiedAuditLog queries entirely
        * Forces at least Purview array explosion even if -ExplodeArrays not supplied
        * Optional -ExplodeDeep further deep‑flattens CopilotEventData.*
        * Allows only filtering parameters (StartDate / EndDate / ActivityTypes / AgentId / AgentsOnly / PromptFilter / ExcludeAgents / UserIds) plus OutputFile & explosion switches
        * Disallowed with RAWInputCSV (error if present): BlockHours, ResultSize, PacingMs, Auth, ParallelMode, MaxParallelGroups, MaxConcurrency, EnableParallel, GroupNames
        * StartDate / EndDate act as inclusive(lower)/exclusive(upper) UTC filters on CreationDate in the replay dataset
        * ActivityTypes filters by Operation (case‑insensitive membership)
        * AgentId filters for specific AgentId value(s); AgentsOnly includes any record with an AgentId present
        * PromptFilter filters messages by isPrompt property (Prompt/Response/Both/Null)
        * ExcludeAgents removes records with AgentId present (inverse of AgentsOnly)
        * UserIds filters by UserId extracted from AuditData JSON (client-side filtering)
        * GroupNames is NOT supported in replay mode (requires authentication for group expansion)
        * Non‑exploded 1:1 mode is intentionally disabled for deterministic schema in offline transforms
    
    Filtering:
        -AgentId <string[]>         : Filter to records matching specific AgentId value(s)
        -AgentsOnly                 : Filter to records with any AgentId present (mutually exclusive with -ExcludeAgents)
        -ExcludeAgents              : Filter to records WITHOUT AgentId (mutually exclusive with -AgentId/-AgentsOnly)
        -PromptFilter <Prompt|Response|Both|Null>
            Prompt   : Only export messages where Message_isPrompt = True
            Response : Only export messages where Message_isPrompt = False
            Both     : Export messages with either True or False isPrompt values
            Null     : Only export messages with null/undefined isPrompt values (rare)
            Note: PromptFilter uses two-stage filtering for optimal performance:
                  Stage 1 (Pre-filter): Filters records before explosion based on message content
                  Stage 2 (Message-level): Filters individual messages during explosion
        
        -UserIds <string[]>         : Filter to specific user identifier(s)
            LIVE MODE: SERVER-SIDE filtering at Purview (efficient, no unnecessary data transfer)
            REPLAY MODE: CLIENT-SIDE filtering by extracting UserId from AuditData JSON (slower but functional)
            
            Accepted formats:
                • User Principal Name (UPN): "john.doe@contoso.com"
                • SMTP Address: "john.doe@contoso.com"
                • User GUID: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            Examples:
                -UserIds "john.doe@contoso.com"
                -UserIds "john.doe@contoso.com","jane.smith@contoso.com","bob.jones@contoso.com"
        
        -GroupNames <string[]>      : Filter to members of distribution/security group(s)
            LIVE MODE ONLY: Groups automatically expanded to individual users after authentication using Get-DistributionGroupMember
            REPLAY MODE: NOT SUPPORTED (requires authentication) - use -UserIds with explicit email addresses instead
            
            Accepted formats (LIVE MODE only):
                • Group Display Name: "Executive Leadership Team"
                • Group Email (Alias): "exec-team@contoso.com"
                • Group GUID: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
                • Distinguished Name: "CN=ExecTeam,OU=Groups,DC=contoso,DC=com"
            Examples:
                -GroupNames "Executive Leadership"
                -GroupNames "exec-team@contoso.com"
                -GroupNames "Engineering Managers","Product Leads","Sales Directors"
            Note: Groups are expanded once after authentication
                  Blocked in replay mode (-RAWInputCSV) - script will exit with error
        
        Combining UserIds + GroupNames (LIVE MODE ONLY):
            • When both are specified, the script combines and deduplicates the user lists
            • Example: -UserIds "ceo@contoso.com" -GroupNames "Board of Directors"
              Pulls records for the CEO plus all expanded board members (duplicates removed)
            • Not available in replay mode - use -UserIds only

    COMBINING FILTERS - Powerful Use Cases:
        
        All filters can be combined for highly targeted data extraction. Filter application order is now CONSISTENT across both modes:
        
        FILTER APPLICATION ORDER (BOTH MODES):
        1. User/Group filtering (server-side in live mode via -UserIds, client-side in replay mode)
        2. Agent filtering (AgentsOnly, AgentId, or ExcludeAgents)
        3. PromptFilter (during explosion: Prompt, Response, Both, or Null)
        
        NOTE: Applying User/Group filtering first improves performance by reducing the dataset before subsequent filters.
        
        TWO-FILTER COMBINATIONS:
        
        User + Agent:
            Use Case: Analyze specific user(s) interactions with Copilot agents
            Example: "Show me all agent usage by our power users"
            Command: -UserIds "poweruser@contoso.com" -AgentsOnly
        
        User + PromptFilter:
            Use Case: Focus on conversation patterns (prompts/responses) for specific users
            Example: "Show me only the questions asked by the executive team"
            Command: -GroupNames "Executive Team" -PromptFilter Prompt
            Result: Removes resource-only explosion rows, keeps only message data
        
        Agent + PromptFilter:
            Use Case: Analyze agent conversation quality, prompt engineering effectiveness
            Example: "Show me all prompts sent to our custom declarative agent"
            Command: -AgentId "CopilotStudio.Declarative.abc123" -PromptFilter Prompt
        
        THREE-FILTER COMBINATION:
        
        User + Agent + PromptFilter:
            Use Case: Deep-dive conversation analysis for specific users with agents
            Example: "Show me all questions the sales team asked our Sales Copilot agent"
            Command: -GroupNames "Sales Team" -AgentId "SalesCopilot.Agent" -PromptFilter Prompt
            Benefits:
                • Server-side filtering reduces data transfer (live mode)
                • Agent filter removes non-agent interactions
                • PromptFilter removes responses and resource-only rows
                • Result: Clean dataset of just sales team questions to the agent
        
        REPLAY MODE COMBINATIONS:
            All filter combinations work in replay mode except GroupNames
            Use -UserIds with explicit email addresses instead of -GroupNames
            Example: -RAWInputCSV "data.csv" -UserIds "user@contoso.com" -AgentsOnly -PromptFilter Both

    PowerShell 5.1 & 7+ supported. Parallel (Auto/On) requires 7+.

.EXECUTIONPOLICY
    No internal execution policy bypass. Use external host invocation if needed:
        powershell.exe -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
        pwsh.exe       -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

.POWERSHELLVERSIONS
    PS 5.1 & 7+. Parallelization requires PS 7+.

.EXAMPLE
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7..ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile C:\Temp\Copilot.csv
.EXAMPLE
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile C:\Temp\Copilot_exploded.csv
.EXAMPLE
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile C:\Temp\Copilot_deep.csv
.EXAMPLE
    powershell -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile C:\Temp\Copilot.csv
.EXAMPLE
    # Offline replay (simple forced explosion) of a previously exported raw CSV
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -OutputFile C:\Temp\Copilot_replay_exploded.csv
.EXAMPLE
    # Offline replay with date & activity filtering + deep flatten
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -ActivityTypes CopilotInteraction -OutputFile C:\Temp\Copilot_replay_deep.csv
.EXAMPLE
    # Deep flatten (wide) with higher schema sample & moderate chunk size (balance column coverage vs memory)
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 4000 -StreamingChunkSize 3000 -OutputFile C:\Temp\Copilot_deep_tuned.csv
.EXAMPLE
    # Extremely wide deep flatten: maximize schema sample, reduce chunk size for lower peak memory
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 6000 -StreamingChunkSize 1500 -OutputFile C:\Temp\Copilot_deep_memoryguard.csv
.EXAMPLE
    # Fast header freeze (narrow schema expectation) – smaller sample, larger chunk for throughput (risk: late columns ignored)
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 800 -StreamingChunkSize 6000 -OutputFile C:\Temp\Copilot_deep_fastfreeze.csv
.EXAMPLE
    # Filter to only records with agents present
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -AgentsOnly -OutputFile C:\Temp\Copilot_agents.csv
.EXAMPLE
    # Filter to only records WITHOUT agents
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -ExcludeAgents -OutputFile C:\Temp\Copilot_no_agents.csv
.EXAMPLE
    # Filter to only prompt messages (Message_isPrompt = True)
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -PromptFilter Prompt -OutputFile C:\Temp\Copilot_prompts.csv
.EXAMPLE
    # Filter to only response messages (Message_isPrompt = False)
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -PromptFilter Response -OutputFile C:\Temp\Copilot_responses.csv
.EXAMPLE
    # Combine filters: agents + prompts only
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -AgentsOnly -PromptFilter Prompt -OutputFile C:\Temp\Copilot_agent_prompts.csv
.EXAMPLE
    # Filter to specific users
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -UserIds "john.doe@contoso.com","jane.smith@contoso.com" -OutputFile C:\Temp\Copilot_users.csv
.EXAMPLE
    # Filter to security group members (automatically expanded)
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -GroupNames "Executive Leadership" -OutputFile C:\Temp\Copilot_executives.csv
.EXAMPLE
    # Filter to multiple groups
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -GroupNames "Executive Team","Engineering Managers" -OutputFile C:\Temp\Copilot_leadership.csv
.EXAMPLE
    # Combine individual users and groups
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -UserIds "ceo@contoso.com" -GroupNames "Board of Directors" -OutputFile C:\Temp\Copilot_mixed.csv
.EXAMPLE
    # Replay mode with user filtering (client-side filtering from JSON)
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -UserIds "john.doe@contoso.com","jane.smith@contoso.com" -OutputFile C:\Temp\Copilot_replay_users.csv
.EXAMPLE
    # COMBINING FILTERS: User + PromptFilter (conversation focus, removes resource-only rows)
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -UserIds "poweruser@contoso.com" -PromptFilter Both -OutputFile C:\Temp\User_Conversations.csv
.EXAMPLE
    # COMBINING FILTERS: Group + Agent (team adoption of specific agent)
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -GroupNames "Sales Team" -AgentsOnly -OutputFile C:\Temp\Sales_Agent_Usage.csv
.EXAMPLE
    # COMBINING FILTERS: User + Agent + PromptFilter (prompts sent to agents by specific users)
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -UserIds "analyst@contoso.com" -AgentId "DataAnalysis.Agent" -PromptFilter Prompt -OutputFile C:\Temp\Analyst_Agent_Prompts.csv
.EXAMPLE
    # COMBINING FILTERS: Replay mode with User + Agent + PromptFilter
    pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.2.ps1 -RAWInputCSV .\data.csv -UserIds "exec@contoso.com" -AgentsOnly -PromptFilter Both -OutputFile C:\Temp\Exec_Agent_Messages.csv
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$StartDate,  # Live mode: if omitted (with EndDate) auto-populated later; Replay: optional filter

    [Parameter(Mandatory = $false)]
    [string]$EndDate,    # Live mode: if omitted (with StartDate) auto-populated; Replay: optional filter

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "C:\Temp\CopilotInteraction_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",

    [Parameter(Mandatory = $false)]
    [ValidateSet('WebLogin', 'DeviceCode', 'Credential', 'Silent')]
    [string]$Auth = 'WebLogin',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0.016667, 24)]
    [double]$BlockHours = 0.5,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10000)]
    [int]$ResultSize = 10000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 10000)]
    [int]$PacingMs = 0,

    [Parameter(Mandatory = $false)]
    [string[]]$ActivityTypes = @('CopilotInteraction'),

    [Parameter(Mandatory = $false)]
    [switch]$ExplodeArrays,

    [Parameter(Mandatory = $false)]
    [switch]$ExplodeDeep,
    # Offline replay of a previously downloaded raw Purview audit CSV (bypasses live Search-UnifiedAuditLog)
    [Parameter(Mandatory = $false)]
    [string]$RAWInputCSV,
    [Parameter(Mandatory = $false)]
    [int]$MaxConcurrency = 2,
    [Parameter(Mandatory = $false)]
    [switch]$EnableParallel,
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 50)]
    [int]$MaxParallelGroups = 3,
    [Parameter(Mandatory = $false)]
    [ValidateSet('Off', 'On', 'Auto')]
    [string]$ParallelMode = 'Off',
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10000)]
    [int]$ExportProgressInterval = 10,

    # Streaming export is always-on
    [Parameter(Mandatory = $false)]
    [ValidateRange(100, 50000)]
    [int]$StreamingSchemaSample = 1000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(100, 50000)]
    [int]$StreamingChunkSize = 5000,

    [Parameter(Mandatory = $false)]
    [string[]]$AgentId,

    [Parameter(Mandatory = $false)]
    [switch]$AgentsOnly,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Prompt', 'Response', 'Both', 'Null')]
    [string]$PromptFilter,

    [Parameter(Mandatory = $false)]
    [switch]$ExcludeAgents,

    [Parameter(Mandatory = $false)]
    [string[]]$UserIds,

    [Parameter(Mandatory = $false)]
    [string[]]$GroupNames,

    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Display help if -Help switch is provided
if ($Help) {
    Get-Help $PSCommandPath -Full
    exit 0
}

# Script version: dynamically read from versions.json
try {
    $versionsPath = Join-Path $PSScriptRoot 'versions.json'
    if (Test-Path $versionsPath) { 
        $versionsData = (Get-Content -Raw $versionsPath) | ConvertFrom-Json
        $ScriptVersion = $versionsData.products.purview.version
    }
    else {
        # Fallback: try to read from parent directory (when script is in subdirectory)
        $parentVersionsPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'versions.json'
        if (Test-Path $parentVersionsPath) {
            $versionsData = (Get-Content -Raw $parentVersionsPath) | ConvertFrom-Json
            $ScriptVersion = $versionsData.products.purview.version
        }
    }
    if (-not $ScriptVersion) { 
        Write-Host "WARNING: Could not read version from versions.json. Using version from filename." -ForegroundColor Yellow
        # Extract version from script filename as last resort
        $scriptName = $MyInvocation.MyCommand.Name
        if ($scriptName -match 'v(\d+\.\d+\.\d+)') {
            $ScriptVersion = $matches[1]
        }
        else {
            $ScriptVersion = 'UNKNOWN'
            Write-Host "ERROR: Could not determine script version. Please ensure versions.json exists." -ForegroundColor Red
        }
    }
}
catch { 
    Write-Host "WARNING: Error reading version from versions.json: $($_.Exception.Message)" -ForegroundColor Yellow
    # Extract version from script filename as fallback
    $scriptName = $MyInvocation.MyCommand.Name
    if ($scriptName -match 'v(\d+\.\d+\.\d+)') {
        $ScriptVersion = $matches[1]
    }
    else {
        $ScriptVersion = 'UNKNOWN'
        Write-Host "ERROR: Could not determine script version. Please ensure versions.json exists." -ForegroundColor Red
    }
}

# --- Early parameter validation & environment sanity checks ---

# Validate mutual exclusivity of ExcludeAgents with AgentId/AgentsOnly
if ($ExcludeAgents -and ($AgentId -or $AgentsOnly)) {
    Write-Host "ERROR: -ExcludeAgents cannot be used with -AgentId or -AgentsOnly switches." -ForegroundColor Red
    Write-Host "These switches are mutually exclusive:" -ForegroundColor Yellow
    Write-Host "  -AgentId/-AgentsOnly: Filter to ONLY records with agents" -ForegroundColor Yellow
    Write-Host "  -ExcludeAgents: Filter to ONLY records without agents" -ForegroundColor Yellow
    Write-Host "Please use only one filtering approach and re-run." -ForegroundColor Yellow
    exit 1
}

# Establish date defaults / validation depending on mode.
if ($RAWInputCSV) {
    # Replay mode: dates are optional filters – only parse if explicitly supplied.
    $parsedStart = $null; $parsedEnd = $null
    if ($PSBoundParameters.ContainsKey('StartDate')) {
        try { $parsedStart = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null) } catch { Write-Host "ERROR: StartDate must be yyyy-MM-dd if provided." -ForegroundColor Red; exit 1 }
    }
    if ($PSBoundParameters.ContainsKey('EndDate')) {
        try { $parsedEnd = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null) } catch { Write-Host "ERROR: EndDate must be yyyy-MM-dd if provided." -ForegroundColor Red; exit 1 }
    }
    if ($parsedStart -and $parsedEnd -and $parsedEnd -lt $parsedStart) { Write-Host "ERROR: EndDate ($EndDate) is earlier than StartDate ($StartDate)." -ForegroundColor Red; exit 1 }
    # If not provided, set to asterisk for display purposes
    if (-not $PSBoundParameters.ContainsKey('StartDate')) { $StartDate = '*' }
    if (-not $PSBoundParameters.ContainsKey('EndDate')) { $EndDate = '*' }
}
else {
    # Live mode: allow partial date specification
    if (-not $PSBoundParameters.ContainsKey('StartDate') -and -not $PSBoundParameters.ContainsKey('EndDate')) {
        # Neither date provided: default to previous full UTC day window
        $yesterdayUtc = (Get-Date).ToUniversalTime().Date.AddDays(-1)
        $StartDate = $yesterdayUtc.ToString('yyyy-MM-dd')
        $EndDate = $yesterdayUtc.AddDays(1).ToString('yyyy-MM-dd')
    }
    elseif (-not $PSBoundParameters.ContainsKey('StartDate')) {
        # Only EndDate provided: set StartDate to asterisk (beginning of available data)
        $StartDate = '*'
        try {
            $parsedEnd = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null)
        } catch { Write-Host "ERROR: EndDate must be yyyy-MM-dd format." -ForegroundColor Red; exit 1 }
    }
    elseif (-not $PSBoundParameters.ContainsKey('EndDate')) {
        # Only StartDate provided: set EndDate to asterisk (up to current time)
        $EndDate = '*'
        try {
            $parsedStart = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)
        } catch { Write-Host "ERROR: StartDate must be yyyy-MM-dd format." -ForegroundColor Red; exit 1 }
    }
    else {
        # Both dates provided: validate them
        try {
            $parsedStart = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)
            $parsedEnd = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null)
        }
        catch { Write-Host "ERROR: StartDate/EndDate must be in yyyy-MM-dd format." -ForegroundColor Red; exit 1 }
        if ($parsedEnd -lt $parsedStart) { Write-Host "ERROR: EndDate ($EndDate) is earlier than StartDate ($StartDate)." -ForegroundColor Red; exit 1 }
    }
}

if ($BlockHours -le 0) { Write-Host "ERROR: BlockHours must be positive." -ForegroundColor Red; exit 1 }

try { if ($PSVersionTable.PSEdition -eq 'Core' -and ($global:InformationPreference -in @('SilentlyContinue', 'Ignore'))) { $global:InformationPreference = 'Continue' } } catch {}

# Safeguard: When using -RAWInputCSV, only filtering params (StartDate, EndDate, ActivityTypes, AgentId, AgentsOnly, UserIds) are allowed; others are invalid.
if ($RAWInputCSV) {
    $rawConflictParams = @('BlockHours', 'ResultSize', 'PacingMs', 'Auth', 'ParallelMode', 'MaxParallelGroups', 'MaxConcurrency', 'EnableParallel', 'GroupNames')
    $specifiedConflicts = @()
    foreach ($cp in $rawConflictParams) { if ($PSBoundParameters.ContainsKey($cp)) { $specifiedConflicts += $cp } }
    if ($specifiedConflicts.Count -gt 0) {
        Write-Host "ERROR: -RAWInputCSV cannot be combined with live query parameter(s): $($specifiedConflicts -join ', ')" -ForegroundColor Red
        Write-Host "Remove those conflicting parameters and re-run. Allowed with RAWInputCSV: StartDate, EndDate, ActivityTypes, AgentId, AgentsOnly, UserIds, OutputFile, explosion switches." -ForegroundColor Yellow
        Write-Host "Note: -GroupNames requires authentication and cannot be used in replay mode. Use -UserIds with explicit email addresses instead." -ForegroundColor Yellow
        exit 1
    }
}

$script:learnedActivityBlockSize = @{}
$script:globalLearnedBlockSize = $BlockHours
$script:subdivisionSequence = @(0.5, 0.25, 0.133333, 0.066667, 0.033333, 0.016667)
$script:Hit10KLimit = $false
$script:LimitTimeWindow = ""
$script:Connected = $false

$script:metrics = @{
    StartTime               = (Get-Date).ToUniversalTime()
    QueryMs                 = 0
    ExplosionMs             = 0
    ExportMs                = 0
    PagesFetched            = 0
    TotalRecordsFetched     = 0
    TotalStructuredRows     = 0
    ExplosionEvents         = 0
    ExplosionRowsFromEvents = 0
    ExplosionMaxPerRecord   = 0
    ExplosionTruncated      = $false
    ShrinkEvents            = 0
    Activities              = @{}
    EffectiveChunkSize      = 0
    ParallelBatchSizeFinal  = 0
    ParallelThrottleFinal   = 0
    AgentFilterApplied      = $false
    AgentFilterPreCount     = 0
    AgentFilterPostCount    = 0
    AgentFilterRemovedCount = 0
    AgentFilterElapsedSec   = 0
    ExcludeAgentsApplied    = $false
    ExcludeAgentsPreCount   = 0
    ExcludeAgentsPostCount  = 0
    ExcludeAgentsRemoved    = 0
    ExcludeAgentsElapsedSec = 0
    PromptFilterApplied     = $false
    PromptFilterType        = ''
    PromptFilterPreCount    = 0
    PromptFilterPostCount   = 0
    PromptFilterRemovedCount = 0
    PromptFilterElapsedSec  = 0
    PromptFilterMsgBefore   = 0
    PromptFilterMsgAfter    = 0
    PromptFilterMsgRemoved  = 0
    PromptFilterRecordsMixed = 0
    PromptFilterRecordsPromptOnly = 0
    PromptFilterRecordsResponseOnly = 0
    PromptFilterRecordsNoMessages = 0
}

# --- Configuration: depth & limits ---
# JSON serialization and flatten recursion depth settings.
$JsonDepth = 60                 # Max depth for all ConvertTo-Json operations
$FlatDepthStandard = 60         # Standard flatten depth (non-deep modes)
$FlatDepthDeep = 120            # Deep flatten recursion ceiling
$ExplosionPerRecordRowCap = 1000 # Max exploded rows per original record (safeguard)
# ExchangeOnlineManagement: no minimum version enforced (any reasonably current version works).

$script:TenantPrimaryDomain = $null
$script:TenantId = $null
$script:TenantIndicators = @()

# Forced explosion when using raw/offline input CSV (always at least Purview exploded schema)
$ForcedRawInputCsvExplosion = $false
if ($RAWInputCSV) { $ForcedRawInputCsvExplosion = $true }

# --- Compiled regex patterns for efficient string matching ---
# Pre-compile regex patterns to improve performance during data processing
$script:RegexTrueFalse = [regex]::new('^(?i:true|false)$', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:RegexYes1 = [regex]::new('^(?i:yes|1)$', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:RegexNo0 = [regex]::new('^(?i:no|0)$', [System.Text.RegularExpressions.RegexOptions]::Compiled)

# Optimized helper functions (defined once at script scope, not per-record)
function script:Format-DatePurviewFast($dt) {
    if (-not $dt) { return '' }
    try {
        if ($dt -is [datetime]) { 
            return $dt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        }
        else { 
            $p = [datetime]::Parse($dt)
            return $p.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        }
    }
    catch { return '' }
}

function script:BoolTFFast($v) {
    if ($null -eq $v) { return '' }
    if ($v -is [bool]) { return $v.ToString().ToUpper() }
    $vStr = [string]$v
    if ($script:RegexTrueFalse.IsMatch($vStr)) { return $vStr.ToUpper() }
    if ($script:RegexYes1.IsMatch($vStr)) { return 'TRUE' }
    if ($script:RegexNo0.IsMatch($vStr)) { return 'FALSE' }
    return $vStr
}

function script:ToJsonIfObjectFast($v) {
    if ($null -eq $v) { return '' }
    if (Test-ScalarValue $v) { return $v }
    try { return ($v | ConvertTo-Json -Depth $JsonDepth -Compress) }
    catch { return [string]$v }
}

function script:GetArrayFast($parent, [string]$name) {
    $val = Get-SafeProperty $parent $name
    if ($null -eq $val) { return @() }
    if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
        return @($val)
    }
    return @($val)
}

$effectiveExplodeForProgress = ($ExplodeDeep -or $ExplodeArrays -or $ForcedRawInputCsvExplosion)
$legacyParallelSwitchUsed = $EnableParallel.IsPresent
if ($legacyParallelSwitchUsed) { $ParallelMode = 'On' }

function Get-ParallelActivationDecision { param([array]$QueryPlan, [string]$ParallelMode, [int]$MaxParallelGroups, [int]$MaxConcurrency) $ps7 = ($PSVersionTable.PSVersion.Major -ge 7); $highGroups = ($QueryPlan | Where-Object { $_.Group -eq 'High' }).Count; $mediumGroups = ($QueryPlan | Where-Object { $_.Group -eq 'Medium' }).Count; $lowGroups = ($QueryPlan | Where-Object { $_.Group -eq 'Low' }).Count; $totalGroups = $QueryPlan.Count; $totalActivities = ($QueryPlan | ForEach-Object { $_.Activities.Count } | Measure-Object -Sum).Sum; $autoEligible = $ps7 -and ($MaxParallelGroups -gt 0) -and ($MaxConcurrency -gt 1) -and ($highGroups -le 1) -and (($mediumGroups + $lowGroups) -ge 1) -and ($totalActivities -le 15) -and ($totalGroups -gt 1); switch ($ParallelMode) { 'On' { return @{ Enabled = ($ps7 -and $MaxParallelGroups -gt 0 -and $MaxConcurrency -gt 0); Reason = if ($ps7) { 'Forced On' } else { 'PS < 7 (cannot parallel)' }; AutoEligible = $autoEligible } } 'Auto' { return @{ Enabled = $autoEligible; Reason = if ($autoEligible) { 'Auto criteria met' } else { 'Auto criteria not met' }; AutoEligible = $autoEligible } } default { return @{ Enabled = $false; Reason = 'Mode Off'; AutoEligible = $autoEligible } } } }

$weights = if ($effectiveExplodeForProgress) { @{ Query = 0.30; Explosion = 0.60; Export = 0.10 } } else { @{ Query = 0.80; Explosion = 0.00; Export = 0.20 } }
# Replay mode: Allocate progress weights to Parsing, Explosion, and Export phases
if ($RAWInputCSV) {
    try {
        $weights = @{ Parsing = 0.10; Query = 0.0; Explosion = 0.80; Export = 0.10 }
    }
    catch {}
}
$script:progressState = @{ Weights = $weights; Phase = 'Query'; Parsing = @{Current = 0; Total = 0 }; Query = @{Current = 0; Total = 0 }; Explode = @{Current = 0; Total = 0 }; Export = @{Current = 0; Total = 1 } }
function Set-ProgressPhase { param([ValidateSet('Parsing', 'Query', 'Explosion', 'Export', 'Complete')] [string]$Phase, [string]$Status = ''); $script:progressState.Phase = $Phase; Update-Progress -Status $Status }
function Update-Progress {
    param(
        [string]$Status = '',
        [int]$BatchCurrent = 0,
        [int]$BatchTotal = 0,
        [int]$BatchRangeStart = 0,
        [int]$BatchRangeEnd = 0,
        [int]$BatchStartPercent = 0,
        [int]$BatchEndPercent = 0,
        [bool]$BatchTotalIsEstimate = $false
    )
    $w = $script:progressState.Weights; $ps = $script:progressState.Parsing; $qs = $script:progressState.Query; $es = $script:progressState.Explode; $xs = $script:progressState.Export
    $pPct = if ($ps.Total -gt 0 -and $w.ContainsKey('Parsing') -and $w.Parsing -gt 0) { [double]$ps.Current / [double]$ps.Total } else { 0.0 }
    $qPct = if ($qs.Total -gt 0) { [double]$qs.Current / [double]$qs.Total } else { 0.0 }
    $ePct = if ($es.Total -gt 0 -and $w.Explosion -gt 0) { [double]$es.Current / [double]$es.Total } else { 0.0 }
    $xPct = if ($xs.Total -gt 0) { [double]$xs.Current / [double]$xs.Total } else { 0.0 }
    $parsingWeight = if ($w.ContainsKey('Parsing')) { $w.Parsing } else { 0.0 }
    $overall = ($parsingWeight * $pPct) + ($w.Query * $qPct) + ($w.Explosion * $ePct) + ($w.Export * $xPct)
    $pct = [int]([Math]::Round($overall * 100))
    $phase = $script:progressState.Phase
    $pDetail = if ($w.ContainsKey('Parsing') -and $w.Parsing -gt 0 -and $ps.Total -gt 0) { "{0}/{1}({2}%)" -f $ps.Current, $ps.Total, ([int]([Math]::Round($pPct * 100))) } else { '' }
    $qDetail = if ($w.Query -gt 0 -and $qs.Total -gt 0) { "{0}/{1}({2}%)" -f $qs.Current, $qs.Total, ([int]([Math]::Round($qPct * 100))) } else { '' }
    # Format explosion progress display with batch range if provided
    if ($BatchRangeStart -ge 1 -and $BatchRangeEnd -ge 1 -and $es.Total -gt 0) {
        # Show record range for current batch with batch number and percentage range inline
        if ($BatchStartPercent -ge 0 -and $BatchEndPercent -gt 0) {
            # Use provided percentage range
            $batchTotalDisplay = if ($BatchTotalIsEstimate) { "~$BatchTotal" } else { "$BatchTotal" }
            $batchInfo = if ($BatchTotal -ge 1) { " Batch: {0}/{1}({2}%-{3}%)" -f $BatchCurrent, $batchTotalDisplay, $BatchStartPercent, $BatchEndPercent } else { '' }
        }
        else {
            # Fallback to calculating from batch count
            $batchPct = if ($BatchTotal -gt 0 -and $BatchCurrent -gt 0) { [int]([Math]::Round(([double]$BatchCurrent / [double]$BatchTotal) * 100)) } else { 0 }
            $batchTotalDisplay = if ($BatchTotalIsEstimate) { "~$BatchTotal" } else { "$BatchTotal" }
            $batchInfo = if ($BatchTotal -ge 1) { " Batch: {0}/{1}({2}%)" -f $BatchCurrent, $batchTotalDisplay, $batchPct } else { '' }
        }
        $explosionCounts = "Records {0}-{1}/{2}{3}" -f $BatchRangeStart, $BatchRangeEnd, $es.Total, $batchInfo
    }
    elseif ($BatchTotal -ge 1) {
        # Fallback: show current record with batch info inline (same style as range format)
        $batchPct = if ($BatchTotal -gt 0 -and $BatchCurrent -gt 0) { [int]([Math]::Round(([double]$BatchCurrent / [double]$BatchTotal) * 100)) } else { 0 }
        $batchTotalDisplay = if ($BatchTotalIsEstimate) { "~$BatchTotal" } else { "$BatchTotal" }
        $batchInfo = " Batch: {0}/{1}({2}%)" -f $BatchCurrent, $batchTotalDisplay, $batchPct
        $explosionCounts = if ($es.Total -gt 0) { "Records {0}/{1}{2}" -f $es.Current, $es.Total, $batchInfo } else { "0/0" }
    }
    else {
        # Standard format without batching
        $explosionCounts = if ($es.Total -gt 0) { "{0}/{1}({2}%)" -f $es.Current, $es.Total, ([int]([Math]::Round($ePct * 100))) } else { '0/0' }
    }
    $eDetail = if ($w.Explosion -gt 0) {
        if ($phase -eq 'Explosion') {
            " | $explosionCounts"
        }
        else {
            " | Explosion: $explosionCounts"
        }
    }
    else { '' }
    # Batch detail is now always included inline with explosion when BatchTotal is provided
    $batchDetail = ''
    $xDetail = if ($xs.Total -gt 0) { " | Export: {0}/{1}({2}%)" -f $xs.Current, $xs.Total, ([int]([Math]::Round($xPct * 100))) } else { ' | Export: 0/0' }
    
    # Build phase prefix with filter indicator
    $parsingLabel = 'Pre-parsing JSON'
    if (($AgentId -or $AgentsOnly -or $ExcludeAgents -or $PromptFilter) -and $phase -eq 'Parsing') {
        $parsingLabel = 'Pre-parsing + Filtering'
    }
    $phasePrefix = switch ($phase) { 'Parsing' { $parsingLabel } 'Query' { 'Query' } 'Explosion' { 'Explosion' } 'Export' { 'Export' } 'Complete' { 'Complete' } default { $phase } }
    
    if ($phase -eq 'Parsing' -and $pDetail) {
        $composite = "${phasePrefix}: $pDetail$eDetail$batchDetail$xDetail"
    }
    elseif ($phase -eq 'Explosion' -and -not $qDetail) {
        $composite = "Explosion: $explosionCounts$batchDetail$xDetail"
    }
    else {
        $composite = if ($qDetail) { "${phasePrefix}: $qDetail$eDetail$batchDetail$xDetail" } else { "${phasePrefix}:$eDetail$batchDetail$xDetail" }
    }
    $statusText = if ($Status) { "$Status :: $composite" } else { $composite }
    if ($statusText.Length -gt 180) { $statusText = $statusText.Substring(0, 177) + '...' }
    
    try {
        Write-Progress -Activity "PAX Purview Audit Log Processing" -Status $statusText -PercentComplete $pct
    }
    catch {}
}
function Complete-Progress { 
    try { 
        Write-Progress -Activity "PAX Purview Audit Log Processing" -Completed
    }
    catch {}
}

$script:highVolumeActivities = @('CopilotInteraction', 'MessageSent', 'FileAccessed', 'MailItemsAccessed')
$script:mediumVolumeActivities = @('MessageRead', 'FileModified', 'MeetingDetail', 'SearchQueryPerformed')
$script:lowVolumeActivities = @('CreatePlugin', 'UpdatePlugin', 'DeletePlugin', 'EnablePlugin', 'DisablePlugin')

function Get-QueryPlan { param([string[]]$RequestedActivities, [int]$MediumBatchSize = 3, [int]$LowBatchSize = 5) $normalized = @(); foreach ($a in $RequestedActivities) { if ($a -and -not ($normalized -contains $a)) { $normalized += $a } } $high = @(); $medium = @(); $low = @(); foreach ($a in $normalized) { $class = Get-ActivityVolumeClassification -ActivityType $a; switch ($class) { 'High' { $high += $a } 'Medium' { $medium += $a } default { $low += $a } } } $plan = @(); foreach ($a in $high) { $plan += @{ Name = "High: $a"; Group = 'High'; Activities = @($a); Concurrency = 1 } } if ($medium.Count -gt 0) { $batches = @(); $current = @(); foreach ($a in $medium) { $current += $a; if ($current.Count -ge $MediumBatchSize) { $batches += , @($current); $current = @() } } if ($current.Count -gt 0) { $batches += , @($current) } $i = 1; foreach ($b in $batches) { $plan += @{ Name = "Medium batch #$i"; Group = 'Medium'; Activities = $b; Concurrency = [Math]::Min(2, $b.Count) }; $i++ } } if ($low.Count -gt 0) { $batches = @(); $current = @(); foreach ($a in $low) { $current += $a; if ($current.Count -ge $LowBatchSize) { $batches += , @($current); $current = @() } } if ($current.Count -gt 0) { $batches += , @($current) } $i = 1; foreach ($b in $batches) { $plan += @{ Name = "Low batch #$i"; Group = 'Low'; Activities = $b; Concurrency = [Math]::Min($MaxConcurrency, [Math]::Max(1, [int]([Math]::Ceiling($b.Count / 2)))) }; $i++ } } if ($plan.Count -eq 0) { $plan += @{ Name = 'Custom'; Group = 'Custom'; Activities = $normalized; Concurrency = 1 } } return $plan }
function Get-OptimalBlockSize { param([string]$ActivityType) if ($script:learnedActivityBlockSize.ContainsKey($ActivityType)) { return $script:learnedActivityBlockSize[$ActivityType] } elseif ($script:globalLearnedBlockSize -ne $BlockHours) { return $script:globalLearnedBlockSize } else { $classification = Get-ActivityVolumeClassification -ActivityType $ActivityType; switch ($classification) { 'High' { 0.5 } 'Medium' { 2.0 } 'Low' { 8.0 } default { $BlockHours } } } }
function Update-LearnedBlockSize { 
    param([string]$ActivityType, [double]$BlockHours, [int]$RecordCount, [bool]$Success) 
    
    if ($Success) { 
        # Hit 10K limit - reduce aggressively
        if ($RecordCount -eq $ResultSize) { 
            $newSize = [Math]::Max(0.083333, $BlockHours * 0.5)  # Reduce by 50%, min 5 minutes
            $script:learnedActivityBlockSize[$ActivityType] = $newSize
            $script:globalLearnedBlockSize = [Math]::Min($script:globalLearnedBlockSize, $newSize)
            Write-LogHost "    → Learned: Reducing block size to $([math]::Round($newSize,2))h due to limit hit" -ForegroundColor Magenta
        } 
        # Very high volume (>8K records) - proactive reduction
        elseif ($RecordCount -gt ($ResultSize * 0.8)) {
            $newSize = [Math]::Max(0.083333, $BlockHours * 0.7)  # Reduce by 30%, min 5 minutes
            $script:learnedActivityBlockSize[$ActivityType] = $newSize
            Write-LogHost "    → Learned: Reducing block size to $([math]::Round($newSize,2))h (high volume: $RecordCount records)" -ForegroundColor Magenta
        }
        # Low volume (<10% of limit) - increase for efficiency
        elseif ($RecordCount -lt ($ResultSize * 0.1)) { 
            $newSize = [Math]::Min(24.0, $BlockHours * 1.5)  # Increase by 50%, max 24 hours
            $script:learnedActivityBlockSize[$ActivityType] = $newSize
            Write-LogHost "    → Learned: Increasing block size to $([math]::Round($newSize,2))h (low volume: $RecordCount records)" -ForegroundColor Magenta
        }
        # Very low volume (<5% of limit) - increase aggressively
        elseif ($RecordCount -lt ($ResultSize * 0.05)) {
            $newSize = [Math]::Min(24.0, $BlockHours * 2.0)  # Double size, max 24 hours
            $script:learnedActivityBlockSize[$ActivityType] = $newSize
            Write-LogHost "    → Learned: Increasing block size to $([math]::Round($newSize,2))h (very low volume: $RecordCount records)" -ForegroundColor Magenta
        }
    } 
    else { 
        # Failure - reduce block size
        $newSize = [Math]::Max(0.083333, $BlockHours * 0.5)  # Reduce by 50%, min 5 minutes
        $script:learnedActivityBlockSize[$ActivityType] = $newSize
        $script:globalLearnedBlockSize = [Math]::Min($script:globalLearnedBlockSize, $newSize)
        Write-LogHost "    → Learned: Reducing block size to $([math]::Round($newSize,2))h due to failure" -ForegroundColor Magenta
    } 
}
function Get-NextSmallerBlockSize { param([double]$CurrentSize) foreach ($size in $script:subdivisionSequence) { if ($size -lt $CurrentSize) { return $size } } return [Math]::Max(0.016667, $CurrentSize / 2) }
function Get-ActivityVolumeClassification { param([string]$ActivityType) if ($script:highVolumeActivities -contains $ActivityType) { 'High' } elseif ($script:mediumVolumeActivities -contains $ActivityType) { 'Medium' } else { 'Low' } }

function Invoke-ActivityTimeWindowProcessing { 
    param(
        [Parameter(Mandatory = $true)][string]$ActivityType, 
        [Parameter(Mandatory = $true)][datetime]$StartDate, 
        [Parameter(Mandatory = $true)][datetime]$EndDate
    ) 
    
    Write-Host "Processing $ActivityType from $($StartDate.ToString('yyyy-MM-dd HH:mm')) to $($EndDate.ToString('yyyy-MM-dd HH:mm'))..." -ForegroundColor White
    $blockHours = Get-OptimalBlockSize -ActivityType $ActivityType
    Write-Host "  Using initial block size: $blockHours hours" -ForegroundColor DarkCyan
    
    $allResults = New-Object System.Collections.ArrayList
    $current = $StartDate
    $blockNumber = 1
    
    while ($current -lt $EndDate) { 
        # Apply learned block size dynamically (updates after each query)
        if ($script:learnedActivityBlockSize.ContainsKey($ActivityType)) {
            $blockHours = $script:learnedActivityBlockSize[$ActivityType]
        }
        
        $blockEnd = $current.AddHours($blockHours)
        if ($blockEnd -gt $EndDate) { $blockEnd = $EndDate }
        
        $actualBlockHours = [math]::Round(($blockEnd - $current).TotalHours, 2)
        Write-Host "  Block $blockNumber`: $($current.ToString('yyyy-MM-dd HH:mm')) to $($blockEnd.ToString('yyyy-MM-dd HH:mm')) ($($actualBlockHours)h)" -ForegroundColor Yellow
        
        try { 
            $results = Invoke-SearchUnifiedAuditLogWithRetry -Start $current -End $blockEnd -Operation $ActivityType -ResultSize $ResultSize -UserIds $script:targetUsers -AutoSubdivide $true
            
            if ($results -and $results.Count -gt 0) { 
                $null = $allResults.AddRange($results)
                Write-Host "    Added $($results.Count) records (total: $($allResults.Count))" -ForegroundColor Green
                Update-LearnedBlockSize -ActivityType $ActivityType -BlockHours $actualBlockHours -RecordCount $results.Count -Success $true
            } 
            else { 
                Write-Host "    No records found in this block" -ForegroundColor Gray
            } 
        } 
        catch { 
            Write-Host "    Block failed: $($_.Exception.Message)" -ForegroundColor Red
            Update-LearnedBlockSize -ActivityType $ActivityType -BlockHours $actualBlockHours -RecordCount 0 -Success $false
            
            # Retry with smaller block on failure
            if ($blockHours -gt 0.5) { 
                $smallerBlockHours = Get-NextSmallerBlockSize -CurrentSize $blockHours
                Write-Host "    Retrying with smaller $smallerBlockHours hour block..." -ForegroundColor Yellow
                
                try { 
                    $blockEnd = $current.AddHours($smallerBlockHours)
                    if ($blockEnd -gt $EndDate) { $blockEnd = $EndDate }
                    
                    $results = Invoke-SearchUnifiedAuditLogWithRetry -Start $current -End $blockEnd -Operation $ActivityType -ResultSize $ResultSize -UserIds $script:targetUsers -AutoSubdivide $true
                    
                    if ($results -and $results.Count -gt 0) { 
                        $null = $allResults.AddRange($results)
                        Write-Host "      Smaller block succeeded: $($results.Count) records" -ForegroundColor Green
                        Update-LearnedBlockSize -ActivityType $ActivityType -BlockHours $smallerBlockHours -RecordCount $results.Count -Success $true
                        $blockHours = $smallerBlockHours
                    } 
                } 
                catch { 
                    Write-Host "      Smaller block also failed: $($_.Exception.Message)" -ForegroundColor Red
                } 
            } 
        } 
        
        try { 
            if ($script:progressState.Query.Current -ge $script:progressState.Query.Total) { 
                $script:progressState.Query.Total += 1
            } 
            $script:progressState.Query.Current += 1
            Update-Progress
        } 
        catch {}
        
        $current = $blockEnd
        $blockNumber++
    } 
    
    Write-Host "  Completed $ActivityType`: $($allResults.Count) total records" -ForegroundColor Green
    return $allResults.ToArray()
}

$LogFile = $OutputFile -replace '\.csv$', '.log'
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [string]$Level = "INFO") $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; $logEntry = "[$timestamp] [$Level] $Message"; Write-Host $Message; try { Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue } catch {} }
function Write-LogHost { param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message, [string]$ForegroundColor = "White") Write-Host $Message -ForegroundColor $ForegroundColor; try { $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; $logEntry = "[$timestamp] [INFO] $Message"; Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue } catch {} }

# --- Fast CSV Writer Utilities ---
function Open-CsvWriter {
    param([string]$Path, [string[]]$Columns)
    $enc = New-Object System.Text.UTF8Encoding($false)
    $script:PAX_CsvWriter = [System.IO.StreamWriter]::new($Path, $false, $enc)
    $escapedCols = New-Object System.Collections.Generic.List[string]
    foreach ($col in $Columns) {
        $c = [string]$col
        $needsQuote = ($c -match '[",\r\n]') -or $c.StartsWith(' ') -or $c.EndsWith(' ')
        $escaped = $c -replace '"', '""'
        if ($needsQuote) { $escaped = '"' + $escaped + '"' }
        $escapedCols.Add($escaped) | Out-Null
    }
    # Correct scope: write header with the script-scoped writer
    $script:PAX_CsvWriter.WriteLine(($escapedCols -join ','))
}
function Close-CsvWriter { if ($script:PAX_CsvWriter) { try { $script:PAX_CsvWriter.Flush(); $script:PAX_CsvWriter.Dispose() } catch {}; Remove-Variable PAX_CsvWriter -Scope Script -ErrorAction SilentlyContinue } }
function Write-CsvRows {
    param([System.Collections.IEnumerable]$Rows, [string[]]$Columns)
    if (-not $Rows) { return }
    if (-not $script:PAX_CsvWriter) { throw "CSV writer not initialized" }
    $sb = New-Object System.Text.StringBuilder
    foreach ($row in $Rows) {
        if ($null -eq $row) { continue }
        $fieldValues = New-Object System.Collections.Generic.List[string]
        foreach ($col in $Columns) {
            $val = $null; try { $val = $row.$col } catch {}
            if ($null -eq $val) { $fieldValues.Add("") | Out-Null; continue }
            if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) { try { $val = ($val | ForEach-Object { if ($_ -ne $null) { [string]$_ } else { '' } }) -join ';' } catch { $val = [string]$val } }
            $s = [string]$val
            if ($s -match '[",\r\n]' -or $s.StartsWith(' ') -or $s.EndsWith(' ')) { $s = '"' + ($s -replace '"', '""') + '"' }
            $fieldValues.Add($s) | Out-Null
        }
        [void]$sb.AppendLine(($fieldValues -join ','))
        if ($sb.Length -gt 1048576) {
            # flush every ~1MB
            $script:PAX_CsvWriter.Write($sb.ToString()); $sb.Clear() | Out-Null
        }
    }
    if ($sb.Length -gt 0) { $script:PAX_CsvWriter.Write($sb.ToString()) }
}

# --- Agent Filtering Function ---
function Test-AgentFilter {
    param(
        [Parameter(Mandatory = $true)]
        $ParsedAuditData,
        [string[]]$AgentIdFilter,
        [bool]$AgentsOnlyFilter
    )
    
    # If no agent filters specified, include the record
    if (-not $AgentIdFilter -and -not $AgentsOnlyFilter) {
        return $true
    }
    
    # Extract AgentId from parsed JSON (top-level property)
    $recordAgentId = $null
    try {
        if ($ParsedAuditData.AgentId) {
            $recordAgentId = [string]$ParsedAuditData.AgentId
        }
    }
    catch {
        # If parsing fails, skip this record
        return $false
    }
    
    # If AgentsOnly filter is active, check if AgentId exists
    if ($AgentsOnlyFilter) {
        if ([string]::IsNullOrWhiteSpace($recordAgentId)) {
            return $false
        }
        # If only AgentsOnly is specified (no specific AgentId filter), include any record with an AgentId
        if (-not $AgentIdFilter) {
            return $true
        }
    }
    
    # If specific AgentId filter is provided, check if this record matches
    if ($AgentIdFilter) {
        if ([string]::IsNullOrWhiteSpace($recordAgentId)) {
            return $false
        }
        # Check if the record's AgentId matches any of the specified AgentIds
        foreach ($filterId in $AgentIdFilter) {
            if ($recordAgentId -eq $filterId) {
                return $true
            }
        }
        return $false
    }
    
    # Default: include the record
    return $true
}

$outputDir = Split-Path $OutputFile -Parent; if (-not (Test-Path $outputDir)) { New-Item -Path $outputDir -ItemType Directory -Force | Out-Null }
$scriptMode = if ($ExplodeDeep) { "Deep Column Explosion" } elseif ($ExplodeArrays -or $ForcedRawInputCsvExplosion) { if ($ForcedRawInputCsvExplosion -and -not $ExplodeArrays.IsPresent -and -not $ExplodeDeep.IsPresent) { "Array Explosion (RAWInput implied)" } else { "Array Explosion" } } else { "Standard (1:1)" }
@"
=== Portable Audit eXporter (PAX) - Purview Audit Log Exporter ===
Script Start Time (UTC): $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC
Script Version: v$ScriptVersion
Mode: $scriptMode
Date Range: $(if ($RAWInputCSV) { if ([string]::IsNullOrWhiteSpace($StartDate) -and [string]::IsNullOrWhiteSpace($EndDate)) { 'Full CSV (no date filter)' } else { "$StartDate (inclusive) to $EndDate (exclusive) (filters)" } } else { "$StartDate (inclusive) to $EndDate (exclusive)" })
Output File: $OutputFile
Log File: $LogFile
========================================================

"@ | Out-File -FilePath $LogFile -Encoding UTF8

Write-LogHost "=== Portable Audit eXporter (PAX) - Purview Audit Log Exporter ===" -ForegroundColor Cyan
Write-LogHost ("Script Version: v$ScriptVersion") -ForegroundColor White
$startTimeStamp = try { $script:metrics.StartTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') } catch { (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') }
Write-LogHost ("Script execution started at $startTimeStamp UTC") -ForegroundColor White
Write-LogHost "Mode: $scriptMode" -ForegroundColor White
${rangeText} = if ($RAWInputCSV) { if ([string]::IsNullOrWhiteSpace($StartDate) -and [string]::IsNullOrWhiteSpace($EndDate)) { 'Full CSV (no date filter)' } else { "$StartDate (inclusive) to $EndDate (exclusive) (filters)" } } else { "$StartDate (inclusive) to $EndDate (exclusive)" }
Write-LogHost "Date Range: $rangeText" -ForegroundColor White
Write-LogHost "Output File: $OutputFile" -ForegroundColor White
Write-LogHost "Log File: $LogFile" -ForegroundColor White
# Authentication type only relevant for live queries (not replay mode)
if (-not $RAWInputCSV) {
    Write-LogHost "Authentication: $Auth" -ForegroundColor White
}
Write-LogHost ("Activity Types: " + ($ActivityTypes -join ', ')) -ForegroundColor White

# Show filters if enabled
if ($AgentId -or $AgentsOnly -or $ExcludeAgents -or $PromptFilter -or $UserIds -or $GroupNames) {
    Write-LogHost "Filters:" -ForegroundColor Yellow
    
    # Agent filters
    if ($AgentsOnly) {
        Write-LogHost "  AgentsOnly: Only records with AgentId present" -ForegroundColor Gray
    }
    if ($AgentId) {
        $agentDisplay = if ($AgentId.Count -eq 1) {
            "Specific AgentId: $($AgentId[0])"
        }
        elseif ($AgentId.Count -le 3) {
            "Specific AgentIds ($($AgentId.Count)): " + ($AgentId -join '; ')
        }
        else {
            "Specific AgentIds ($($AgentId.Count) total):"
        }
        Write-LogHost "  $agentDisplay" -ForegroundColor Gray
        if ($AgentId.Count -gt 3) {
            # Show first 3 and indicate there are more (with truncation for very long IDs)
            for ($i = 0; $i -lt [Math]::Min(3, $AgentId.Count); $i++) {
                $displayId = if ($AgentId[$i].Length -gt 80) { $AgentId[$i].Substring(0, 77) + '...' } else { $AgentId[$i] }
                Write-LogHost "    [$($i+1)] $displayId" -ForegroundColor DarkGray
            }
            if ($AgentId.Count -gt 3) {
                Write-LogHost "    ... and $($AgentId.Count - 3) more" -ForegroundColor DarkGray
            }
        }
    }
    
    # ExcludeAgents filter
    if ($ExcludeAgents) {
        Write-LogHost "  ExcludeAgents: Only records without AgentId" -ForegroundColor Gray
    }
    
    # PromptFilter
    if ($PromptFilter) {
        $promptLabel = switch ($PromptFilter) {
            'Prompt'   { 'Only prompts (Message_isPrompt = True)' }
            'Response' { 'Only responses (Message_isPrompt = False)' }
            'Both'     { 'Both prompts and responses (Message_isPrompt = True or False)' }
            'Null'     { 'Only records with no Message_isPrompt values (Null/Empty)' }
        }
        Write-LogHost "  PromptFilter: $promptLabel" -ForegroundColor Gray
    }
    
    # User/Group filtering
    if ($UserIds -or $GroupNames) {
        if ($UserIds) {
            if ($UserIds.Count -eq 1) {
                Write-LogHost "  UserIds: 1 user" -ForegroundColor Gray
            } else {
                Write-LogHost "  UserIds: $($UserIds.Count) users" -ForegroundColor Gray
            }
        }
        if ($GroupNames) {
            if ($GroupNames.Count -eq 1) {
                Write-LogHost "  GroupNames: 1 group" -ForegroundColor Gray
            } else {
                Write-LogHost "  GroupNames: $($GroupNames.Count) groups" -ForegroundColor Gray
            }
        }
    }
}

Write-LogHost "=============================================" -ForegroundColor Cyan
Write-LogHost ""
if ($ExplodeDeep -and $ExplodeArrays) { Write-LogHost "Note: -ExplodeDeep takes precedence over -ExplodeArrays (arrays will still explode, plus deep flatten)." -ForegroundColor DarkYellow }
if ($ForcedRawInputCsvExplosion -and -not $ExplodeDeep -and -not $ExplodeArrays.IsPresent) { Write-LogHost "RAWInputCSV provided -> forcing Purview array explosion (non-exploded mode disabled)." -ForegroundColor Yellow }

# Full parameter echo (post-initialization snapshot)
if ($RAWInputCSV) {
    # Replay mode: only show replay-relevant parameters (omit live-only query/perf params)
    $paramSnapshot = [ordered]@{
        Mode                   = $scriptMode
        RAWInputCSV            = $RAWInputCSV
        'StartDate (inclusive)' = $StartDate
        'EndDate (exclusive)'   = $EndDate
        ActivityTypes          = ($ActivityTypes -join ';')
        AgentsOnly              = $AgentsOnly.IsPresent
        AgentId                = $(if ($AgentId) { ($AgentId -join ';') } else { '' })
        ExcludeAgents          = $ExcludeAgents.IsPresent
        UserId                = $(if ($UserIds) { ($UserIds -join ';') } else { '' })
        PromptFilter           = $(if ($PromptFilter) { $PromptFilter } else { '' })
        ExplodeArrays          = $ForcedRawInputCsvExplosion
        ExplodeDeep            = $ExplodeDeep.IsPresent
        OutputFile             = $OutputFile
        LogFile                = $LogFile
        PSVersion              = $PSVersionTable.PSVersion.ToString()
        PSEdition              = $PSVersionTable.PSEdition
        HostName               = $Host.Name
        HostVersion            = $(try { $Host.Version.ToString() } catch { '' })
    }
}
else {
    $paramSnapshot = [ordered]@{
        'StartDate (inclusive)' = $StartDate
        'EndDate (exclusive)'   = $EndDate
        OutputFile              = $OutputFile
        LogFile                = $LogFile
        Auth                    = $Auth
        BlockHours              = $BlockHours
        ResultSize              = $ResultSize
        PacingMs                = $PacingMs
        ActivityTypes          = ($ActivityTypes -join ';')
        AgentsOnly              = $AgentsOnly.IsPresent
        AgentId                = $(if ($AgentId) { ($AgentId -join ';') } else { '' })
        ExcludeAgents          = $ExcludeAgents.IsPresent
        UserId                = $(if ($UserIds) { ($UserIds -join ';') } else { '' })
        GroupName             = $(if ($GroupNames) { ($GroupNames -join ';') } else { '' })
        PromptFilter           = $(if ($PromptFilter) { $PromptFilter } else { '' })
        ExplodeArrays          = ($ExplodeArrays.IsPresent -or $ForcedRawInputCsvExplosion -or $ExplodeDeep.IsPresent)
        ExplodeDeep            = $ExplodeDeep.IsPresent
        RAWInputCSV            = $(if ([string]::IsNullOrWhiteSpace($RAWInputCSV)) { '' } else { $RAWInputCSV })
        MaxConcurrency         = $MaxConcurrency
        ParallelMode           = $ParallelMode
        MaxParallelGroups      = $MaxParallelGroups
        PSVersion              = $PSVersionTable.PSVersion.ToString()
        PSEdition              = $PSVersionTable.PSEdition
        HostName               = $Host.Name
        HostVersion            = $(try { $Host.Version.ToString() } catch { '' })
    }
}
Write-LogHost "Parameter Snapshot:" -ForegroundColor Cyan
foreach ($k in $paramSnapshot.Keys) { Write-LogHost ("  {0} = {1}" -f $k, $paramSnapshot[$k]) -ForegroundColor DarkGray }
Write-LogHost "" -ForegroundColor DarkGray

function Connect-ToComplianceCenter {
    try {
        Write-LogHost "Connecting to Microsoft 365 Security & Compliance Center..." -ForegroundColor Cyan; function Show-EXOParamInfo { try { $exo = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue; $mod = Get-Module ExchangeOnlineManagement -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1; $ver = if ($mod) { $mod.Version.ToString() } else { '<unknown>' }; $params = if ($exo) { ($exo.Parameters.Keys | Sort-Object) -join ', ' } else { '<missing>' }; Write-LogHost ("EXO module version: " + $ver) -ForegroundColor DarkCyan; Write-LogHost ("Connect-ExchangeOnline params: " + $params) -ForegroundColor DarkYellow; $ipps = Get-Command Connect-IPPSSession -ErrorAction SilentlyContinue; if ($ipps) { Write-LogHost ("Connect-IPPSSession params: " + (($ipps.Parameters.Keys | Sort-Object) -join ', ')) -ForegroundColor DarkYellow } } catch {} }
        switch ($Auth.ToLower()) {
            'weblogin' {
                Show-EXOParamInfo; $connected = $false; $exoCmd = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue; if ($exoCmd) {
                    $hasDisableWAM = $exoCmd.Parameters.ContainsKey('DisableWAM'); if ($hasDisableWAM) {
                        try { Write-LogHost "Attempting Connect-ExchangeOnline authentication with DisableWAM..." -ForegroundColor Yellow; Connect-ExchangeOnline -ShowBanner:$false -DisableWAM -ErrorAction Stop | Out-Null; $connected = $true; Write-LogHost "Successfully connected with Connect-ExchangeOnline!" -ForegroundColor Green } catch {
                            Write-LogHost ("Connect-ExchangeOnline with DisableWAM failed: " + $_.Exception.Message) -ForegroundColor DarkYellow; # Fallback WITHOUT aborting: try UseWebLogin immediately
                            try { Write-LogHost "Retrying with -UseWebLogin fallback..." -ForegroundColor Yellow; Connect-ExchangeOnline -ShowBanner:$false -UseWebLogin -ErrorAction Stop | Out-Null; $connected = $true; Write-LogHost "Successfully connected with UseWebLogin fallback!" -ForegroundColor Green } catch { Write-LogHost ("UseWebLogin fallback also failed: " + $_.Exception.Message) -ForegroundColor DarkYellow } 
                        } 
                    }
                    else { try { Write-LogHost "DisableWAM not available, using UseWebLogin path..." -ForegroundColor Yellow; Connect-ExchangeOnline -ShowBanner:$false -UseWebLogin -ErrorAction Stop | Out-Null; $connected = $true; Write-LogHost "Successfully connected with UseWebLogin." -ForegroundColor Green } catch { Write-LogHost ("UseWebLogin path failed: " + $_.Exception.Message) -ForegroundColor DarkYellow; $connected = $false } } 
                } if (-not $connected) { throw "Failed to authenticate via WebLogin" } 
            } 'devicecode' { Connect-ExchangeOnline -ShowBanner:$false -Device } 'credential' { $cred = Get-Credential -Message "Enter admin credentials for Exchange Online"; Connect-ExchangeOnline -ShowBanner:$false -Credential $cred } default { $silentOk = $true; try { $exoCmd = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue; $connectionArgs = @{ ShowBanner = $false }; if ($exoCmd -and $exoCmd.Parameters.ContainsKey('DisableWAM')) { $connectionArgs['DisableWAM'] = $true } & Connect-ExchangeOnline @connectionArgs -ErrorAction Stop } catch { $silentOk = $false; Write-LogHost "Silent sign-in failed; switching to browser-based sign-in..." -ForegroundColor Yellow } if (-not $silentOk) { try { $exoCmd = Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue; $hasDisableWAM = $exoCmd -and $exoCmd.Parameters.ContainsKey('DisableWAM'); if ($hasDisableWAM) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM -ErrorAction Stop | Out-Null } else { Connect-ExchangeOnline -ShowBanner:$false -UseWebLogin -ErrorAction Stop | Out-Null } } catch { Write-LogHost ("-OpenWebPage failed, retrying with standard authentication: " + $_.Exception.Message) -ForegroundColor DarkYellow; Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop | Out-Null } } } 
        }
        Write-LogHost "Connected successfully!" -ForegroundColor Green; try { $tenantId = $null; $primaryDomain = $null; $fallbackIndicators = @(); try { $org = Get-OrganizationConfig -ErrorAction Stop; if ($org) { $primaryDomain = ($org.HybridConfigurationDomainName, $org.InitialDomain, $org.DefaultDomain) | Where-Object { $_ } | Select-Object -First 1 } } catch {} if (-not $primaryDomain) { try { $accepted = Get-AcceptedDomain -ErrorAction Stop | Sort-Object { if ($_.InitialDomain) { 0 }elseif ($_.Default) { 1 }else { 2 } }, DomainName; $ad = $accepted | Select-Object -First 1; if ($ad) { $primaryDomain = $ad.DomainName } } catch {} } if (-not $primaryDomain) { try { $rawUser = $env:USERNAME; if ($rawUser -match '@') { $primaryDomain = $rawUser.Split('@')[-1] } } catch {} } try { $session = Get-PSSession | Where-Object { $_.ConfigurationName -match 'Microsoft.Exchange' } | Select-Object -First 1; if ($session -and $session.ComputerName -match 'https://outlook.office365.com/psserviceextensibility/') { $tenantId = $null } if (-not $tenantId) { try { $azureTenant = (Get-Variable -Name 'AADTenantId' -Scope Global -ErrorAction SilentlyContinue).Value; if ($azureTenant) { $tenantId = $azureTenant } } catch {} } } catch {} try { $exServer = Get-ExchangeServer -ErrorAction Stop | Select-Object -First 1 Name Edition IsClientAccessServer IsMailboxServer; if ($exServer -and $exServer.Name) { $fallbackIndicators += "EXOServer=$($exServer.Name)" } } catch {} if (-not $fallbackIndicators -or $fallbackIndicators.Count -eq 0) { try { $orgRel = Get-OrganizationRelationship -ErrorAction Stop | Select-Object -First 1 Name DomainNames; if ($orgRel -and $orgRel.Name) { $fallbackIndicators += "OrgRel=$($orgRel.Name)" } } catch {} } $corrParts = @(); if ($primaryDomain) { $corrParts += "Domain=$primaryDomain" } else { $corrParts += 'Domain=<unknown>' } if ($tenantId) { $corrParts += "TenantId=$tenantId" } else { $corrParts += 'TenantId=<unresolved>' } if ($fallbackIndicators -and $fallbackIndicators.Count -gt 0) { $corrParts += ($fallbackIndicators -join ',') } Write-LogHost ("Tenant context: " + ($corrParts -join ' | ')) -ForegroundColor DarkCyan; $script:TenantPrimaryDomain = $primaryDomain; $script:TenantId = $tenantId; $script:TenantIndicators = $fallbackIndicators } catch {}; $script:Connected = $true 
    }
    catch { Write-LogHost "Failed to connect: $($_.Exception.Message)" -ForegroundColor Red; exit 1 } 
}

function Invoke-SearchUnifiedAuditLogWithRetry {
    param([Parameter(Mandatory = $true)][datetime]$Start, [Parameter(Mandatory = $true)][datetime]$End, [Parameter(Mandatory = $true)][string]$Operation, [Parameter(Mandatory = $true)][int]$ResultSize, [Parameter(Mandatory = $false)][string[]]$UserIds, [int]$MaxRetries = 3, [bool]$AutoSubdivide = $true) $script:Hit10KLimit = $false; $script:LimitTimeWindow = ""; $allResults = New-Object System.Collections.ArrayList; $totalFetched = 0; $pageNumber = 1; $maxPages = 50; $pageSize = [Math]::Min($ResultSize, 5000); $useSessionPagination = $ResultSize -gt 5000; if ($useSessionPagination) { Write-LogHost "  Using session-based pagination for ResultSize $ResultSize (page size: $pageSize)" -ForegroundColor Cyan; $sessionId = [Guid]::NewGuid().ToString() } else { Write-LogHost "  Using standard pagination for ResultSize $ResultSize (page size: $pageSize)" -ForegroundColor Cyan }
    try { while ($totalFetched -lt $ResultSize -and $pageNumber -le $maxPages) { $remainingNeeded = $ResultSize - $totalFetched; $currentPageSize = [Math]::Min($pageSize, $remainingNeeded); $pageAttempt = 0; $pageResults = $null; $pageMaxRetries = 3; while ($pageAttempt -le $pageMaxRetries) { try { $params = @{ 'StartDate' = $Start; 'EndDate' = $End; 'Operations' = $Operation; 'ResultSize' = $currentPageSize; 'ErrorAction' = 'Stop' }; if ($UserIds -and $UserIds.Count -gt 0) { $params['UserIds'] = $UserIds }; if ($useSessionPagination) { $params.Add('SessionId', $sessionId); if ($pageNumber -eq 1) { $params.Add('SessionCommand', 'ReturnLargeSet') } else { $params.Add('SessionCommand', 'ReturnNextPreviewPage') } } if ($pageAttempt -eq 0) { if ($useSessionPagination) { if ($pageNumber -eq 1) { Write-LogHost "    Starting session $sessionId, requesting page $pageNumber ($currentPageSize records)..." -ForegroundColor DarkCyan } else { Write-LogHost "    Fetching page $pageNumber ($currentPageSize records)..." -ForegroundColor DarkCyan } } else { Write-LogHost "    Fetching page $pageNumber ($currentPageSize records)..." -ForegroundColor DarkCyan } } else { Write-LogHost "    Retrying page $pageNumber (attempt $($pageAttempt + 1) of $($pageMaxRetries + 1))" -ForegroundColor Yellow } $delayMs = $PacingMs + ($pageAttempt * 2000); if ($delayMs -gt 0) { Start-Sleep -Milliseconds $delayMs } $pageResults = Search-UnifiedAuditLog @params; break } catch { $pageAttempt++; if ($pageAttempt -le $pageMaxRetries) { $msg = $_.Exception.Message; $status = $null; try { $status = $_.Exception.Response.StatusCode.Value__ } catch {}; $isThrottle = ($msg -match '429' -or $msg -match 'Too\s*Many\s*Requests' -or $msg -match 'throttl' -or $msg -match '503' -or $msg -match 'Service\s*Unavailable' -or $status -in 429, 503); if ($isThrottle) { Write-LogHost "    Page $pageNumber throttled (attempt $pageAttempt). Retrying..." -ForegroundColor Yellow; $base = 0.5; $delay = [math]::Min(30.0, $base * [math]::Pow(2, $pageAttempt - 1)); $jitter = (Get-Random -Minimum 0 -Maximum 250) / 1000.0; Start-Sleep -Milliseconds ([int]([math]::Round(($delay + $jitter) * 1000))) } else { Write-LogHost "    Page $pageNumber attempt $pageAttempt failed: $($_.Exception.Message). Retrying..." -ForegroundColor Yellow } if ($useSessionPagination -and $pageAttempt -gt 1) { $sessionId = [Guid]::NewGuid().ToString(); Write-LogHost "    Creating new session ID for retry: $sessionId" -ForegroundColor Yellow } } else { Write-LogHost "    Page $pageNumber failed after $($pageMaxRetries + 1) attempts: $($_.Exception.Message)" -ForegroundColor Red; throw } } } if ($pageResults -and $pageResults.Count -gt 0) { if ($pageNumber -eq 1 -and $AutoSubdivide) { try { $estimatedTotal = $pageResults[0].ResultCount; if ($null -ne $estimatedTotal -and $estimatedTotal -ge 10000) { Write-LogHost "    ⚠️  First page indicates ~$estimatedTotal total records available (≥10K limit)" -ForegroundColor Yellow; Write-LogHost "    📊 Proactively subdividing time window to ensure complete data retrieval" -ForegroundColor Yellow; Write-LogHost "    💡 Optimization: Detected limit early - avoiding unnecessary pagination" -ForegroundColor Cyan; $script:Hit10KLimit = $true; $script:LimitTimeWindow = "$(($Start).ToString('yyyy-MM-dd HH:mm')) to $(($End).ToString('yyyy-MM-dd HH:mm'))"; $null = $allResults.AddRange($pageResults); Write-LogHost "  Early subdivision triggered after first page ($($pageResults.Count) records)" -ForegroundColor Green; $res = $allResults.ToArray(); break } elseif ($null -ne $estimatedTotal) { Write-LogHost "    ✓ First page indicates ~$estimatedTotal total records (<10K) - safe to paginate" -ForegroundColor DarkCyan } } catch {} } $null = $allResults.AddRange($pageResults); $totalFetched += $pageResults.Count; try { $script:metrics.PagesFetched += 1 } catch {}; Write-LogHost "    Page $pageNumber returned $($pageResults.Count) records (total: $totalFetched)" -ForegroundColor DarkCyan; if ($pageResults.Count -lt $currentPageSize) { Write-LogHost "    Reached end of data (page returned $($pageResults.Count) < $currentPageSize requested)" -ForegroundColor DarkCyan; break } if ($totalFetched -eq 10000 -and $pageResults.Count -eq $currentPageSize) { Write-LogHost "" -ForegroundColor Red; Write-LogHost "      CRITICAL: Exchange Online 10,000 Record Server Limit Reached!" -ForegroundColor Red; Write-LogHost "     Retrieved: 10,000 records" -ForegroundColor Yellow; Write-LogHost "     Missing: Additional records are likely available but CANNOT be accessed" -ForegroundColor Red; Write-LogHost "     Solution: Use smaller time blocks (30 minutes or less) to get complete data" -ForegroundColor Cyan; Write-LogHost "     This is a hard Exchange Online server limitation - pagination cannot bypass it" -ForegroundColor Yellow; Write-LogHost "" -ForegroundColor Red; $script:Hit10KLimit = $true; $script:LimitTimeWindow = "$(($Start).ToString('yyyy-MM-dd HH:mm')) to $(($End).ToString('yyyy-MM-dd HH:mm'))" } } else { Write-LogHost "    Page $pageNumber returned no results - ending pagination" -ForegroundColor DarkCyan; break } $pageNumber++ } if ($pageNumber -gt $maxPages) { Write-LogHost "  WARNING: Reached maximum page limit ($maxPages). There may be more data available." -ForegroundColor Yellow } if ($script:Hit10KLimit) { Write-LogHost "" -ForegroundColor Red; Write-LogHost "   INCOMPLETE DATA WARNING " -ForegroundColor Red; Write-LogHost "  Time window: $($script:LimitTimeWindow)" -ForegroundColor Yellow; Write-LogHost "  Retrieved exactly 10,000 records - Exchange Online server limit reached" -ForegroundColor Red; Write-LogHost "  Additional records exist but are inaccessible with this time window" -ForegroundColor Red; Write-LogHost "  REQUIRED ACTION: Re-run with smaller time blocks (30min recommended)" -ForegroundColor Cyan; Write-LogHost "" -ForegroundColor Red } Write-LogHost "  Pagination done: $($allResults.Count) total records" -ForegroundColor Green; $res = $allResults.ToArray() } catch { Write-LogHost "  Pagination failed: $($_.Exception.Message)" -ForegroundColor Red; throw } # Enhanced auto-subdivision with dynamic block sizing - removes 30-minute minimum threshold
    if ($AutoSubdivide -and $res -and $res.Count -eq $ResultSize) { 
        $timeSpan = $End - $Start
        $minMinutes = 5  # Minimum 5-minute blocks (was 30 minutes)
        
        if ($timeSpan.TotalMinutes -gt $minMinutes) { 
            # Calculate optimal subdivision size based on current window
            if ($timeSpan.TotalHours -ge 12) { 
                # Very large windows: use 2-hour chunks
                Write-LogHost "  ⚠ 10K limit hit. Auto-subdividing large window into 2-hour chunks..." -ForegroundColor Yellow
                $chunkResults = New-Object System.Collections.ArrayList
                $current = $Start
                $chunkCount = 0
                while ($current -lt $End) { 
                    $chunkEnd = [datetime]::new([Math]::Min($current.AddHours(2).Ticks, $End.Ticks))
                    $chunkCount++
                    Write-LogHost "    Chunk $chunkCount`: $($current.ToString('HH:mm')) - $($chunkEnd.ToString('HH:mm'))" -ForegroundColor DarkYellow
                    $chunk = Invoke-SearchUnifiedAuditLogWithRetry -Start $current -End $chunkEnd -Operation $Operation -ResultSize $ResultSize -UserId $UserIds -MaxRetries $MaxRetries -AutoSubdivide $AutoSubdivide
                    if ($chunk) { $null = $chunkResults.AddRange($chunk) }
                    $current = $chunkEnd
                } 
                Write-LogHost "  ✓ Subdivision completed. Total: $($chunkResults.Count) records from $chunkCount chunks" -ForegroundColor Green
                return $chunkResults.ToArray()
            } 
            elseif ($timeSpan.TotalMinutes -ge 60) {
                # Medium windows (1+ hours): use 30-minute chunks
                Write-LogHost "  ⚠ 10K limit hit. Auto-subdividing into 30-minute chunks..." -ForegroundColor Yellow
                $chunkResults = New-Object System.Collections.ArrayList
                $current = $Start
                $chunkCount = 0
                while ($current -lt $End) { 
                    $chunkEnd = [datetime]::new([Math]::Min($current.AddMinutes(30).Ticks, $End.Ticks))
                    $chunkCount++
                    Write-LogHost "    Chunk $chunkCount`: $($current.ToString('HH:mm')) - $($chunkEnd.ToString('HH:mm'))" -ForegroundColor DarkYellow
                    $chunk = Invoke-SearchUnifiedAuditLogWithRetry -Start $current -End $chunkEnd -Operation $Operation -ResultSize $ResultSize -UserId $UserIds -MaxRetries $MaxRetries -AutoSubdivide $AutoSubdivide
                    if ($chunk) { $null = $chunkResults.AddRange($chunk) }
                    $current = $chunkEnd
                } 
                Write-LogHost "  ✓ Subdivision completed. Total: $($chunkResults.Count) records from $chunkCount chunks" -ForegroundColor Green
                return $chunkResults.ToArray()
            }
            else { 
                # Small windows (5-60 minutes): split in half recursively
                Write-LogHost "  ⚠ 10K limit hit. Auto-subdividing $([math]::Round($timeSpan.TotalMinutes,1))min window in half..." -ForegroundColor Yellow
                $midPoint = $Start.AddTicks(($End - $Start).Ticks / 2)
                Write-LogHost "    First half: $($Start.ToString('HH:mm')) - $($midPoint.ToString('HH:mm'))" -ForegroundColor DarkYellow
                $firstHalf = Invoke-SearchUnifiedAuditLogWithRetry -Start $Start -End $midPoint -Operation $Operation -ResultSize $ResultSize -UserId $UserIds -MaxRetries $MaxRetries -AutoSubdivide $AutoSubdivide
                Write-LogHost "    Second half: $($midPoint.ToString('HH:mm')) - $($End.ToString('HH:mm'))" -ForegroundColor DarkYellow
                $secondHalf = Invoke-SearchUnifiedAuditLogWithRetry -Start $midPoint -End $End -Operation $Operation -ResultSize $ResultSize -UserId $UserIds -MaxRetries $MaxRetries -AutoSubdivide $AutoSubdivide
                $combinedResults = New-Object System.Collections.ArrayList
                if ($firstHalf) { $null = $combinedResults.AddRange($firstHalf) }
                if ($secondHalf) { $null = $combinedResults.AddRange($secondHalf) }
                Write-LogHost "  ✓ Subdivision completed. Total: $($combinedResults.Count) records (First: $($firstHalf.Count), Second: $($secondHalf.Count))" -ForegroundColor Green
                return $combinedResults.ToArray()
            } 
        } 
        else { 
            # Window is already at minimum (5 minutes) - cannot subdivide further
            Write-LogHost "  ⚠ CRITICAL: 10K limit hit but time window is already at minimum ($([math]::Round($timeSpan.TotalMinutes,1))min)!" -ForegroundColor Red
            Write-LogHost "     This represents EXTREMELY high volume (~2000 records/minute)" -ForegroundColor Red
            Write-LogHost "     Data loss is unavoidable - additional records exist but cannot be retrieved" -ForegroundColor Red
        } 
    }
    return $res 
}

function Find-AllArrays {
    param(
        $Data,
        $Path = "",
        $Arrays = @{},
        $Depth = 0
    )
    if ($null -eq $Data -or $Depth -gt 50) { return $Arrays }
    $isArray = $false; $arrayCount = 0; $arrayData = $null
    if ($Data -is [System.Array]) {
        $isArray = $true; $arrayCount = $Data.Count; $arrayData = $Data
    }
    elseif ($Data -is [System.Collections.ICollection] -and -not ($Data -is [string])) {
        $isArray = $true; $arrayCount = $Data.Count; $arrayData = @($Data)
    }
    elseif ($Data -is [System.Collections.IEnumerable] -and -not ($Data -is [string]) -and -not ($Data -is [System.Collections.IDictionary])) {
        $tempArray = @($Data)
        if ($tempArray.Count -gt 0) { $isArray = $true; $arrayCount = $tempArray.Count; $arrayData = $tempArray }
    }
    if ($isArray -and $arrayCount -gt 0 -and -not $Arrays.ContainsKey($Path)) {
        $Arrays[$Path] = @{ Path = $Path; Count = $arrayCount; Data = $arrayData; Depth = $Depth }
    }
    try {
        if ($Data -is [PSCustomObject] -or ($null -ne $Data -and $Data.GetType().Name -eq 'PSCustomObject')) {
            foreach ($prop in $Data.PSObject.Properties) {
                try {
                    $newPath = if ($Path) { "$Path.$($prop.Name)" } else { $prop.Name }
                    $propValue = $Data.($prop.Name)
                    $Arrays = Find-AllArrays -Data $propValue -Path $newPath -Arrays $Arrays -Depth ($Depth + 1)
                }
                catch {}
            }
        }
    }
    catch {}
    return $Arrays
}

function Set-ValueAtPath {
    param($Record, $Path, $Value)
    try {
        if ($Path -match '^(.+?)\[(\d+)\](.*)$') {
            $basePath = $matches[1]; $index = [int]$matches[2]; $remainingPath = $matches[3]; $current = $Record
            if ($basePath) {
                $baseParts = $basePath -split '\.'
                foreach ($part in $baseParts) {
                    if ($part -and $current.PSObject.Properties[$part]) { $current = $current.PSObject.Properties[$part].Value } else { return $false }
                }
            }
            if ($current -is [System.Array] -and $index -lt $current.Count) {
                if ($remainingPath -and $remainingPath.StartsWith('.')) {
                    $subPath = $remainingPath.Substring(1)
                    return Set-ValueAtPath -Record $current[$index] -Path $subPath -Value $Value
                }
                else { $current[$index] = $Value; return $true }
            }
            return $false
        }
        $pathParts = $Path -split '\.'; $current = $Record
        for ($i = 0; $i -lt $pathParts.Count - 1; $i++) {
            $part = $pathParts[$i]; if (-not $part) { continue }
            if (-not $current.PSObject.Properties[$part]) { Add-Member -InputObject $current -NotePropertyName $part -NotePropertyValue ([PSCustomObject]@{}) -Force }
            $current = $current.PSObject.Properties[$part].Value
        }
        $finalPart = $pathParts[-1]
        if ($finalPart) {
            if ($current.PSObject.Properties[$finalPart]) { $current.PSObject.Properties[$finalPart].Value = $Value } else { Add-Member -InputObject $current -NotePropertyName $finalPart -NotePropertyValue $Value -Force }
            return $true
        }
        return $false
    }
    catch { return $false }
}

function Test-ScalarValue { param($v) ($null -eq $v -or $v -is [string] -or $v -is [char] -or $v -is [bool] -or $v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal] -or $v -is [float] -or $v -is [datetime] -or $v -is [guid]) }

function ConvertTo-UniqueString {
    param([object]$items, [char]$Sep = ';')
    if ($null -eq $items) { return $null }
    $set = New-Object System.Collections.Generic.HashSet[string]
    foreach ($v in $items) { if ($null -ne $v -and $v -ne '') { [void]$set.Add([string]$v) } }
    ([string]::Join($Sep, $set))
}

function ConvertTo-FlatColumns {
    param([object]$Node, [string]$Prefix = '', [int]$MaxDepth = 60)
    $cols = @{}
    function Recurse([object]$n, [string]$p, [int]$d) {
        if ($d -gt $MaxDepth) { return }
        if ($null -eq $n) { if ($p) { $cols[$p.TrimEnd('.')] = $null }; return }
        if (Test-ScalarValue $n) { if ($p) { $cols[$p.TrimEnd('.')] = $n }; return }
        if ($n -is [System.Collections.IEnumerable] -and -not ($n -is [string]) -and -not ($n -is [System.Collections.IDictionary])) {
            $i = 0
            foreach ($el in $n) { $ip = if ($p) { "$p[$i]." } else { "[$i]." }; Recurse -n $el -p $ip -d ($d + 1); $i++ }
            if ($i -eq 0 -and $p) { $cols[$p.TrimEnd('.')] = '' }
            return
        }
        $props = $null; try { $props = $n.PSObject.Properties } catch {}
        if ($props) {
            foreach ($prop in $props) { $name = [string]$prop.Name; $child = $prop.Value; $cp = if ($p) { $p + $name + '.' } else { $name + '.' }; Recurse -n $child -p $cp -d ($d + 1) }
        }
    }
    Recurse -n $Node -p $Prefix -d 0
    return $cols
}

function Get-SafeProperty { param($obj, [string]$name) try { if ($null -ne $obj -and $obj.PSObject.Properties[$name]) { return $obj.($name) } } catch {}; return $null }

# --- Purview Exploded Schema (35 core columns) ---
$PurviewExplodedHeader = @(
    'RecordId', 'CreationDate', 'RecordType', 'Operation', 'UserId', 'AssociatedAdminUnits', 'AssociatedAdminUnitsNames',
    'AgentId', 'AgentName', 'AppIdentity', 'AppIdentity_DisplayName', 'AppIdentity_PublisherId', 'ApplicationName',
    'CreationTime', 'ClientRegion', 'ClientIP', 'Audit_UserId', 'AppHost', 'ThreadId', 'Context_Id', 'Context_Type', 'Message_Id',
    'Message_isPrompt', 'AccessedResource_Action', 'AccessedResource_PolicyDetails', 'AccessedResource_SiteUrl',
    'AISystemPlugin_Id', 'AISystemPlugin_Name', 'ModelTransparencyDetails_ModelName', 'MessageIds',
    'OrganizationId', 'Version', 'UserType', 'CopilotLogVersion', 'Workload'
)

# Base schema list used directly when emitting headers (even for empty datasets).

if (-not $script:DeepExtraColumns) { $script:DeepExtraColumns = New-Object System.Collections.Generic.List[string] }

function Convert-ToPurviewExplodedRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Record,
        [switch]$Deep,
        [string]$PromptFilterValue
    )
    try {
        # Use pre-parsed AuditData if available for improved processing speed
        $auditData = if ($Record.PSObject.Properties['_ParsedAuditData']) {
            $Record._ParsedAuditData
        }
        else {
            # Parse AuditData JSON if not already parsed
            try { $Record.AuditData | ConvertFrom-Json -ErrorAction Stop } catch { $null }
        }
        if (-not $auditData) { return @() }
        $ced = Get-SafeProperty $auditData 'CopilotEventData'
        
        # Extract array properties from CopilotEventData
        $messages = script:GetArrayFast $ced 'Messages'
        
        # Apply conversation-level PromptFilter during explosion (Stage 2 filtering) - OPTIMIZED
        # Stage 1 already filtered out records without any matching conversation turns (or kept all for 'Both')
        # This filters the actual conversation turns (prompts/responses) to only output matching types
        if ($PromptFilterValue) {
            # Fast filtering using List instead of Where-Object pipeline
            $filteredMessages = New-Object System.Collections.Generic.List[object]
            
            if ($PromptFilterValue -eq 'Null') {
                # Keep conversation turns where isPrompt is null/missing
                foreach ($msg in $messages) {
                    if ($null -eq $msg.isPrompt) {
                        $filteredMessages.Add($msg)
                    }
                }
            }
            elseif ($PromptFilterValue -eq 'Both') {
                # Keep conversation turns where isPrompt has an explicit value (TRUE or FALSE)
                # This filters out resource-only rows that have no conversation data
                foreach ($msg in $messages) {
                    if ($null -ne $msg.isPrompt) {
                        $filteredMessages.Add($msg)
                    }
                }
            }
            else {
                # Prompt or Response filtering
                $targetValue = ($PromptFilterValue -eq 'Prompt')
                foreach ($msg in $messages) {
                    try {
                        if ($msg.isPrompt -eq $targetValue) {
                            $filteredMessages.Add($msg)
                        }
                    } catch {
                        # Skip messages where isPrompt can't be accessed
                    }
                }
            }
            
            $messages = $filteredMessages
            
            # If no conversation turns remain after filtering, return empty (no rows for this record)
            if ($messages.Count -eq 0) {
                return @()
            }
        }
        
        $contexts = script:GetArrayFast $ced 'Contexts'
        $resources = script:GetArrayFast $ced 'AccessedResources'
        $pluginsRaw = script:GetArrayFast $ced 'AISystemPlugin'
        $modelDetRaw = script:GetArrayFast $ced 'ModelTransparencyDetails'
        $messageIds = script:GetArrayFast $ced 'MessageIds'

        # Determine max row count across exploded arrays
        # When PromptFilter is active, base rowCount on filtered conversation turns only
        # to avoid outputting rows with blank Message_isPrompt values for unmatched contexts/resources
        if ($PromptFilterValue) {
            # When filtering conversation turns (including 'Both'), only output rows for the filtered turns
            $rowCount = [Math]::Max(1, $messages.Count)
        }
        else {
            # No filter - use max of all arrays
            $rowCount = (1, $messages.Count, $contexts.Count, $resources.Count | Measure-Object -Maximum).Maximum
        }

        # Choose first plugin / model transparency element if any
        $plugin0 = if ($pluginsRaw.Count -gt 0) { $pluginsRaw[0] } else { $null }
        $model0 = if ($modelDetRaw.Count -gt 0) { $modelDetRaw[0] } else { $null }

        # Extract record-level values from audit data
        $creationDate = script:Format-DatePurviewFast $Record.CreationDate
        $creationTime = try { script:Format-DatePurviewFast $auditData.CreationTime } catch { '' }
        # AppIdentity can be a string OR an object - check both cases
        $appIdentityRaw = (Select-FirstNonNull -Values @((Get-SafeProperty $auditData 'AppIdentity'), (Get-SafeProperty $ced 'AppIdentity')))
        if ($appIdentityRaw -is [string]) {
            # AppIdentity is a simple string (e.g., "Copilot.Security.SecurityCopilot")
            $appIdentity = $appIdentityRaw
            $appId = ''
            $appDisp = ''
            $appPub = ''
        }
        elseif ($null -ne $appIdentityRaw) {
            # AppIdentity is an object with properties
            $appIdentity = ''
            $appId = Get-SafeProperty $appIdentityRaw 'AppId'
            $appDisp = Get-SafeProperty $appIdentityRaw 'DisplayName'
            $appPub = Get-SafeProperty $appIdentityRaw 'PublisherId'
        }
        else {
            # No AppIdentity at all
            $appIdentity = ''
            $appId = ''
            $appDisp = ''
            $appPub = ''
        }
        $appHost = (Select-FirstNonNull -Values @((Get-SafeProperty $ced 'AppHost'), (Get-SafeProperty $auditData 'AppHost'), (Get-SafeProperty $auditData 'Workload')))
        # ClientRegion is at top-level AuditData
        $clientRegion = (Get-SafeProperty $auditData 'ClientRegion')
        $agentId = (Get-SafeProperty $auditData 'AgentId')
        $agentName = (Get-SafeProperty $auditData 'AgentName')
        $appName = (Select-FirstNonNull -Values @((Get-SafeProperty $auditData 'ApplicationName'), (Get-SafeProperty $ced 'HostAppName'), (Get-SafeProperty $ced 'ClientAppName')))
        $threadId = (Get-SafeProperty $ced 'ThreadId')
        $auditUserKey = try { $auditData.UserKey } catch { $null }
        $modelName = Get-SafeProperty $model0 'ModelName'
        # Additional top-level AuditData fields
        $clientIP = (Get-SafeProperty $auditData 'ClientIP')
        $organizationId = (Get-SafeProperty $auditData 'OrganizationId')
        $version = (Get-SafeProperty $auditData 'Version')
        $userType = (Get-SafeProperty $auditData 'UserType')
        $copilotLogVersion = (Get-SafeProperty $auditData 'CopilotLogVersion')
        $workload = (Get-SafeProperty $auditData 'Workload')

        $baseSet = New-Object System.Collections.Generic.HashSet[string]
        foreach ($c in $PurviewExplodedHeader) { $null = $baseSet.Add($c) }
        $rows = New-Object System.Collections.Generic.List[object]

        for ($i = 0; $i -lt $rowCount; $i++) {
            # Use [PSCustomObject] directly for faster object creation (vs [ordered]@{} then New-Object)
            $rowObj = [PSCustomObject]@{
                RecordId                           = $(try { $auditData.Id } catch { $Record.Identity })
                CreationDate                       = $creationDate
                RecordType                         = $Record.RecordType
                Operation                          = $auditData.Operation
                UserId                             = $auditData.UserId
                AssociatedAdminUnits               = (Get-SafeProperty $auditData 'AssociatedAdminUnits')
                AssociatedAdminUnitsNames          = (Get-SafeProperty $auditData 'AssociatedAdminUnitsNames')
                AgentId                            = $agentId
                AgentName                          = $agentName
                AppIdentity                        = $appIdentity
                AppIdentity_DisplayName            = $appDisp
                AppIdentity_PublisherId            = $appPub
                ApplicationName                    = $appName
                CreationTime                       = $creationTime
                ClientRegion                       = $clientRegion
                ClientIP                           = $clientIP
                Audit_UserId                       = $auditUserKey
                AppHost                            = $appHost
                ThreadId                           = $threadId
                Context_Id                         = $(if ($i -lt $contexts.Count -and $contexts[$i]) { try { Get-SafeProperty $contexts[$i] 'Id' } catch { '' } } else { '' })
                Context_Type                       = $(if ($i -lt $contexts.Count -and $contexts[$i]) { try { Get-SafeProperty $contexts[$i] 'Type' } catch { '' } } else { '' })
                Message_Id                         = $(if ($i -lt $messages.Count) { $msg = $messages[$i]; if ($msg -is [psobject]) { try { Get-SafeProperty $msg 'Id' } catch { '' } } else { $msg } } else { '' })
                Message_isPrompt                   = $(if ($i -lt $messages.Count) { $msg = $messages[$i]; if ($msg -is [psobject]) { try { script:BoolTFFast (Get-SafeProperty $msg 'isPrompt') } catch { '' } } else { '' } } else { '' })
                AccessedResource_Action            = $(if ($i -lt $resources.Count -and $resources[$i]) { try { Get-SafeProperty $resources[$i] 'Action' } catch { '' } } else { '' })
                AccessedResource_PolicyDetails     = $(if ($i -lt $resources.Count -and $resources[$i]) { try { script:ToJsonIfObjectFast (Get-SafeProperty $resources[$i] 'PolicyDetails') } catch { '' } } else { '' })
                AccessedResource_SiteUrl           = $(if ($i -lt $resources.Count -and $resources[$i]) { try { Get-SafeProperty $resources[$i] 'SiteUrl' } catch { '' } } else { '' })
                AISystemPlugin_Id                  = $(if ($plugin0) { try { Get-SafeProperty $plugin0 'Id' } catch { '' } } else { '' })
                AISystemPlugin_Name                = $(if ($plugin0) { try { Get-SafeProperty $plugin0 'Name' } catch { '' } } else { '' })
                ModelTransparencyDetails_ModelName = $(if ($model0) { $modelName } else { '' })
                MessageIds                         = $(if ($messageIds.Count -gt 0) { $messageIds -join ';' } else { '' })
                OrganizationId                     = $organizationId
                Version                            = $version
                UserType                           = $userType
                CopilotLogVersion                  = $copilotLogVersion
                Workload                           = $workload
            }

            if ($Deep -and $ced) {
                # Deep flatten CopilotEventData
                $flat = ConvertTo-FlatColumns -Node $ced -Prefix 'CopilotEventData.' -MaxDepth $FlatDepthDeep
                foreach ($k in $flat.Keys) {
                    if ($baseSet.Contains($k)) { continue }
                    if (-not $rowObj.PSObject.Properties[$k]) {
                        # Register column ordering globally
                        if (-not $script:DeepExtraColumns.Contains($k)) { [void]$script:DeepExtraColumns.Add($k) }
                        try { Add-Member -InputObject $rowObj -NotePropertyName $k -NotePropertyValue $flat[$k] -Force } catch {}
                    }
                }
            }
            
            if ($Deep -and $auditData) {
                # Deep flatten top-level AuditData (excluding CopilotEventData which is already processed)
                $auditDataClone = [PSCustomObject]@{}
                foreach ($prop in $auditData.PSObject.Properties) {
                    # Skip CopilotEventData as it's already processed above, and skip already-extracted core fields
                    if ($prop.Name -ne 'CopilotEventData') {
                        Add-Member -InputObject $auditDataClone -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                    }
                }
                $flatAudit = ConvertTo-FlatColumns -Node $auditDataClone -Prefix 'AuditData.' -MaxDepth $FlatDepthDeep
                foreach ($k in $flatAudit.Keys) {
                    if ($baseSet.Contains($k)) { continue }
                    if (-not $rowObj.PSObject.Properties[$k]) {
                        # Register column ordering globally
                        if (-not $script:DeepExtraColumns.Contains($k)) { [void]$script:DeepExtraColumns.Add($k) }
                        try { Add-Member -InputObject $rowObj -NotePropertyName $k -NotePropertyValue $flatAudit[$k] -Force } catch {}
                    }
                }
            }

            $rows.Add($rowObj) | Out-Null
        }

        return , @($rows.ToArray())
    }
    catch { Write-Host "Failed Purview explosion: $($_.Exception.Message)" -ForegroundColor Red; return @() }
}

function Select-FirstNonNull {
    param([object[]]$Values)
    foreach ($v in $Values) { if ($null -ne $v -and ('' -ne [string]$v)) { return $v } }
    return $null
}
function Convert-ToStructuredRecord {
    param(
        [Parameter(Mandatory = $true)] $Record,
        [bool]$EnableExplosion = $false
    )
    try {
        function Local:Get-Num([object]$v) { if ($null -eq $v) { return $null }; try { if ($v -is [string] -and [string]::IsNullOrWhiteSpace($v)) { return $null }; return [double]$v } catch { return $null } }
        function Local:Add-OrUpdate([pscustomobject]$obj, [string]$name, $value) { try { if ($obj.PSObject.Properties[$name]) { $obj.PSObject.Properties[$name].Value = $value } else { Add-Member -InputObject $obj -NotePropertyName $name -NotePropertyValue $value -Force } } catch {} }
        
        # Use pre-parsed AuditData if available for improved processing speed
        $auditData = if ($Record.PSObject.Properties['_ParsedAuditData']) {
            $Record._ParsedAuditData
        }
        else {
            # Parse AuditData JSON if not already parsed
            try { $Record.AuditData | ConvertFrom-Json -ErrorAction Stop } catch { $null }
        }
        if (-not $auditData) { return @() }
        $ced = Get-SafeProperty $auditData 'CopilotEventData'
        $modelId = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'ModelId'), (Get-SafeProperty $ced 'ModelID'), (Get-SafeProperty $auditData 'ModelId'))
        $modelProvider = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'ModelProvider'), (Get-SafeProperty $ced 'Provider'), (Get-SafeProperty $ced 'ModelVendor'))
        $modelFamily = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'ModelFamily'), (Get-SafeProperty $ced 'ModelType'))
        $usageNode = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'Usage'), (Get-SafeProperty $ced 'TokenUsage'), (Get-SafeProperty $ced 'Tokens'), (Get-SafeProperty $auditData 'Usage'))
        $tokensTotal = $null; $tokensInput = $null; $tokensOutput = $null
        if ($usageNode) {
            $tokensTotal = Local:Get-Num (Select-FirstNonNull -Values @((Get-SafeProperty $usageNode 'Total'), (Get-SafeProperty $usageNode 'TotalTokens'), (Get-SafeProperty $usageNode 'TokensTotal')))
            $tokensInput = Local:Get-Num (Select-FirstNonNull -Values @((Get-SafeProperty $usageNode 'Input'), (Get-SafeProperty $usageNode 'Prompt'), (Get-SafeProperty $usageNode 'InputTokens'), (Get-SafeProperty $usageNode 'TokensInput')))
            $tokensOutput = Local:Get-Num (Select-FirstNonNull -Values @((Get-SafeProperty $usageNode 'Output'), (Get-SafeProperty $usageNode 'Completion'), (Get-SafeProperty $usageNode 'OutputTokens'), (Get-SafeProperty $usageNode 'TokensOutput')))
        }
        if (-not $tokensTotal -and ($tokensInput -or $tokensOutput)) { try { $tokensTotal = ($tokensInput + $tokensOutput) } catch {} }
        $durationMs = Local:Get-Num (Select-FirstNonNull -Values @((Get-SafeProperty $ced 'DurationMs'), (Get-SafeProperty $ced 'ElapsedMs'), (Get-SafeProperty $ced 'ProcessingTimeMs'), (Get-SafeProperty $ced 'LatencyMs')))
        $outcomeStatus = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'OutcomeStatus'), (Get-SafeProperty $ced 'Outcome'), (Get-SafeProperty $ced 'Result'), (Get-SafeProperty $ced 'Status'))
        if ($outcomeStatus -is [bool]) { $outcomeStatus = if ($outcomeStatus) { 'Success' } else { 'Failure' } }
        $conversationId = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'ConversationId'), (Get-SafeProperty $ced 'ConversationID'), (Get-SafeProperty $ced 'SessionId'))
        $turnNumber = Local:Get-Num (Select-FirstNonNull -Values @((Get-SafeProperty $ced 'TurnNumber'), (Get-SafeProperty $ced 'TurnIndex'), (Get-SafeProperty $ced 'MessageIndex')))
        $retryCount = Local:Get-Num (Select-FirstNonNull -Values @((Get-SafeProperty $ced 'RetryCount'), (Get-SafeProperty $ced 'Retries')))
        $clientVersion = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'ClientVersion'), (Get-SafeProperty $ced 'Version'), (Get-SafeProperty $ced 'Build'))
        $clientPlatform = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'ClientPlatform'), (Get-SafeProperty $ced 'Platform'), (Get-SafeProperty $ced 'OS'))
        $agentId = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'AgentId'), (Get-SafeProperty $ced 'AgentID'), (Get-SafeProperty $ced 'AssistantId'))
        $agentName = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'AgentName'), (Get-SafeProperty $ced 'AssistantName'))
        $appIdentity = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'AppIdentity'), (Get-SafeProperty $ced 'ApplicationId'), (Get-SafeProperty $ced 'HostAppId'))
        $applicationName = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'ApplicationName'), (Get-SafeProperty $ced 'HostAppName'), (Get-SafeProperty $ced 'ClientAppName'))
        $suggestions = (Get-SafeProperty $ced 'Suggestions'); if (-not $suggestions) { $suggestions = Get-SafeProperty $ced 'SuggestionList' }
        $actions = Get-SafeProperty $ced 'Actions'
        $references = Select-FirstNonNull -Values @((Get-SafeProperty $ced 'References'), (Get-SafeProperty $ced 'Sources'), (Get-SafeProperty $ced 'Citations'))
        $participants = Get-SafeProperty $ced 'Participants'
        function Local:Measure-Collection($items, [string]$prefix) {
            $result = @{}; if (-not $items) { return $result }; $arr = @($items); if ($arr.Count -eq 0) { return $result }
            $result["${prefix}Count"] = $arr.Count; $types = New-Object System.Collections.Generic.HashSet[string]; $latencies = @(); $edits = @(); $accepted = 0; $success = 0; $failure = 0
            foreach ($s in $arr) {
                foreach ($cand in @('Type', 'SuggestionType', 'Name', 'Kind', 'ActionType')) { try { if ($s.PSObject.Properties[$cand]) { [void]$types.Add([string]$s.$cand); break } } catch {} }
                foreach ($lat in @('LatencyMs', 'DurationMs', 'ElapsedMs')) { try { if ($s.PSObject.Properties[$lat]) { $v = Local:Get-Num $s.$lat; if ($null -ne $v) { $latencies += $v; break } } } catch {} }
                foreach ($ed in @('EditCount', 'Edits', 'EditsCount')) { try { if ($s.PSObject.Properties[$ed]) { $v = Local:Get-Num $s.$ed; if ($null -ne $v) { $edits += $v; break } } } catch {} }
                foreach ($acc in @('Accepted', 'IsAccepted', 'Success', 'Succeeded')) { try { if ($s.PSObject.Properties[$acc]) { $val = $s.$acc; if ($val -is [bool]) { if ($val) { $accepted++ } } elseif ($val -match '^(?i:true|yes|1|success)') { $accepted++ } } } catch {} }
                foreach ($succ in @('Success', 'Succeeded')) { try { if ($s.PSObject.Properties[$succ]) { $val = $s.$succ; if ($val -is [bool]) { if ($val) { $success++ } else { $failure++ } } elseif ($val -match '^(?i:true|yes|1|success)') { $success++ } else { $failure++ } } } catch {} }
            }
            if ($types.Count -gt 0) { $result["${prefix}Types"] = [string]::Join(';', [array]$types) }
            if ($latencies.Count -gt 0) { $result["${prefix}AvgLatencyMs"] = [math]::Round(($latencies | Measure-Object -Average).Average, 2) }
            if ($edits.Count -gt 0) { $result["${prefix}AvgEdits"] = [math]::Round(($edits | Measure-Object -Average).Average, 2); $result["${prefix}TotalEdits"] = ($edits | Measure-Object -Sum).Sum }
            if ($accepted -gt 0) { $result["${prefix}Accepted"] = $accepted; $result["${prefix}AcceptanceRate"] = [math]::Round(($accepted / $arr.Count) * 100, 2) }
            if ($success -gt 0 -or $failure -gt 0) { $result["${prefix}Success"] = $success; $result["${prefix}Failure"] = $failure }
            return $result
        }
        $suggestAgg = Local:Measure-Collection $suggestions 'Suggestions'
        $actionAgg = Local:Measure-Collection $actions 'Actions'
        $refAgg = Local:Measure-Collection $references 'References'
        $partAgg = Local:Measure-Collection $participants 'Participants'
        $baseRecord = [pscustomobject]@{
            RecordType         = $Record.RecordType
            CreationDate       = $Record.CreationDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            UserIds            = $Record.UserIds
            Operations         = $Record.Operations
            ResultStatus       = $Record.ResultStatus
            ResultCount        = $Record.ResultCount
            Identity           = $Record.Identity
            IsValid            = $Record.IsValid
            ObjectState        = $Record.ObjectState
            Id                 = $auditData.Id
            CreationTime       = ([datetime]::Parse($auditData.CreationTime)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            Operation          = $auditData.Operation
            OrganizationId     = $auditData.OrganizationId
            RecordTypeNum      = $auditData.RecordType
            ResultStatus_Audit = $auditData.ResultStatus
            UserKey            = $auditData.UserKey
            UserType           = $auditData.UserType
            Version            = $auditData.Version
            Workload           = $auditData.Workload
            UserId             = $auditData.UserId
            AppId              = $auditData.AppId
            ClientAppId        = $auditData.ClientAppId
            CorrelationId      = $auditData.CorrelationId
            ModelId            = $modelId
            ModelProvider      = $modelProvider
            ModelFamily        = $modelFamily
            TokensTotal        = $tokensTotal
            TokensInput        = $tokensInput
            TokensOutput       = $tokensOutput
            DurationMs         = $durationMs
            OutcomeStatus      = $outcomeStatus
            ConversationId     = $conversationId
            TurnNumber         = $turnNumber
            RetryCount         = $retryCount
            ClientVersion      = $clientVersion
            ClientPlatform     = $clientPlatform
            AgentId            = $agentId
            AgentName          = $agentName
            AppIdentity        = $appIdentity
            ApplicationName    = $applicationName
            OriginalAuditData  = $auditData
        }
        foreach ($k in $suggestAgg.Keys) { Local:Add-OrUpdate $baseRecord $k $suggestAgg[$k] }
        foreach ($k in $actionAgg.Keys) { Local:Add-OrUpdate $baseRecord $k $actionAgg[$k] }
        foreach ($k in $refAgg.Keys) { Local:Add-OrUpdate $baseRecord $k $refAgg[$k] }
        foreach ($k in $partAgg.Keys) { Local:Add-OrUpdate $baseRecord $k $partAgg[$k] }
        # Raw CopilotEventData only in non-explosion mode
        if (-not ($EnableExplosion -or $ExplodeDeep)) { Local:Add-OrUpdate $baseRecord 'CopilotEventData' (if ($ced) { $ced | ConvertTo-Json -Depth $JsonDepth -Compress } else { $null }) }
        if (-not $EnableExplosion -and -not $ExplodeDeep) { return @($baseRecord) }
        $rows = @($baseRecord)
        $arraysToExplode = @(
            @{ Name = 'Suggestions'; Data = $suggestions; Prefix = 'Suggestion'; Enabled = $suggestions },
            @{ Name = 'Actions'; Data = $actions; Prefix = 'Action'; Enabled = $actions },
            @{ Name = 'References'; Data = $references; Prefix = 'Reference'; Enabled = $references },
            @{ Name = 'Participants'; Data = $participants; Prefix = 'Participant'; Enabled = $participants }
        )
        $maxRows = $ExplosionPerRecordRowCap
        foreach ($entry in $arraysToExplode) {
            if (-not $entry.Enabled) { continue }
            $dataArr = @($entry.Data); if ($dataArr.Count -eq 0) { continue }
            $newRows = New-Object System.Collections.ArrayList
            foreach ($r in $rows) {
                $idx = 0
                foreach ($el in $dataArr) {
                    $nr = [pscustomobject]@{}
                    foreach ($p in $r.PSObject.Properties) { Add-Member -InputObject $nr -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force }
                    Local:Add-OrUpdate $nr ("ArrayIndex_{0}" -f $entry.Name) $idx
                    if ($el) {
                        foreach ($prop in $el.PSObject.Properties) {
                            $pname = ("{0}_{1}" -f $entry.Prefix, $prop.Name)
                            if ($nr.PSObject.Properties[$pname]) { continue }
                            $val = $prop.Value
                            if (Test-ScalarValue $val) { Local:Add-OrUpdate $nr $pname $val } else { try { Local:Add-OrUpdate $nr $pname ($val | ConvertTo-Json -Depth $JsonDepth -Compress) } catch {} }
                        }
                    }
                    [void]$newRows.Add($nr); $idx++
                    if ($newRows.Count -gt $maxRows) { break }
                }
                if ($newRows.Count -gt $maxRows) { break }
            }
            $rows = @($newRows)
            if ($rows.Count -gt $maxRows) { break }
        }
        if ($rows.Count -gt $maxRows) { foreach ($r in $rows) { Local:Add-OrUpdate $r 'ExplosionTruncated' $true }; $rows = $rows[0..($maxRows - 1)]; try { $script:metrics.ExplosionTruncated = $true } catch {} }
        if ($ExplodeDeep -and $ced) {
            for ($i = 0; $i -lt $rows.Count; $i++) {
                $r = $rows[$i]
                $flat = ConvertTo-FlatColumns -Node $ced -Prefix 'CopilotEventData.' -MaxDepth $FlatDepthStandard
                foreach ($ck in $flat.Keys) { if (-not $r.PSObject.Properties[$ck]) { Local:Add-OrUpdate $r $ck $flat[$ck] } }
            }
        }
        return $rows
    }
    catch { Write-LogHost "Failed to process record: $($_.Exception.Message)" -ForegroundColor Red; return @() }
}
try {
    $allLogs = New-Object System.Collections.ArrayList
    if ($RAWInputCSV) {
        Write-LogHost "Replay mode enabled: ingesting raw Purview CSV '$RAWInputCSV' (bypassing live service queries)" -ForegroundColor Yellow
        if (-not (Test-Path $RAWInputCSV)) { Write-LogHost "Replay file not found: $RAWInputCSV" -ForegroundColor Red; exit 1 }
        $csvData = Import-Csv -Path $RAWInputCSV
        $rawTotal = $csvData.Count
        $applyDateFilter = ($PSBoundParameters.ContainsKey('StartDate') -or $PSBoundParameters.ContainsKey('EndDate'))
        $applyActivityFilter = ($PSBoundParameters.ContainsKey('ActivityTypes') -and $ActivityTypes -and $ActivityTypes.Count -gt 0)
        $startFilter = $null; $endFilter = $null
        if ($applyDateFilter) {
            if ($PSBoundParameters.ContainsKey('StartDate')) { try { $startFilter = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null) } catch {} }
            if ($PSBoundParameters.ContainsKey('EndDate')) { try { $endFilter = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null) } catch {} }
        }
        $activitySet = $null
        if ($applyActivityFilter) { $activitySet = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase); foreach ($a in $ActivityTypes) { if ($a) { [void]$activitySet.Add($a) } } }
        $filteredRows = New-Object System.Collections.Generic.List[object]
        foreach ($row in $csvData) {
            $keep = $true
            $creationRaw = $row.CreationDate
            $creation = $null
            try { if ($creationRaw) { $creation = [datetime]$creationRaw } } catch {}
            if ($applyDateFilter -and $creation) {
                if ($startFilter -and $creation -lt $startFilter) { $keep = $false }
                if ($endFilter -and $creation -ge $endFilter) { $keep = $false }
            }
            if ($keep -and $applyActivityFilter) {
                $op = $row.Operation
                if (-not $op -or -not $activitySet.Contains([string]$op)) { $keep = $false }
            }
            if (-not $keep) { continue }
            $auditData = if ($row.AuditData) { $row.AuditData } elseif ($row.OriginalAuditData) { $row.OriginalAuditData } else { $null }
            $identity = if ($row.Id) { $row.Id } elseif ($row.RecordId) { $row.RecordId } else { [guid]::NewGuid().ToString() }
            $rec = [pscustomobject]@{
                RecordType   = $(try { [int]$row.RecordType } catch { 0 })
                CreationDate = $(if ($creation) { $creation } else { Get-Date })
                UserIds      = @($row.UserId)
                Operations   = $row.Operation
                ResultStatus = $(try { $row.ResultStatus } catch { '' })
                ResultCount  = 0
                Identity     = $identity
                IsValid      = $true
                ObjectState  = ''
                AuditData    = $auditData
                Operation    = $row.Operation
                UserId       = $row.UserId
            }
            [void]$filteredRows.Add($row)
            [void]$allLogs.Add($rec)
        }
        $ingested = $allLogs.Count
        if ($applyDateFilter -or $applyActivityFilter) {
            Write-LogHost ("Replay ingestion complete: {0} records (filtered from {1}; DateFilter={2} ActivityFilter={3})" -f $ingested, $rawTotal, $applyDateFilter, $applyActivityFilter) -ForegroundColor Green
        }
        else {
            Write-LogHost "Replay ingestion complete: $ingested records" -ForegroundColor Green
        }
        # Minimal placeholders for later summary sections
        $queryPlan = @(); $parallelGroupsUsed = 0; $sequentialGroups = 0; $parallelDecision = @{ Enabled = $false; Reason = 'Replay'; AutoEligible = $false }; $parallelOverallEnabled = $false
        $script:metrics.TotalRecordsFetched = $ingested
        $script:progressState.Query.Total = 1; $script:progressState.Query.Current = 1
    }
    else {
        $existingEOM = Get-Module -ListAvailable -Name ExchangeOnlineManagement | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $existingEOM) {
            Write-LogHost "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
            try { Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber; Write-LogHost "Module installed successfully." -ForegroundColor Green } catch { Write-LogHost "Failed to install ExchangeOnlineManagement module: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
        }
        else {
        }
        Import-Module ExchangeOnlineManagement -Force
        Connect-ToComplianceCenter

        # Handle user/group filtering
        $script:targetUsers = @()
        if ($UserIds -or $GroupNames) {
            Write-LogHost ""
            Write-LogHost "User/Group Filtering Enabled:" -ForegroundColor Cyan
            
            if ($UserIds) {
                $script:targetUsers += $UserIds
                Write-LogHost "  Individual users: $($UserIds.Count)" -ForegroundColor DarkCyan
            }
            
            if ($GroupNames) {
                Write-LogHost "  Expanding groups to individual users..." -ForegroundColor DarkCyan
                foreach ($group in $GroupNames) {
                    try {
                        Write-LogHost "    Processing group: '$group'" -ForegroundColor Gray
                        $members = Get-DistributionGroupMember -Identity $group -ErrorAction Stop | 
                                   Select-Object -ExpandProperty PrimarySmtpAddress
                        $script:targetUsers += $members
                        Write-LogHost "      Expanded: $($members.Count) member(s)" -ForegroundColor DarkGray
                    }
                    catch {
                        Write-LogHost "      Warning: Failed to expand group '$group': $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            }
            
            # Deduplicate
            $script:targetUsers = $script:targetUsers | Select-Object -Unique
            Write-LogHost "  Total target users after deduplication: $($script:targetUsers.Count)" -ForegroundColor Green
            Write-LogHost ""
        }

        $startDateObj = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)
        $endDateObj = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null)

        Write-LogHost "Starting enterprise-grade audit log search..." -ForegroundColor Yellow
        Write-LogHost "Date range: $($startDateObj.ToString('yyyy-MM-dd')) (inclusive) to $($endDateObj.ToString('yyyy-MM-dd')) (exclusive)" -ForegroundColor Gray
        Write-LogHost "Processing mode: $(if ($ExplodeDeep){'Deep Column Explosion (with Row Explosion)'} elseif ($ExplodeArrays){'Array Explosion'} else {'Standard 1:1'})" -ForegroundColor Gray
        Write-LogHost ""

        Write-LogHost "Initializing adaptive block sizing..." -ForegroundColor Cyan
        $allLogs = New-Object System.Collections.ArrayList

        $queryPlan = Get-QueryPlan -RequestedActivities $ActivityTypes
        $script:progressState.Query.Current = 0
        $totalEstimatedBlocks = 0
        foreach ($grp in $queryPlan) { foreach ($act in $grp.Activities) { try { $initialBlock = Get-OptimalBlockSize -ActivityType $act; if (-not $initialBlock -or $initialBlock -le 0) { $initialBlock = $BlockHours }; $rangeHours = ($endDateObj - $startDateObj).TotalHours; $blocks = [int][Math]::Ceiling($rangeHours / $initialBlock); if ($blocks -lt 1) { $blocks = 1 }; $totalEstimatedBlocks += $blocks } catch { $totalEstimatedBlocks += 1 } } }
        if ($totalEstimatedBlocks -lt 1) { $totalEstimatedBlocks = 1 }
        $script:progressState.Query.Total = [int]$totalEstimatedBlocks
        Set-ProgressPhase -Phase 'Query' -Status "Planning queries: $($queryPlan.Count) groups (~$totalEstimatedBlocks blocks)"
        Write-LogHost "Planned $($queryPlan.Count) query groups; estimated query blocks: ~$totalEstimatedBlocks" -ForegroundColor DarkCyan
        $parallelGroupsUsed = 0; $sequentialGroups = 0
        $parallelDecision = Get-ParallelActivationDecision -QueryPlan $queryPlan -ParallelMode $ParallelMode -MaxParallelGroups $MaxParallelGroups -MaxConcurrency $MaxConcurrency
        $parallelOverallEnabled = $parallelDecision.Enabled
        Write-LogHost ("ParallelMode requested: {0} | Effective: {1} ({2})" -f $ParallelMode, ($(if ($parallelOverallEnabled) { 'Enabled' } else { 'Disabled' })), $parallelDecision.Reason) -ForegroundColor DarkCyan
        if ($ParallelMode -eq 'Auto' -and -not $parallelOverallEnabled) { Write-LogHost "WARNING: ParallelMode Auto requested but heuristics not met -> running sequential. Reason: $($parallelDecision.Reason)." -ForegroundColor Yellow }
        if ($ParallelMode -eq 'Auto' -and -not $parallelOverallEnabled) { Write-LogHost "WARNING: ParallelMode Auto requested but heuristics not met -> running sequential. Reason: $($parallelDecision.Reason)." -ForegroundColor Yellow; Write-LogHost "Tip: Force parallel with -ParallelMode On (PS 7+ required) or reduce activity/group count." -ForegroundColor DarkYellow }
        if ($legacyParallelSwitchUsed) { Write-LogHost "Legacy -EnableParallel switch detected -> overriding ParallelMode to On" -ForegroundColor DarkYellow }
        if ($EnableParallel -and $queryPlan.Count -gt 0 -and $MaxParallelGroups -gt $queryPlan.Count) { Write-LogHost "Note: MaxParallelGroups ($MaxParallelGroups) exceeds total groups ($($queryPlan.Count)). Consider lowering it for less overhead." -ForegroundColor DarkYellow }
        $groupIndex = 0
        foreach ($grp in $queryPlan) { $groupIndex++; Write-LogHost "Group: $($grp.Name) [$(($grp.Activities -join ', '))] (concurrency: $([Math]::Min($grp.Concurrency,$MaxConcurrency)))" -ForegroundColor Yellow; $degree = [Math]::Min($grp.Concurrency, $MaxConcurrency); $withinCap = $groupIndex -le $MaxParallelGroups; $canParallel = $parallelOverallEnabled -and $withinCap -and ($PSVersionTable.PSVersion.Major -ge 7) -and ($degree -gt 1) -and ($grp.Activities.Count -gt 1); if ($parallelOverallEnabled -and -not $withinCap) { Write-LogHost "  Parallel eligible but group index $groupIndex exceeds MaxParallelGroups ($MaxParallelGroups). Running sequentially." -ForegroundColor DarkYellow }; if ($parallelOverallEnabled -and -not ($PSVersionTable.PSVersion.Major -ge 7)) { Write-LogHost "Parallel mode requested but PowerShell 7+ is required. Falling back to sequential." -ForegroundColor DarkYellow }; if ($canParallel) { $parallelGroupsUsed++; Write-LogHost "  Processing group in parallel (ThrottleLimit=$degree)..." -ForegroundColor Cyan; try { $results = $grp.Activities | ForEach-Object -Parallel { $t0 = Get-Date; $activity = $_; try { $sleepMs = (Get-Random -Minimum 100 -Maximum 600); Start-Sleep -Milliseconds $sleepMs } catch {}; $logs = Invoke-ActivityTimeWindowProcessing -ActivityType $activity -StartDate $using:startDateObj -EndDate $using:endDateObj; $t1 = Get-Date; $count = if ($logs) { [int]$logs.Count } else { 0 }; [pscustomobject]@{ Activity = $activity; Logs = $logs; RetrievedCount = $count; ElapsedMs = [int]($t1 - $t0).TotalMilliseconds } } -ThrottleLimit $degree; foreach ($res in $results) { $act = $res.Activity; try { $script:metrics.QueryMs += [int]$res.ElapsedMs; if (-not $script:metrics.Activities.ContainsKey($act)) { $script:metrics.Activities[$act] = @{ Retrieved = 0; Structured = 0 } }; $script:metrics.Activities[$act].Retrieved += [int]$res.RetrievedCount; $script:metrics.TotalRecordsFetched += [int]$res.RetrievedCount } catch {}; if ($res.Logs) { [void]$allLogs.AddRange($res.Logs) } } } catch { Write-LogHost "  Parallel processing failed for group '$($grp.Name)': $($_.Exception.Message). Falling back to sequential for this group." -ForegroundColor DarkYellow; foreach ($act in $grp.Activities) { $tq0 = Get-Date; Write-LogHost "Querying activity: $act" -ForegroundColor DarkCyan; $logs = Invoke-ActivityTimeWindowProcessing -ActivityType $act -StartDate $startDateObj -EndDate $endDateObj; $tq1 = Get-Date; try { $ms = [int]($tq1 - $tq0).TotalMilliseconds; $script:metrics.QueryMs += $ms; if (-not $script:metrics.Activities.ContainsKey($act)) { $script:metrics.Activities[$act] = @{ Retrieved = 0; Structured = 0 } }; if ($logs) { $script:metrics.Activities[$act].Retrieved += $logs.Count; $script:metrics.TotalRecordsFetched += $logs.Count; [void]$allLogs.AddRange($logs) } } catch {} } } } else { $sequentialGroups++; foreach ($act in $grp.Activities) { $tq0 = Get-Date; Write-LogHost "Querying activity: $act" -ForegroundColor DarkCyan; $logs = Invoke-ActivityTimeWindowProcessing -ActivityType $act -StartDate $startDateObj -EndDate $endDateObj; $tq1 = Get-Date; try { $ms = [int]($tq1 - $tq0).TotalMilliseconds; $script:metrics.QueryMs += $ms; if (-not $script:metrics.Activities.ContainsKey($act)) { $script:metrics.Activities[$act] = @{ Retrieved = 0; Structured = 0 } }; if ($logs) { $script:metrics.Activities[$act].Retrieved += $logs.Count; $script:metrics.TotalRecordsFetched += $logs.Count; [void]$allLogs.AddRange($logs) } } catch {} } } }
    }
    Set-ProgressPhase -Phase 'Explosion' -Status 'Analyzing and exploding records'

    Write-LogHost ""; Write-LogHost "=== Enterprise Processing Summary ===" -ForegroundColor Green
    Write-LogHost "Total audit records retrieved: $($allLogs.Count)" -ForegroundColor Cyan
    
    # Show agent filter metrics if filtering was applied
    if ($script:metrics.AgentFilterApplied) {
        Write-LogHost ""
        Write-LogHost "Agent Filtering Metrics:" -ForegroundColor Yellow
        Write-LogHost "  Records before agent filter: $($script:metrics.AgentFilterPreCount)" -ForegroundColor Cyan
        Write-LogHost "  Records after agent filter: $($script:metrics.AgentFilterPostCount)" -ForegroundColor Cyan
        Write-LogHost "  Records filtered out: $($script:metrics.AgentFilterRemovedCount)" -ForegroundColor Gray
        $retentionPct = if ($script:metrics.AgentFilterPreCount -gt 0) { 
            [math]::Round(($script:metrics.AgentFilterPostCount / $script:metrics.AgentFilterPreCount) * 100, 2) 
        } else { 0 }
        Write-LogHost "  Retention rate: $retentionPct%" -ForegroundColor Cyan
        Write-LogHost "  Filter processing time: $($script:metrics.AgentFilterElapsedSec) seconds" -ForegroundColor Gray
    }
    
    # Show ExcludeAgents filter metrics if filtering was applied
    if ($script:metrics.ExcludeAgentsApplied) {
        Write-LogHost ""
        Write-LogHost "ExcludeAgents Filtering Metrics:" -ForegroundColor Yellow
        Write-LogHost "  Records before ExcludeAgents: $($script:metrics.ExcludeAgentsPreCount)" -ForegroundColor Cyan
        Write-LogHost "  Records after ExcludeAgents: $($script:metrics.ExcludeAgentsPostCount)" -ForegroundColor Cyan
        Write-LogHost "  Agent records excluded: $($script:metrics.ExcludeAgentsRemoved)" -ForegroundColor Gray
        $excludeRetentionPct = if ($script:metrics.ExcludeAgentsPreCount -gt 0) { 
            [math]::Round(($script:metrics.ExcludeAgentsPostCount / $script:metrics.ExcludeAgentsPreCount) * 100, 2) 
        } else { 0 }
        Write-LogHost "  Retention rate: $excludeRetentionPct%" -ForegroundColor Cyan
        Write-LogHost "  Filter processing time: $($script:metrics.ExcludeAgentsElapsedSec) seconds" -ForegroundColor Gray
    }
    
    # Show PromptFilter metrics if filtering was applied
    if ($script:metrics.PromptFilterApplied) {
        Write-LogHost ""
        Write-LogHost "Prompt Filtering Metrics:" -ForegroundColor Yellow
        $filterTypeLabel = if ($script:metrics.PromptFilterType -eq 'Prompt') { 'Prompts Only (isPrompt=True)' } else { 'Responses Only (isPrompt=False)' }
        Write-LogHost "  Filter type: $filterTypeLabel" -ForegroundColor Cyan
        Write-LogHost "  Messages before filter: $($script:metrics.PromptFilterMsgBefore)" -ForegroundColor Cyan
        Write-LogHost "  Messages after filter: $($script:metrics.PromptFilterMsgAfter)" -ForegroundColor Cyan
        Write-LogHost "  Messages filtered out: $($script:metrics.PromptFilterMsgRemoved)" -ForegroundColor Gray
        $msgRetentionPct = if ($script:metrics.PromptFilterMsgBefore -gt 0) { 
            [math]::Round(($script:metrics.PromptFilterMsgAfter / $script:metrics.PromptFilterMsgBefore) * 100, 2) 
        } else { 0 }
        Write-LogHost "  Retention rate: $msgRetentionPct%" -ForegroundColor Cyan
    }
    
    if (-not $RAWInputCSV) {
        Write-LogHost "Learned block sizes: $(if ($script:learnedActivityBlockSize.Count -gt 0){ ($script:learnedActivityBlockSize.GetEnumerator()|ForEach-Object{"{0}={1}h" -f $_.Key,$_.Value}) -join ', ' } else {'Using defaults'})" -ForegroundColor Gray
        Write-LogHost "Global learned size: $($script:globalLearnedBlockSize) hours" -ForegroundColor Gray
    }

    if ($script:Hit10KLimit) { Write-LogHost ""; Write-LogHost "  CRITICAL NOTICE: Exchange Online 10K limit was reached during processing!" -ForegroundColor Red; Write-LogHost "   Time window affected: $($script:LimitTimeWindow)" -ForegroundColor Yellow; Write-LogHost "   Data may be incomplete - consider using smaller time blocks" -ForegroundColor Red; Write-LogHost "" }

    if ($allLogs.Count -eq 0) {
        Write-LogHost ""; Write-LogHost "No audit logs found in the specified date range for the selected activity types." -ForegroundColor Yellow
        Write-LogHost "This might be because:" -ForegroundColor Yellow
        Write-LogHost "- No matching activity occurred during this period" -ForegroundColor Yellow
        Write-LogHost "- Audit logging is not enabled for the selected activities" -ForegroundColor Yellow
        Write-LogHost "- Insufficient permissions to view audit logs" -ForegroundColor Yellow
        Write-LogHost "- Time blocks may need further subdivision (try shorter date ranges)" -ForegroundColor Yellow
        # Only show tenant context for live queries (not replay mode)
        if (-not $RAWInputCSV) {
            try {
                $endDomain = if ($script:TenantPrimaryDomain) { $script:TenantPrimaryDomain } else { '<unknown>' }
                $endTenantId = if ($script:TenantId) { $script:TenantId } else { '<unresolved>' }
                $ind = ''; if ($script:TenantIndicators -and $script:TenantIndicators.Count -gt 0) { $ind = ' | Indicators=' + ($script:TenantIndicators -join ',') }
                Write-LogHost ("Tenant context: Domain=$endDomain | TenantId=$endTenantId$ind") -ForegroundColor DarkCyan
            }
            catch {}
        }
        # Deterministic empty CSV output with header only
        Write-LogHost "Emitting header-only CSV (0 rows) for deterministic downstream processing..." -ForegroundColor Cyan
        $headerColumns = if ($ExplodeDeep -or $ExplodeArrays -or $ForcedRawInputCsvExplosion) { $PurviewExplodedHeader } else { @('RecordType', 'CreationDate', 'UserIds', 'Operations', 'ResultStatus', 'ResultCount', 'Identity', 'IsValid', 'ObjectState', 'Id', 'CreationTime', 'Operation', 'OrganizationId', 'RecordTypeNum', 'ResultStatus_Audit', 'UserKey', 'UserType', 'Version', 'Workload', 'UserId', 'AppId', 'ClientAppId', 'CorrelationId', 'ModelId', 'ModelProvider', 'ModelFamily', 'TokensTotal', 'TokensInput', 'TokensOutput', 'DurationMs', 'OutcomeStatus', 'ConversationId', 'TurnNumber', 'RetryCount', 'ClientVersion', 'ClientPlatform', 'AgentId', 'AgentName', 'AppIdentity', 'ApplicationName', 'OriginalAuditData', 'CopilotEventData') }
        try {
            $outputDirEmpty = Split-Path $OutputFile -Parent; if (-not (Test-Path $outputDirEmpty)) { New-Item -ItemType Directory -Path $outputDirEmpty -Force | Out-Null }
            # Build header using same escaping logic as writer (duplicate lightweight implementation to avoid side-effects)
            $enc = New-Object System.Text.UTF8Encoding($false)
            $sw = [System.IO.StreamWriter]::new($OutputFile, $false, $enc)
            $escapedCols = @()
            foreach ($col in $headerColumns) {
                $c = [string]$col
                $needsQuote = ($c -match '[",\r\n]') -or $c.StartsWith(' ') -or $c.EndsWith(' ')
                $escaped = $c -replace '"', '""'
                if ($needsQuote) { $escaped = '"' + $escaped + '"' }
                $escapedCols += , $escaped
            }
            $sw.WriteLine(($escapedCols -join ',')); $sw.Flush(); $sw.Dispose()
        }
        catch { Write-LogHost "Failed to write header-only CSV: $($_.Exception.Message)" -ForegroundColor Red }
        $script:metrics.TotalStructuredRows = 0
        $script:metrics.EffectiveChunkSize = 0
        Set-ProgressPhase -Phase 'Complete' -Status 'No data'
        Complete-Progress
        Write-LogHost "Header-only CSV created at: $OutputFile" -ForegroundColor Green
        return
    }
    # Avoid duplicate global learned size line; suppress entirely for replay
    if (-not $RAWInputCSV) { Write-LogHost "Global learned size: $($script:globalLearnedBlockSize) hours" -ForegroundColor Gray }
    if ($script:metrics.ShrinkEvents -gt 5) { Write-LogHost "NOTICE: Frequent block shrink events ($($script:metrics.ShrinkEvents)). Consider smaller -BlockHours for high-volume activities." -ForegroundColor DarkYellow }

    $effectiveExplode = ($ExplodeDeep -or $ExplodeArrays -or $ForcedRawInputCsvExplosion)
    $processingMode = if ($ExplodeDeep) { "deep column flattening (with row explosion)" } elseif ($ExplodeArrays -or $ForcedRawInputCsvExplosion) { "array explosion" } else { "standard 1:1 format" }
    Write-LogHost "Converting audit records to structured format using $processingMode..." -ForegroundColor Yellow
    # --- Explosion & Export (streaming) ---
    # Streaming export: rows converted & flushed incrementally to manage memory.
    $structuredDataCount = 0
    Write-LogHost "Streaming export mode enabled (schema sample=$StreamingSchemaSample; base chunk size=$StreamingChunkSize)" -ForegroundColor Yellow
    
    # Note: Parallel eligibility will be checked after agent filtering (if applicable) to use correct filtered count
    $te0 = Get-Date
    $schemaFrozen = $false; $schemaSampleRows = New-Object System.Collections.Generic.List[object]; $postFreezeNewColumns = 0
    # Track distinct late (post-freeze) columns ignored (deep mode / parallel replay)
    $lateIgnoredColumns = New-Object System.Collections.Generic.HashSet[string]
    $columnOrder = $null
    $buffer = New-Object System.Collections.Generic.List[object]
    $exportTemp = New-TemporaryFile; try { Remove-Item $exportTemp -ErrorAction SilentlyContinue } catch {}
    # CSV writer is opened after schema (column order) is finalized
    $csvWriter = $false  # indicates initialization state
    $explosionError = $null
    
    # Pre-parse JSON data from CSV for improved processing speed
    if ($RAWInputCSV) {
        # Initialize parsing phase progress tracking
        $parsingStatus = 'Pre-parsing JSON from CSV'
        if ($AgentId -or $AgentsOnly) {
            $parsingStatus += ' + Agent filter'
        }
        if ($UserIds) {
            $parsingStatus += ' + User filter'
        }
        Set-ProgressPhase -Phase 'Parsing' -Status $parsingStatus
        $script:progressState.Parsing.Total = [int]$allLogs.Count
        $script:progressState.Parsing.Current = 0
    }
    Write-LogHost "Pre-parsing AuditData JSON for $($allLogs.Count) records..." -ForegroundColor Cyan
    $parseStart = Get-Date
    $parseErrors = 0
    $parseCount = 0
    foreach ($log in $allLogs) {
        if ($log.AuditData -and $log.AuditData -is [string]) {
            try {
                $parsed = $log.AuditData | ConvertFrom-Json -ErrorAction Stop
                # Add parsed data as a new property to avoid repeated parsing
                Add-Member -InputObject $log -NotePropertyName '_ParsedAuditData' -NotePropertyValue $parsed -Force
            }
            catch {
                $parseErrors++
                Add-Member -InputObject $log -NotePropertyName '_ParsedAuditData' -NotePropertyValue $null -Force
            }
        }
        else {
            # Already parsed or missing
            Add-Member -InputObject $log -NotePropertyName '_ParsedAuditData' -NotePropertyValue $log.AuditData -Force
        }
        
        # Update parsing progress (replay mode only)
        if ($RAWInputCSV) {
            $parseCount++
            # Pre-parsing represents 80% of the parsing+filtering task
            # Scale current to 80% of actual progress
            $script:progressState.Parsing.Current = [int]($parseCount * 0.8)
            # Update progress bar every 500 records or at completion
            if ($parseCount % 500 -eq 0 -or $parseCount -eq $allLogs.Count) {
                Update-Progress
            }
        }
    }
    $parseEnd = Get-Date
    $parseElapsed = [int]($parseEnd - $parseStart).TotalSeconds
    Write-LogHost "JSON pre-parsing complete in $parseElapsed seconds ($parseErrors parse errors)" -ForegroundColor Green
    
    # Calculate filter progress allocation (replay mode only)
    # Pre-parsing = 80%, All filters = 20% (divided among active filters)
    # Filter order: User → Agent → ExcludeAgents → Prompt (matches live mode logic)
    if ($RAWInputCSV) {
        $activeFilters = @()
        if ($UserIds) { $activeFilters += 'User' }
        if ($AgentId -or $AgentsOnly) { $activeFilters += 'Agent' }
        if ($ExcludeAgents) { $activeFilters += 'ExcludeAgents' }
        if ($PromptFilter) { $activeFilters += 'Prompt' }
        
        $filterCount = $activeFilters.Count
        if ($filterCount -gt 0) {
            $filterProgressPerFilter = 0.20 / $filterCount  # 20% divided among active filters
            $script:filterProgressOffset = 0.80  # Start at 80% (after pre-parsing)
            $script:filterProgressAllocation = $filterProgressPerFilter
            $script:currentFilterIndex = 0
        } else {
            # No filters active, set to 100%
            $script:progressState.Parsing.Current = $script:progressState.Parsing.Total
            Update-Progress
        }
    }
    
    # --- User/Group Filtering (if specified in replay mode) ---
    # Applied FIRST in replay mode to match live mode logic and improve performance
    if ($RAWInputCSV -and $UserIds) {
        Write-LogHost "Applying User filtering (client-side)..." -ForegroundColor Yellow
        
        # In replay mode, UserIds is used directly (GroupNames is blocked)
        $targetUserList = $UserIds
        
        # Populate script-level targetUsers for summary display consistency
        $script:targetUsers = $UserIds
        
        # Normalize to lowercase for case-insensitive comparison
        $targetUserLookup = @{}
        foreach ($user in $targetUserList) {
            if ($user) {
                $targetUserLookup[$user.ToLower()] = $true
            }
        }
        
        Write-LogHost "  Filtering for $($targetUserLookup.Count) unique user identifier(s)" -ForegroundColor Gray
        
        $preUserFilterCount = $allLogs.Count
        $userFilterStart = Get-Date
        $filteredLogs = New-Object System.Collections.Generic.List[object]
        $userFilterCount = 0
        
        foreach ($log in $allLogs) {
            $logUserId = $null
            try {
                $logUserId = $log._ParsedAuditData.UserId
            } catch {}
            
            if ($logUserId -and $targetUserLookup.ContainsKey($logUserId.ToLower())) {
                $filteredLogs.Add($log)
            }
            $userFilterCount++
            
            # Update progress (replay mode only)
            if ($RAWInputCSV -and ($userFilterCount % 500 -eq 0 -or $userFilterCount -eq $preUserFilterCount)) {
                # Calculate this filter's progress within its allocated 20% slice
                $userFilterProgress = $userFilterCount / $preUserFilterCount
                $progressStart = $script:filterProgressOffset + ($script:currentFilterIndex * $script:filterProgressAllocation)
                $script:progressState.Parsing.Current = [int]($script:progressState.Parsing.Total * ($progressStart + ($userFilterProgress * $script:filterProgressAllocation)))
                Update-Progress
            }
        }
        
        $allLogs = $filteredLogs
        $postUserFilterCount = $allLogs.Count
        $userFilterEnd = Get-Date
        $userFilterElapsed = [int](($userFilterEnd - $userFilterStart).TotalSeconds)
        $userFilteredOutCount = [int]$preUserFilterCount - [int]$postUserFilterCount
        
        # Store user filter metrics
        $script:metrics.UserFilterApplied = $true
        $script:metrics.UserFilterPreCount = $preUserFilterCount
        $script:metrics.UserFilterPostCount = $postUserFilterCount
        $script:metrics.UserFilterRemovedCount = $userFilteredOutCount
        $script:metrics.UserFilterElapsedSec = $userFilterElapsed
        
        Write-LogHost "User filtering complete in $userFilterElapsed seconds" -ForegroundColor Green
        Write-LogHost "  Records before filtering: $preUserFilterCount" -ForegroundColor Gray
        Write-LogHost "  Records after filtering: $postUserFilterCount" -ForegroundColor Gray
        Write-LogHost "  Records filtered out: $userFilteredOutCount" -ForegroundColor Gray
        
        if ($postUserFilterCount -eq 0) {
            Write-LogHost "WARNING: No records match the User filter criteria. Output will contain header only." -ForegroundColor Yellow
        }
        
        # Increment filter index for progress tracking
        if ($RAWInputCSV) { $script:currentFilterIndex++ }
    }
    
    # --- Agent Filtering (if specified) ---
    $preFilterCount = $allLogs.Count
    if ($AgentId -or $AgentsOnly) {
        Write-LogHost "Applying Agent filtering..." -ForegroundColor Yellow
        if ($AgentId) {
            Write-LogHost "  Filtering for AgentId values: $($AgentId -join ', ')" -ForegroundColor Gray
        }
        if ($AgentsOnly) {
            Write-LogHost "  Filtering for records with any AgentId present" -ForegroundColor Gray
        }
        
        $filterStart = Get-Date
        $filteredLogs = New-Object System.Collections.Generic.List[object]
        $filterCount = 0
        
        foreach ($log in $allLogs) {
            if (Test-AgentFilter -ParsedAuditData $log._ParsedAuditData -AgentIdFilter $AgentId -AgentsOnlyFilter $AgentsOnly.IsPresent) {
                $filteredLogs.Add($log)
            }
            $filterCount++
            
            # Update parsing progress bar during filtering (replay mode only)
            if ($RAWInputCSV -and ($filterCount % 500 -eq 0 -or $filterCount -eq $preFilterCount)) {
                # Calculate this filter's progress within its allocated 20% slice
                $filterProgress = $filterCount / $preFilterCount
                $progressStart = $script:filterProgressOffset + ($script:currentFilterIndex * $script:filterProgressAllocation)
                $progressEnd = $progressStart + $script:filterProgressAllocation
                $script:progressState.Parsing.Current = [int]($script:progressState.Parsing.Total * ($progressStart + ($filterProgress * $script:filterProgressAllocation)))
                Update-Progress
            }
        }
        
        $allLogs = $filteredLogs
        $postFilterCount = $allLogs.Count
        $filterEnd = Get-Date
        $filterElapsed = [int](($filterEnd - $filterStart).TotalSeconds)
        $filteredOutCount = [int]$preFilterCount - [int]$postFilterCount
        
        # Store agent filter metrics
        $script:metrics.AgentFilterApplied = $true
        $script:metrics.AgentFilterPreCount = $preFilterCount
        $script:metrics.AgentFilterPostCount = $postFilterCount
        $script:metrics.AgentFilterRemovedCount = $filteredOutCount
        $script:metrics.AgentFilterElapsedSec = $filterElapsed
        
        Write-LogHost "Agent filtering complete in $filterElapsed seconds" -ForegroundColor Green
        Write-LogHost "  Records before filtering: $preFilterCount" -ForegroundColor Gray
        Write-LogHost "  Records after filtering: $postFilterCount" -ForegroundColor Gray
        Write-LogHost "  Records filtered out: $filteredOutCount" -ForegroundColor Gray
        
        if ($postFilterCount -eq 0) {
            Write-LogHost "WARNING: No records match the Agent filter criteria. Output will contain header only." -ForegroundColor Yellow
        }
        
        # Increment filter index for progress tracking
        if ($RAWInputCSV) { $script:currentFilterIndex++ }
    }
    
    # --- ExcludeAgents Filtering (if specified) ---
    if ($ExcludeAgents) {
        Write-LogHost "Applying ExcludeAgents filter..." -ForegroundColor Yellow
        $preExcludeCount = $allLogs.Count
        $excludeStart = Get-Date
        $filteredLogs = New-Object System.Collections.Generic.List[object]
        $excludeCount = 0
        
        foreach ($log in $allLogs) {
            $agentId = $null
            try {
                $agentId = $log._ParsedAuditData.AgentId
            } catch {}
            
            if ([string]::IsNullOrEmpty($agentId)) {
                $filteredLogs.Add($log)
            }
            $excludeCount++
            
            # Update parsing progress bar during ExcludeAgents filtering (replay mode only)
            if ($RAWInputCSV -and ($excludeCount % 500 -eq 0 -or $excludeCount -eq $preExcludeCount)) {
                # Calculate this filter's progress within its allocated 20% slice
                $excludeProgress = $excludeCount / $preExcludeCount
                $progressStart = $script:filterProgressOffset + ($script:currentFilterIndex * $script:filterProgressAllocation)
                $script:progressState.Parsing.Current = [int]($script:progressState.Parsing.Total * ($progressStart + ($excludeProgress * $script:filterProgressAllocation)))
                Update-Progress
            }
        }
        
        $allLogs = $filteredLogs
        $postExcludeCount = $allLogs.Count
        $excludeEnd = Get-Date
        $excludeElapsed = [int](($excludeEnd - $excludeStart).TotalSeconds)
        $excludedCount = [int]$preExcludeCount - [int]$postExcludeCount
        
        # Store ExcludeAgents filter metrics
        $script:metrics.ExcludeAgentsApplied = $true
        $script:metrics.ExcludeAgentsPreCount = $preExcludeCount
        $script:metrics.ExcludeAgentsPostCount = $postExcludeCount
        $script:metrics.ExcludeAgentsRemoved = $excludedCount
        $script:metrics.ExcludeAgentsElapsedSec = $excludeElapsed
        
        Write-LogHost "ExcludeAgents filtering complete in $excludeElapsed seconds" -ForegroundColor Green
        Write-LogHost "  Records before ExcludeAgents: $preExcludeCount" -ForegroundColor Gray
        Write-LogHost "  Records after ExcludeAgents: $postExcludeCount" -ForegroundColor Gray
        Write-LogHost "  Agent records excluded: $excludedCount" -ForegroundColor Gray
        
        if ($postExcludeCount -eq 0) {
            Write-LogHost "WARNING: No non-agent records found. Output will contain header only." -ForegroundColor Yellow
        }
        
        # Increment filter index for progress tracking
        if ($RAWInputCSV) { $script:currentFilterIndex++ }
    }
    
    # --- PromptFilter Filtering (if specified) ---
    if ($PromptFilter) {
        Write-LogHost "Applying PromptFilter..." -ForegroundColor Yellow
        
        $filterDescription = switch ($PromptFilter) {
            'Prompt' { "Prompt messages (isPrompt = True)" }
            'Response' { "Response messages (isPrompt = False)" }
            'Both' { "Both Prompt AND Response messages" }
            'Null' { "Messages with null/missing isPrompt values" }
        }
        Write-LogHost "  Filtering for: $filterDescription" -ForegroundColor Gray
        
        $prePromptCount = $allLogs.Count
        $promptStart = Get-Date
        $filteredLogs = New-Object System.Collections.Generic.List[object]
        $promptCount = 0
        $totalMsgBefore = 0
        $totalMsgAfter = 0
        
        # Track record type breakdown for summary
        $recordsMixed = 0
        $recordsPromptOnly = 0
        $recordsResponseOnly = 0
        $recordsNoMessages = 0
        
        foreach ($log in $allLogs) {
            $hasMatchingMessages = $false
            $hasPrompt = $false
            $hasResponse = $false
            $msgCount = 0
            
            try {
                $messages = $log._ParsedAuditData.CopilotEventData.Messages
                if ($null -eq $messages -or $messages.Count -eq 0) {
                    $recordsNoMessages++
                }
                else {
                    $msgCount = $messages.Count
                    $totalMsgBefore += $msgCount
                    
                    # Analyze record to determine type (for breakdown stats)
                    foreach ($msg in $messages) {
                        if ($msg.isPrompt -eq $true) { $hasPrompt = $true }
                        elseif ($msg.isPrompt -eq $false) { $hasResponse = $true }
                    }
                    
                    # Categorize record type
                    if ($hasPrompt -and $hasResponse) { $recordsMixed++ }
                    elseif ($hasPrompt -and -not $hasResponse) { $recordsPromptOnly++ }
                    elseif ($hasResponse -and -not $hasPrompt) { $recordsResponseOnly++ }
                    
                    # Check based on filter type
                    if ($PromptFilter -eq 'Both') {
                        # Keep records with at least one conversation turn that has explicit isPrompt value (TRUE or FALSE)
                        # This filters out records where all conversation turns have null/undefined isPrompt
                        foreach ($msg in $messages) {
                            if ($null -ne $msg.isPrompt) {
                                $hasMatchingMessages = $true
                                $totalMsgAfter++
                            }
                        }
                    }
                    elseif ($PromptFilter -eq 'Null') {
                        # Keep records that have at least one conversation turn with null isPrompt
                        foreach ($msg in $messages) {
                            if ($null -eq $msg.isPrompt) {
                                $hasMatchingMessages = $true
                                $totalMsgAfter++
                            }
                        }
                    }
                    else {
                        # Prompt or Response filtering
                        $targetIsPromptValue = ($PromptFilter -eq 'Prompt')
                        foreach ($msg in $messages) {
                            if ($msg.isPrompt -eq $targetIsPromptValue) {
                                $hasMatchingMessages = $true
                                $totalMsgAfter++
                            }
                        }
                    }
                }
            } catch {}
            
            if ($hasMatchingMessages) {
                $filteredLogs.Add($log)
            }
            $promptCount++
            
            # Update progress bar during PromptFilter filtering (replay mode only)
            if ($RAWInputCSV -and ($promptCount % 500 -eq 0 -or $promptCount -eq $prePromptCount)) {
                # Calculate this filter's progress within its allocated 20% slice
                $promptProgress = $promptCount / $prePromptCount
                $progressStart = $script:filterProgressOffset + ($script:currentFilterIndex * $script:filterProgressAllocation)
                $script:progressState.Parsing.Current = [int]($script:progressState.Parsing.Total * ($progressStart + ($promptProgress * $script:filterProgressAllocation)))
                Update-Progress
            }
        }
        
        $allLogs = $filteredLogs
        $postPromptCount = $allLogs.Count
        $promptEnd = Get-Date
        $promptElapsed = [Math]::Round(($promptEnd - $promptStart).TotalSeconds, 2)
        $promptFilteredCount = [int]$prePromptCount - [int]$postPromptCount
        $totalMsgRemoved = [int]$totalMsgBefore - [int]$totalMsgAfter
        
        # Store PromptFilter metrics
        $script:metrics.PromptFilterApplied = $true
        $script:metrics.PromptFilterType = $PromptFilter
        $script:metrics.PromptFilterPreCount = $prePromptCount
        $script:metrics.PromptFilterPostCount = $postPromptCount
        $script:metrics.PromptFilterRemovedCount = $promptFilteredCount
        $script:metrics.PromptFilterElapsedSec = $promptElapsed
        $script:metrics.PromptFilterMsgBefore = $totalMsgBefore
        $script:metrics.PromptFilterMsgAfter = $totalMsgAfter
        $script:metrics.PromptFilterMsgRemoved = $totalMsgRemoved
        $script:metrics.PromptFilterRecordsMixed = $recordsMixed
        $script:metrics.PromptFilterRecordsPromptOnly = $recordsPromptOnly
        $script:metrics.PromptFilterRecordsResponseOnly = $recordsResponseOnly
        $script:metrics.PromptFilterRecordsNoMessages = $recordsNoMessages
        
        Write-LogHost "PromptFilter complete in $promptElapsed seconds" -ForegroundColor Green
        Write-LogHost "  Records before PromptFilter: $prePromptCount" -ForegroundColor Gray
        Write-LogHost "  Records after PromptFilter: $postPromptCount" -ForegroundColor Gray
        Write-LogHost "  Records filtered out: $promptFilteredCount" -ForegroundColor Gray
        Write-LogHost "  Messages before PromptFilter: $totalMsgBefore" -ForegroundColor Gray
        Write-LogHost "  Matching messages found: $totalMsgAfter" -ForegroundColor Gray
        
        if ($postPromptCount -eq 0) {
            Write-LogHost "WARNING: No records match the PromptFilter criteria. Output will contain header only." -ForegroundColor Yellow
        }
        elseif ($PromptFilter -eq 'Null' -and $totalMsgAfter -eq 0) {
            Write-LogHost "WARNING: PromptFilter=Null found no matching messages." -ForegroundColor Yellow
            Write-LogHost "  This means all messages in the filtered records have explicit isPrompt values (True or False)." -ForegroundColor Yellow
            Write-LogHost "  Consider using PromptFilter=Prompt or PromptFilter=Response instead." -ForegroundColor Yellow
        }
        
        # Increment filter index for progress tracking (final filter)
        if ($RAWInputCSV) { 
            $script:currentFilterIndex++ 
            # Set progress to 100% after all filters complete
            $script:progressState.Parsing.Current = $script:progressState.Parsing.Total
            Update-Progress
        }
    }
    
    # Set explosion phase total based on final filtered count
    $script:progressState.Explode.Total = [int]$allLogs.Count
    $script:progressState.Explode.Current = 0
    
    # Check parallel eligibility AFTER agent filtering (uses filtered count)
    $replayParallelEligible = $false
    if ($RAWInputCSV -and ($PSVersionTable.PSVersion.Major -ge 7)) {
        $eligibilityThreshold = ($StreamingSchemaSample + 5000)
        Write-LogHost "Parallel eligibility check: RAW=$RAWInputCSV, PS=$($PSVersionTable.PSVersion.Major), Count=$($allLogs.Count), Threshold=$eligibilityThreshold" -ForegroundColor DarkGray
        if ($allLogs.Count -gt $eligibilityThreshold) { 
            $replayParallelEligible = $true 
            Write-LogHost "Replay parallel explosion ELIGIBLE -> will parallelize after schema freeze ($($allLogs.Count) records)" -ForegroundColor Green
        }
        else {
            Write-LogHost "Replay parallel NOT eligible (dataset too small: $($allLogs.Count) <= $eligibilityThreshold)" -ForegroundColor DarkYellow
        }
    }
    else {
        if (-not $RAWInputCSV) { Write-LogHost "Parallel not eligible: Not in replay mode" -ForegroundColor DarkGray }
        elseif ($PSVersionTable.PSVersion.Major -lt 7) { Write-LogHost "Parallel not eligible: PowerShell $($PSVersionTable.PSVersion) (need 7+)" -ForegroundColor DarkYellow }
    }
    
    # Begin record explosion and transformation phase
    Set-ProgressPhase -Phase 'Explosion' -Status 'Analyzing and exploding records'
    
    # Capture the count of records going into explosion (after all filtering)
    $script:metrics.RecordsAfterFiltering = $allLogs.Count
    
    $parallelProcessingComplete = $false
    try {
        foreach ($log in $allLogs) {
            # Skip remaining logs if parallel processing already handled them
            if ($parallelProcessingComplete) { continue }
            
            $records = if ($effectiveExplode) { Convert-ToPurviewExplodedRecords -Record $log -Deep:$ExplodeDeep -PromptFilterValue $PromptFilter } else { Convert-ToStructuredRecord -Record $log -EnableExplosion:$false }
            if ($records -and $records.Count -gt 0) {
                try {
                    $script:metrics.TotalStructuredRows += $records.Count; $structuredDataCount += $records.Count
                    $opName = $null; try { $opName = if ($log.Operation) { [string]$log.Operation } elseif ($log.Operations) { [string]$log.Operations } else { $null } } catch {}; if (-not $opName) { $opName = 'Unknown' }
                    if (-not $script:metrics.Activities.ContainsKey($opName)) { $script:metrics.Activities[$opName] = @{ Retrieved = 0; Structured = 0 } }
                    $script:metrics.Activities[$opName].Structured += $records.Count
                    if ($effectiveExplode -and $records.Count -gt 1) { $script:metrics.ExplosionEvents += 1; $script:metrics.ExplosionRowsFromEvents += ($records.Count - 1); if ($records.Count -gt $script:metrics.ExplosionMaxPerRecord) { $script:metrics.ExplosionMaxPerRecord = $records.Count } }
                }
                catch {}
                foreach ($r in $records) {
                    if (-not $schemaFrozen) {
                        $schemaSampleRows.Add($r) | Out-Null
                        if ($schemaSampleRows.Count -ge $StreamingSchemaSample) {
                            # Build column order now
                            if ($ExplodeArrays -or $ExplodeDeep -or $ForcedRawInputCsvExplosion) {
                                $columnOrder = New-Object System.Collections.Generic.List[string]; foreach ($c in $PurviewExplodedHeader) { [void]$columnOrder.Add($c) }
                                if ($ExplodeDeep -and $script:DeepExtraColumns -and $script:DeepExtraColumns.Count -gt 0) { foreach ($c in $script:DeepExtraColumns) { if (-not $columnOrder.Contains($c)) { [void]$columnOrder.Add($c) } } }
                            }
                            else {
                                $columnOrder = New-Object System.Collections.Generic.List[string]; foreach ($sr in $schemaSampleRows) { foreach ($pn in $sr.PSObject.Properties.Name) { if (-not $columnOrder.Contains($pn)) { [void]$columnOrder.Add($pn) } } }
                            }
                            # Flush schema sample rows (header + first chunk)
                            Write-LogHost "Schema frozen with $($columnOrder.Count) columns after $($schemaSampleRows.Count) sample rows" -ForegroundColor DarkCyan
                            # Adaptive chunk sizing based on column width to balance memory & throughput
                            $effectiveChunkSize = $StreamingChunkSize
                            $colCount = $columnOrder.Count
                            if ($colCount -gt 1000) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 1000) }
                            elseif ($colCount -gt 750) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 1500) }
                            elseif ($colCount -gt 500) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 2500) }
                            elseif ($colCount -gt 250) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 4000) }
                            else {
                                # Narrow schema (<=250 columns) -> upscale chunk size to reduce flush calls & writer overhead
                                $effectiveChunkSize = $StreamingChunkSize
                                if ($colCount -le 60 -and $StreamingChunkSize -lt 15000) {
                                    $autoBoost = [int][Math]::Min(15000, [Math]::Max($StreamingChunkSize * 3, 8000))
                                    $effectiveChunkSize = $autoBoost
                                }
                            }
                            if ($effectiveChunkSize -ne $StreamingChunkSize) { Write-LogHost "Adaptive chunk size applied: $effectiveChunkSize (was $StreamingChunkSize) due to column width $colCount" -ForegroundColor DarkYellow } else { Write-LogHost "Chunk size retained/boosted: $effectiveChunkSize (columns=$colCount)" -ForegroundColor DarkGray }
                            $script:metrics.EffectiveChunkSize = $effectiveChunkSize
                            if (-not $csvWriter) { Open-CsvWriter -Path $exportTemp -Columns $columnOrder; $csvWriter = $true }
                            $emitRows = @()
                            foreach ($sr in $schemaSampleRows) { $emitRows += ($sr | Select-Object -Property $columnOrder) }
                            if ($emitRows.Count -gt 0) { Write-CsvRows -Rows $emitRows -Columns $columnOrder }
                            $schemaSampleRows.Clear(); $schemaFrozen = $true
                            if ($replayParallelEligible) {
                                # Switch to parallel processing for remaining logs
                                $logsConsumedForSchema = $script:progressState.Explode.Current
                                Write-LogHost "Starting parallel explosion for remaining logs (consumed=$logsConsumedForSchema, total=$($allLogs.Count))" -ForegroundColor Cyan
                                $remainingLogs = @()
                                if ($logsConsumedForSchema -lt $allLogs.Count) { $remainingLogs = $allLogs[$logsConsumedForSchema..($allLogs.Count - 1)] } else { $remainingLogs = @() }
                                # Configure parallel processing with optimized batch sizes for large datasets
                                $parallelBatchSize = [int][Math]::Max(10000, [Math]::Min(20000, [int]($remainingLogs.Count / 20)))
                                $parallelBatchSizeOriginal = $parallelBatchSize  # Preserve original for batch total calculation
                                $throttle = [int][Math]::Min([Environment]::ProcessorCount, 8)
                                $targetMinMs = 3000; $targetMaxMs = 12000
                                $remainingCount = $remainingLogs.Count
                                $processedRemaining = 0
                                # Calculate total batches ONCE at the start using ORIGINAL batch size (don't recalculate if batchSize changes mid-stream)
                                $totalBatchesInitial = [Math]::Ceiling($remainingCount / $parallelBatchSizeOriginal)
                                Write-LogHost "Parallel batch config: batchSize=$parallelBatchSize, throttle=$throttle, batches=$totalBatchesInitial" -ForegroundColor DarkCyan
                                # Show progress note in terminal only (not in log file)
                                Write-Host "NOTE: Progress bar updates between batches - progress may appear paused during intensive parallel processing." -ForegroundColor Yellow
                                
                                # Get function definitions to pass into parallel runspace
                                $convertExplodedDef = ${function:Convert-ToPurviewExplodedRecords}.ToString()
                                $convertStructuredDef = ${function:Convert-ToStructuredRecord}.ToString()
                                $getSafePropertyDef = ${function:Get-SafeProperty}.ToString()
                                $getArrayFastDef = ${function:GetArrayFast}.ToString()
                                $selectFirstNonNullDef = ${function:Select-FirstNonNull}.ToString()
                                $formatDateDef = ${function:Format-DatePurviewFast}.ToString()
                                $boolTFDef = ${function:BoolTFFast}.ToString()
                                # Pass required script variables
                                $purviewHeader = $PurviewExplodedHeader
                                $deepExtraColumns = $script:DeepExtraColumns
                                $regexTrueFalse = $script:RegexTrueFalse
                                $regexYes1 = $script:RegexYes1
                                $regexNo0 = $script:RegexNo0
                                
                                # Show initial batch progress before starting
                                # Calculate initial batch display with dynamic total
                                $firstBatchSize = [Math]::Min($parallelBatchSize, $remainingCount)
                                $firstRangeStart = 1
                                $firstRangeEnd = $logsConsumedForSchema + $firstBatchSize
                                $remainingAfterFirstBatch = $remainingCount - $firstBatchSize
                                if ($remainingAfterFirstBatch -le 0) {
                                    # No records left - only one batch
                                    $firstBatchTotal = 1
                                    $firstBatchIsEstimate = $false
                                } else {
                                    # Smart batch estimation: Account for the fact that the final batch will
                                    # process ALL remaining records in one go (no splitting of the last batch)
                                    $estimatedRemainingBatches = [Math]::Ceiling($remainingAfterFirstBatch / $parallelBatchSize)
                                    # If Math.Ceiling says 2+ batches, but the "excess" in the last batch is small,
                                    # reduce the estimate by 1 (assuming adaptive sizing or final batch consolidation)
                                    if ($estimatedRemainingBatches -ge 2) {
                                        $excessInLastBatch = $remainingAfterFirstBatch - (($estimatedRemainingBatches - 1) * $parallelBatchSize)
                                        # If the "last batch" would be tiny (< 20% of batch size), assume it gets absorbed
                                        if ($excessInLastBatch -le ($parallelBatchSize * 0.2)) {
                                            $estimatedRemainingBatches--
                                        }
                                    }
                                    $firstBatchTotal = 1 + $estimatedRemainingBatches
                                    $firstBatchIsEstimate = $true
                                }
                                # Calculate percentage range for this batch
                                $firstBatchStartPct = 0
                                $firstBatchEndPct = [int]([Math]::Round(([double]$firstRangeEnd / [double]$script:progressState.Explode.Total) * 100))
                                Update-Progress -BatchCurrent 1 -BatchTotal $firstBatchTotal -BatchRangeStart $firstRangeStart -BatchRangeEnd $firstRangeEnd -BatchStartPercent $firstBatchStartPct -BatchEndPercent $firstBatchEndPct -BatchTotalIsEstimate $firstBatchIsEstimate
                                
                                # Track actual batch iteration count (not calculated from position)
                                $actualBatchIteration = 1
                                while ($processedRemaining -lt $remainingCount) {
                                    $batchSize = [Math]::Min($parallelBatchSize, $remainingCount - $processedRemaining)
                                    $batch = $remainingLogs[$processedRemaining..($processedRemaining + $batchSize - 1)]
                                    
                                    # Calculate batch info for progress display
                                    # Use actual iteration count (accounts for adaptive batch sizing)
                                    $currentBatch = $actualBatchIteration
                                    # Calculate total batches dynamically based on current position and remaining records
                                    # This accounts for adaptive batch sizing that may have changed the actual number of batches
                                    $remainingAfterThisBatch = $remainingCount - ($processedRemaining + $batchSize)
                                    if ($remainingAfterThisBatch -le 0) {
                                        # This is the last batch - show exact total
                                        $totalBatches = $currentBatch
                                        $batchTotalIsEstimate = $false
                                    } else {
                                        # Smart batch estimation
                                        $estimatedRemainingBatches = [Math]::Ceiling($remainingAfterThisBatch / $parallelBatchSize)
                                        # If the final batch would be tiny, assume it gets absorbed into the previous batch
                                        if ($estimatedRemainingBatches -ge 2) {
                                            $excessInLastBatch = $remainingAfterThisBatch - (($estimatedRemainingBatches - 1) * $parallelBatchSize)
                                            if ($excessInLastBatch -le ($parallelBatchSize * 0.2)) {
                                                $estimatedRemainingBatches--
                                            }
                                        }
                                        $totalBatches = $currentBatch + $estimatedRemainingBatches
                                        $batchTotalIsEstimate = $true
                                    }
                                    
                                    # Calculate the record range for THIS batch being processed (1-indexed display)
                                    $rangeStart = $logsConsumedForSchema + $processedRemaining + 1
                                    $rangeEnd = $logsConsumedForSchema + $processedRemaining + $batchSize
                                    
                                    # Calculate percentage range for this batch
                                    $batchStartPct = [int]([Math]::Round(([double]($logsConsumedForSchema + $processedRemaining) / [double]$script:progressState.Explode.Total) * 100))
                                    $batchEndPct = [int]([Math]::Round(([double]$rangeEnd / [double]$script:progressState.Explode.Total) * 100))
                                    
                                    # Update progress BEFORE starting batch to show what's being processed
                                    $script:progressState.Explode.Current = $logsConsumedForSchema + $processedRemaining
                                    Update-Progress -BatchCurrent $currentBatch -BatchTotal $totalBatches -BatchRangeStart $rangeStart -BatchRangeEnd $rangeEnd -BatchStartPercent $batchStartPct -BatchEndPercent $batchEndPct -BatchTotalIsEstimate $batchTotalIsEstimate
                                    
                                    $batchStart = Get-Date
                                    try {
                                        $batchResults = $batch | ForEach-Object -Parallel {
                                            # Reconstruct helper functions and variables in parallel runspace
                                            $script:PurviewExplodedHeader = $using:purviewHeader
                                            $script:DeepExtraColumns = $using:deepExtraColumns
                                            $script:RegexTrueFalse = $using:regexTrueFalse
                                            $script:RegexYes1 = $using:regexYes1
                                            $script:RegexNo0 = $using:regexNo0
                                            
                                            # Define helper functions in script scope for parallel runspace
                                            $null = New-Item -Path function:script:Get-SafeProperty -Value ([scriptblock]::Create($using:getSafePropertyDef)) -Force
                                            $null = New-Item -Path function:script:GetArrayFast -Value ([scriptblock]::Create($using:getArrayFastDef)) -Force
                                            $null = New-Item -Path function:script:Select-FirstNonNull -Value ([scriptblock]::Create($using:selectFirstNonNullDef)) -Force
                                            $null = New-Item -Path function:script:Format-DatePurviewFast -Value ([scriptblock]::Create($using:formatDateDef)) -Force
                                            $null = New-Item -Path function:script:BoolTFFast -Value ([scriptblock]::Create($using:boolTFDef)) -Force
                                            # Also create non-script versions for functions that may be called without prefix
                                            $null = New-Item -Path function:Get-SafeProperty -Value ([scriptblock]::Create($using:getSafePropertyDef)) -Force
                                            $null = New-Item -Path function:Select-FirstNonNull -Value ([scriptblock]::Create($using:selectFirstNonNullDef)) -Force
                                            # Define conversion functions
                                            $null = New-Item -Path function:Convert-ToPurviewExplodedRecords -Value ([scriptblock]::Create($using:convertExplodedDef)) -Force
                                            $null = New-Item -Path function:Convert-ToStructuredRecord -Value ([scriptblock]::Create($using:convertStructuredDef)) -Force
                                            
                                            # Access variables from outer scope using $using:
                                            $effectiveExplode = $using:effectiveExplode
                                            $explodeDeep = $using:ExplodeDeep
                                            $promptFilterVal = $using:PromptFilter
                                            
                                            $rows = if ($effectiveExplode) { Convert-ToPurviewExplodedRecords -Record $_ -Deep:$explodeDeep -PromptFilterValue $promptFilterVal } else { Convert-ToStructuredRecord -Record $_ -EnableExplosion:$false }
                                            $rc = 0; if ($null -ne $rows) { if ($rows -is [System.Array]) { $rc = $rows.Count } else { $rc = 1 } }
                                            [pscustomobject]@{ Rows = $rows; RowCount = $rc; ExplosionRows = if ($rc -gt 1) { $rc - 1 } else { 0 }; MaxRows = $rc }
                                        } -ThrottleLimit $throttle
                                    }
                                    catch {
                                        if ($_.Exception -is [System.OutOfMemoryException]) {
                                            $oldBatchSize = $parallelBatchSize
                                            $oldThrottle = $throttle
                                            $parallelBatchSize = [int][Math]::Max(200, [int]($parallelBatchSize / 2))
                                            $throttle = [int][Math]::Max(1, [int]($throttle / 2))
                                            Write-LogHost "OutOfMemory during parallel batch -> reducing batch size from $oldBatchSize to $parallelBatchSize, throttle from $oldThrottle to $throttle (batch totals remain fixed at $totalBatchesInitial)" -ForegroundColor Red
                                            continue
                                        }
                                        else { throw }
                                    }
                                    # batchResults is an array of arrays / single objects
                                    $flatRows = New-Object System.Collections.Generic.List[object]
                                    foreach ($br in $batchResults) {
                                        if ($null -ne $br) {
                                            $rc = 0; try { $rc = $br.RowCount } catch {}
                                            $rowsObj = $null; try { $rowsObj = $br.Rows } catch { $rowsObj = $br }
                                            if ($rowsObj -is [System.Array]) { foreach ($r in $rowsObj) { if ($null -ne $r) { $flatRows.Add($r) | Out-Null } } } elseif ($null -ne $rowsObj) { $flatRows.Add($rowsObj) | Out-Null }
                                            if ($rc -gt 1) {
                                                $script:metrics.ExplosionEvents += 1
                                                $script:metrics.ExplosionRowsFromEvents += ($rc - 1)
                                                if ($rc -gt $script:metrics.ExplosionMaxPerRecord) { $script:metrics.ExplosionMaxPerRecord = $rc }
                                            }
                                        }
                                    }
                                    # Metrics update
                                    $rowCountThisBatch = $flatRows.Count
                                    $structuredDataCount += $rowCountThisBatch
                                    try {
                                        $script:metrics.TotalStructuredRows += $rowCountThisBatch
                                    }
                                    catch {}
                                    # Flush in sub-chunks according to effectiveChunkSize
                                    if ($flatRows.Count -gt 0) {
                                        $flushIndex = 0
                                        while ($flushIndex -lt $flatRows.Count) {
                                            $subCount = [Math]::Min($effectiveChunkSize, $flatRows.Count - $flushIndex)
                                            $subRows = $flatRows[$flushIndex..($flushIndex + $subCount - 1)] | ForEach-Object { $_ | Select-Object -Property $columnOrder }
                                            if (-not $csvWriter) { Open-CsvWriter -Path $exportTemp -Columns $columnOrder; $csvWriter = $true }
                                            if ($subRows.Count -gt 0) { Write-CsvRows -Rows $subRows -Columns $columnOrder }
                                            $flushIndex += $subCount
                                        }
                                        # Track late columns surfaced only in parallel replay
                                        foreach ($pr in $flatRows) {
                                            foreach ($pn in $pr.PSObject.Properties.Name) {
                                                if (-not $columnOrder.Contains($pn)) {
                                                    if (-not $lateIgnoredColumns.Contains($pn)) { [void]$lateIgnoredColumns.Add($pn) }
                                                }
                                            }
                                        }
                                    }
                                    $processedRemaining += $batchSize
                                    $actualBatchIteration++  # Increment for next iteration
                                    $batchElapsed = (Get-Date) - $batchStart
                                    $elapsedMs = [int]$batchElapsed.TotalMilliseconds
                                    
                                    # Update explosion current count after batch completes
                                    $script:progressState.Explode.Current = [Math]::Min($script:progressState.Explode.Total, ($logsConsumedForSchema + $processedRemaining))
                                    
                                    # Dynamically adjust throttle based on batch completion time
                                    if ($elapsedMs -lt $targetMinMs -and $throttle -lt [Math]::Min([Environment]::ProcessorCount, 12)) { $throttle += 1 }
                                    elseif ($elapsedMs -gt $targetMaxMs -and $throttle -gt 2) { $throttle = [int][Math]::Max(2, $throttle - 1) }
                                    # Adjust batch size based on performance
                                    if ($elapsedMs -lt $targetMinMs -and $parallelBatchSize -lt 40000) { $parallelBatchSize = [int][Math]::Min(40000, [int]($parallelBatchSize * 1.3)) }
                                    elseif ($elapsedMs -gt ($targetMaxMs * 2) -and $parallelBatchSize -gt 5000) { $parallelBatchSize = [int][Math]::Max(5000, [int]($parallelBatchSize * 0.8)) }
                                }
                                $script:metrics.ParallelBatchSizeFinal = $parallelBatchSize
                                $script:metrics.ParallelThrottleFinal = $throttle
                                Write-LogHost "Replay parallel explosion complete (processed remaining=$processedRemaining)" -ForegroundColor DarkCyan
                                $parallelProcessingComplete = $true
                                break
                            }
                        }
                    }
                    else {
                        # Post-freeze rows -> buffer + flush in chunks; track any new columns (ignored) & collect distinct names
                        $rowHadNew = $false
                        foreach ($pn in $r.PSObject.Properties.Name) {
                            if (-not $columnOrder.Contains($pn)) {
                                if (-not $rowHadNew) { $postFreezeNewColumns++; $rowHadNew = $true }
                                if (-not $lateIgnoredColumns.Contains($pn)) { [void]$lateIgnoredColumns.Add($pn) }
                            }
                        }
                        $buffer.Add($r) | Out-Null
                        if (-not $effectiveChunkSize) { $effectiveChunkSize = $StreamingChunkSize }
                        if ($buffer.Count -ge $effectiveChunkSize) {
                            $emitSet = $buffer | ForEach-Object { $_ | Select-Object -Property $columnOrder }
                            if (-not $csvWriter) { Open-CsvWriter -Path $exportTemp -Columns $columnOrder; $csvWriter = $true }
                            if ($emitSet.Count -gt 0) { Write-CsvRows -Rows $emitSet -Columns $columnOrder }
                            $buffer.Clear()
                        }
                    }
                }
            }
            # Streaming continues over the in-memory collection for stable enumeration.
            $script:progressState.Explode.Current++
            if ($script:progressState.Explode.Current % 200 -eq 0 -or $script:progressState.Explode.Current -eq $script:progressState.Explode.Total) { Update-Progress -Status "Exploding (stream): $($script:progressState.Explode.Current)/$($script:progressState.Explode.Total)" } else { Update-Progress }
        }
        # If schema never froze (low volume) build it now and flush remaining sample rows.
        if (-not $schemaFrozen) {
            if ($ExplodeArrays -or $ExplodeDeep -or $ForcedRawInputCsvExplosion) {
                $columnOrder = New-Object System.Collections.Generic.List[string]; foreach ($c in $PurviewExplodedHeader) { [void]$columnOrder.Add($c) }; if ($ExplodeDeep -and $script:DeepExtraColumns -and $script:DeepExtraColumns.Count -gt 0) { foreach ($c in $script:DeepExtraColumns) { if (-not $columnOrder.Contains($c)) { [void]$columnOrder.Add($c) } } }
            }
            else { $columnOrder = New-Object System.Collections.Generic.List[string]; foreach ($sr in $schemaSampleRows) { foreach ($pn in $sr.PSObject.Properties.Name) { if (-not $columnOrder.Contains($pn)) { [void]$columnOrder.Add($pn) } } } }
            Write-LogHost "Schema frozen late with $($columnOrder.Count) columns (total rows <$StreamingSchemaSample)" -ForegroundColor DarkCyan
            $effectiveChunkSize = $StreamingChunkSize; $colCount = $columnOrder.Count
            if ($colCount -gt 1000) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 1000) }
            elseif ($colCount -gt 750) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 1500) }
            elseif ($colCount -gt 500) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 2500) }
            elseif ($colCount -gt 250) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 4000) }
            else {
                if ($colCount -le 60 -and $StreamingChunkSize -lt 15000) {
                    $autoBoost = [int][Math]::Min(15000, [Math]::Max($StreamingChunkSize * 3, 8000))
                    $effectiveChunkSize = $autoBoost
                }
            }
            if ($effectiveChunkSize -ne $StreamingChunkSize) { Write-LogHost "Adaptive chunk size applied: $effectiveChunkSize (was $StreamingChunkSize) due to column width $colCount" -ForegroundColor DarkYellow } else { Write-LogHost "Chunk size retained: $effectiveChunkSize (columns=$colCount)" -ForegroundColor DarkGray }
            if (-not $csvWriter) { Open-CsvWriter -Path $exportTemp -Columns $columnOrder; $csvWriter = $true }
            $lateEmit = @(); foreach ($sr in $schemaSampleRows) { $lateEmit += ($sr | Select-Object -Property $columnOrder) }
            if ($lateEmit.Count -gt 0) { Write-CsvRows -Rows $lateEmit -Columns $columnOrder }
            $schemaSampleRows.Clear(); $schemaFrozen = $true
        }
        # Flush remainder buffer
        if ($buffer.Count -gt 0) {
            $emitSet = $buffer | ForEach-Object { $_ | Select-Object -Property $columnOrder }
            if (-not $csvWriter) { Open-CsvWriter -Path $exportTemp -Columns $columnOrder; $csvWriter = $true }
            if ($emitSet.Count -gt 0) { Write-CsvRows -Rows $emitSet -Columns $columnOrder }
            $buffer.Clear()
        }
        if ($csvWriter) { Close-CsvWriter }
    }
    catch {
        $explosionError = $_
        Write-LogHost "ERROR: Failure during explosion/export pipeline: $($explosionError.Exception.Message)" -ForegroundColor Red
        throw
    }
    finally {
        try { if ($csvWriter) { Close-CsvWriter } } catch {}
    }
    $te1 = Get-Date; try { $script:metrics.ExplosionMs += [int]($te1 - $te0).TotalMilliseconds } catch {}
    if ($ExplodeDeep) { Write-LogHost "Deep column flattening (streamed) complete: $structuredDataCount rows" -ForegroundColor Cyan } elseif ($ExplodeArrays -or $ForcedRawInputCsvExplosion) { Write-LogHost "Array explosion (streamed) complete: $($allLogs.Count) input -> $structuredDataCount output" -ForegroundColor Cyan } else { Write-LogHost "Standard processing (streamed) complete: $($allLogs.Count) input -> $structuredDataCount output" -ForegroundColor Cyan }
    if ($postFreezeNewColumns -gt 0) {
        Write-LogHost "NOTICE: $postFreezeNewColumns row(s) contained new columns after schema freeze (ignored). Increase -StreamingSchemaSample if needed." -ForegroundColor DarkYellow
        if ($lateIgnoredColumns.Count -gt 0) {
            $previewLate = ($lateIgnoredColumns | Select-Object -First 25) -join ', '
            Write-LogHost "Late ignored columns (first 25): $previewLate" -ForegroundColor DarkYellow
            if ($lateIgnoredColumns.Count -gt 25) { Write-LogHost "(+ $($lateIgnoredColumns.Count - 25) more)" -ForegroundColor DarkYellow }
        }
    }
    Set-ProgressPhase -Phase 'Export' -Status 'Finalizing streaming CSV'
    $tx0 = Get-Date; Move-Item -Force -Path $exportTemp -Destination $OutputFile; $tx1 = Get-Date; try { $script:metrics.ExportMs += [int]($tx1 - $tx0).TotalMilliseconds } catch {}
    $script:progressState.Export.Total = 1; $script:progressState.Export.Current = 1; Update-Progress -Status 'Export complete (stream)'; Set-ProgressPhase -Phase 'Complete' -Status 'Done'; Complete-Progress

    Write-LogHost ""; Write-LogHost "=== Enterprise Export Complete ===" -ForegroundColor Green
    Write-LogHost "Processing mode: $processingMode" -ForegroundColor White
    Write-LogHost "Records exported: $($script:metrics.TotalStructuredRows)" -ForegroundColor White
    Write-LogHost "Output file: $OutputFile" -ForegroundColor White
    Write-LogHost "Log file: $LogFile" -ForegroundColor White
    Write-LogHost "File size: $([math]::Round((Get-Item $OutputFile).Length / 1KB,2)) KB" -ForegroundColor White
    
    # Only show tenant context for live queries (not replay mode)
    if (-not $RAWInputCSV) {
        try { $endDomain = if ($script:TenantPrimaryDomain) { $script:TenantPrimaryDomain } else { $primaryDomain }; $endTenantId = if ($script:TenantId) { $script:TenantId } else { $tenantId }; $endFallback = if ($script:TenantIndicators -and $script:TenantIndicators.Count -gt 0) { $script:TenantIndicators } else { $fallbackIndicators }; if (-not $endDomain) { $endDomain = '<unknown>' }; if (-not $endTenantId) { $endTenantId = '<unresolved>' }; $endParts = @("Domain=$endDomain", "TenantId=$endTenantId"); if ($endFallback -and $endFallback.Count -gt 0) { $endParts += ("Indicators=" + ($endFallback -join ',')) }; Write-LogHost ("Tenant context: " + ($endParts -join ' | ')) -ForegroundColor DarkCyan } catch {}
    }

    # Show agent filtering metrics if filter was applied
    if ($script:metrics.AgentFilterApplied) {
        Write-LogHost ""; Write-LogHost "=== Agent Filtering Summary ===" -ForegroundColor Cyan
        Write-LogHost ("Records before agent filter: {0}" -f $script:metrics.AgentFilterPreCount) -ForegroundColor White
        Write-LogHost ("Records after agent filter: {0}" -f $script:metrics.AgentFilterPostCount) -ForegroundColor White
        Write-LogHost ("Records filtered out: {0}" -f $script:metrics.AgentFilterRemovedCount) -ForegroundColor Gray
        $retentionRate = if ($script:metrics.AgentFilterPreCount -gt 0) { [Math]::Round(($script:metrics.AgentFilterPostCount / $script:metrics.AgentFilterPreCount) * 100, 2) } else { 0 }
        Write-LogHost ("Retention rate: {0}%" -f $retentionRate) -ForegroundColor White
        Write-LogHost ("Agent filter time: {0:F2} seconds" -f $script:metrics.AgentFilterElapsedSec) -ForegroundColor Gray
    }
    
    # Show ExcludeAgents filtering metrics if filter was applied
    if ($script:metrics.ExcludeAgentsApplied) {
        Write-LogHost ""; Write-LogHost "=== ExcludeAgents Filtering Summary ===" -ForegroundColor Cyan
        Write-LogHost ("Records before ExcludeAgents filter: {0}" -f $script:metrics.ExcludeAgentsPreCount) -ForegroundColor White
        Write-LogHost ("Records after ExcludeAgents filter: {0}" -f $script:metrics.ExcludeAgentsPostCount) -ForegroundColor White
        Write-LogHost ("Agent records excluded: {0}" -f $script:metrics.ExcludeAgentsRemoved) -ForegroundColor Gray
        $excludeRetentionRate = if ($script:metrics.ExcludeAgentsPreCount -gt 0) { [Math]::Round(($script:metrics.ExcludeAgentsPostCount / $script:metrics.ExcludeAgentsPreCount) * 100, 2) } else { 0 }
        Write-LogHost ("Retention rate: {0}%" -f $excludeRetentionRate) -ForegroundColor White
        Write-LogHost ("ExcludeAgents filter time: {0:F2} seconds" -f $script:metrics.ExcludeAgentsElapsedSec) -ForegroundColor Gray
    }
    
    # Show User/Group filtering metrics if filter was applied
    if ($script:metrics.UserFilterApplied) {
        Write-LogHost ""; Write-LogHost "=== User/Group Filtering Summary ===" -ForegroundColor Cyan
        
        # Determine which criteria to display (use script:targetUsers for actual values, parameters for type detection)
        $displayUserList = if ($script:targetUsers -and $script:targetUsers.Count -gt 0) { $script:targetUsers } else { $UserIds }
        
        # Show filter criteria
        if ($UserIds -and $GroupNames) {
            Write-LogHost ("Filter type: UserIds + GroupNames") -ForegroundColor White
            # Show UserIds (truncate if more than 5)
            if ($displayUserList.Count -le 5) {
                Write-LogHost ("  UserIds: {0}" -f ($displayUserList -join ', ')) -ForegroundColor Gray
            } else {
                Write-LogHost ("  UserIds: {0} users specified ({1}, {2}, {3}, ... and {4} more)" -f $displayUserList.Count, $displayUserList[0], $displayUserList[1], $displayUserList[2], ($displayUserList.Count - 3)) -ForegroundColor Gray
            }
            # Show GroupNames (truncate if more than 5)
            if ($GroupNames.Count -le 5) {
                Write-LogHost ("  GroupNames: {0}" -f ($GroupNames -join ', ')) -ForegroundColor Gray
            } else {
                Write-LogHost ("  GroupNames: {0} groups specified ({1}, {2}, {3}, ... and {4} more)" -f $GroupNames.Count, $GroupNames[0], $GroupNames[1], $GroupNames[2], ($GroupNames.Count - 3)) -ForegroundColor Gray
            }
        }
        elseif ($UserIds) {
            Write-LogHost ("Filter type: UserIds") -ForegroundColor White
            if ($displayUserList.Count -le 5) {
                Write-LogHost ("  Criteria: {0}" -f ($displayUserList -join ', ')) -ForegroundColor Gray
            } else {
                Write-LogHost ("  Criteria: {0} users specified ({1}, {2}, {3}, ... and {4} more)" -f $displayUserList.Count, $displayUserList[0], $displayUserList[1], $displayUserList[2], ($displayUserList.Count - 3)) -ForegroundColor Gray
            }
        }
        elseif ($GroupNames) {
            Write-LogHost ("Filter type: GroupNames") -ForegroundColor White
            if ($GroupNames.Count -le 5) {
                Write-LogHost ("  Criteria: {0}" -f ($GroupNames -join ', ')) -ForegroundColor Gray
            } else {
                Write-LogHost ("  Criteria: {0} groups specified ({1}, {2}, {3}, ... and {4} more)" -f $GroupNames.Count, $GroupNames[0], $GroupNames[1], $GroupNames[2], ($GroupNames.Count - 3)) -ForegroundColor Gray
            }
        }
        
        # Show expansion results (only show if different from input or if groups were expanded)
        if ($script:targetUsers -and $script:targetUsers.Count -gt 0 -and $GroupNames) {
            Write-LogHost ("Total unique users after expansion: {0}" -f $script:targetUsers.Count) -ForegroundColor White
        }
        
        # Show filtering results
        Write-LogHost ("Records before user filter: {0}" -f $script:metrics.UserFilterPreCount) -ForegroundColor White
        Write-LogHost ("Records after user filter: {0}" -f $script:metrics.UserFilterPostCount) -ForegroundColor White
        Write-LogHost ("Records filtered out: {0}" -f $script:metrics.UserFilterRemovedCount) -ForegroundColor Gray
        $userRetentionRate = if ($script:metrics.UserFilterPreCount -gt 0) { [Math]::Round(($script:metrics.UserFilterPostCount / $script:metrics.UserFilterPreCount) * 100, 2) } else { 0 }
        Write-LogHost ("Retention rate: {0}%" -f $userRetentionRate) -ForegroundColor White
        
        # Show explosion impact if arrays were exploded
        if ($ExplodeArrays -or $ExplodeDeep -or $RAWInputCSV) {
            # Use RecordsAfterFiltering if available (accounts for all filters), otherwise use TotalRecordsFetched as baseline
            $recordsIntoExplosion = if ($script:metrics.RecordsAfterFiltering -gt 0) { $script:metrics.RecordsAfterFiltering } else { $script:metrics.TotalRecordsFetched }
            $explosionRatio = if ($recordsIntoExplosion -gt 0) { [Math]::Round(($script:metrics.TotalStructuredRows / $recordsIntoExplosion), 2) } else { 0 }
            Write-LogHost ("Exploded to {0} output rows (explosion ratio: {1}x)" -f $script:metrics.TotalStructuredRows, $explosionRatio) -ForegroundColor White
        }
        
        Write-LogHost ("User filter time: {0:F2} seconds" -f $script:metrics.UserFilterElapsedSec) -ForegroundColor Gray
        if ($RAWInputCSV) {
            Write-LogHost ("Note: Client-side filtering in replay mode (extracted from AuditData JSON)") -ForegroundColor DarkGray
        } else {
            Write-LogHost ("Note: Server-side filtering at Purview (efficient)") -ForegroundColor DarkGray
        }
    }
    
    # Show PromptFilter metrics if filter was applied
    if ($script:metrics.PromptFilterApplied) {
        Write-LogHost ""; Write-LogHost "=== Prompt Filtering Summary ===" -ForegroundColor Cyan
        
        # Display filter type
        $filterTypeDisplay = switch ($script:metrics.PromptFilterType) {
            'Prompt' { 'Prompts Only (isPrompt=True)' }
            'Response' { 'Responses Only (isPrompt=False)' }
            'Both' { 'Both Prompts AND Responses' }
            'Null' { 'Null/Missing isPrompt values' }
        }
        Write-LogHost ("Filter type: {0}" -f $filterTypeDisplay) -ForegroundColor White
        
        # Record-level statistics
        Write-LogHost ""
        Write-LogHost "Record-level statistics:" -ForegroundColor Yellow
        Write-LogHost ("  Records before filter: {0}" -f $script:metrics.PromptFilterPreCount) -ForegroundColor White
        Write-LogHost ("  Records after filter: {0}" -f $script:metrics.PromptFilterPostCount) -ForegroundColor White
        Write-LogHost ("  Records filtered out: {0}" -f $script:metrics.PromptFilterRemovedCount) -ForegroundColor Gray
        $recordRetentionRate = if ($script:metrics.PromptFilterPreCount -gt 0) { [Math]::Round(($script:metrics.PromptFilterPostCount / $script:metrics.PromptFilterPreCount) * 100, 2) } else { 0 }
        Write-LogHost ("  Retention rate: {0}%" -f $recordRetentionRate) -ForegroundColor White
        
        # Record type breakdown
        Write-LogHost ""
        Write-LogHost "Record type breakdown (from input):" -ForegroundColor Yellow
        $totalWithMessages = $script:metrics.PromptFilterRecordsMixed + $script:metrics.PromptFilterRecordsPromptOnly + $script:metrics.PromptFilterRecordsResponseOnly
        $mixedPct = if ($totalWithMessages -gt 0) { [Math]::Round(($script:metrics.PromptFilterRecordsMixed / $totalWithMessages) * 100, 1) } else { 0 }
        $promptOnlyPct = if ($totalWithMessages -gt 0) { [Math]::Round(($script:metrics.PromptFilterRecordsPromptOnly / $totalWithMessages) * 100, 1) } else { 0 }
        $responseOnlyPct = if ($totalWithMessages -gt 0) { [Math]::Round(($script:metrics.PromptFilterRecordsResponseOnly / $totalWithMessages) * 100, 1) } else { 0 }
        
        Write-LogHost ("  Mixed (both prompts & responses): {0} ({1}%)" -f $script:metrics.PromptFilterRecordsMixed, $mixedPct) -ForegroundColor Cyan
        Write-LogHost ("  Prompt-only records: {0} ({1}%)" -f $script:metrics.PromptFilterRecordsPromptOnly, $promptOnlyPct) -ForegroundColor Cyan
        Write-LogHost ("  Response-only records: {0} ({1}%)" -f $script:metrics.PromptFilterRecordsResponseOnly, $responseOnlyPct) -ForegroundColor Cyan
        if ($script:metrics.PromptFilterRecordsNoMessages -gt 0) {
            Write-LogHost ("  Records with no messages: {0}" -f $script:metrics.PromptFilterRecordsNoMessages) -ForegroundColor DarkYellow
        }
        
        # Conversation turn-level statistics
        Write-LogHost ""
        Write-LogHost "Conversation turn-level statistics:" -ForegroundColor Yellow
        Write-LogHost ("  Conversation turns before filter: {0}" -f $script:metrics.PromptFilterMsgBefore) -ForegroundColor White
        Write-LogHost ("  Conversation turns after filter: {0}" -f $script:metrics.PromptFilterMsgAfter) -ForegroundColor White
        Write-LogHost ("  Conversation turns filtered out: {0}" -f $script:metrics.PromptFilterMsgRemoved) -ForegroundColor Gray
        $msgRetentionRate = if ($script:metrics.PromptFilterMsgBefore -gt 0) { [Math]::Round(($script:metrics.PromptFilterMsgAfter / $script:metrics.PromptFilterMsgBefore) * 100, 2) } else { 0 }
        Write-LogHost ("  Retention rate: {0}%" -f $msgRetentionRate) -ForegroundColor White
        
        # Add explanation if PromptFilter=Null produced no output
        if ($script:metrics.PromptFilterType -eq 'Null' -and $script:metrics.PromptFilterMsgAfter -eq 0) {
            Write-LogHost ""
            Write-LogHost "Explanation of PromptFilter=Null results:" -ForegroundColor Yellow
            Write-LogHost "  No messages with null/undefined isPrompt values were found." -ForegroundColor White
            Write-LogHost ("  All {0} messages in the {1} analyzed records had explicit isPrompt values (True or False)." -f $script:metrics.PromptFilterMsgBefore, $script:metrics.PromptFilterPreCount) -ForegroundColor White
            if ($script:metrics.PromptFilterRecordsNoMessages -gt 0) {
                Write-LogHost ("  Note: {0} record(s) had no Messages array and were excluded." -f $script:metrics.PromptFilterRecordsNoMessages) -ForegroundColor Gray
            }
            Write-LogHost "  To export data, use PromptFilter=Prompt, PromptFilter=Response, or PromptFilter=Both." -ForegroundColor Cyan
        }
        
        Write-LogHost ""
        Write-LogHost ("PromptFilter processing time: {0:F2} seconds" -f $script:metrics.PromptFilterElapsedSec) -ForegroundColor Gray
    }

    # Only show Performance Optimization Summary if adaptive sizing was used (live query mode)
    if (-not $RAWInputCSV) {
        Write-LogHost ""; Write-LogHost "=== Performance Optimization Summary ===" -ForegroundColor Cyan
        Write-LogHost "Adaptive sizing results:" -ForegroundColor White
        if ($script:learnedActivityBlockSize.Count -gt 0) { foreach ($kvp in $script:learnedActivityBlockSize.GetEnumerator()) { Write-LogHost ("  {0}: {1} hours (learned)" -f $($kvp.Key), $($kvp.Value)) -ForegroundColor Gray } } else { Write-LogHost "  No adaptive learning occurred (used defaults)" -ForegroundColor Gray }
        Write-LogHost "Global learned size: $($script:globalLearnedBlockSize) hours" -ForegroundColor Gray
        if ($script:Hit10KLimit) { Write-LogHost ""; Write-LogHost "  DATA COMPLETENESS WARNING " -ForegroundColor Red; Write-LogHost "Exchange Online 10K server limit was reached!" -ForegroundColor Red; Write-LogHost "Affected time window: $($script:LimitTimeWindow)" -ForegroundColor Yellow; Write-LogHost "RECOMMENDATION: Re-run with smaller time windows (30min blocks)" -ForegroundColor Cyan; Write-LogHost "This ensures complete data retrieval for high-volume periods" -ForegroundColor Yellow } else { Write-LogHost ""; Write-LogHost " Data retrieval completed without hitting limits" -ForegroundColor Green }
    }

    # Only show Explosion & Progress Metrics if explosion mode was used
    if ($effectiveExplode) {
        Write-LogHost ""; Write-LogHost "=== Explosion & Progress Metrics ===" -ForegroundColor Cyan
        Write-LogHost ("Query time: {0} ms | Explosion time: {1} ms | Export time: {2} ms" -f $script:metrics.QueryMs, $script:metrics.ExplosionMs, $script:metrics.ExportMs) -ForegroundColor Gray
        Write-LogHost ("Pages fetched: {0}" -f $script:metrics.PagesFetched) -ForegroundColor Gray
        Write-LogHost ("Records fetched: {0} | Structured rows: {1}" -f $script:metrics.TotalRecordsFetched, $script:metrics.TotalStructuredRows) -ForegroundColor Gray
        
        # Calculate overall explosion ratio using records that actually went into explosion (after all filtering)
        $recordsIntoExplosion = if ($script:metrics.RecordsAfterFiltering -gt 0) { [int]$script:metrics.RecordsAfterFiltering } else { [int]$script:metrics.TotalRecordsFetched }
        $overallExplosionRatio = if ($recordsIntoExplosion -gt 0) { [math]::Round($script:metrics.TotalStructuredRows / $recordsIntoExplosion, 2) } else { 0 }
        
        if ($script:metrics.ExplosionEvents -gt 0) {
            # Calculate single-row records (records that produced exactly 1 output row)
            $singleRowRecords = [int]$recordsIntoExplosion - [int]$script:metrics.ExplosionEvents
            
            Write-LogHost ("Explosion summary:") -ForegroundColor Gray
            Write-LogHost ("  Multi-row records (explosion events): {0}" -f $script:metrics.ExplosionEvents) -ForegroundColor Gray
            Write-LogHost ("  Single-row records: {0}" -f $singleRowRecords) -ForegroundColor Gray
            Write-LogHost ("  Total records exploded: {0}" -f $recordsIntoExplosion) -ForegroundColor Gray
            Write-LogHost ("  Avg rows/record: {0} | Max rows in single record: {1}" -f $overallExplosionRatio, $script:metrics.ExplosionMaxPerRecord) -ForegroundColor Gray
        } else { 
            Write-LogHost "Explosion events: 0 (no multi-row expansions)" -ForegroundColor Gray 
        }
        if ($script:metrics.ExplosionTruncated) { Write-LogHost "WARNING: One or more exploded records exceeded row cap (1000) and were truncated." -ForegroundColor Yellow }
        if ($script:metrics.EffectiveChunkSize -gt 0) { Write-LogHost ("Effective chunk size: {0}" -f $script:metrics.EffectiveChunkSize) -ForegroundColor Gray }
        if ($script:metrics.ParallelBatchSizeFinal -gt 0) { Write-LogHost ("Final parallel batch size: {0}" -f $script:metrics.ParallelBatchSizeFinal) -ForegroundColor Gray }
        if ($script:metrics.ParallelThrottleFinal -gt 0) { Write-LogHost ("Final parallel throttle: {0}" -f $script:metrics.ParallelThrottleFinal) -ForegroundColor Gray }
        if ($script:metrics.Activities.Count -gt 0) { Write-LogHost "Per-activity counts:" -ForegroundColor Gray; foreach ($k in $script:metrics.Activities.Keys) { $a = $script:metrics.Activities[$k]; Write-LogHost ([string]::Format('  {0} - retrieved={1} structured={2}', $k, $a.Retrieved, $a.Structured)) -ForegroundColor Gray } }
        Write-LogHost "" -ForegroundColor Gray
    }
    
    # Only show Parallel Execution Summary if parallel mode was actually used
    if (-not $RAWInputCSV -and $parallelGroupsUsed -gt 0) {
        Write-LogHost "=== Parallel Execution Summary ===" -ForegroundColor Cyan
        Write-LogHost ("Total query groups: {0}" -f $queryPlan.Count) -ForegroundColor Gray
        Write-LogHost ("Groups executed in parallel: {0}" -f $parallelGroupsUsed) -ForegroundColor Gray
        Write-LogHost ("Groups executed sequentially: {0}" -f ($sequentialGroups + ($queryPlan.Count - $parallelGroupsUsed - $sequentialGroups))) -ForegroundColor Gray
        Write-LogHost ("MaxConcurrency: {0} | MaxParallelGroups: {1} | ParallelMode: {2}" -f $MaxConcurrency, $MaxParallelGroups, $ParallelMode) -ForegroundColor Gray
        if ($ParallelMode -eq 'Auto') { $highGroups = ($queryPlan | Where-Object { $_.Group -eq 'High' }).Count; $mediumGroups = ($queryPlan | Where-Object { $_.Group -eq 'Medium' }).Count; $lowGroups = ($queryPlan | Where-Object { $_.Group -eq 'Low' }).Count; $activitiesTotal = ($queryPlan | ForEach-Object { $_.Activities.Count } | Measure-Object -Sum).Sum; $groupsTotal = $queryPlan.Count; $autoStatus = if ($parallelOverallEnabled) { 'met' } else { 'not met' }; Write-LogHost ("Auto criteria (PS7+, MPG>0, MC>1, <=1 High, >=1 Med/Low, activities<=15, groups>1): {0}; High={1} Medium={2} Low={3} Activities={4} Groups={5}" -f $autoStatus, $highGroups, $mediumGroups, $lowGroups, $activitiesTotal, $groupsTotal) -ForegroundColor Gray }
        Write-LogHost "" -ForegroundColor Gray
    }
}
catch { Write-LogHost "Script failed: $($_.Exception.Message)" -ForegroundColor Red; Write-LogHost $_.ScriptStackTrace -ForegroundColor Red }
finally { $endUtc = (Get-Date).ToUniversalTime(); try { if ($script:metrics -and $script:metrics.StartTime) { $startTail = $script:metrics.StartTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'); Write-Log ("Script execution started at $startTail UTC") } } catch {}; Write-Log "Script execution completed at $($endUtc.ToString('yyyy-MM-dd HH:mm:ss')) UTC"; Write-Log "Script version: v$ScriptVersion"; try { if ($script:metrics -and $script:metrics.StartTime) { $elapsed = $endUtc - $script:metrics.StartTime; $totalHours = [math]::Floor($elapsed.TotalHours); $remainder = $elapsed - [TimeSpan]::FromHours($totalHours); $elapsedFormatted = ("{0}:{1:00}:{2:00}.{3:000}" -f $totalHours, $remainder.Minutes, $remainder.Seconds, $remainder.Milliseconds); Write-Log ("Total elapsed time: {0} (hours:minutes:seconds.milliseconds)" -f $elapsedFormatted) } } catch {}; if ($script:Connected) { try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null; Write-LogHost "Disconnected from Exchange Online" -ForegroundColor Gray } catch {} } }




