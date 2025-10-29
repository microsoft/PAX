# Portable Audit eXporter (PAX) - Purview Audit Log Processor
# Version: v1.7.4
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
		powershell.exe -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02
		pwsh.exe       -ExecutionPolicy Bypass -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02

.POWERSHELLVERSIONS
	PS 5.1 & 7+. Parallelization requires PS 7+.

.EXAMPLE
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile C:\Temp\Copilot.csv
.EXAMPLE
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile C:\Temp\Copilot_exploded.csv
.EXAMPLE
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile C:\Temp\Copilot_deep.csv
.EXAMPLE
	powershell -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -OutputFile C:\Temp\Copilot.csv
.EXAMPLE
	# Offline replay (simple forced explosion) of a previously exported raw CSV
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -OutputFile C:\Temp\Copilot_replay_exploded.csv
.EXAMPLE
	# Offline replay with date & activity filtering + deep flatten
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -ActivityTypes CopilotInteraction -OutputFile C:\Temp\Copilot_replay_deep.csv
.EXAMPLE
	# Deep flatten (wide) with higher schema sample & moderate chunk size (balance column coverage vs memory)
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 4000 -StreamingChunkSize 3000 -OutputFile C:\Temp\Copilot_deep_tuned.csv
.EXAMPLE
	# Extremely wide deep flatten: maximize schema sample, reduce chunk size for lower peak memory
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 6000 -StreamingChunkSize 1500 -OutputFile C:\Temp\Copilot_deep_memoryguard.csv
.EXAMPLE
	# Fast header freeze (narrow schema expectation) – smaller sample, larger chunk for throughput (risk: late columns ignored)
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -ExplodeDeep -StartDate 2025-10-01 -EndDate 2025-10-02 -StreamingSchemaSample 800 -StreamingChunkSize 6000 -OutputFile C:\Temp\Copilot_deep_fastfreeze.csv
.EXAMPLE
	# Filter to only records with agents present
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -AgentsOnly -OutputFile C:\Temp\Copilot_agents.csv
.EXAMPLE
	# Filter to only records WITHOUT agents
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -ExcludeAgents -OutputFile C:\Temp\Copilot_no_agents.csv
.EXAMPLE
	# Filter to only prompt messages (Message_isPrompt = True)
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -PromptFilter Prompt -OutputFile C:\Temp\Copilot_prompts.csv
.EXAMPLE
	# Filter to only response messages (Message_isPrompt = False)
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -PromptFilter Response -OutputFile C:\Temp\Copilot_responses.csv
.EXAMPLE
	# Combine filters: agents + prompts only
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -ExplodeArrays -StartDate 2025-10-01 -EndDate 2025-10-02 -AgentsOnly -PromptFilter Prompt -OutputFile C:\Temp\Copilot_agent_prompts.csv
.EXAMPLE
	# Filter to specific users
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -UserIds "john.doe@contoso.com","jane.smith@contoso.com" -OutputFile C:\Temp\Copilot_users.csv
.EXAMPLE
	# Emit metrics JSON alongside CSV (default metrics filename)
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-01 -EmitMetricsJson -OutputFile C:\Temp\Copilot.csv
.EXAMPLE
	# Emit metrics JSON to custom path
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-01 -EmitMetricsJson -MetricsPath C:\Temp\purview_metrics_20251001.json -OutputFile C:\Temp\Copilot.csv
.EXAMPLE
	# AutoCompleteness remediation workflow: first run incomplete (exit code 10), second run resolves saturated windows
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-05 -EndDate 2025-10-05 -EmitMetricsJson -OutputFile C:\Temp\Copilot_initial.csv
	# (Exit code 10 indicates saturated windows remain)
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-05 -EndDate 2025-10-05 -AutoCompleteness -EmitMetricsJson -OutputFile C:\Temp\Copilot_autocomplete.csv
.EXAMPLE
	# Filter to security group members (automatically expanded)
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -GroupNames "Executive Leadership" -OutputFile C:\Temp\Copilot_executives.csv
.EXAMPLE
	# Filter to multiple groups
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -GroupNames "Executive Team","Engineering Managers" -OutputFile C:\Temp\Copilot_leadership.csv
.EXAMPLE
	# Combine individual users and groups
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -UserIds "ceo@contoso.com" -GroupNames "Board of Directors" -OutputFile C:\Temp\Copilot_mixed.csv
.EXAMPLE
	# Replay mode with user filtering (client-side filtering from JSON)
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -RAWInputCSV .\output\Copilot_RAW_20251001.csv -UserIds "john.doe@contoso.com","jane.smith@contoso.com" -OutputFile C:\Temp\Copilot_replay_users.csv
.EXAMPLE
	# COMBINING FILTERS: User + PromptFilter (conversation focus, removes resource-only rows)
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -UserIds "poweruser@contoso.com" -PromptFilter Both -OutputFile C:\Temp\User_Conversations.csv
.EXAMPLE
	# COMBINING FILTERS: Group + Agent (team adoption of specific agent)
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -GroupNames "Sales Team" -AgentsOnly -OutputFile C:\Temp\Sales_Agent_Usage.csv
.EXAMPLE
	# COMBINING FILTERS: User + Agent + PromptFilter (prompts sent to agents by specific users)
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -StartDate 2025-10-01 -EndDate 2025-10-02 -UserIds "analyst@contoso.com" -AgentId "DataAnalysis.Agent" -PromptFilter Prompt -OutputFile C:\Temp\Analyst_Agent_Prompts.csv
.EXAMPLE
	# COMBINING FILTERS: Replay mode with User + Agent + PromptFilter
	pwsh -File .\PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 -RAWInputCSV .\data.csv -UserIds "exec@contoso.com" -AgentsOnly -PromptFilter Both -OutputFile C:\Temp\Exec_Agent_Messages.csv
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
	# Increased default for more aggressive parallel partitioning (was 2)
	[int]$MaxConcurrency = 3,
	[Parameter(Mandatory = $false)]
	[switch]$EnableParallel,
	[Parameter(Mandatory = $false)]
	[ValidateRange(0, 50)]
	# Slightly higher default to allow multiple activity groups concurrently (was 3)
	[int]$MaxParallelGroups = 4,
	[Parameter(Mandatory = $false)]
	[ValidateRange(1,200)]
	# Upper bound on partitions for any single activity group (was hard-coded 12)
	[int]$MaxActivePartitions = 12,
	[Parameter(Mandatory = $false)]
	[ValidateSet('Off', 'On', 'Auto')]
	# Default now 'Auto' so that PS 7+ environments engage parallel processing automatically unless explicitly turned Off.
	[string]$ParallelMode = 'Auto',
	[Parameter(Mandatory = $false)]
	[switch]$DisableAdaptive,  # Disable adaptive safeguards (memory/latency/concurrency smoothing)
	[Parameter(Mandatory = $false)]
	[ValidateRange(0.0,1.0)]
	[double]$ProgressSmoothingAlpha = 0.3,  # Weight for smoothing dynamic progress total recalculation (0 => off)
	[Parameter(Mandatory = $false)]
	[ValidateRange(1000,600000)]
	[int]$HighLatencyMs = 90000,            # Partition average latency threshold (ms) triggering mild concurrency reduction
	[Parameter(Mandatory = $false)]
	[ValidateRange(256,32768)]
	[int]$MemoryPressureMB = 1500,          # Working set (MB) threshold to trigger mild concurrency reduction
	[Parameter(Mandatory = $false)]
	[ValidateRange(100,600000)]
	[int]$LowLatencyMs = 20000,             # Sustained low latency threshold to consider concurrency step-up
	[Parameter(Mandatory = $false)]
	[ValidateRange(1,10)]
	[int]$LowLatencyConsecutive = 2,        # Required consecutive low-latency groups before step-up
	[Parameter(Mandatory = $false)]
	[ValidateRange(1,100)]
	[int]$ThroughputDropPct = 15,           # % drop vs baseline required (with high latency) to justify reduction
	[Parameter(Mandatory = $false)]
	[ValidateRange(0.0,1.0)]
	[double]$ThroughputSmoothingAlpha = 0.3,# EMA smoothing for throughput baseline
	[Parameter(Mandatory = $false)]
	[ValidateRange(1,50)]
	[int]$AdaptiveConcurrencyCeiling = 6,   # Upper bound for adaptive step-ups
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

	# --- Reliability Enhancements (Backoff & Circuit Breaker) ---
	[Parameter(Mandatory = $false)]
	[ValidateRange(1,50)]
	[int]$CircuitBreakerThreshold = 5,      # Consecutive block failures before opening circuit breaker
	[Parameter(Mandatory = $false)]
	[ValidateRange(5,3600)]
	[int]$CircuitBreakerCooldownSeconds = 120, # Cooldown duration after breaker trips
	[Parameter(Mandatory = $false)]
	[ValidateRange(0.1,120)]
	[double]$BackoffBaseSeconds = 1.0,      # Base seconds for exponential backoff between block retries
	[Parameter(Mandatory = $false)]
	[ValidateRange(1,600)]
	[int]$BackoffMaxSeconds = 45,           # Max cap for exponential backoff delay

	[Parameter(Mandatory = $false)]
	[switch]$ExcludeAgents,

	[Parameter(Mandatory = $false)]
	[string[]]$UserIds,

	[Parameter(Mandatory = $false)]
	[string[]]$GroupNames,

	[Parameter(Mandatory = $false)]
	[switch]$Help,

	# Emit structured metrics JSON alongside CSV (OutputFile name with .metrics.json)
	[Parameter(Mandatory = $false)]
	[switch]$EmitMetricsJson,

	# Override metrics output path (optional). If provided and -EmitMetricsJson specified, writes here instead of OutputFile substitution.
	[Parameter(Mandatory = $false)]
	[string]$MetricsPath,

	# Ensure completeness: aggressively subdivide any window still returning server 10K limit until below threshold or min window reached.
	[Parameter(Mandatory = $false)]
	[switch]$AutoCompleteness

	,# Skip pre-query capability diagnostics (advanced)
	[Parameter(Mandatory = $false)]
	[switch]$SkipDiagnostics
)

# Display help if -Help switch is provided
if ($Help) {
	Get-Help $PSCommandPath -Full
	exit 0
}

# Script version constant (must appear after param/help to keep param() valid as first executable block)
$ScriptVersion = '1.7.4'

# --- Early parameter validation & environment sanity checks ---

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
	$parsedStart = $null; $parsedEnd = $null
	if ($PSBoundParameters.ContainsKey('StartDate')) {
		try { $parsedStart = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null) } catch { Write-Host "ERROR: StartDate must be yyyy-MM-dd if provided." -ForegroundColor Red; exit 1 }
	}
	if ($PSBoundParameters.ContainsKey('EndDate')) {
		try { $parsedEnd = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null) } catch { Write-Host "ERROR: EndDate must be yyyy-MM-dd if provided." -ForegroundColor Red; exit 1 }
	}
	if ($parsedStart -and $parsedEnd -and $parsedEnd -lt $parsedStart) { Write-Host "ERROR: EndDate ($EndDate) is earlier than StartDate ($StartDate)." -ForegroundColor Red; exit 1 }
	if (-not $PSBoundParameters.ContainsKey('StartDate')) { $StartDate = '*' }
	if (-not $PSBoundParameters.ContainsKey('EndDate')) { $EndDate = '*' }
}
else {
	if (-not $PSBoundParameters.ContainsKey('StartDate') -and -not $PSBoundParameters.ContainsKey('EndDate')) {
		$yesterdayUtc = (Get-Date).ToUniversalTime().Date.AddDays(-1)
		$StartDate = $yesterdayUtc.ToString('yyyy-MM-dd')
		$EndDate = $yesterdayUtc.AddDays(1).ToString('yyyy-MM-dd')
	}
	elseif (-not $PSBoundParameters.ContainsKey('StartDate')) {
		$StartDate = '*'
		try {
			$parsedEnd = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null)
		} catch { Write-Host "ERROR: EndDate must be yyyy-MM-dd format." -ForegroundColor Red; exit 1 }
	}
	elseif (-not $PSBoundParameters.ContainsKey('EndDate')) {
		$EndDate = '*'
		try {
			$parsedStart = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)
		} catch { Write-Host "ERROR: StartDate must be yyyy-MM-dd format." -ForegroundColor Red; exit 1 }
	}
	else {
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
	AdaptiveEvents             = @()
	AdaptiveMemoryReductions   = 0
	AdaptiveLatencyReductions  = 0
	AdaptiveLatencyIncreases   = 0
	ThroughputBaselineRps      = 0
	CircuitBreakerTrips        = 0
	BackoffTotalDelaySeconds   = 0
	PartitionCapsApplied       = 0
	PartitionCapHighestRequested = 0
}
$script:adaptiveThroughputBaseline = $null
$script:adaptiveLowLatencyStreak = 0
$script:consecutiveBlockFailures = 0
$script:circuitBreakerOpen = $false
$script:circuitBreakerOpenUntil = $null

#
# Core live-mode functions providing connectivity and paged audit retrieval.

function Connect-ToComplianceCenter {
	param()
	if ($script:Connected) { return }
	Write-LogHost "Connecting to Microsoft 365 Security & Compliance Center..." -ForegroundColor Cyan
	# Ensure ExchangeOnlineManagement module is available
	try {
		$existingEOM = Get-Module -ListAvailable -Name ExchangeOnlineManagement | Sort-Object Version -Descending | Select-Object -First 1
		if (-not $existingEOM) {
			Write-LogHost "Installing ExchangeOnlineManagement module (CurrentUser scope)..." -ForegroundColor Yellow
			try { Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop } catch { Write-LogHost "Failed to install module: $($_.Exception.Message)" -ForegroundColor Red; throw }
		}
		Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop
	} catch {
		Write-LogHost "Module load/install failure: $($_.Exception.Message)" -ForegroundColor Red
		throw
	}

	# Authentication modes (subset retained for stability)
	try {
			switch ($Auth.ToLower()) {
				'weblogin' {
					try {
						$exoCmd = Get-Command Connect-ExchangeOnline -ErrorAction Stop
						$hasUseWeb = $exoCmd.Parameters.ContainsKey('UseWebLogin')
						if ($hasUseWeb) {
							Write-LogHost 'Using Connect-ExchangeOnline -UseWebLogin (parameter present).' -ForegroundColor DarkGray
							Connect-ExchangeOnline -ShowBanner:$false -UseWebLogin -ErrorAction Stop | Out-Null
						}
						else {
							Write-LogHost 'UseWebLogin parameter not available in this host/module; invoking standard interactive Connect-ExchangeOnline.' -ForegroundColor Yellow
							Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop | Out-Null
						}
					}
					catch { Write-LogHost "WebLogin flow failed: $($_.Exception.Message)" -ForegroundColor Red; throw }
				}
			'devicecode' {
				Connect-ExchangeOnline -ShowBanner:$false -Device | Out-Null
			}
			'credential' {
				$cred = Get-Credential -Message 'Enter admin credentials for Exchange Online'
				Connect-ExchangeOnline -ShowBanner:$false -Credential $cred | Out-Null
			}
			default {
				# Silent first, fallback to WebLogin
				$silentOk = $true
				try { Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop | Out-Null } catch { $silentOk = $false }
				if (-not $silentOk) {
					try { Connect-ExchangeOnline -ShowBanner:$false -UseWebLogin -ErrorAction Stop | Out-Null } catch { Write-LogHost "Silent + fallback auth failed: $($_.Exception.Message)" -ForegroundColor Red; throw }
				}
			}
		}
		$script:Connected = $true
		Write-LogHost "Connected successfully." -ForegroundColor Green
	}
	catch {
		Write-LogHost "Connection failure: $($_.Exception.Message)" -ForegroundColor Red
		throw
	}
}

# Pre-query diagnostic: verify Search-UnifiedAuditLog availability & likely permission coverage.
function Invoke-AuditCapabilityDiagnostics {
	param()
	if ($SkipDiagnostics) { return $true }
	$cmd = Get-Command Search-UnifiedAuditLog -ErrorAction SilentlyContinue
	if (-not $cmd) {
		Write-LogHost "DIAGNOSTIC: 'Search-UnifiedAuditLog' cmdlet not found in this session." -ForegroundColor Red
		Write-LogHost "Guidance: Ensure ExchangeOnlineManagement module (v3+) is installed and imported. Try: Install-Module ExchangeOnlineManagement -Scope CurrentUser" -ForegroundColor Yellow
		Write-LogHost "Role Requirements: Membership in 'Audit Logs' (preferred) or 'View-Only Audit Logs' / appropriate Compliance role group." -ForegroundColor Yellow
		return $false
	}
	# Attempt a minimal, very narrow harmless probe query (empty expected results)
	try {
		$now = (Get-Date).ToUniversalTime()
		$probeStart = $now.AddMinutes(-7)
		$probeEnd   = $now.AddMinutes(-6)
		# Use an operation that is unlikely to appear but valid syntactically
		$null = Search-UnifiedAuditLog -StartDate $probeStart -EndDate $probeEnd -Operations 'UserLoggedIn' -ResultSize 1 -ErrorAction Stop
		Write-LogHost "Diagnostics: Audit search cmdlet available (probe succeeded/no error)." -ForegroundColor DarkGray
		return $true
	}
	catch {
		$msg = $_.Exception.Message
		Write-LogHost "DIAGNOSTIC: Probe audit search failed: $msg" -ForegroundColor Yellow
		if ($msg -match 'is not within the current user' -or $msg -match 'Access denied' -or $msg -match 'not authorized' -or $msg -match 'insufficient') {
			Write-LogHost "Likely Missing Roles: Add the account to 'Audit Logs' (Microsoft Purview) or at minimum 'View-Only Audit Logs'." -ForegroundColor Red
		}
		elseif ($msg -match 'The term .*Search-UnifiedAuditLog.* is not recognized') {
			Write-LogHost "Module Issue: Cmdlet not loaded. Import-Module ExchangeOnlineManagement or update module version." -ForegroundColor Red
		}
		else {
			Write-LogHost "General Guidance: Ensure Unified Audit Log is enabled tenant-wide & correct role assignments are in place." -ForegroundColor Yellow
		}
		return $false
	}
}

function Invoke-SearchUnifiedAuditLogWithRetry {
	<#
		Adapted from v1.7.3: Provides pagination & early 10K detection.
		Adjustments:
		  * Honors $PacingMs but leaves adaptive / circuit breaker to caller.
		  * Maintains metrics.PagesFetched & global limit flags used by higher layers.
	#>
	param(
		[Parameter(Mandatory)][datetime]$Start,
		[Parameter(Mandatory)][datetime]$End,
		[Parameter(Mandatory)][string]$Operation,
		[Parameter(Mandatory)][int]$ResultSize,
		[string[]]$UserIds,
		[int]$MaxRetries = 3,
		[bool]$AutoSubdivide = $true
	)

	$script:Hit10KLimit = $false
	$script:LimitTimeWindow = ""
	$allResults = New-Object System.Collections.ArrayList
	$totalFetched = 0
	$pageNumber = 1
	$maxPages = 50
	$pageSize = [Math]::Min($ResultSize, 5000)
	$useSessionPagination = $ResultSize -gt 5000
	$sessionId = if ($useSessionPagination) { [guid]::NewGuid().ToString() } else { $null }

	Write-LogHost ("  Using {0} pagination (page size {1})" -f ($(if ($useSessionPagination){'session'} else {'standard'}), $pageSize)) -ForegroundColor DarkCyan

	try {
		while ($totalFetched -lt $ResultSize -and $pageNumber -le $maxPages) {
			$remainingNeeded = $ResultSize - $totalFetched
			$currentPageSize = [Math]::Min($pageSize, $remainingNeeded)
			$attempt = 0; $pageResults = $null
			while ($attempt -le $MaxRetries) {
				try {
					$params = @{ StartDate = $Start; EndDate = $End; Operations = $Operation; ResultSize = $currentPageSize; ErrorAction = 'Stop' }
					if ($UserIds) { $params['UserIds'] = $UserIds }
					if ($useSessionPagination) {
						$params['SessionId'] = $sessionId
						$params['SessionCommand'] = if ($pageNumber -eq 1) { 'ReturnLargeSet' } else { 'ReturnNextPreviewPage' }
					}
					if ($PacingMs -gt 0) { Start-Sleep -Milliseconds $PacingMs }
					if ($attempt -gt 0) { Write-LogHost "    Retrying page $pageNumber (attempt $($attempt+1))" -ForegroundColor Yellow }
					$pageResults = Search-UnifiedAuditLog @params
					break
				}
				catch {
					$attempt++
					if ($attempt -le $MaxRetries) {
						$delay = [Math]::Min(30, [Math]::Pow(2, $attempt))
						Write-LogHost "    Page $pageNumber failed: $($_.Exception.Message). Backoff ${delay}s" -ForegroundColor DarkYellow
						Start-Sleep -Seconds $delay
						if ($useSessionPagination -and $attempt -gt 1) { $sessionId = [guid]::NewGuid().ToString(); Write-LogHost "    New session id for retry: $sessionId" -ForegroundColor DarkGray }
					} else {
						Write-LogHost "    Page $pageNumber permanently failed after $attempt attempts" -ForegroundColor Red
						throw
					}
				}
			}

			if ($pageResults -and $pageResults.Count -gt 0) {
				# Early 10K detection (first page result count meta)
				if ($pageNumber -eq 1 -and $AutoSubdivide) {
					try {
						$est = $pageResults[0].ResultCount
						if ($null -ne $est -and $est -ge 10000) {
							Write-LogHost "    ⚠ Estimated >=10K records in window – consider subdivision" -ForegroundColor Yellow
						}
					} catch {}
				}
				$null = $allResults.AddRange($pageResults)
				$totalFetched += $pageResults.Count
				# Hard stop enforcement: never return more than requested -ResultSize
				if ($totalFetched -ge $ResultSize) {
					if ($totalFetched -gt $ResultSize) {
						$excess = $totalFetched - $ResultSize
						# Trim excess items from tail
						for ($trim = 0; $trim -lt $excess; $trim++) { [void]$allResults.RemoveAt($allResults.Count - 1) }
						$totalFetched = $ResultSize
					}
					Write-LogHost "    Requested result size $ResultSize reached (cum: $totalFetched) – stopping" -ForegroundColor DarkCyan
					try { $script:metrics.PagesFetched += 1 } catch {}
					break
				}
				try { $script:metrics.PagesFetched += 1 } catch {}
				Write-LogHost "    Page $pageNumber returned $($pageResults.Count) (cum: $totalFetched)" -ForegroundColor DarkCyan
				if ($pageResults.Count -lt $currentPageSize) { break }
				if ($totalFetched -ge 10000) { 
					$script:Hit10KLimit = $true 
					$script:LimitTimeWindow = "$(($Start).ToString('yyyy-MM-dd HH:mm')) to $(($End).ToString('yyyy-MM-dd HH:mm'))" 
					Write-LogHost "    10K server limit reached in this window" -ForegroundColor Yellow 
					break 
				}
			} else {
				Write-LogHost "    Page $pageNumber empty – stopping" -ForegroundColor DarkCyan
				break
			}
			$pageNumber++
		}

		if ($pageNumber -gt $maxPages) {
			Write-LogHost "  Reached max page limit ($maxPages)" -ForegroundColor Yellow
		}
		Write-LogHost "  Pagination complete: $($allResults.Count) records" -ForegroundColor Green
		return $allResults.ToArray()
	}
	catch {
		Write-LogHost "  Pagination failed: $($_.Exception.Message)" -ForegroundColor Red
		throw
	}
}

# Wrapper for main processing (kept minimal for clarity)
function Invoke-PAXProcessingCore {
	param()
	try {
		# Existing core logic already executed above in previous top-level scope.
		# This wrapper intentionally left minimal to avoid structural parse issues.
	}
	catch {
		Write-LogHost "Core processing error: $($_.Exception.Message)" -ForegroundColor Red
		throw
	}
}

$script:adaptiveThroughputBaseline = $null
$script:adaptiveLowLatencyStreak = 0
$script:consecutiveBlockFailures = 0
$script:circuitBreakerOpen = $false
$script:circuitBreakerOpenUntil = $null

function Get-BackoffDelaySeconds {
	param(
		[Parameter(Mandatory)][int]$Attempt,
		[Parameter(Mandatory)][double]$BaseSeconds,
		[Parameter(Mandatory)][int]$MaxSeconds
	)
	if ($Attempt -lt 1) { return 0 }
	$raw = $BaseSeconds * [math]::Pow(2, ($Attempt - 1))
	return [math]::Min($MaxSeconds, $raw)
}

function Test-CircuitBreakerTrip {
	param(
		[Parameter(Mandatory)][int]$ConsecutiveFailures,
		[Parameter(Mandatory)][int]$Threshold
	)
	return ($ConsecutiveFailures -ge $Threshold)
}

$JsonDepth = 60
$FlatDepthStandard = 60
$FlatDepthDeep = 120
$ExplosionPerRecordRowCap = 1000
$script:TenantPrimaryDomain = $null
$script:TenantId = $null
$script:TenantIndicators = @()
$ForcedRawInputCsvExplosion = $false
if ($RAWInputCSV) { $ForcedRawInputCsvExplosion = $true }

$script:RegexTrueFalse = [regex]::new('^(?i:true|false)$', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:RegexYes1 = [regex]::new('^(?i:yes|1)$', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:RegexNo0 = [regex]::new('^(?i:no|0)$', [System.Text.RegularExpressions.RegexOptions]::Compiled)

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

function Get-ParallelActivationDecision {
	param(
		[array]$QueryPlan,
		[string]$ParallelMode,
		[int]$MaxParallelGroups,
		[int]$MaxConcurrency
	)
	$ps7 = ($PSVersionTable.PSVersion.Major -ge 7)
	$totalGroups = $QueryPlan.Count
	$totalActivities = ($QueryPlan | ForEach-Object { $_.Activities.Count } | Measure-Object -Sum).Sum
	# Auto parallel eligibility heuristic: previously required more than one group, causing single-activity
	# multi-partition scenarios (e.g., CopilotInteraction with 3 partitions) to run sequentially.
	# Adjust logic: allow auto parallel when there's at least one group AND either >1 group OR
	# a single group whose planned concurrency would yield >1 partition.
	$singleGroupMultiPartition = ($totalGroups -eq 1) -and ($QueryPlan[0].Concurrency -gt 1)
	$autoEligible = $ps7 -and ($MaxParallelGroups -gt 0) -and ($MaxConcurrency -gt 1) -and ($totalActivities -le 15) -and ($totalGroups -ge 1) -and (($totalGroups -gt 1) -or $singleGroupMultiPartition)

	switch ($ParallelMode) {
		'On' {
			return @{ Enabled = ($ps7 -and $MaxParallelGroups -gt 0 -and $MaxConcurrency -gt 0); Reason = if ($ps7) { 'Forced On' } else { 'PS < 7 (cannot parallel)' }; AutoEligible = $autoEligible }
		}
		'Auto' {
			return @{ Enabled = $autoEligible; Reason = if ($autoEligible) { 'Auto criteria met' } else { 'Auto criteria not met' }; AutoEligible = $autoEligible }
		}
		default {
			return @{ Enabled = $false; Reason = 'Mode Off'; AutoEligible = $autoEligible }
		}
	}
}

$weights = if ($effectiveExplodeForProgress) { @{ Query = 0.30; Explosion = 0.60; Export = 0.10 } } else { @{ Query = 0.80; Explosion = 0.00; Export = 0.20 } }
if ($RAWInputCSV) {
	try {
		$weights = @{ Parsing = 0.10; Query = 0.0; Explosion = 0.80; Export = 0.10 }
	}
	catch {}
}
$script:originalWeights = $weights.Clone()
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
	# Temporary zero-record weighting override: If no records retrieved so far AND still in Query phase,
	# emphasize Query progression to avoid a flat 0% bar for long empty windows.
	if ($script:progressState.Phase -eq 'Query' -and ($script:metrics.TotalRecordsFetched -eq 0)) {
		$w.Query = 1.0; $w.Explosion = 0.0; $w.Export = 0.0; if ($w.ContainsKey('Parsing')) { $w.Parsing = 0.0 }
	}
	# Restoration: Once at least one record has been fetched, revert weights if they were temporarily overridden.
	elseif ($script:progressState.Phase -eq 'Query' -and ($script:metrics.TotalRecordsFetched -gt 0)) {
		if ($script:originalWeights -and $w.Query -eq 1.0 -and $w.Explosion -eq 0.0 -and $w.Export -eq 0.0) {
			foreach ($key in $script:originalWeights.Keys) { $w[$key] = $script:originalWeights[$key] }
		}
	}
	$overall = ($parsingWeight * $pPct) + ($w.Query * $qPct) + ($w.Explosion * $ePct) + ($w.Export * $xPct)
	$pct = [int]([Math]::Round($overall * 100))
	$phase = $script:progressState.Phase
	$pDetail = if ($w.ContainsKey('Parsing') -and $w.Parsing -gt 0 -and $ps.Total -gt 0) { "{0}/{1}({2}%)" -f $ps.Current, $ps.Total, ([int]([Math]::Round($pPct * 100))) } else { '' }
	$qDetail = if ($w.Query -gt 0 -and $qs.Total -gt 0) { "{0}/{1}({2}%)" -f $qs.Current, $qs.Total, ([int]([Math]::Round($qPct * 100))) } else { '' }
	if ($BatchRangeStart -ge 1 -and $BatchRangeEnd -ge 1 -and $es.Total -gt 0) {
		if ($BatchStartPercent -ge 0 -and $BatchEndPercent -gt 0) {
			$batchTotalDisplay = if ($BatchTotalIsEstimate) { "~$BatchTotal" } else { "$BatchTotal" }
			$batchInfo = if ($BatchTotal -ge 1) { " Batch: {0}/{1}({2}%-{3}%)" -f $BatchCurrent, $batchTotalDisplay, $BatchStartPercent, $BatchEndPercent } else { '' }
		}
		else {
			$batchPct = if ($BatchTotal -gt 0 -and $BatchCurrent -gt 0) { [int]([Math]::Round(([double]$BatchCurrent / [double]$BatchTotal) * 100)) } else { 0 }
			$batchTotalDisplay = if ($BatchTotalIsEstimate) { "~$BatchTotal" } else { "$BatchTotal" }
			$batchInfo = if ($BatchTotal -ge 1) { " Batch: {0}/{1}({2}%)" -f $BatchCurrent, $batchTotalDisplay, $batchPct } else { '' }
		}
		$explosionCounts = "Records {0}-{1}/{2}{3}" -f $BatchRangeStart, $BatchRangeEnd, $es.Total, $batchInfo
	}
	elseif ($BatchTotal -ge 1) {
		$batchPct = if ($BatchTotal -gt 0 -and $BatchCurrent -gt 0) { [int]([Math]::Round(([double]$BatchCurrent / [double]$BatchTotal) * 100)) } else { 0 }
		$batchTotalDisplay = if ($BatchTotalIsEstimate) { "~$BatchTotal" } else { "$BatchTotal" }
		$batchInfo = " Batch: {0}/{1}({2}%)" -f $BatchCurrent, $batchTotalDisplay, $batchPct
		$explosionCounts = if ($es.Total -gt 0) { "Records {0}/{1}{2}" -f $es.Current, $es.Total, $batchInfo } else { "0/0" }
	}
	else {
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
	$batchDetail = ''
	$xDetail = if ($xs.Total -gt 0) { " | Export: {0}/{1}({2}%)" -f $xs.Current, $xs.Total, ([int]([Math]::Round($xPct * 100))) } else { ' | Export: 0/0' }
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

# Lightweight explicit progress tick to ensure visual movement in long zero-record scenarios.
function Write-ProgressTick {
	try {
		$qs = $script:progressState.Query
		if ($qs.Total -gt 0) {
			$pct = [int]([math]::Round(($qs.Current / [double]$qs.Total) * 100))
			Write-Progress -Activity "PAX Purview Audit Log Processing" -Status "Query blocks: $($qs.Current)/$($qs.Total) (~$pct%)" -PercentComplete $pct
		}
	} catch {}
}

$script:learnedActivityBlockSize = @{}
$script:globalLearnedBlockSize = $BlockHours

function Get-QueryPlan {
	param([string[]]$RequestedActivities)
	$normalized = @(); foreach ($a in $RequestedActivities) { if ($a -and -not ($normalized -contains $a)) { $normalized += $a } }
	if ($normalized.Count -eq 0) { $normalized = @('CopilotInteraction') }
	$plan = @(); $i = 0
	foreach ($a in $normalized) {
		$i++
		$plan += @{ Name = "Activity: $a"; Group = 'Generic'; Activities = @($a); Concurrency = $MaxConcurrency }
	}
	return $plan
}

function Update-LearnedBlockSize {
	param([string]$ActivityType, [double]$BlockHours, [int]$RecordCount, [bool]$Success)
	if ($Success) {
		if ($RecordCount -eq $ResultSize) {
			$newSize = [Math]::Max(0.083333, $BlockHours * 0.5)
			$script:learnedActivityBlockSize[$ActivityType] = $newSize
			$script:globalLearnedBlockSize = [Math]::Min($script:globalLearnedBlockSize, $newSize)
			Write-LogHost "    → Learned: Reducing block size to $([math]::Round($newSize,2))h due to limit hit" -ForegroundColor Magenta
		}
		elseif ($RecordCount -gt ($ResultSize * 0.8)) {
			$newSize = [Math]::Max(0.083333, $BlockHours * 0.7)
			$script:learnedActivityBlockSize[$ActivityType] = $newSize
			Write-LogHost "    → Learned: Reducing block size to $([math]::Round($newSize,2))h (high volume: $RecordCount records)" -ForegroundColor Magenta
		}
		elseif ($RecordCount -lt ($ResultSize * 0.1)) {
			$newSize = [Math]::Min(24.0, $BlockHours * 1.5)
			$script:learnedActivityBlockSize[$ActivityType] = $newSize
			Write-LogHost "    → Learned: Increasing block size to $([math]::Round($newSize,2))h (low volume: $RecordCount records)" -ForegroundColor Magenta
		}
		elseif ($RecordCount -lt ($ResultSize * 0.05)) {
			$newSize = [Math]::Min(24.0, $BlockHours * 2.0)
			$script:learnedActivityBlockSize[$ActivityType] = $newSize
			Write-LogHost "    → Learned: Increasing block size to $([math]::Round($newSize,2))h (very low volume: $RecordCount records)" -ForegroundColor Magenta
		}
	} else {
		$newSize = [Math]::Max(0.083333, $BlockHours * 0.5)
		$script:learnedActivityBlockSize[$ActivityType] = $newSize
		$script:globalLearnedBlockSize = [Math]::Min($script:globalLearnedBlockSize, $newSize)
		Write-LogHost "    → Learned: Reducing block size to $([math]::Round($newSize,2))h due to failure" -ForegroundColor Magenta
	}
}
function Get-NextSmallerBlockSize { param([double]$CurrentSize) return [Math]::Max(0.016667, $CurrentSize / 2) }

function Get-OptimalBlockSize { param([string]$ActivityType) if ($script:learnedActivityBlockSize.ContainsKey($ActivityType)) { return $script:learnedActivityBlockSize[$ActivityType] } elseif ($script:globalLearnedBlockSize -ne $BlockHours) { return $script:globalLearnedBlockSize } else { return $BlockHours } }

function Invoke-ActivityTimeWindowProcessing { 
	param(
		[Parameter(Mandatory = $true)][string]$ActivityType, 
		[Parameter(Mandatory = $true)][datetime]$StartDate, 
		[Parameter(Mandatory = $true)][datetime]$EndDate,
		[int]$PartitionIndex = 1,
		[int]$TotalPartitions = 1
	) 
    
	Write-Host "Processing $ActivityType (partition $PartitionIndex/$TotalPartitions) from $($StartDate.ToString('yyyy-MM-dd HH:mm')) to $($EndDate.ToString('yyyy-MM-dd HH:mm'))..." -ForegroundColor White
	$blockHours = Get-OptimalBlockSize -ActivityType $ActivityType
	Write-Host "  Using initial block size: $blockHours hours" -ForegroundColor DarkCyan
    
	$allResults = New-Object System.Collections.ArrayList
	$current = $StartDate
	$blockNumber = 1
    
	while ($current -lt $EndDate) { 
		if ($script:circuitBreakerOpen) {
			if ($script:circuitBreakerOpenUntil -and (Get-Date) -lt $script:circuitBreakerOpenUntil) {
				Write-LogHost "    Circuit breaker OPEN until $($script:circuitBreakerOpenUntil.ToString('HH:mm:ss')) – skipping remaining blocks for $ActivityType" -ForegroundColor Red
				break
			} else {
				$script:circuitBreakerOpen = $false
				$script:consecutiveBlockFailures = 0
				Write-LogHost "    Circuit breaker cooldown elapsed – resuming block processing" -ForegroundColor DarkGreen
			}
		}
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
				$script:consecutiveBlockFailures = 0
			} 
			else { 
				Write-Host "    No records found in this block" -ForegroundColor Gray
				$script:consecutiveBlockFailures = 0
			} 
		} 
		catch { 
			Write-Host "    Block failed: $($_.Exception.Message)" -ForegroundColor Red
			Update-LearnedBlockSize -ActivityType $ActivityType -BlockHours $actualBlockHours -RecordCount 0 -Success $false
			$script:consecutiveBlockFailures++
			$attemptNum = $script:consecutiveBlockFailures
			$expDelay = [math]::Min($BackoffMaxSeconds, $BackoffBaseSeconds * [math]::Pow(2, ($attemptNum - 1)))
			$jitterMs = Get-Random -Minimum 150 -Maximum 750
			$totalDelaySec = [math]::Round($expDelay,2) + [math]::Round($jitterMs/1000,2)
			try { $script:metrics.BackoffTotalDelaySeconds += $totalDelaySec } catch {}
			Write-LogHost "    Reliability: Backoff delay $([math]::Round($expDelay,2))s + jitter $([math]::Round($jitterMs/1000,2))s (attempt $attemptNum)" -ForegroundColor DarkYellow
			Start-Sleep -Seconds ([int][math]::Ceiling($expDelay))
			Start-Sleep -Milliseconds $jitterMs
			if ($script:consecutiveBlockFailures -ge $CircuitBreakerThreshold) {
				$script:circuitBreakerOpen = $true
				$script:circuitBreakerOpenUntil = (Get-Date).AddSeconds($CircuitBreakerCooldownSeconds)
				try { $script:metrics.CircuitBreakerTrips++ } catch {}
				Write-LogHost "    CIRCUIT BREAKER TRIPPED after $script:consecutiveBlockFailures consecutive block failures – cooling down for $CircuitBreakerCooldownSeconds seconds (until $($script:circuitBreakerOpenUntil.ToString('HH:mm:ss')))" -ForegroundColor Magenta
				break
			}
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
						$script:consecutiveBlockFailures = 0
					} 
				} 
				catch { 
					Write-Host "      Smaller block also failed: $($_.Exception.Message)" -ForegroundColor Red
					$script:consecutiveBlockFailures++
					$attemptNum = $script:consecutiveBlockFailures
					$expDelay = [math]::Min($BackoffMaxSeconds, $BackoffBaseSeconds * [math]::Pow(2, ($attemptNum - 1)))
					$jitterMs = Get-Random -Minimum 150 -Maximum 750
					$totalDelaySec = [math]::Round($expDelay,2) + [math]::Round($jitterMs/1000,2)
					try { $script:metrics.BackoffTotalDelaySeconds += $totalDelaySec } catch {}
					Write-LogHost "      Reliability: Backoff delay $([math]::Round($expDelay,2))s + jitter $([math]::Round($jitterMs/1000,2))s (attempt $attemptNum)" -ForegroundColor DarkYellow
					Start-Sleep -Seconds ([int][math]::Ceiling($expDelay))
					Start-Sleep -Milliseconds $jitterMs
					if ($script:consecutiveBlockFailures -ge $CircuitBreakerThreshold) {
						$script:circuitBreakerOpen = $true
						$script:circuitBreakerOpenUntil = (Get-Date).AddSeconds($CircuitBreakerCooldownSeconds)
						try { $script:metrics.CircuitBreakerTrips++ } catch {}
						Write-LogHost "      CIRCUIT BREAKER TRIPPED after $script:consecutiveBlockFailures consecutive block failures – cooling down for $CircuitBreakerCooldownSeconds seconds (until $($script:circuitBreakerOpenUntil.ToString('HH:mm:ss')))" -ForegroundColor Magenta
						break
					}
				} 
			} 
		} 
        
		try { 
			if ($script:progressState.Query.Current -ge $script:progressState.Query.Total) { 
				$script:progressState.Query.Total += 1
			} 
			$script:progressState.Query.Current += 1
			$script:progressBlocksCompleted = ($script:progressBlocksCompleted + 1)
			$script:progressBlockHoursSum = ($script:progressBlockHoursSum + $actualBlockHours)
			if ($script:progressBlocksCompleted -gt 0) {
				# --- Progress Estimation Logic (Improved for multi-partition accuracy) ---
				# Previously, the dynamic recalculation only considered the current partition's remaining hours.
				# In multi-partition scenarios this allowed Query.Total to shrink between partitions, causing
				# premature 100% completion when later partitions had not yet started.
				# New approach:
				#   1. Estimate remaining blocks in the CURRENT partition (as before).
				#   2. Add an estimate for yet-to-start partitions based on the average blocks/partition so far.
				#   3. Enforce a monotonic (non-decreasing) Query.Total so percent cannot jump to 100% early.
				$avgBlock = $script:progressBlockHoursSum / $script:progressBlocksCompleted
				$elapsedHours = $script:progressBlockHoursSum
				$currentPartitionRangeHours = ($EndDate - $StartDate).TotalHours
				$remainingHoursCurrentPartition = [Math]::Max(0.0, $currentPartitionRangeHours - $elapsedHours)
				$remainingBlocksEstCurrent = if ($avgBlock -gt 0) { [Math]::Ceiling($remainingHoursCurrentPartition / $avgBlock) } else { 0 }
				$remainingPartitions = if ($TotalPartitions -gt $PartitionIndex) { $TotalPartitions - $PartitionIndex } else { 0 }
				$avgBlocksPerCompletedPartition = if ($PartitionIndex -gt 0) { [double]$script:progressBlocksCompleted / [double]$PartitionIndex } else { [double]$script:progressBlocksCompleted }
				$futurePartitionBlocksEst = if ($remainingPartitions -gt 0 -and $avgBlocksPerCompletedPartition -gt 0) { [int][Math]::Ceiling($avgBlocksPerCompletedPartition * $remainingPartitions) } else { 0 }
				$newCalcGlobal = $script:progressBlocksCompleted + $remainingBlocksEstCurrent + $futurePartitionBlocksEst
				# Apply optional smoothing but NEVER allow total to decrease (monotonic total).
				if ($ProgressSmoothingAlpha -gt 0 -and $script:progressState.Query.Total -gt 0) {
					$smoothed = [int]([Math]::Round(($ProgressSmoothingAlpha * $newCalcGlobal) + ((1 - $ProgressSmoothingAlpha) * $script:progressState.Query.Total)))
					$newTotalCandidate = [Math]::Max($script:progressState.Query.Total, $smoothed, $newCalcGlobal)
				} else {
					$newTotalCandidate = [Math]::Max($script:progressState.Query.Total, $newCalcGlobal)
				}
				$script:progressState.Query.Total = [Math]::Max($script:progressState.Query.Total, $newTotalCandidate, $script:progressBlocksCompleted)
			}
			Update-Progress
			# Explicit tick for visibility even if Update-Progress weighting collapses.
			Write-ProgressTick
		} 
		catch {}
        
		$current = $blockEnd
		$blockNumber++
	} 
    
	Write-Host "  Completed $ActivityType (partition $PartitionIndex/$TotalPartitions)`: $($allResults.Count) total records" -ForegroundColor Green
	return $allResults.ToArray()
}

$LogFile = $OutputFile -replace '\.csv$', '.log'
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [string]$Level = "INFO") $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; $logEntry = "[$timestamp] [$Level] $Message"; Write-Host $Message; try { Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue } catch {} }
function Write-LogHost { param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message, [string]$ForegroundColor = "White") Write-Host $Message -ForegroundColor $ForegroundColor; try { $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; $logEntry = "[$timestamp] [INFO] $Message"; Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue } catch {} }

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
			$script:PAX_CsvWriter.Write($sb.ToString()); $sb.Clear() | Out-Null
		}
	}
	if ($sb.Length -gt 0) { $script:PAX_CsvWriter.Write($sb.ToString()) }
}

function Test-AgentFilter {
	param(
		[Parameter(Mandatory = $true)]
		$ParsedAuditData,
		[string[]]$AgentIdFilter,
		[bool]$AgentsOnlyFilter
	)
	if (-not $AgentIdFilter -and -not $AgentsOnlyFilter) {
		return $true
	}
	$recordAgentId = $null
	try {
		if ($ParsedAuditData.AgentId) {
			$recordAgentId = [string]$ParsedAuditData.AgentId
		}
	}
	catch {
		return $false
	}
	if ($AgentsOnlyFilter) {
		if ([string]::IsNullOrWhiteSpace($recordAgentId)) {
			return $false
		}
		if (-not $AgentIdFilter) {
			return $true
		}
	}
	if ($AgentIdFilter) {
		if ([string]::IsNullOrWhiteSpace($recordAgentId)) {
			return $false
		}
		foreach ($filterId in $AgentIdFilter) {
			if ($recordAgentId -eq $filterId) {
				return $true
			}
		}
		return $false
	}
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
if (-not $RAWInputCSV) {
	Write-LogHost "Authentication: $Auth" -ForegroundColor White
}
Write-LogHost ("Activity Types: " + ($ActivityTypes -join ', ')) -ForegroundColor White

if ($AgentId -or $AgentsOnly -or $ExcludeAgents -or $PromptFilter -or $UserIds -or $GroupNames) {
	Write-LogHost "Filters:" -ForegroundColor Yellow
	if ($AgentsOnly) { Write-LogHost "  AgentsOnly: Only records with AgentId present" -ForegroundColor Gray }
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
			for ($i = 0; $i -lt [Math]::Min(3, $AgentId.Count); $i++) {
				$displayId = if ($AgentId[$i].Length -gt 80) { $AgentId[$i].Substring(0, 77) + '...' } else { $AgentId[$i] }
				Write-LogHost "    [$($i+1)] $displayId" -ForegroundColor DarkGray
			}
			if ($AgentId.Count -gt 3) {
				Write-LogHost "    ... and $($AgentId.Count - 3) more" -ForegroundColor DarkGray
			}
		}
	}
	if ($ExcludeAgents) { Write-LogHost "  ExcludeAgents: Only records without AgentId" -ForegroundColor Gray }
	if ($PromptFilter) {
		$promptLabel = switch ($PromptFilter) {
			'Prompt'   { 'Only prompts (Message_isPrompt = True)' }
			'Response' { 'Only responses (Message_isPrompt = False)' }
			'Both'     { 'Both prompts and responses (Message_isPrompt = True or False)' }
			'Null'     { 'Only records with no Message_isPrompt values (Null/Empty)' }
		}
		Write-LogHost "  PromptFilter: $promptLabel" -ForegroundColor Gray
	}
	if ($UserIds -or $GroupNames) {
		if ($UserIds) {
			if ($UserIds.Count -eq 1) { Write-LogHost "  UserIds: 1 user" -ForegroundColor Gray } else { Write-LogHost "  UserIds: $($UserIds.Count) users" -ForegroundColor Gray }
		}
		if ($GroupNames) {
			if ($GroupNames.Count -eq 1) { Write-LogHost "  GroupNames: 1 group" -ForegroundColor Gray } else { Write-LogHost "  GroupNames: $($GroupNames.Count) groups" -ForegroundColor Gray }
		}
	}
}

Write-LogHost "=============================================" -ForegroundColor Cyan
Write-LogHost ""
if ($ExplodeDeep -and $ExplodeArrays) { Write-LogHost "Note: -ExplodeDeep takes precedence over -ExplodeArrays (arrays will still explode, plus deep flatten)." -ForegroundColor DarkYellow }
if ($ForcedRawInputCsvExplosion -and -not $ExplodeDeep -and -not $ExplodeArrays.IsPresent) { Write-LogHost "RAWInputCSV provided -> forcing Purview array explosion (non-exploded mode disabled)." -ForegroundColor Yellow }

if ($RAWInputCSV) {
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

# Predeclare script-scope collections to satisfy StrictMode before first access
if (-not (Get-Variable -Name DeepExtraColumns -Scope Script -ErrorAction SilentlyContinue)) { $script:DeepExtraColumns = $null }

# Removed host relaunch: we now stay in PS 7+ and adapt WebLogin call dynamically.

<#
=====================================================================
	Operational Logic
  NOTE: Intentional verbatim transplant (only version/header above changed)
=====================================================================
#>

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

$existingDeep = Get-Variable -Name DeepExtraColumns -Scope Script -ErrorAction SilentlyContinue
if (-not $existingDeep -or -not $script:DeepExtraColumns) { $script:DeepExtraColumns = New-Object System.Collections.Generic.List[string] }

function Convert-ToPurviewExplodedRecords {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)] $Record,
		[switch]$Deep,
		[string]$PromptFilterValue,
		[switch]$SkipMetrics  # Used by parallel replay to defer metrics aggregation to parent thread
	)
	try {
		$auditData = if ($Record.PSObject.Properties['_ParsedAuditData']) { $Record._ParsedAuditData } else { try { $Record.AuditData | ConvertFrom-Json -ErrorAction Stop } catch { $null } }
		if (-not $auditData) { return @() }
		$ced = Get-SafeProperty $auditData 'CopilotEventData'
		$messages = script:GetArrayFast $ced 'Messages'
		if ($PromptFilterValue) {
			$filteredMessages = New-Object System.Collections.Generic.List[object]
			if ($PromptFilterValue -eq 'Null') {
				foreach ($msg in $messages) { if ($null -eq $msg.isPrompt) { $filteredMessages.Add($msg) } }
			}
			elseif ($PromptFilterValue -eq 'Both') {
				foreach ($msg in $messages) { if ($null -ne $msg.isPrompt) { $filteredMessages.Add($msg) } }
			}
			else {
				$targetValue = ($PromptFilterValue -eq 'Prompt')
				foreach ($msg in $messages) { try { if ($msg.isPrompt -eq $targetValue) { $filteredMessages.Add($msg) } } catch {} }
			}
			$messages = $filteredMessages
			if ($messages.Count -eq 0) { return @() }
		}
		$contexts = script:GetArrayFast $ced 'Contexts'
		$resources = script:GetArrayFast $ced 'AccessedResources'
		$pluginsRaw = script:GetArrayFast $ced 'AISystemPlugin'
		$modelDetRaw = script:GetArrayFast $ced 'ModelTransparencyDetails'
		$messageIds = script:GetArrayFast $ced 'MessageIds'
		if ($PromptFilterValue) { $rowCount = [Math]::Max(1, $messages.Count) } else { $rowCount = (1, $messages.Count, $contexts.Count, $resources.Count | Measure-Object -Maximum).Maximum }
		$plugin0 = if ($pluginsRaw.Count -gt 0) { $pluginsRaw[0] } else { $null }
		$model0 = if ($modelDetRaw.Count -gt 0) { $modelDetRaw[0] } else { $null }
		$creationDate = script:Format-DatePurviewFast $Record.CreationDate
		$creationTime = try { script:Format-DatePurviewFast $auditData.CreationTime } catch { '' }
		$appIdentityRaw = (Select-FirstNonNull -Values @((Get-SafeProperty $auditData 'AppIdentity'), (Get-SafeProperty $ced 'AppIdentity')))
		if ($appIdentityRaw -is [string]) { $appIdentity = $appIdentityRaw; $appDisp = ''; $appPub = '' }
		elseif ($null -ne $appIdentityRaw) {
			$appIdentity = ''; $appDisp = Get-SafeProperty $appIdentityRaw 'DisplayName'; $appPub = Get-SafeProperty $appIdentityRaw 'PublisherId'
		}
		else { $appIdentity = ''; $appDisp = ''; $appPub = '' }
		$appHost = (Select-FirstNonNull -Values @((Get-SafeProperty $ced 'AppHost'), (Get-SafeProperty $auditData 'AppHost'), (Get-SafeProperty $auditData 'Workload')))
		$clientRegion = (Get-SafeProperty $auditData 'ClientRegion')
		$agentId = (Get-SafeProperty $auditData 'AgentId')
		$agentName = (Get-SafeProperty $auditData 'AgentName')
		$appName = (Select-FirstNonNull -Values @((Get-SafeProperty $auditData 'ApplicationName'), (Get-SafeProperty $ced 'HostAppName'), (Get-SafeProperty $ced 'ClientAppName')))
		$threadId = (Get-SafeProperty $ced 'ThreadId')
		$auditUserKey = try { $auditData.UserKey } catch { $null }
		$modelName = Get-SafeProperty $model0 'ModelName'
		$clientIP = (Get-SafeProperty $auditData 'ClientIP')
		$organizationId = (Get-SafeProperty $auditData 'OrganizationId')
		$version = (Get-SafeProperty $auditData 'Version')
		$userType = (Get-SafeProperty $auditData 'UserType')
		$copilotLogVersion = (Get-SafeProperty $auditData 'CopilotLogVersion')
		$workload = (Get-SafeProperty $auditData 'Workload')
		$baseSet = New-Object System.Collections.Generic.HashSet[string]; foreach ($c in $PurviewExplodedHeader) { $null = $baseSet.Add($c) }
		$rows = New-Object System.Collections.Generic.List[object]
		for ($i = 0; $i -lt $rowCount; $i++) {
			$rowObj = [PSCustomObject]@{
				RecordId = $(try { $auditData.Id } catch { $Record.Identity })
				CreationDate = $creationDate
				RecordType = $Record.RecordType
				Operation = $auditData.Operation
				UserId = $auditData.UserId
				AssociatedAdminUnits = (Get-SafeProperty $auditData 'AssociatedAdminUnits')
				AssociatedAdminUnitsNames = (Get-SafeProperty $auditData 'AssociatedAdminUnitsNames')
				AgentId = $agentId
				AgentName = $agentName
				AppIdentity = $appIdentity
				AppIdentity_DisplayName = $appDisp
				AppIdentity_PublisherId = $appPub
				ApplicationName = $appName
				CreationTime = $creationTime
				ClientRegion = $clientRegion
				ClientIP = $clientIP
				Audit_UserId = $auditUserKey
				AppHost = $appHost
				ThreadId = $threadId
				Context_Id = $(if ($i -lt $contexts.Count -and $contexts[$i]) { try { Get-SafeProperty $contexts[$i] 'Id' } catch { '' } } else { '' })
				Context_Type = $(if ($i -lt $contexts.Count -and $contexts[$i]) { try { Get-SafeProperty $contexts[$i] 'Type' } catch { '' } } else { '' })
				Message_Id = $(if ($i -lt $messages.Count) { $msg = $messages[$i]; if ($msg -is [psobject]) { try { Get-SafeProperty $msg 'Id' } catch { '' } } else { $msg } } else { '' })
				Message_isPrompt = $(if ($i -lt $messages.Count) { $msg = $messages[$i]; if ($msg -is [psobject]) { try { script:BoolTFFast (Get-SafeProperty $msg 'isPrompt') } catch { '' } } else { '' } } else { '' })
				AccessedResource_Action = $(if ($i -lt $resources.Count -and $resources[$i]) { try { Get-SafeProperty $resources[$i] 'Action' } catch { '' } } else { '' })
				AccessedResource_PolicyDetails = $(if ($i -lt $resources.Count -and $resources[$i]) { try { script:ToJsonIfObjectFast (Get-SafeProperty $resources[$i] 'PolicyDetails') } catch { '' } } else { '' })
				AccessedResource_SiteUrl = $(if ($i -lt $resources.Count -and $resources[$i]) { try { Get-SafeProperty $resources[$i] 'SiteUrl' } catch { '' } } else { '' })
				AISystemPlugin_Id = $(if ($plugin0) { try { Get-SafeProperty $plugin0 'Id' } catch { '' } } else { '' })
				AISystemPlugin_Name = $(if ($plugin0) { try { Get-SafeProperty $plugin0 'Name' } catch { '' } } else { '' })
				ModelTransparencyDetails_ModelName = $(if ($model0) { $modelName } else { '' })
				MessageIds = $(if ($messageIds.Count -gt 0) { $messageIds -join ';' } else { '' })
				OrganizationId = $organizationId
				Version = $version
				UserType = $userType
				CopilotLogVersion = $copilotLogVersion
				Workload = $workload
			}
			if ($Deep -and $ced) {
				$flat = ConvertTo-FlatColumns -Node $ced -Prefix 'CopilotEventData.' -MaxDepth $FlatDepthDeep
				foreach ($k in $flat.Keys) { if ($baseSet.Contains($k)) { continue }; if (-not $rowObj.PSObject.Properties[$k]) { if (-not $script:DeepExtraColumns.Contains($k)) { [void]$script:DeepExtraColumns.Add($k) }; try { Add-Member -InputObject $rowObj -NotePropertyName $k -NotePropertyValue $flat[$k] -Force } catch {} } }
			}
			if ($Deep -and $auditData) {
				$auditDataClone = [PSCustomObject]@{}
				foreach ($prop in $auditData.PSObject.Properties) { if ($prop.Name -ne 'CopilotEventData') { Add-Member -InputObject $auditDataClone -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force } }
				$flatAudit = ConvertTo-FlatColumns -Node $auditDataClone -Prefix 'AuditData.' -MaxDepth $FlatDepthDeep
				foreach ($k in $flatAudit.Keys) { if ($baseSet.Contains($k)) { continue }; if (-not $rowObj.PSObject.Properties[$k]) { if (-not $script:DeepExtraColumns.Contains($k)) { [void]$script:DeepExtraColumns.Add($k) }; try { Add-Member -InputObject $rowObj -NotePropertyName $k -NotePropertyValue $flatAudit[$k] -Force } catch {} } }
			}
			$rows.Add($rowObj) | Out-Null
		}
		if (-not $SkipMetrics -and $rows.Count -gt 1) { try { $script:metrics.ExplosionEvents += 1; $script:metrics.ExplosionRowsFromEvents += ($rows.Count - 1); if ($rows.Count -gt $script:metrics.ExplosionMaxPerRecord) { $script:metrics.ExplosionMaxPerRecord = $rows.Count } } catch {} }
		return , @($rows.ToArray())
	}
	catch { Write-Host "Failed Purview explosion: $($_.Exception.Message)" -ForegroundColor Red; return @() }
}

function Select-FirstNonNull { param([object[]]$Values) foreach ($v in $Values) { if ($null -ne $v -and ('' -ne [string]$v)) { return $v } } return $null }

function Convert-ToStructuredRecord {
	# Reverted to proven v1.7.3 implementation for stability; only prior parenthesis cleanup retained.
	param(
		[Parameter(Mandatory = $true)] $Record,
		[bool]$EnableExplosion = $false
	)
	try {
		function Local:Get-Num([object]$v) { if ($null -eq $v) { return $null }; try { if ($v -is [string] -and [string]::IsNullOrWhiteSpace($v)) { return $null }; return [double]$v } catch { return $null } }
		function Local:Add-OrUpdate([pscustomobject]$obj, [string]$name, $value) { try { if ($obj.PSObject.Properties[$name]) { $obj.PSObject.Properties[$name].Value = $value } else { Add-Member -InputObject $obj -NotePropertyName $name -NotePropertyValue $value -Force } } catch {} }
		# Use pre-parsed AuditData if available
		$auditData = if ($Record.PSObject.Properties['_ParsedAuditData']) { $Record._ParsedAuditData } else { try { $Record.AuditData | ConvertFrom-Json -ErrorAction Stop } catch { $null } }
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
		foreach ($k in $suggestAgg.Keys) { Add-OrUpdate $baseRecord $k $suggestAgg[$k] }
		foreach ($k in $actionAgg.Keys) { Add-OrUpdate $baseRecord $k $actionAgg[$k] }
		foreach ($k in $refAgg.Keys) { Add-OrUpdate $baseRecord $k $refAgg[$k] }
		foreach ($k in $partAgg.Keys) { Add-OrUpdate $baseRecord $k $partAgg[$k] }
		if (-not ($EnableExplosion -or $ExplodeDeep)) { Add-OrUpdate $baseRecord 'CopilotEventData' (if ($ced) { $ced | ConvertTo-Json -Depth $JsonDepth -Compress } else { $null }) }
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
					Add-OrUpdate $nr ("ArrayIndex_{0}" -f $entry.Name) $idx
					if ($el) {
						foreach ($prop in $el.PSObject.Properties) {
							$pname = ("{0}_{1}" -f $entry.Prefix, $prop.Name)
							if ($nr.PSObject.Properties[$pname]) { continue }
							$val = $prop.Value
							if (Test-ScalarValue $val) { Add-OrUpdate $nr $pname $val } else { try { Add-OrUpdate $nr $pname ($val | ConvertTo-Json -Depth $JsonDepth -Compress) } catch {} }
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
		if ($rows.Count -gt $maxRows) { foreach ($r in $rows) { Add-OrUpdate $r 'ExplosionTruncated' $true }; $rows = $rows[0..($maxRows - 1)]; try { $script:metrics.ExplosionTruncated = $true } catch {} }
		if ($ExplodeDeep -and $ced) {
			for ($i = 0; $i -lt $rows.Count; $i++) {
				$r = $rows[$i]
				$flat = ConvertTo-FlatColumns -Node $ced -Prefix 'CopilotEventData.' -MaxDepth $FlatDepthStandard
				foreach ($ck in $flat.Keys) { if (-not $r.PSObject.Properties[$ck]) { Add-OrUpdate $r $ck $flat[$ck] } }
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
		# (rawTotal removed; count unused beyond logging)
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
		$queryPlan = @(); $sequentialGroups = 0; $parallelDecision = @{ Enabled = $false; Reason = 'Replay'; AutoEligible = $false }; $parallelOverallEnabled = $false
		$script:metrics.TotalRecordsFetched = $ingested
		$script:progressState.Query.Total = 1; $script:progressState.Query.Current = 1
	}
	else {
		$existingEOM = Get-Module -ListAvailable -Name ExchangeOnlineManagement | Sort-Object Version -Descending | Select-Object -First 1
		if (-not $existingEOM) {
			Write-LogHost "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
			try { Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber; Write-LogHost "Module installed successfully." -ForegroundColor Green } catch { Write-LogHost "Failed to install ExchangeOnlineManagement module: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
		}
		Import-Module ExchangeOnlineManagement -Force
		Connect-ToComplianceCenter
		$diagOk = Invoke-AuditCapabilityDiagnostics
		if (-not $diagOk) { Write-LogHost "Continuing despite diagnostic warnings; live queries may fail." -ForegroundColor DarkYellow }
		$script:targetUsers = @()
		if ($UserIds -or $GroupNames) {
			Write-LogHost ""; Write-LogHost "User/Group Filtering Enabled:" -ForegroundColor Cyan
			if ($UserIds) { $script:targetUsers += $UserIds; Write-LogHost "  Individual users: $($UserIds.Count)" -ForegroundColor DarkCyan }
			if ($GroupNames) {
				Write-LogHost "  Expanding groups to individual users..." -ForegroundColor DarkCyan
				foreach ($group in $GroupNames) {
					try { Write-LogHost "    Processing group: '$group'" -ForegroundColor Gray; $members = Get-DistributionGroupMember -Identity $group -ErrorAction Stop | Select-Object -ExpandProperty PrimarySmtpAddress; $script:targetUsers += $members; Write-LogHost "      Expanded: $($members.Count) member(s)" -ForegroundColor DarkGray }
					catch { Write-LogHost "      Warning: Failed to expand group '$group': $($_.Exception.Message)" -ForegroundColor Yellow }
				}
			}
			$script:targetUsers = $script:targetUsers | Select-Object -Unique
			Write-LogHost "  Total target users after deduplication: $($script:targetUsers.Count)" -ForegroundColor Green; Write-LogHost ""
		}
		$startDateObj = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)
		$endDateObj = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', $null)
		Write-LogHost "Starting enterprise-grade audit log search..." -ForegroundColor Yellow
		Write-LogHost "Date range: $($startDateObj.ToString('yyyy-MM-dd')) (inclusive) to $($endDateObj.ToString('yyyy-MM-dd')) (exclusive)" -ForegroundColor Gray
		Write-LogHost "Processing mode: $(if ($ExplodeDeep){'Deep Column Explosion (with Row Explosion)'} elseif ($ExplodeArrays){'Array Explosion'} else {'Standard 1:1'})" -ForegroundColor Gray
		Write-LogHost ""; Write-LogHost "Initializing adaptive block sizing..." -ForegroundColor Cyan
		$allLogs = New-Object System.Collections.ArrayList
		$queryPlan = Get-QueryPlan -RequestedActivities $ActivityTypes
		$script:progressBlocksCompleted = 0; $script:progressBlockHoursSum = 0.0
		$script:progressState.Query.Current = 0
		$totalEstimatedBlocks = 0
		foreach ($grp in $queryPlan) { foreach ($act in $grp.Activities) { try { $initialBlock = Get-OptimalBlockSize -ActivityType $act; if (-not $initialBlock -or $initialBlock -le 0) { $initialBlock = $BlockHours }; $rangeHours = ($endDateObj - $startDateObj).TotalHours; $blocks = [int][Math]::Ceiling($rangeHours / $initialBlock); if ($blocks -lt 1) { $blocks = 1 }; $totalEstimatedBlocks += $blocks } catch { $totalEstimatedBlocks += 1 } } }
		if ($totalEstimatedBlocks -lt 1) { $totalEstimatedBlocks = 1 }
		$script:progressState.Query.Total = [int]$totalEstimatedBlocks
		Set-ProgressPhase -Phase 'Query' -Status "Planning queries: $($queryPlan.Count) groups (~$totalEstimatedBlocks blocks)"
		Write-LogHost "Planned $($queryPlan.Count) query groups; estimated query blocks: ~$totalEstimatedBlocks" -ForegroundColor DarkCyan
		$sequentialGroups = 0
		$ps7 = ($PSVersionTable.PSVersion.Major -ge 7)
		if (-not $ps7 -and $ParallelMode -ne 'Off') { $ParallelMode = 'Off' }
		$parallelDecision = Get-ParallelActivationDecision -QueryPlan $queryPlan -ParallelMode $ParallelMode -MaxParallelGroups $MaxParallelGroups -MaxConcurrency $MaxConcurrency
		$parallelOverallEnabled = $parallelDecision.Enabled
		Write-LogHost ("ParallelMode requested: {0} | Effective: {1} ({2})" -f $ParallelMode, ($(if ($parallelOverallEnabled) { 'Enabled' } else { 'Disabled' })), $parallelDecision.Reason) -ForegroundColor DarkCyan
		if ($ParallelMode -eq 'Auto' -and -not $parallelOverallEnabled) { Write-LogHost "WARNING: ParallelMode Auto requested but heuristics not met -> running sequential. Reason: $($parallelDecision.Reason)." -ForegroundColor Yellow }
		if ($legacyParallelSwitchUsed) { Write-LogHost "Legacy -EnableParallel switch detected -> overriding ParallelMode to On" -ForegroundColor DarkYellow }
		$groupIndex = 0
		foreach ($grp in $queryPlan) {
			$groupIndex++
			$degree = [Math]::Min($grp.Concurrency, $MaxConcurrency)
			Write-LogHost "Group: $($grp.Name) [$(($grp.Activities -join ', '))] (desired partitions=$degree)" -ForegroundColor Yellow
			$requestedDegree = $degree
			if ($degree -gt $MaxActivePartitions) { $degree = 12; try { $script:metrics.PartitionCapsApplied++; if ($script:metrics.PartitionCapHighestRequested -lt $requestedDegree) { $script:metrics.PartitionCapHighestRequested = $requestedDegree } } catch {}; Write-LogHost "  Applying max active tasks cap ($MaxActivePartitions): requested $requestedDegree -> capped to $degree" -ForegroundColor Magenta }
			$withinCap = $groupIndex -le $MaxParallelGroups
			$canParallel = $parallelOverallEnabled -and $withinCap -and ($PSVersionTable.PSVersion.Major -ge 7) -and ($degree -gt 1)
			if (-not $DisableAdaptive) { try { $workingSetMB = [math]::Round(([System.Diagnostics.Process]::GetCurrentProcess().WorkingSet64 / 1MB),0); if ($workingSetMB -gt $MemoryPressureMB -and $MaxConcurrency -gt 1) { $old = $MaxConcurrency; $MaxConcurrency = [Math]::Max(1, $MaxConcurrency - 1); if ($degree -gt $MaxConcurrency) { $degree = $MaxConcurrency }; $script:metrics.AdaptiveMemoryReductions++; $script:metrics.AdaptiveEvents += "Memory pressure detected (${workingSetMB}MB > ${MemoryPressureMB}MB) reduced MaxConcurrency $old -> $MaxConcurrency"; Write-LogHost "Adaptive: Memory pressure ($workingSetMB MB) reducing MaxConcurrency to $MaxConcurrency" -ForegroundColor DarkYellow } } catch {} }
			$activity = $grp.Activities[0]
			$partitions = @()
			if ($degree -gt 1) { $totalHours = ($endDateObj - $startDateObj).TotalHours; $sliceHours = $totalHours / $degree; for ($pi = 0; $pi -lt $degree; $pi++) { $pStart = $startDateObj.AddHours($sliceHours * $pi); $pEnd = if ($pi -eq ($degree - 1)) { $endDateObj } else { $startDateObj.AddHours($sliceHours * ($pi + 1)) }; $partitions += [pscustomobject]@{ Activity = $activity; PStart = $pStart; PEnd = $pEnd; Index = ($pi + 1); Total = $degree } } } else { $partitions += [pscustomobject]@{ Activity = $activity; PStart = $startDateObj; PEnd = $endDateObj; Index = 1; Total = 1 } }
			# Capture function body text so thread jobs can recreate missing function definitions.
				# (Removed dynamic function code capture for parallel path – using isolated job logic instead)
			if ($canParallel) {
				Write-LogHost "  Processing partitions in parallel (ThreadJobs, Max=$degree)..." -ForegroundColor Cyan
				try {
						$jobs = @()
						$jobMeta = @{}
						foreach ($pt in $partitions) {
							$job = Start-ThreadJob -ScriptBlock {
								param($activity,$pStart,$pEnd,$idx,$tot,$resultSize,$userIds,$pacingMs)
								function Invoke-LocalAuditSearch {
									param([datetime]$Start,[datetime]$End,[string]$Operation,[int]$ResultSize,[string[]]$UserIds)
									$all = New-Object System.Collections.ArrayList
									$pageSize = [Math]::Min($ResultSize,5000)
									$page = 1
									$maxPages = 50
									$useSession = ($ResultSize -gt 5000)
									$sessionId = if ($useSession) { [guid]::NewGuid().ToString() } else { $null }
									while ($all.Count -lt $ResultSize -and $page -le $maxPages) {
										$remaining = $ResultSize - $all.Count
										$currentSize = [Math]::Min($pageSize,$remaining)
										$params = @{ StartDate=$Start; EndDate=$End; Operations=$Operation; ResultSize=$currentSize; ErrorAction='Stop' }
										if ($UserIds) { $params['UserIds']=$UserIds }
										if ($useSession) { $params['SessionId']=$sessionId; $params['SessionCommand']= if ($page -eq 1) { 'ReturnLargeSet' } else { 'ReturnNextPreviewPage' } }
										try { $res = Search-UnifiedAuditLog @params } catch { $res = @() }
										if ($res -and $res.Count -gt 0) { $null = $all.AddRange($res); if ($res.Count -lt $currentSize) { break } } else { break }
										$page++
										if ($pacingMs -gt 0) { Start-Sleep -Milliseconds $pacingMs }
									}
									return $all.ToArray()
								}
								$t0 = Get-Date
								$records = Invoke-LocalAuditSearch -Start $pStart -End $pEnd -Operation $activity -ResultSize $resultSize -UserIds $userIds
								$t1 = Get-Date
								[pscustomobject]@{ Activity=$activity; Logs=$records; RetrievedCount=($records.Count); ElapsedMs=[int]($t1-$t0).TotalMilliseconds; Partition=$idx }
							} -ArgumentList $pt.Activity,$pt.PStart,$pt.PEnd,$pt.Index,$pt.Total,$ResultSize,$script:targetUsers,$PacingMs
							$jobs += $job
							$jobMeta[$job.Id] = $pt
						}
						# Incremental wait to surface progress as each partition completes
						$initialBlockSize = if ($script:globalLearnedBlockSize -and $script:globalLearnedBlockSize -gt 0) { $script:globalLearnedBlockSize } else { $BlockHours }
						if ($initialBlockSize -le 0) { $initialBlockSize = 0.5 }
						$processedJobIds = New-Object System.Collections.Generic.HashSet[int]
						while (($jobs | Where-Object { $_.State -in 'Running','NotStarted' }).Count -gt 0) {
							$completedNow = $jobs | Where-Object { $_.State -eq 'Completed' -and -not $processedJobIds.Contains($_.Id) }
							foreach ($cj in $completedNow) {
								$res = Receive-Job -Job $cj
								$pt = $jobMeta[$cj.Id]
								if ($res) {
									try {
										$script:metrics.QueryMs += [int]$res.ElapsedMs
										if (-not $script:metrics.Activities.ContainsKey($res.Activity)) { $script:metrics.Activities[$($res.Activity)] = @{ Retrieved = 0; Structured = 0 } }
										$script:metrics.Activities[$($res.Activity)].Retrieved += [int]$res.RetrievedCount
										$script:metrics.TotalRecordsFetched += [int]$res.RetrievedCount
									} catch {}
									if ($res.Logs) { [void]$allLogs.AddRange($res.Logs) }
								}
								# Estimate blocks for this partition
								$ph = ($pt.PEnd - $pt.PStart).TotalHours
								$blocksForPartition = [int]([Math]::Ceiling([Math]::Max(0.1, $ph) / [Math]::Max(0.05, $initialBlockSize)))
								if ($blocksForPartition -lt 1) { $blocksForPartition = 1 }
								$remainingNeeded = $script:progressState.Query.Total - $script:progressState.Query.Current
								if ($blocksForPartition -gt $remainingNeeded) { $blocksForPartition = $remainingNeeded }
								if ($blocksForPartition -gt 0) {
									$script:progressState.Query.Current += $blocksForPartition
									$script:progressBlocksCompleted += $blocksForPartition
									Update-Progress -Status ("Partition {0}/{1} complete (+{2} est blocks)" -f $pt.Index,$pt.Total,$blocksForPartition)
									$qc = $script:progressState.Query.Current; $qt = $script:progressState.Query.Total
									Write-LogHost ("  Parallel partition {0} complete: +{1} block(s) (Query {2}/{3})" -f $pt.Index,$blocksForPartition,$qc,$qt) -ForegroundColor DarkGray
									Write-ProgressTick
								}
								[void]$processedJobIds.Add($cj.Id)
							}
							Start-Sleep -Milliseconds 200
						}
						# Receive & log any remaining (edge cases: very fast completions at loop end)
						$remainingUnprocessed = $jobs | Where-Object { -not $processedJobIds.Contains($_.Id) }
						foreach ($rj in $remainingUnprocessed) {
							$res = Receive-Job -Job $rj
							$pt = $jobMeta[$rj.Id]
							if ($res) {
								try {
									$script:metrics.QueryMs += [int]$res.ElapsedMs
									if (-not $script:metrics.Activities.ContainsKey($res.Activity)) { $script:metrics.Activities[$($res.Activity)] = @{ Retrieved = 0; Structured = 0 } }
									$script:metrics.Activities[$($res.Activity)].Retrieved += [int]$res.RetrievedCount
									$script:metrics.TotalRecordsFetched += [int]$res.RetrievedCount
								} catch {}
								if ($res.Logs) { [void]$allLogs.AddRange($res.Logs) }
							}
							$ph = ($pt.PEnd - $pt.PStart).TotalHours
							$blocksForPartition = [int]([Math]::Ceiling([Math]::Max(0.1, $ph) / [Math]::Max(0.05, $initialBlockSize)))
							if ($blocksForPartition -lt 1) { $blocksForPartition = 1 }
							$remainingNeeded = $script:progressState.Query.Total - $script:progressState.Query.Current
							if ($blocksForPartition -gt $remainingNeeded) { $blocksForPartition = $remainingNeeded }
							if ($blocksForPartition -gt 0) {
								$script:progressState.Query.Current += $blocksForPartition
								$script:progressBlocksCompleted += $blocksForPartition
								Update-Progress -Status ("Partition {0}/{1} complete (+{2} est blocks)" -f $pt.Index,$pt.Total,$blocksForPartition)
								$qc = $script:progressState.Query.Current; $qt = $script:progressState.Query.Total
								Write-LogHost ("  Parallel partition {0} complete: +{1} block(s) (Query {2}/{3})" -f $pt.Index,$blocksForPartition,$qc,$qt) -ForegroundColor DarkGray
								Write-ProgressTick
							}
							[void]$processedJobIds.Add($rj.Id)
						}
						# If after all partitions Query.Current still < Query.Total (overestimation), clamp to total for clarity
						if ($script:progressState.Query.Current -lt $script:progressState.Query.Total -and $script:progressState.Query.Total -le 200) {
							$script:progressState.Query.Current = $script:progressState.Query.Total
							Update-Progress -Status 'Parallel partitions complete (normalized)'
						}
						Remove-Job -Job $jobs -Force -ErrorAction SilentlyContinue | Out-Null
				}
				catch { Write-LogHost "  Parallel ThreadJob execution failed: $($_.Exception.Message). Falling back to sequential." -ForegroundColor DarkYellow; $canParallel = $false }
			}
			if (-not $canParallel) {
				$sequentialGroups++
				foreach ($pt in $partitions) {
					$tq0 = Get-Date
					Write-LogHost "Querying activity partition $($pt.Index)/$($pt.Total) sequentially" -ForegroundColor DarkCyan
					$logs = Invoke-ActivityTimeWindowProcessing -ActivityType $pt.Activity -StartDate $pt.PStart -EndDate $pt.PEnd -PartitionIndex $pt.Index -TotalPartitions $pt.Total
					$tq1 = Get-Date
					try {
						$ms = [int]($tq1 - $tq0).TotalMilliseconds
						$script:metrics.QueryMs += $ms
						if (-not $script:metrics.Activities.ContainsKey($activity)) { $script:metrics.Activities[$activity] = @{ Retrieved = 0; Structured = 0 } }
						if ($logs) {
							$script:metrics.Activities[$activity].Retrieved += $logs.Count
							$script:metrics.TotalRecordsFetched += $logs.Count
							[void]$allLogs.AddRange($logs)
						}
						# Explicit progress tick per sequential partition
						$script:progressState.Query.Current = [Math]::Min($script:progressState.Query.Current + 1, $script:progressState.Query.Total)
						Write-ProgressTick
					} catch {}
				}
			}
		}
	}
	Set-ProgressPhase -Phase 'Explosion' -Status 'Analyzing and exploding records'
	Write-LogHost ""; Write-LogHost "=== Enterprise Processing Summary ===" -ForegroundColor Green
	Write-LogHost "Total audit records retrieved: $($allLogs.Count)" -ForegroundColor Cyan
	if ($script:Hit10KLimit) { Write-LogHost ""; Write-LogHost "  CRITICAL NOTICE: Exchange Online 10K limit was reached during processing!" -ForegroundColor Red }
	if ($allLogs.Count -eq 0) {
		Write-LogHost ""; Write-LogHost "No audit logs found in the specified date range for the selected activity types." -ForegroundColor Yellow
		Write-LogHost "Emitting header-only CSV (0 rows) for deterministic downstream processing..." -ForegroundColor Cyan
		$headerColumns = if ($ExplodeDeep -or $ExplodeArrays -or $ForcedRawInputCsvExplosion) { $PurviewExplodedHeader } else { @('RecordType', 'CreationDate', 'UserIds', 'Operations', 'ResultStatus', 'ResultCount', 'Identity', 'IsValid', 'ObjectState', 'Id', 'CreationTime', 'Operation', 'OrganizationId', 'RecordTypeNum', 'ResultStatus_Audit', 'UserKey', 'UserType', 'Version', 'Workload', 'UserId', 'AppId', 'ClientAppId', 'CorrelationId', 'ModelId', 'ModelProvider', 'ModelFamily', 'TokensTotal', 'TokensInput', 'TokensOutput', 'DurationMs', 'OutcomeStatus', 'ConversationId', 'TurnNumber', 'RetryCount', 'ClientVersion', 'ClientPlatform', 'AgentId', 'AgentName', 'AppIdentity', 'ApplicationName', 'OriginalAuditData', 'CopilotEventData') }
		try { $outputDirEmpty = Split-Path $OutputFile -Parent; if (-not (Test-Path $outputDirEmpty)) { New-Item -ItemType Directory -Path $outputDirEmpty -Force | Out-Null }; $enc = New-Object System.Text.UTF8Encoding($false); $sw = [System.IO.StreamWriter]::new($OutputFile, $false, $enc); $escapedCols = @(); foreach ($col in $headerColumns) { $c = [string]$col; $needsQuote = ($c -match '[",\r\n]') -or $c.StartsWith(' ') -or $c.EndsWith(' '); $escaped = $c -replace '"', '""'; if ($needsQuote) { $escaped = '"' + $escaped + '"' }; $escapedCols += , $escaped }; $sw.WriteLine(($escapedCols -join ',')); $sw.Flush(); $sw.Dispose() } catch { Write-LogHost "Failed to write header-only CSV: $($_.Exception.Message)" -ForegroundColor Red }
		$script:metrics.TotalStructuredRows = 0; $script:metrics.EffectiveChunkSize = 0; Set-ProgressPhase -Phase 'Complete' -Status 'No data'; Complete-Progress; Write-LogHost "Header-only CSV created at: $OutputFile" -ForegroundColor Green; return
	}
	$effectiveExplode = ($ExplodeDeep -or $ExplodeArrays -or $ForcedRawInputCsvExplosion)
	$processingMode = if ($ExplodeDeep) { "deep column flattening (with row explosion)" } elseif ($ExplodeArrays -or $ForcedRawInputCsvExplosion) { "array explosion" } else { "standard 1:1 format" }
	Write-LogHost "Converting audit records to structured format using $processingMode..." -ForegroundColor Yellow
	$structuredDataCount = 0
	Write-LogHost "Streaming export mode enabled (schema sample=$StreamingSchemaSample; base chunk size=$StreamingChunkSize)" -ForegroundColor Yellow
	$te0 = Get-Date
	$schemaFrozen = $false; $schemaSampleRows = New-Object System.Collections.Generic.List[object]; $postFreezeNewColumns = 0; $lateIgnoredColumns = New-Object System.Collections.Generic.HashSet[string]; $columnOrder = $null; $buffer = New-Object System.Collections.Generic.List[object]; $exportTemp = Join-Path ([System.IO.Path]::GetTempPath()) ("pax_export_" + [guid]::NewGuid().ToString() + ".tmp"); $csvWriter = $false
	foreach ($log in $allLogs) {
		$records = if ($effectiveExplode) { Convert-ToPurviewExplodedRecords -Record $log -Deep:$ExplodeDeep -PromptFilterValue $PromptFilter } else { Convert-ToStructuredRecord -Record $log -EnableExplosion:$false }
		if ($records -and $records.Count -gt 0) { try { $script:metrics.TotalStructuredRows += $records.Count; $structuredDataCount += $records.Count; $opName = $null; try { $opName = if ($log.Operation) { [string]$log.Operation } elseif ($log.Operations) { [string]$log.Operations } else { $null } } catch {}; if (-not $opName) { $opName = 'Unknown' }; if (-not $script:metrics.Activities.ContainsKey($opName)) { $script:metrics.Activities[$opName] = @{ Retrieved = 0; Structured = 0 } }; $script:metrics.Activities[$opName].Structured += $records.Count } catch {}; foreach ($r in $records) { if (-not $schemaFrozen) { $schemaSampleRows.Add($r) | Out-Null; if ($schemaSampleRows.Count -ge $StreamingSchemaSample) { if ($ExplodeArrays -or $ExplodeDeep -or $ForcedRawInputCsvExplosion) { $columnOrder = New-Object System.Collections.Generic.List[string]; foreach ($c in $PurviewExplodedHeader) { [void]$columnOrder.Add($c) }; if ($ExplodeDeep -and $script:DeepExtraColumns -and $script:DeepExtraColumns.Count -gt 0) { foreach ($c in $script:DeepExtraColumns) { if (-not $columnOrder.Contains($c)) { [void]$columnOrder.Add($c) } } } } else { $columnOrder = New-Object System.Collections.Generic.List[string]; foreach ($sr in $schemaSampleRows) { foreach ($pn in $sr.PSObject.Properties.Name) { if (-not $columnOrder.Contains($pn)) { [void]$columnOrder.Add($pn) } } } }; Write-LogHost "Schema frozen with $($columnOrder.Count) columns after $($schemaSampleRows.Count) sample rows" -ForegroundColor DarkCyan; $effectiveChunkSize = $StreamingChunkSize; $colCount = $columnOrder.Count; if ($colCount -gt 1000) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 1000) } elseif ($colCount -gt 750) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 1500) } elseif ($colCount -gt 500) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 2500) } elseif ($colCount -gt 250) { $effectiveChunkSize = [int][Math]::Min($effectiveChunkSize, 4000) } else { if ($colCount -le 60 -and $StreamingChunkSize -lt 15000) { $autoBoost = [int][Math]::Min(15000, [Math]::Max($StreamingChunkSize * 3, 8000)); $effectiveChunkSize = $autoBoost } }; if ($effectiveChunkSize -ne $StreamingChunkSize) { Write-LogHost "Adaptive chunk size applied: $effectiveChunkSize (was $StreamingChunkSize) due to column width $colCount" -ForegroundColor DarkYellow } else { Write-LogHost "Chunk size retained/boosted: $effectiveChunkSize (columns=$colCount)" -ForegroundColor DarkGray }; $script:metrics.EffectiveChunkSize = $effectiveChunkSize; if (-not $csvWriter) { Open-CsvWriter -Path $exportTemp -Columns $columnOrder; $csvWriter = $true }; $emitRows = @(); foreach ($sr in $schemaSampleRows) { $emitRows += ($sr | Select-Object -Property $columnOrder) }; if ($emitRows.Count -gt 0) { Write-CsvRows -Rows $emitRows -Columns $columnOrder }; $schemaSampleRows.Clear(); $schemaFrozen = $true } } else { $rowHadNew = $false; foreach ($pn in $r.PSObject.Properties.Name) { if (-not $columnOrder.Contains($pn)) { if (-not $rowHadNew) { $postFreezeNewColumns++; $rowHadNew = $true }; if (-not $lateIgnoredColumns.Contains($pn)) { [void]$lateIgnoredColumns.Add($pn) } } }; $buffer.Add($r) | Out-Null; if (-not $effectiveChunkSize) { $effectiveChunkSize = $StreamingChunkSize }; if ($buffer.Count -ge $effectiveChunkSize) { $emitSet = $buffer | ForEach-Object { $_ | Select-Object -Property $columnOrder }; if (-not $csvWriter) { Open-CsvWriter -Path $exportTemp -Columns $columnOrder; $csvWriter = $true }; if ($emitSet.Count -gt 0) { Write-CsvRows -Rows $emitSet -Columns $columnOrder }; $buffer.Clear() } } }
		}
	}
	# Cleanup: ensure writer closed before export finalization.
	if ($csvWriter) { try { Close-CsvWriter } catch {} }
	# Fallback: ensure temp file exists so Move-Item does not fail (very small datasets may not have flushed rows yet)
	if (-not (Test-Path $exportTemp)) {
		try {
			$enc = New-Object System.Text.UTF8Encoding($false)
			$sw = [System.IO.StreamWriter]::new($exportTemp, $false, $enc)
			if ($columnOrder) {
				$escapedCols = New-Object System.Collections.Generic.List[string]
				foreach ($col in $columnOrder) {
					$c = [string]$col; $needsQuote = ($c -match '[",\r\n]') -or $c.StartsWith(' ') -or $c.EndsWith(' ')
					$escaped = $c -replace '"','""'
					if ($needsQuote) { $escaped = '"' + $escaped + '"' }
					$escapedCols.Add($escaped) | Out-Null
				}
				$sw.WriteLine(($escapedCols -join ','))
			} else {
				$sw.WriteLine('RecordId')
			}
			$sw.Flush(); $sw.Dispose()
		} catch { Write-LogHost "WARNING: Fallback temp file creation failed: $($_.Exception.Message)" -ForegroundColor Yellow }
	}
	$te1 = Get-Date; try { $script:metrics.ExplosionMs += [int]($te1 - $te0).TotalMilliseconds } catch {}
	Write-LogHost "Standard processing (streamed) complete: $($allLogs.Count) input -> $structuredDataCount output" -ForegroundColor Cyan
	if ($postFreezeNewColumns -gt 0) { Write-LogHost "NOTICE: $postFreezeNewColumns row(s) contained new columns after schema freeze (ignored). Increase -StreamingSchemaSample if needed." -ForegroundColor DarkYellow }
	Set-ProgressPhase -Phase 'Export' -Status 'Finalizing streaming CSV'
	$tx0 = Get-Date; Move-Item -Force -Path $exportTemp -Destination $OutputFile; $tx1 = Get-Date; try { $script:metrics.ExportMs += [int]($tx1 - $tx0).TotalMilliseconds } catch {}
	$script:progressState.Export.Total = 1; $script:progressState.Export.Current = 1; Update-Progress -Status 'Export complete (stream)'; Set-ProgressPhase -Phase 'Complete' -Status 'Done'; Complete-Progress
	Write-LogHost ""; Write-LogHost "=== Enterprise Export Complete ===" -ForegroundColor Green
	Write-LogHost "Processing mode: $processingMode" -ForegroundColor White
	Write-LogHost "Records exported: $($script:metrics.TotalStructuredRows)" -ForegroundColor White
	Write-LogHost "Output file: $OutputFile" -ForegroundColor White
	Write-LogHost "Log file: $LogFile" -ForegroundColor White
	Write-LogHost "File size: $([math]::Round((Get-Item $OutputFile).Length / 1KB,2)) KB" -ForegroundColor White
}
catch {
	$msg = $_.Exception.Message
	if ($msg -eq '__PAX_EARLY_EXIT__' -or $script:EarlyExit) {
		# Graceful early exit path (e.g., header-only CSV)
		Write-LogHost "Early exit executed: $script:EarlyExit" -ForegroundColor DarkGray
	} else {
		Write-LogHost "Script failed: $msg" -ForegroundColor Red
		Write-LogHost $_.ScriptStackTrace -ForegroundColor Red
	}
}
finally {
	$endUtc = (Get-Date).ToUniversalTime()
	try { if ($script:metrics -and $script:metrics.StartTime) { $startTail = $script:metrics.StartTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'); Write-Log "Script execution started at $startTail UTC" } } catch {}
	Write-Log "Script execution completed at $($endUtc.ToString('yyyy-MM-dd HH:mm:ss')) UTC"
	Write-Log "Script version: v$ScriptVersion"
	try { if ($script:metrics -and $script:metrics.StartTime) { $elapsed = $endUtc - $script:metrics.StartTime; $totalHours = [math]::Floor($elapsed.TotalHours); $remainder = $elapsed - [TimeSpan]::FromHours($totalHours); $elapsedFormatted = ("{0}:{1:00}:{2:00}.{3:000}" -f $totalHours, $remainder.Minutes, $remainder.Seconds, $remainder.Milliseconds); Write-Log ("Total elapsed time: {0} (hours:minutes:seconds.milliseconds)" -f $elapsedFormatted) } } catch {}
	if ($script:Connected) { try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null; Write-LogHost "Disconnected from Exchange Online" -ForegroundColor Gray } catch {} }
	if ($EmitMetricsJson) {
		try { $metricsPath = if ($MetricsPath) { if ($MetricsPath.ToLower().EndsWith('.json')) { $MetricsPath } else { "$MetricsPath.json" } } else { $OutputFile -replace '\\.csv$', '.metrics.json' }; $emitObj = [ordered]@{ version = $ScriptVersion; timestampUtc = (Get-Date).ToUniversalTime().ToString('o'); parameters = $paramSnapshot; metrics = $script:metrics }; ($emitObj | ConvertTo-Json -Depth 6) | Out-File -FilePath $metricsPath -Encoding UTF8; Write-LogHost "Metrics JSON emitted: $metricsPath" -ForegroundColor DarkCyan } catch { Write-LogHost "Failed to emit metrics JSON: $($_.Exception.Message)" -ForegroundColor Yellow }
	}
	$exitCode = 0; if ($script:circuitBreakerOpen) { $exitCode = 20 } elseif ($script:Hit10KLimit -and -not $AutoCompleteness) { $exitCode = 10 }
	Write-LogHost "Exit code: $exitCode" -ForegroundColor DarkGray
	exit $exitCode
}

