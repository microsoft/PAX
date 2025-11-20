<#
.SYNOPSIS
    PAX CopilotInteractions Content Audit Log Processor - Extract Copilot interaction content via Graph API.

.DESCRIPTION
    This script uses Microsoft Graph Copilot Interaction Export API to extract Copilot 
    interaction content including prompts, responses, and metadata directly from the service.
    
    Content includes interactions from all Microsoft 365 Copilot applications:
    - IPM.SkypeTeams.Message.Copilot.Word
    - IPM.SkypeTeams.Message.Copilot.Excel
    - IPM.SkypeTeams.Message.Copilot.PowerPoint
    - IPM.SkypeTeams.Message.Copilot.Outlook
    - IPM.SkypeTeams.Message.Copilot.Teams
    - IPM.SkypeTeams.Message.Copilot.BizChat (Copilot Chat/Business Chat)
    - IPM.SkypeTeams.Message.Copilot.OneNote
    - IPM.SkypeTeams.Message.Copilot.Loop
    - IPM.SkypeTeams.Message.Copilot.Whiteboard
    - IPM.SkypeTeams.Message.Copilot.Forms
    - IPM.SkypeTeams.Message.Copilot.Planner
    - IPM.SkypeTeams.Message.Copilot.SharePoint
    - IPM.SkypeTeams.Message.Copilot.Stream
    
    WORKFLOW:
    1. Connect to Microsoft Graph with app-only authentication
    2. Detect filter support in tenant (appClass vs createdDateTime)
    3. Load watermarks from previous run (optional, for incremental processing)
    4. Process users in parallel batches (20 users per batch, 25 concurrent)
    5. Fetch interactions via getAllEnterpriseInteractions API with pagination
    6. Apply client-side filtering (dates, appClass) and watermark early-exit
    7. Update watermarks with latest timestamps and export to CSV/Excel
    
    API CONFIGURATION:
    • Endpoint: /v1.0/copilot/users/{upn}/interactionHistory/getAllEnterpriseInteractions
    • Pagination: Automatic via @odata.nextLink
    • Batch size: 20 requests per JSON batch (Microsoft Graph limit)
    • Parallel execution: Configurable concurrent batches (default: 25)
    
    FILTERING SUPPORT:
    • appClass filter: Supported server-side (documented feature)
    • createdDateTime filter: Tenant variance (may return 400 in some tenants)
    • Client-side filtering: Applied for dates and appClass when server-side fails
    • Watermark pattern: Stores last seen timestamp per user for incremental processing
    
    The output provides:
    - Full interaction content (body with prompt/response text)
    - Core identifiers, timestamps, user and app context
    - Interaction metadata including contexts, links, mentions, attachments
    - All fields suitable for compliance and analytics with composite keys for deduplication

    PREREQUISITES - APP REGISTRATION:
    This script requires an Azure AD App Registration with specific API permissions configured
    in your Microsoft 365 tenant. You must create this app registration before running the script.
    
    QUICK SETUP GUIDE:
    1. Create App Registration
       • Navigate to Azure Portal > Microsoft Entra ID > App registrations > New registration
       • Name: "PAX Copilot Interactions Export" (or your preferred name)
       • Supported account types: "Accounts in this organizational directory only (Single tenant)"
       • Redirect URI: Leave blank (not needed for client credentials flow)
       • Click "Register"
       
       📖 Detailed Instructions:
       https://learn.microsoft.com/entra/identity-platform/quickstart-register-app
    
    2. Configure API Permissions (Application Permissions - NOT Delegated)
       Required for Copilot interaction retrieval:
       • API: Microsoft Graph
       • Permission: AiEnterpriseInteraction.Read.All (Application)
       • Admin consent: REQUIRED (click "Grant admin consent for [tenant]")
       
       Required when using -IncludeUserInfo parameter:
       • API: Microsoft Graph
       • Permission: User.Read.All (Application)
       • Admin consent: REQUIRED
       
       📖 How to Add API Permissions:
       https://learn.microsoft.com/entra/identity-platform/quickstart-configure-app-access-web-apis#application-permission-to-microsoft-graph
    
    3. Create Client Secret
       • Go to "Certificates & secrets" > "Client secrets" > "New client secret"
       • Description: "PAX Script Access" (or your preferred name)
       • Expires: Choose expiration period (6 months, 12 months, or 24 months recommended)
       • Click "Add"
       • ⚠️ CRITICAL: Copy the secret VALUE immediately - it won't be shown again
       
       📖 Creating Client Secrets:
       https://learn.microsoft.com/entra/identity-platform/quickstart-register-app#add-a-client-secret
    
    4. Collect Required Values
       After setup, you'll need these three values to run the script:
       • Tenant ID: Found on App registration "Overview" page (Directory/tenant ID)
       • Client ID: Found on App registration "Overview" page (Application/client ID)
       • Client Secret: The VALUE you copied in step 3 (not the Secret ID)
       
       Usage with script:
       .\script.ps1 -TenantId your-tenant-id-guid -ClientId your-client-id-guid
       
       Alternatively, set environment variables (recommended for security):
       $env:GRAPH_TENANT_ID = "your-tenant-id"
       $env:GRAPH_CLIENT_ID = "your-client-id"
       $env:GRAPH_CLIENT_SECRET = "your-client-secret-value"
       Then run: .\script.ps1
    
    SECURITY BEST PRACTICES:
    • Use Azure Key Vault for production environments to store client secrets
    • Rotate client secrets regularly (before expiration)
    • Grant only the minimum required permissions (principle of least privilege)
    • Use separate app registrations for dev/test/prod environments
    • Monitor app registration sign-in logs for unusual activity
    • Document the app registration purpose and owner for your organization
    
    PERMISSION DETAILS:
    • AiEnterpriseInteraction.Read.All: Grants access to read Copilot interaction history
      for all users in the tenant (audit/compliance scenarios)
    • User.Read.All: Grants access to read basic user profile information from Entra ID
      (required only when using -IncludeUserInfo parameter)
    
    Both permissions require Application type (app-only access) and tenant admin consent.

.PARAMETER UserPrincipalNames
    Array of user UPNs to search. If not provided, searches all licensed users.
    Example: @("user1@contoso.com", "user2@contoso.com")

.PARAMETER UserListFile
    Path to a text file containing one UPN per line.

.PARAMETER StartDate
    Start date for content search. Defaults to 180 days ago.
    Applied client-side when server-side createdDateTime filter not supported.

.PARAMETER EndDate
    End date for content search (INCLUSIVE). Defaults to current date.
    Both StartDate and EndDate are included in the search.
    Applied client-side when server-side createdDateTime filter not supported.
    Example: -StartDate 2025-10-31 -EndDate 2025-11-04 searches Oct 31 through Nov 4 (includes both dates).

.PARAMETER DaysBack
    Number of days to look back from EndDate when StartDate is not specified.
    Default: 180 days
    Valid range: 1-3650 (1 day to 10 years)
    
    Examples:
      • No dates provided: searches last 180 days (DaysBack from today)
      • -EndDate 2025-06-30: searches 180 days back from June 30
      • -EndDate 2025-06-30 -DaysBack 90: searches 90 days back from June 30
      • -StartDate 2025-01-01: searches from Jan 1 to today (DaysBack ignored)

.PARAMETER CopilotApps
    Filter by specific Copilot applications. Valid values:
    All (default), BizChat, Teams, Outlook, Word, Excel, PowerPoint, OneNote, Loop, SharePoint, Whiteboard, Planner, Designer, Forms, Stream
    
    Parameter values are case-insensitive ("Teams", "teams", and "TEAMS" all work).
    
    Use comma-separated values for multiple apps (no @ sign needed):
    -CopilotApps Teams
    -CopilotApps Word,Excel,PowerPoint

.PARAMETER OutputPath
    Directory path where all output files will be created with auto-generated timestamped filenames.
    Default: C:\Temp\
    
    The script automatically generates descriptive filenames based on:
      • Export mode (CSV vs Excel)
      • Current timestamp (yyyyMMdd_HHmmss format)
    
    Examples of auto-generated filenames:
      • CopilotInteractions_Content_20251117_143022.csv
      • CopilotInteractions_Content_20251117_143022.log
      • CopilotInteractions_Content_20251117_143022.xlsx (with -ExportWorkbook)
      • CopilotInteractions_StatsByUser_20251117_143022.csv (with -IncludeStats)
      • CopilotInteractions_StatsByApp_20251117_143022.csv (with -IncludeStats)
      • CopilotInteractions_StatsByDate_20251117_143022.csv (with -IncludeStats)
    
    Note: OutputPath accepts ONLY directory paths, not filenames.

.PARAMETER IncludeBody
    Include body content (prompts/responses) in the output.
    Default: Not included (metadata only)
    Specify this switch to include prompts and responses in output.
    
    PROMPT & RESPONSE CONTENT:
    By default, the script exports metadata only (timestamps, users, apps, sessions).
    Use -IncludeBody to extract full conversation text:
    
    • Prompt Body: Complete question/request text sent to Copilot
    • Response Body: Full response text returned by Copilot
    • Schema Impact: Adds PromptBody and ResponseBody columns to output
    • Use Cases: Content analysis, compliance review, quality assessment
    • Length Control: Use -MaxBodyLength to limit text size (default 10000 characters)
    
    Example: -IncludeBody -MaxBodyLength 5000

.PARAMETER MaxBodyLength
    Maximum character length for body content before truncation.
    Default: 10000 characters
    Set to 0 to disable truncation (include full content regardless of length).
    Only applies when IncludeBody is $true.

.PARAMETER TenantId
    Azure AD Tenant ID (required for app-only authentication with client credentials).
    Format: GUID (e.g., 12345678-1234-1234-1234-123456789012)

.PARAMETER ClientId
    Azure AD App Registration Client ID (required for app-only authentication).
    Format: GUID (e.g., 12345678-1234-1234-1234-123456789012)

.PARAMETER ClientSecret
    Azure AD App Registration Client Secret value (required for app-only authentication).
    
    Can be provided via:
    • Command-line parameters: -TenantId, -ClientId, -ClientSecret (less secure, visible in history)
    • Environment variables (RECOMMENDED for security):
      $env:GRAPH_TENANT_ID = "your-tenant-id"
      $env:GRAPH_CLIENT_ID = "your-client-id"
      $env:GRAPH_CLIENT_SECRET = "your-secret-value"

    How to use environment variables:
    1. Open PowerShell
    2. Set all three variables:
       $env:GRAPH_TENANT_ID = "your-tenant-id-here"
       $env:GRAPH_CLIENT_ID = "your-client-id-here"
       $env:GRAPH_CLIENT_SECRET = "your-actual-secret-here"
    3. Run the script: .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1
    4. (Optional) Clear them: $env:GRAPH_TENANT_ID = $null; $env:GRAPH_CLIENT_ID = $null; $env:GRAPH_CLIENT_SECRET = $null
    
    Environment variables are session-only (disappear when you close PowerShell).
    This prevents credentials from being saved in command history or on disk.
    
    Parameters override environment variables if both are provided.
    If authentication values are not provided via either method, script will exit with error.

.PARAMETER ParallelBatchThrottle
    Maximum concurrent $batch API requests to process in parallel.
    Default: 25 concurrent batches (each batch contains up to 20 user requests).
    
    • Higher values = faster completion but more API load
    • Lower values = more conservative API usage
    • Each batch processes 20 users, so 25 batches = 500 users in flight
    • Only applies when -ParallelMode is 'On' or 'Auto' (with PowerShell 7+)

.PARAMETER ParallelMode
    Controls parallel processing mode for batch API requests.
    
    Options:
    • Auto (default): Automatically enable parallel if PowerShell 7+ detected, fall back to sequential on PS 5.1
    • On: Force parallel processing (requires PowerShell 7+, exits if PS 5.1 detected)
    • Off: Sequential processing (one batch at a time, useful for debugging)
    
    Benefits of Parallel Mode:
    • Processes multiple user batches (20 users per batch) concurrently
    • Dramatically faster for large user sets (50,000 users: minutes vs hours)
    • Automatic retry logic with 429 throttling handling
    
    Default: Auto (automatically uses parallel processing when available)

.PARAMETER UseWatermark
    Enable watermark pattern for incremental processing.
    Stores last seen createdDateTime per user in JSON file.
    
    Benefits:
      • First run: Retrieves all historical interactions, saves watermarks
      • Subsequent runs: Only retrieves new interactions since last watermark
      • Early-exit pagination: Stops when reaching watermark timestamp
      • Massive time savings for large user sets on incremental runs
    
    Optional: Use -WatermarkFile parameter to specify custom JSON file path (defaults to copilot-watermarks.json).

.PARAMETER WatermarkFile
    Optional path to JSON file for storing/loading watermarks (used with -UseWatermark).
    Default: .\copilot-watermarks.json (in current directory if not specified)
    
    File structure: JSON object with user UPNs as keys, ISO 8601 timestamps as values.
    The script creates this file automatically on first run.
    Atomic writes with validation prevent corruption.
    Can be moved to any location and referenced in subsequent runs.

.PARAMETER ExportWorkbook
    Export results to Excel workbook (.xlsx) instead of CSV. Requires ImportExcel module.
    When specified with -IncludeStats, creates multi-tab workbook with data and statistics.
    Default: CSV export.

.PARAMETER IncludeUserInfo
    Enrich output with Entra ID user attributes (35 core properties + 5 manager properties).
    Requires additional Graph API calls. Default: $false
    
    Output:
      • CSV mode: Creates separate EntraUsers_MAClicensing_*.csv file
      • Excel mode (-ExportWorkbook): Adds EntraUsers_MAClicensing tab to workbook

.PARAMETER AppendFile
    Append interaction data to an existing output file instead of creating a new timestamped file.
    Accepts either a filename (combined with -OutputPath) or a full path to the existing file.
    
    Requirements:
      • File must already exist (create it first without -AppendFile)
      • File extension must match export mode (.csv without -ExportWorkbook, .xlsx with -ExportWorkbook)
      • Cannot be used with -IncludeUserInfo (EntraUsers data is never appended)
    
    CSV Mode Behavior:
      • Validates headers match exactly (case-sensitive column names)
      • If headers match: Appends rows to existing CSV file
      • If headers mismatch: Creates new timestamped CSV file (preserves original data)
    
    Excel Mode Behavior:
      • Requires -ExportWorkbook parameter
      • Validates headers match for each tab
      • If headers match: Appends new rows to existing tabs
      • If headers mismatch: Creates timestamped duplicate tabs (preserves both datasets)
      • EntraUsers tab always replaced (never appended - point-in-time snapshot)
    
    EntraUsers Export Restriction:
      • Cannot use -AppendFile with -IncludeUserInfo
      • EntraUsers data represents a point-in-time snapshot, not time-based content
      • Each export should create a fresh EntraUsers dataset

.PARAMETER Help
    Display this help documentation and exit. Equivalent to Get-Help <script> -Full.
    Example: .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -Help

.PARAMETER IncludeStats
    Include statistics aggregations in the output (default: OFF for cleaner output).
    
    Statistics Generated (when enabled):
      • By User: TotalMessages, Prompts, Responses, TotalCharactersPrompts, TotalCharactersResponses, AvgCharactersPerPrompt, AvgCharactersPerResponse
      • By App: TotalMessages, Prompts, Responses, UniqueUsers per Copilot application
      • By Date: TotalMessages, Prompts, Responses, UniqueUsers per day
    
    Output Formats:
      • Console: Summary statistics displayed during execution
      • CSV (default): Creates 3 separate CSV files with stats
      • Excel (-ExportWorkbook): Creates 3 additional tabs in workbook
    
    Default: Stats are NOT included (only raw interaction data exported)

.PARAMETER EmitMetricsJson
    Export script execution metrics as JSON file for performance tracking and diagnostics.
    
    Includes:
      • Script execution metadata (version, start/end times, elapsed time)
      • Parameters used (date range, apps, watermark status)
      • Results summary (total users, success/error counts, total interactions, unique users/sessions)
      • Output file path
    
    Uses -MetricsPath if specified, otherwise auto-generates: metrics_*.json
    Example: metrics_20251117_143055.json

.PARAMETER MetricsPath
    Custom path for metrics JSON file (requires -EmitMetricsJson to take effect).
    Accepts full path or just filename (combines with -OutputPath if relative).
    Auto-appends .json extension if not present.
    
    Example: -EmitMetricsJson -MetricsPath C:\Reports\metrics.json

.PARAMETER OnlyUserInfo
    Export ONLY Entra ID user directory (skips all Copilot interaction retrieval).
    Fast execution (less than a minute) for obtaining user snapshots without interaction data.
    
    Incompatible Parameters (will error if combined):
      • Content filtering: -StartDate, -EndDate, -DaysBack, -UserPrincipalNames, -UserListFile, -CopilotApps
      • Processing: -IncludeBody, -MaxBodyLength, -ParallelBatchThrottle
      • Watermark: -UseWatermark, -WatermarkFile
      • Output: -IncludeStats
    
    Compatible Parameters (work with -OnlyUserInfo):
      • -OutputPath: Where to save the file
      • -ExportWorkbook: Export to Excel format
      • -EmitMetricsJson / -MetricsPath: Track Entra retrieval metrics
      • -TenantId / -ClientId / -ClientSecret: App registration authentication
    
    Output:
      • CSV mode: Creates EntraUsers_MAClicensing_*.csv file (no interaction data)
      • Excel mode (-ExportWorkbook): Creates .xlsx workbook with single EntraUsers_MAClicensing tab (no interaction data)

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -UserPrincipalNames user@contoso.com
    
    Extract Copilot interactions for a single user with default settings.

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -StartDate 2025-10-01 -EndDate 2025-10-31 -CopilotApps Teams,BizChat
    
    Extract October 2025 Copilot interactions from Teams and Business Chat for all users.
    Note: Use comma-separated values for multiple apps (no @ sign needed).
    EndDate is inclusive, so Oct 31 includes all content through the end of that day.

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -UserListFile .\users.txt
    
    Extract interactions for all users listed in the text file (one UPN per line).

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -DaysBack 90
    
    Extract last 90 days of interactions (instead of default 180 days) for all licensed users.

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -EndDate 2025-06-30 -DaysBack 90
    
    Extract 90 days of interactions ending June 30, 2025 (March 2 - June 30).
    StartDate automatically calculated as EndDate minus DaysBack.

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -UseWatermark -WatermarkFile .\copilot-watermarks.json
    
    Use watermark pattern for incremental processing. Stores last seen createdDateTime per user.
    First run: Retrieves all historical interactions and saves watermarks.
    Subsequent runs: Only retrieves new interactions since last watermark (massive time savings).

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -UserPrincipalNames user@contoso.com -ExportWorkbook -IncludeUserInfo
    
    Extract interactions with Excel export and Entra ID user enrichment.

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -ParallelBatchThrottle 25
    
    Enable parallel JSON batching for all licensed users. Processes 25 concurrent batches (20 users per batch).
    Each batch = 1 HTTP request to Graph API (JSON batching reduces network overhead).
    Ideal for Fortune 50 deployments with 50,000+ users.

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -UserListFile .\50000_users.txt -UseWatermark -StartDate 2025-01-01 -EndDate 2025-12-31
    
    Process 50,000 users over 1 year with parallel batching and watermark pattern.
    First run: ~4-5 minutes (retrieves all 2025 data, saves watermarks).
    Incremental runs: Seconds to minutes (only new data since last run).

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -UserPrincipalNames user@contoso.com -IncludeStats
    
    Extract interactions with optional statistics tabs/files. 
    CSV output includes:
      • CopilotInteractions_Content_*.csv (main data with timestamp)
      • CopilotInteractions_StatsByUser_*.csv (with timestamp)
      • CopilotInteractions_StatsByApp_*.csv (with timestamp)
      • CopilotInteractions_StatsByDate_*.csv (with timestamp)
    
    Excel output includes tabs (no timestamps unless append mismatch):
      • CopilotInteractions_Content
      • StatsByUser
      • StatsByApp
      • StatsByDate

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -OutputPath "C:\Reports\" -AppendFile "MasterData.csv"
    
    Append new interactions to existing CSV file using filename with OutputPath.
    File path resolved: C:\Reports\MasterData.csv
    Requirements: File must exist and headers must match exactly.

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -AppendFile "D:\Archives\2025\CopilotData.xlsx" -ExportWorkbook
    
    Append to existing Excel workbook using full path (OutputPath ignored).
    File path: D:\Archives\2025\CopilotData.xlsx
    Headers must match or new timestamped tabs are created.

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -OnlyUserInfo -ExportWorkbook
    
    Fast export of Entra ID user directory only (skips interaction retrieval).
    Output: EntraUsers_MAClicensing_*.xlsx with user and manager properties.
    Execution time: Less than a minute (vs minutes for full interaction retrieval).

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -Help
    
    Display complete help documentation and exit.

.EXAMPLE
    .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -EmitMetricsJson -MetricsPath C:\Reports\copilot_metrics.json
    
    Export execution metrics to custom path for performance tracking.
    Metrics include: execution time, interaction counts, API call stats, error rates.

.NOTES
    ARCHITECTURE:
    Direct API access to Copilot interaction history via Microsoft Graph.
    No mailbox searches or complex export workflows required.
    
    GRAPH API ENDPOINT:
    • /v1.0/copilot/users/{upn}/interactionHistory/getAllEnterpriseInteractions
    • Pagination: Automatic via @odata.nextLink
    • Batch size: 20 requests per JSON batch (Microsoft Graph limit)
    • Parallel execution: Configurable concurrent batches (default: 25)
    • Throttling: 30 requests/second per app per tenant (1,800/minute)
    
    FILTERING CAPABILITIES:
    • appClass filter: Supported server-side (documented feature)
    • createdDateTime filter: Tenant variance (may return 400 in some tenants)
    • Client-side filtering: Applied for dates and appClass when server-side fails
    • Watermark pattern: Stores last seen timestamp per user for incremental processing
    
    REQUIRED PERMISSIONS (Application Type with Admin Consent):
    • AiEnterpriseInteraction.Read.All - Read Copilot interaction history for all users
    • User.Read.All - Read user directory and license information
    • Organization.Read.All - Read organization and related resources
    
    All three permissions are required for every script execution.
    
    AUTHENTICATION:
    • App-only authentication using client credentials flow (OAuth 2.0)
    • Requires: TenantId, ClientId, and ClientSecret (via parameters or environment variables)
    • Environment variables (recommended): $env:GRAPH_TENANT_ID, $env:GRAPH_CLIENT_ID, $env:GRAPH_CLIENT_SECRET
    • Parameters: -TenantId, -ClientId, -ClientSecret (parameters override environment variables)
    • No interactive/delegated authentication - runs unattended with app registration
    
    WATERMARK PATTERN:
    • Stores last seen createdDateTime per user in JSON file
    • First run: Retrieves all historical interactions, saves watermarks
    • Incremental runs: Only retrieves new interactions since last watermark
    • Early-exit pagination: Stops when reaching watermark timestamp (massive time savings)
    • Atomic writes with validation to prevent corruption
    
    MODULE DEPENDENCIES (Auto-Installed):
    - Microsoft.Graph.Authentication (always required) - Auto-installs if not present
    - ImportExcel (required for -ExportWorkbook) - Auto-installs if not present
    
    ENTRA ENRICHMENT (-IncludeUserInfo):
    - Adds Entra user attributes including identity, job details, location, organizational info, and manager data
    - User data cached per user to minimize API calls
    
    RETENTION:
    - Content subject to Microsoft 365 retention policies
    - Historical data available based on tenant configuration
    
    DATA JOINING:
    - Use composite key: UserId + SessionId + RequestId + CreatedDateTime
    - SessionId = conversation identifier
    - RequestId = individual interaction identifier
#>

[CmdletBinding(DefaultParameterSetName='Default')]
param(
    [Parameter(Mandatory=$false)]
    [string[]]$UserPrincipalNames,
    
    [Parameter(Mandatory=$false)]
    [string]$UserListFile,
    
    [Parameter(Mandatory=$false)]
    [DateTime]$StartDate,
    
    [Parameter(Mandatory=$false)]
    [DateTime]$EndDate,
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 3650)]
    [int]$DaysBack = 180,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('All', 'Word', 'Excel', 'PowerPoint', 'Outlook', 'Teams', 'BizChat', 'OneNote', 'Loop', 'Whiteboard', 'Forms', 'Planner', 'SharePoint', 'Stream')]
    [string[]]$CopilotApps = @('All'),
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\Temp",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeBody,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxBodyLength = 10000,
    
    [Parameter(Mandatory=$false, HelpMessage="Enter your Azure AD Tenant ID (GUID format) or set environment variable GRAPH_TENANT_ID")]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false, HelpMessage="Enter your Azure AD App Registration Client ID (GUID format) or set environment variable GRAPH_CLIENT_ID")]
    [string]$ClientId,
    
    [Parameter(Mandatory=$false, HelpMessage="Enter your Azure AD App Registration Client Secret value or set environment variable GRAPH_CLIENT_SECRET")]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 25)]
    [int]$ParallelBatchThrottle = 25,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Auto', 'On', 'Off')]
    [string]$ParallelMode = 'Auto',
    
    [Parameter(Mandatory=$false)]
    [switch]$UseWatermark,
    
    [Parameter(Mandatory=$false)]
    [string]$WatermarkFile = "C:\Temp\copilot-watermarks.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportWorkbook,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeUserInfo,
    
    [Parameter(Mandatory=$false)]
    [string]$AppendFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeStats,
    
    [Parameter(Mandatory=$false)]
    [switch]$Help,
    
    [Parameter(Mandatory=$false)]
    [switch]$EmitMetricsJson,
    
    [Parameter(Mandatory=$false)]
    [string]$MetricsPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$OnlyUserInfo
)

#Requires -Version 5.1

# Normalize parameter values for case-insensitive input
# CopilotApps: Normalize to proper casing
$validApps = @('All', 'Word', 'Excel', 'PowerPoint', 'Outlook', 'Teams', 'BizChat', 'OneNote', 'Loop', 'Whiteboard', 'Forms', 'Planner', 'SharePoint', 'Stream')
$CopilotApps = $CopilotApps | ForEach-Object {
    $inputApp = $_
    $matchedApp = $validApps | Where-Object { $_ -eq $inputApp } | Select-Object -First 1
    if ($matchedApp) {
        $matchedApp
    } else {
        Write-Warning "Invalid CopilotApp value: '$inputApp'. Skipping."
        $null
    }
} | Where-Object { $_ -ne $null }

if ($CopilotApps.Count -eq 0) {
    $CopilotApps = @('All')
}

# ParallelMode: Normalize to proper casing
$validModes = @('Auto', 'On', 'Off')
$ParallelMode = $validModes | Where-Object { $_ -eq $ParallelMode } | Select-Object -First 1
if (-not $ParallelMode) {
    $ParallelMode = 'Auto'
}

# Optional global logging suppression for test scenarios
if ($env:PAX_SUPPRESS_LOG -eq '1') {
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        # Override existing Write-Log implementation with a no-op to minimize test output
        Set-Item -Path Function:Write-Log -Value { param([string]$Message,[string]$Level='Info') }
    } else {
        function Write-Log { param([string]$Message,[string]$Level='Info') }
    }
    # Also silence Write-Host calls commonly used for progress
    Set-Item -Path Function:Write-Host -Value { param($Object) }
}

# Script version and metadata
$ScriptVersion = "1.0.0"
$ScriptName = "PAX CopilotInteractions Content Audit Log Processor"
$ScriptStartTime = Get-Date
$ScriptTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

# Known Microsoft 365 Copilot SKU IDs for license detection
$script:CopilotSkuIds = @{
    'c815c93d-0759-4bb8-b857-bc921a71be83' = 'Microsoft 365 Copilot'
    '06ebc4ee-1bb5-47dd-8120-11324bc54e06' = 'Microsoft 365 Copilot'
    'a1c5e422-7c00-4433-a276-0f5b5f02e952' = 'Copilot Pro'
    '4a51bca5-1eff-43f5-878c-177680f191af' = 'Microsoft Copilot for Microsoft 365'
    'f841e8a7-8d86-4eae-af8c-d14b2a4c7228' = 'Microsoft 365 Copilot'
    'd814ea5e-2d90-455a-8b9e-2e5e4f3e8e8d' = 'Microsoft Copilot for M365'
    '440eaaa8-b3e0-484b-a8be-62870b9ba70a' = 'Microsoft 365 Copilot'
    'ad9c22b3-52d7-4e7e-973c-88121ea96436' = 'Microsoft 365 Copilot (Education Faculty)'
    '15f2e9fc-b782-4f73-bf51-81d8b7fff6f4' = 'Microsoft Copilot for Sales'
    '639dec6b-bb19-468b-871c-c5c441c4b0cb' = 'Copilot for Microsoft 365'
}

if ($Help) {
    Get-Help $PSCommandPath -Full
    exit 0
}

# Check for TenantId (parameter or environment variable)
if ([string]::IsNullOrWhiteSpace($TenantId)) {
    # Try to get from environment variable
    $TenantId = $env:GRAPH_TENANT_ID
    
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  $ScriptName v$ScriptVersion" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "ERROR: Missing required parameter -TenantId" -ForegroundColor Red
        Write-Host ""
        Write-Host "The -TenantId parameter is required for app-only authentication." -ForegroundColor Yellow
        Write-Host "Provide your Azure AD Tenant ID value." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "RECOMMENDED: Use environment variable for better security." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "How to set environment variable:" -ForegroundColor White
        Write-Host "  1. Open PowerShell" -ForegroundColor White
        Write-Host "  2. Set the variable: `$env:GRAPH_TENANT_ID = 'your-tenant-id-here'" -ForegroundColor White
        Write-Host "  3. Run the script: .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1" -ForegroundColor White
        Write-Host "  4. (Optional) Clear it: `$env:GRAPH_TENANT_ID = `$null" -ForegroundColor White
        Write-Host ""
        Write-Host "The environment variable is session-only (disappears when you close PowerShell)." -ForegroundColor Gray
        Write-Host "This prevents your tenant ID from being saved in command history." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Alternative (less secure): Use command-line parameter:" -ForegroundColor White
        Write-Host "  .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -TenantId your-tenant-id -ClientId ... -ClientSecret ..." -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

# Check for ClientId (parameter or environment variable)
if ([string]::IsNullOrWhiteSpace($ClientId)) {
    # Try to get from environment variable
    $ClientId = $env:GRAPH_CLIENT_ID
    
    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  $ScriptName v$ScriptVersion" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "ERROR: Missing required parameter -ClientId" -ForegroundColor Red
        Write-Host ""
        Write-Host "The -ClientId parameter is required for app-only authentication." -ForegroundColor Yellow
        Write-Host "Provide your Azure AD App Registration Client ID value." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "RECOMMENDED: Use environment variable for better security." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "How to set environment variable:" -ForegroundColor White
        Write-Host "  1. Open PowerShell" -ForegroundColor White
        Write-Host "  2. Set the variable: `$env:GRAPH_CLIENT_ID = 'your-client-id-here'" -ForegroundColor White
        Write-Host "  3. Run the script: .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1" -ForegroundColor White
        Write-Host "  4. (Optional) Clear it: `$env:GRAPH_CLIENT_ID = `$null" -ForegroundColor White
        Write-Host ""
        Write-Host "The environment variable is session-only (disappears when you close PowerShell)." -ForegroundColor Gray
        Write-Host "This prevents your client ID from being saved in command history." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Alternative (less secure): Use command-line parameter:" -ForegroundColor White
        Write-Host "  .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -TenantId ... -ClientId your-client-id -ClientSecret ..." -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

# Check for ClientSecret (parameter or environment variable)
$ClientSecretSource = "command-line parameter"
if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
    # Try to get from environment variable
    $ClientSecret = $env:GRAPH_CLIENT_SECRET
    $ClientSecretSource = "environment variable"
    
    if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  $ScriptName v$ScriptVersion" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "ERROR: Missing required parameter -ClientSecret" -ForegroundColor Red
        Write-Host ""
        Write-Host "The -ClientSecret parameter is required for app-only authentication." -ForegroundColor Yellow
        Write-Host "Provide your Azure AD App Registration Client Secret value." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "RECOMMENDED: Use environment variable for better security." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "How to set environment variable:" -ForegroundColor White
        Write-Host "  1. Open PowerShell" -ForegroundColor White
        Write-Host "  2. Set the variable: `$env:GRAPH_CLIENT_SECRET = 'your-actual-secret-here'" -ForegroundColor White
        Write-Host "  3. Run the script: .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1" -ForegroundColor White
        Write-Host "  4. (Optional) Clear it: `$env:GRAPH_CLIENT_SECRET = `$null" -ForegroundColor White
        Write-Host ""
        Write-Host "The environment variable is session-only (disappears when you close PowerShell)." -ForegroundColor Gray
        Write-Host "This prevents your secret from being saved in command history." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Alternative (less secure): Use command-line parameter:" -ForegroundColor White
        Write-Host "  .\PAX_CopilotInteractions_Content_Audit_Log_Processor.ps1 -TenantId ... -ClientId ... -ClientSecret your-secret" -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

if ($OnlyUserInfo) {
    $incompatibleParams = @()
    
    if ($PSBoundParameters.ContainsKey('StartDate')) { $incompatibleParams += "  - StartDate (not applicable for user-only export)" }
    if ($PSBoundParameters.ContainsKey('EndDate')) { $incompatibleParams += "  - EndDate (not applicable for user-only export)" }
    
    if ($PSBoundParameters.ContainsKey('UserPrincipalNames')) { $incompatibleParams += "  - UserPrincipalNames (user-only mode fetches all users)" }
    if ($PSBoundParameters.ContainsKey('UserListFile')) { $incompatibleParams += "  - UserListFile (user-only mode fetches all users)" }
    
    # Copilot app filtering
    if ($PSBoundParameters.ContainsKey('CopilotApps') -and ($CopilotApps -ne @('All'))) { $incompatibleParams += "  - CopilotApps (not applicable for user-only export)" }
    
    # Content parameters
    if ($PSBoundParameters.ContainsKey('IncludeBody')) { $incompatibleParams += "  - IncludeBody (no content data in user-only mode)" }
    if ($PSBoundParameters.ContainsKey('MaxBodyLength')) { $incompatibleParams += "  - MaxBodyLength (no content data in user-only mode)" }
    
    # Processing parameters
    if ($PSBoundParameters.ContainsKey('ParallelBatchThrottle') -and $ParallelBatchThrottle -ne 25) { $incompatibleParams += "  - ParallelBatchThrottle (API batching setting)" }
    if ($PSBoundParameters.ContainsKey('UseWatermark')) { $incompatibleParams += "  - UseWatermark (watermark pattern for incremental interaction retrieval)" }
    if ($PSBoundParameters.ContainsKey('WatermarkFile')) { $incompatibleParams += "  - WatermarkFile (watermark storage for incremental interaction retrieval)" }
    
    # Output combination parameters
    if ($IncludeStats) { $incompatibleParams += "  - IncludeStats (no interaction data to generate stats from)" }
    
    if ($incompatibleParams.Count -gt 0) {
        Write-Host ""
        Write-Host "ERROR: The -OnlyUserInfo switch cannot be used with the following parameters:" -ForegroundColor Red
        Write-Host ""
        $incompatibleParams | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
        Write-Host ""
        Write-Host "The -OnlyUserInfo switch exports only Entra user directory and license information (no interaction content)." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Compatible parameters:" -ForegroundColor Green
        Write-Host "  - OutputPath (where to save the file)" -ForegroundColor White
        Write-Host "  - ExportWorkbook (export to Excel format)" -ForegroundColor White
        Write-Host "  - EmitMetricsJson (track Entra retrieval metrics)" -ForegroundColor White
        Write-Host "  - MetricsPath (custom metrics output location)" -ForegroundColor White
        Write-Host "  - TenantId / ClientId / ClientSecret (app registration authentication)" -ForegroundColor White
        Write-Host ""
        Write-Host "Please remove the incompatible parameters and try again." -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }
    
    # If validation passes, configure for user-only export
    Write-Host ""
    Write-Host "INFO: -OnlyUserInfo mode enabled. Exporting only Entra user data (no interaction content)." -ForegroundColor Green
    Write-Host ""
    
    $IncludeUserInfo = $true
}

# Display script banner
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  $ScriptName v$ScriptVersion" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Custom error formatting for cleaner messages
$PSDefaultParameterValues['Write-Error:ErrorAction'] = 'Continue'
trap {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  ERROR: $ScriptName v$ScriptVersion" -ForegroundColor Red
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Yellow
    if ($_.InvocationInfo.Line) {
        Write-Host "Line:    $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "For help, run: Get-Help '$PSCommandPath' -Full" -ForegroundColor Cyan
    Write-Host ""
    break
}

# Initialize counters
$Global:Stats = @{
    UsersProcessed = 0
    UsersWithContent = 0
    TotalMessages = 0
    PromptsFound = 0
    ResponsesFound = 0
    Errors = 0
    APICallsMade = 0
    NetworkRetries = 0
    StartTime = $ScriptStartTime
}

$Global:LogFile = $null

#region Helper Functions

function Get-MaskedUsername {
    <#
    .SYNOPSIS
        Masks a username or email address for secure display in logs and screenshots.
    
    .DESCRIPTION
        Converts "admin@contoso.com" to "a******n@contoso.com" to prevent accidental
        credential exposure in terminal output, screenshots, or log files.
        
        Preserves first and last character of local part, masks middle with 6 asterisks.
        Returns original string if input is null, empty, or doesn't contain "@".
    
    .PARAMETER Username
        The username or email address to mask
    
    .OUTPUTS
        Masked string (e.g., "a******n@contoso.com")
    
    .EXAMPLE
        Get-MaskedUsername -Username "admin@contoso.com"
        Returns: "a******n@contoso.com"
    #>
    
    param(
        [Parameter(Mandatory = $false)]
        [string]$Username
    )
    
    if ([string]::IsNullOrWhiteSpace($Username)) {
        return $Username
    }
    
    # Only mask if it looks like an email address
    if ($Username -notmatch '@') {
        return $Username
    }
    
    $parts = $Username -split '@'
    if ($parts.Count -ne 2) {
        return $Username
    }
    
    $localPart = $parts[0]
    $domain = $parts[1]
    
    # Handle very short usernames
    if ($localPart.Length -le 2) {
        return "$($localPart[0])******@$domain"
    }
    
    $first = $localPart[0]
    $last = $localPart[$localPart.Length - 1]
    $masked = "$first******$last@$domain"
    
    return $masked
}

function Write-Log {
    param(
        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [string]$Message = "",
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Header', 'Highlight', 'Metric', 'Processing')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'Info'       { 'DarkYellow' }
        'Warning'    { 'Yellow' }
        'Error'      { 'Red' }
        'Success'    { 'Green' }
        'Header'     { 'Cyan' }
        'Highlight'  { 'Magenta' }
        'Metric'     { 'DarkCyan' }
        'Processing' { 'DarkGray' }
    }
    
    # Allow blank lines for spacing
    if ([string]::IsNullOrWhiteSpace($Message)) {
        Write-Host ""
        if ($Global:LogFile) {
            "" | Out-File -FilePath $Global:LogFile -Append -Encoding utf8
        }
    } else {
        $consoleMessage = "[$timestamp] $Message"
        $logMessage = "[$timestamp] [$Level] $Message"
        Write-Host $consoleMessage -ForegroundColor $color
        
        # Write to log file with level for record-keeping
        if ($Global:LogFile) {
            $logMessage | Out-File -FilePath $Global:LogFile -Append -Encoding utf8
        }
    }
}

function Get-ItemClassPatterns {
    <#
    .SYNOPSIS
        Returns ItemClass patterns for filtering Copilot content by application.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Apps
    )
    
    $patterns = @{
        'Word'        = 'IPM.SkypeTeams.Message.Copilot.Word'
        'Excel'       = 'IPM.SkypeTeams.Message.Copilot.Excel'
        'PowerPoint'  = 'IPM.SkypeTeams.Message.Copilot.PowerPoint'
        'Outlook'     = 'IPM.SkypeTeams.Message.Copilot.Outlook'
        'Teams'       = 'IPM.SkypeTeams.Message.Copilot.Teams'
        'BizChat'     = 'IPM.SkypeTeams.Message.Copilot.BizChat'
        'OneNote'     = 'IPM.SkypeTeams.Message.Copilot.OneNote'
        'Loop'        = 'IPM.SkypeTeams.Message.Copilot.Loop'
        'Whiteboard'  = 'IPM.SkypeTeams.Message.Copilot.Whiteboard'
        'Forms'       = 'IPM.SkypeTeams.Message.Copilot.Forms'
        'Planner'     = 'IPM.SkypeTeams.Message.Copilot.Planner'
        'SharePoint'  = 'IPM.SkypeTeams.Message.Copilot.SharePoint'
        'Stream'      = 'IPM.SkypeTeams.Message.Copilot.Stream'
    }
    
    if ($Apps -contains 'All') {
        return @('IPM.SkypeTeams.Message.Copilot.*')
    }
    
    $selectedPatterns = @()
    foreach ($app in $Apps) {
        if ($patterns.ContainsKey($app)) {
            $selectedPatterns += $patterns[$app]
        }
    }
    
    return $selectedPatterns
}

function Get-SafeProperty {
    <#
    .SYNOPSIS
        Safely extracts a property value from an object, returning $null if not found.
    #>
    param(
        [Parameter(Mandatory=$false)]
        $Object,
        
        [Parameter(Mandatory=$true)]
        [string]$PropertyName,
        
        [Parameter(Mandatory=$false)]
        $DefaultValue = $null
    )
    
    if ($null -eq $Object) { return $DefaultValue }
    
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.ContainsKey($PropertyName)) {
            return $Object[$PropertyName]
        }
    } else {
        if ($Object.PSObject.Properties[$PropertyName]) {
            return $Object.$PropertyName
        }
    }
    
    return $DefaultValue
}

function Test-Is429 {
    <#
    .SYNOPSIS
        Safely detects 429 (Too Many Requests) throttling errors.
    .DESCRIPTION
        Provides null-safe detection of 429 throttling responses from Graph API.
        Three-layer fallback strategy:
        1. Check .Response.StatusCode (when Response object exists)
        2. Check .Exception.Response.StatusCode directly (PS7+ pattern)
        3. Parse error message for '429' string (final fallback)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.ErrorRecord]$Exception
    )
    
    # Layer 1: Check .Response.StatusCode (traditional method)
    if ($Exception.Exception.Response -and $Exception.Exception.Response.StatusCode) {
        if ($Exception.Exception.Response.StatusCode -eq 429 -or $Exception.Exception.Response.StatusCode -eq 'TooManyRequests') {
            return $true
        }
    }
    
    # Layer 2: Check .Exception.Response.StatusCode directly (PS7+)
    if ($Exception.Exception.Response.StatusCode) {
        if ($Exception.Exception.Response.StatusCode.value__ -eq 429) {
            return $true
        }
    }
    
    # Layer 3: Parse error message as final fallback
    $errorMessage = $Exception.Exception.Message
    if ($errorMessage -match '429' -or $errorMessage -match 'Too Many Requests' -or $errorMessage -match 'TooManyRequests') {
        return $true
    }
    
    return $false
}

function Test-AppendFileCompatibility {
    <#
    .SYNOPSIS
        Validates existing file before append to prevent data corruption.
    .DESCRIPTION
        Pre-validates file existence, readability, correct extension, and schema compatibility.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [bool]$IsExcel = $false
    )
    
    $result = @{
        Compatible = $true
        ExistingColumns = @()
        ExistingCount = 0
        ErrorMessage = $null
    }
    
    try {
        if (-not (Test-Path $FilePath)) {
            $result.ErrorMessage = "File does not exist: $FilePath"
            $result.Compatible = $false
            return $result
        }
        
        try {
            $null = Get-Content -Path $FilePath -First 1 -ErrorAction Stop
        } catch {
            $result.ErrorMessage = "File exists but is not readable (locked or permissions issue)"
            $result.Compatible = $false
            return $result
        }
        
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        if ($IsExcel -and $extension -ne '.xlsx') {
            $result.ErrorMessage = "Expected .xlsx file for Excel export, got $extension"
            $result.Compatible = $false
            return $result
        }
        if (-not $IsExcel -and $extension -ne '.csv') {
            $result.ErrorMessage = "Expected .csv file, got $extension"
            $result.Compatible = $false
            return $result
        }
        
        # Read existing columns
        if ($IsExcel) {
            if (-not (Get-Module -Name ImportExcel -ListAvailable)) {
                $result.ErrorMessage = "ImportExcel module not available for validation"
                $result.Compatible = $false
                return $result
            }
            
            Import-Module ImportExcel -ErrorAction Stop
            $headerData = Import-Excel -Path $FilePath -StartRow 1 -EndRow 1 -NoHeader -ErrorAction Stop
            $existingCols = $headerData[0].PSObject.Properties.Value | Where-Object { $_ }
        } else {
            $firstLine = Get-Content -Path $FilePath -First 1 -Encoding UTF8 -ErrorAction Stop
            $existingCols = ($firstLine -split ',') | ForEach-Object { $_.Trim('"') }
        }
        
        $result.ExistingColumns = $existingCols
        $result.ExistingCount = $existingCols.Count
        
        if ($result.ExistingCount -eq 0) {
            $result.ErrorMessage = "File has no header columns"
            $result.Compatible = $false
            return $result
        }
        
        $result.Compatible = $true
        
    } catch {
        $result.ErrorMessage = $_.Exception.Message
        $result.Compatible = $false
    }
    
    return $result
}

#region Core API Functions

function Test-FilterSupport {
    <#
    .SYNOPSIS
        Tests which $filter parameters are supported in the current tenant.
    
    .DESCRIPTION
        Tests appClass and createdDateTime filters to determine tenant support:
        - appClass filtering is documented and should work
        - createdDateTime filtering may return 400 in some tenants (tenant variance)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserIdOrUpn
    )
    
    $results = @{
        User = $UserIdOrUpn
        AppClassFilterSupported = $null
        DateFilterSupported = $null
        RecommendedApproach = $null
        Details = @()
    }
    
    $appClassFilter = "appClass eq 'IPM.SkypeTeams.Message.Copilot.Teams'"
    $fltEnc = [System.Web.HttpUtility]::UrlEncode($appClassFilter)
    $uri = "/v1.0/copilot/users/$UserIdOrUpn/interactionHistory/getAllEnterpriseInteractions?`$filter=$fltEnc&`$top=1"
    
    try {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType HttpResponseMessage -ErrorAction Stop
        $status = [int]$resp.StatusCode
        
        if ($status -eq 200) {
            $results.AppClassFilterSupported = $true
            $results.Details += "appClass filter SUPPORTED"
        }
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        
        if ($statusCode -eq 400) {
            $results.AppClassFilterSupported = $false
            $results.Details += "appClass filter NOT SUPPORTED (400)"
        }
        else {
            $results.AppClassFilterSupported = $null
            $results.Details += "appClass filter UNKNOWN (error: $statusCode)"
        }
    }
    
    $now = [DateTime]::UtcNow
    $past = $now.AddDays(-7)
    $dateFilter = "createdDateTime ge $($past.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    $fltEnc = [System.Web.HttpUtility]::UrlEncode($dateFilter)
    $uri = "/v1.0/copilot/users/$UserIdOrUpn/interactionHistory/getAllEnterpriseInteractions?`$filter=$fltEnc&`$top=1"
    
    try {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType HttpResponseMessage -ErrorAction Stop
        $status = [int]$resp.StatusCode
        
        if ($status -eq 200) {
            $results.DateFilterSupported = $true
            $results.Details += "createdDateTime filter SUPPORTED"
        }
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        
        if ($statusCode -eq 400) {
            $results.DateFilterSupported = $false
            $results.Details += "createdDateTime filter NOT SUPPORTED (400)"
        }
        else {
            $results.DateFilterSupported = $null
            $results.Details += "createdDateTime filter UNKNOWN (error: $statusCode)"
        }
    }
    
    if ($results.AppClassFilterSupported -eq $true) {
        $results.RecommendedApproach = "Use appClass filter server-side, apply date filtering client-side with watermark"
    }
    elseif ($results.DateFilterSupported -eq $true) {
        $results.RecommendedApproach = "Use createdDateTime filter server-side, apply appClass filtering client-side"
    }
    else {
        $results.RecommendedApproach = "No server-side filtering available - use watermark + client-side filtering"
    }
    
    return $results
}

function Initialize-WatermarkStore {
    <#
    .SYNOPSIS
        Loads or initializes watermark store from JSON file.
    
    .DESCRIPTION
        Loads existing watermark data or creates new empty store.
        Validates JSON structure and handles corruption gracefully.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$WatermarkFile
    )
    
    $store = @{}
    
    if (Test-Path $WatermarkFile) {
        try {
            $content = Get-Content $WatermarkFile -Raw -ErrorAction Stop
            $loaded = $content | ConvertFrom-Json -ErrorAction Stop
            
            # Validate structure: should be hashtable of user -> datetime strings
            if ($loaded -is [PSCustomObject]) {
                foreach ($prop in $loaded.PSObject.Properties) {
                    $user = $prop.Name
                    $timestamp = $prop.Value
                    
                    # Validate timestamp format
                    try {
                        $dt = [DateTime]::Parse($timestamp)
                        $store[$user] = $dt
                    }
                    catch {
                        Write-Log "Invalid timestamp for user $user in watermark file: $timestamp" -Level Warning
                    }
                }
                
                Write-Log "Loaded watermarks for $($store.Count) users from $WatermarkFile"
            }
            else {
                Write-Log "Watermark file has invalid structure, starting fresh" -Level Warning
            }
        }
        catch {
            Write-Log "Failed to load watermark file: $($_.Exception.Message). Starting fresh." -Level Warning
        }
    }
    else {
        Write-Log "No existing watermark file found. Starting fresh watermark store."
    }
    
    return $store
}

function Get-UserWatermark {
    <#
    .SYNOPSIS
        Retrieves watermark timestamp for a specific user.
    
    .DESCRIPTION
        Returns the last seen createdDateTime for the user, or $null if no watermark exists.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$WatermarkStore,
        
        [Parameter(Mandatory = $true)]
        [string]$UserUpn
    )
    
    if ($WatermarkStore.ContainsKey($UserUpn)) {
        return $WatermarkStore[$UserUpn]
    }
    
    return $null
}

function Update-UserWatermark {
    <#
    .SYNOPSIS
        Updates watermark timestamp for a specific user.
    
    .DESCRIPTION
        Stores the newest createdDateTime seen for this user.
        Only updates if new timestamp is newer than existing.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$WatermarkStore,
        
        [Parameter(Mandatory = $true)]
        [string]$UserUpn,
        
        [Parameter(Mandatory = $true)]
        [datetime]$NewTimestamp
    )
    
    $existing = Get-UserWatermark -WatermarkStore $WatermarkStore -UserUpn $UserUpn
    
    if (-not $existing -or $NewTimestamp -gt $existing) {
        $WatermarkStore[$UserUpn] = $NewTimestamp
        return $true
    }
    
    return $false
}

function Export-WatermarkStore {
    <#
    .SYNOPSIS
        Exports watermark store to JSON file with atomic write.
    
    .DESCRIPTION
        Saves watermark data with atomic write pattern:
        1. Write to temporary file
        2. Validate JSON integrity
        3. Create backup of existing file
        4. Replace existing file with new file
        
        This prevents corruption if write operation is interrupted.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$WatermarkStore,
        
        [Parameter(Mandatory = $true)]
        [string]$WatermarkFile
    )
    
    try {
        # Convert to JSON-friendly object
        $exportObj = @{}
        foreach ($user in $WatermarkStore.Keys) {
            $timestamp = $WatermarkStore[$user]
            if ($timestamp -is [DateTime]) {
                $exportObj[$user] = $timestamp.ToString('o')  # ISO 8601 format
            }
        }
        
        # Write to temporary file
        $tempFile = "$WatermarkFile.tmp"
        $json = $exportObj | ConvertTo-Json -Depth 10
        $json | Set-Content -Path $tempFile -Encoding UTF8 -ErrorAction Stop
        
        # Validate by reading back
        $validation = Get-Content $tempFile -Raw | ConvertFrom-Json -ErrorAction Stop
        if (-not $validation) {
            throw "Validation failed: temporary file is empty or invalid"
        }
        
        # Backup existing file if it exists
        if (Test-Path $WatermarkFile) {
            $backupFile = "$WatermarkFile.bak"
            Copy-Item $WatermarkFile $backupFile -Force -ErrorAction Stop
        }
        
        # Atomic replace: move temp file to actual file
        Move-Item $tempFile $WatermarkFile -Force -ErrorAction Stop
        
        return $true
    }
    catch {
        Write-Log "Failed to export watermark store: $($_.Exception.Message)" -Level Error
        
        # Clean up temp file if it exists
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
        
        return $false
    }
}

#endregion

function Invoke-GraphRequestWithRetry {
    <#
    .SYNOPSIS
        Executes Graph API request with exponential backoff retry logic.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        
        [Parameter(Mandatory=$false)]
        [string]$Method = 'GET',
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Body,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Headers,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxRetries = 5
    )
    
    $retryCount = 0
    $backoffSeconds = 1.0  # Hardcoded: Start with 1 second backoff
    $maxBackoffSeconds = 60  # Hardcoded: Maximum 60 seconds backoff
    
    while ($retryCount -le $MaxRetries) {
        try {
            $Global:Stats.APICallsMade++
            
            $params = @{
                Uri = $Uri
                Method = $Method
                ContentType = 'application/json'
            }
            
            if ($Body) {
                $params.Body = ($Body | ConvertTo-Json -Depth 10)
            }
            
            if ($Headers) {
                $params.Headers = $Headers
            }
            
            $response = Invoke-MgGraphRequest @params
            
            # Success
            return $response
            
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.Exception.Message
            
            # Handle authorization errors (401/403) - likely expired token
            if ($statusCode -eq 401 -or $statusCode -eq 403) {
                $retryCount++
                $Global:Stats.NetworkRetries++
                
                if ($retryCount -le 2) {
                    Write-Log "Authorization error (Status: $statusCode). Attempting to refresh token... Retry $retryCount/2" -Level Warning
                    
                    try {
                        Disconnect-MgGraph -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 2
                        
                        # Re-acquire token using client credentials
                        $tokenUrl = "https://login.microsoftonline.com/$script:TenantId/oauth2/v2.0/token"
                        $body = @{
                            client_id     = $script:ClientId
                            client_secret = $script:ClientSecret
                            scope         = "https://graph.microsoft.com/.default"
                            grant_type    = "client_credentials"
                        }
                        $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $body -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
                        $secureToken = ConvertTo-SecureString -String $tokenResponse.access_token -AsPlainText -Force
                        Connect-MgGraph -AccessToken $secureToken -NoWelcome -ErrorAction Stop
                        
                        Write-Log "Token refreshed successfully" -Level Success
                        continue
                    } catch {
                        Write-Log "Failed to refresh token: $($_.Exception.Message)" -Level Error
                        throw "Authorization failed - unable to refresh token"
                    }
                } else {
                    throw "Authorization failed after $retryCount attempts. Check permissions: AiEnterpriseInteraction.Read.All, User.Read.All"
                }
            }
            
            # Handle throttling (429) with exponential backoff using Test-Is429
            if (Test-Is429 -Exception $_) {
                $retryCount++
                $Global:Stats.NetworkRetries++
                
                if ($retryCount -le $MaxRetries) {
                    $retryAfter = $_.Exception.Response.Headers | Where-Object { $_.Key -eq 'Retry-After' } | Select-Object -ExpandProperty Value -First 1
                    $waitTime = if ($retryAfter) { [int]$retryAfter } else { $backoffSeconds }
                    
                    Write-Log "API rate limited (429). Waiting $waitTime seconds... Retry $retryCount/$MaxRetries" -Level Warning
                    Start-Sleep -Seconds $waitTime
                    $backoffSeconds = [Math]::Min($backoffSeconds * 2, $maxBackoffSeconds)
                    continue
                }
            }
            
            # Handle server errors (5xx) with exponential backoff
            if ($statusCode -ge 500 -and $statusCode -lt 600) {
                $retryCount++
                $Global:Stats.NetworkRetries++
                
                if ($retryCount -le $MaxRetries) {
                    Write-Log "Server error (Status: $statusCode). Retry $retryCount/$MaxRetries in $backoffSeconds seconds..." -Level Warning
                    Start-Sleep -Seconds $backoffSeconds
                    $backoffSeconds = [Math]::Min($backoffSeconds * 2, $maxBackoffSeconds)
                    continue
                }
            }
            
            # Non-retryable error or max retries exceeded
            $Global:Stats.Errors++
            Write-Log "API request failed: $errorMessage (Status: $statusCode)" -Level Error
            throw
        }
    }
    
    throw "Max retries exceeded for Graph API request: $Uri"
}

function ConvertTo-FlatEntraUsers {
    <#
    .SYNOPSIS
        Flattens Entra user objects into CSV-friendly format.
    
    .DESCRIPTION
        Converts Entra ID user objects with nested properties into flat tabular format.
        Filters out non-user accounts (rooms, resources) based on userType validation.
        Explodes arrays (proxyAddresses, manager) into individual columns.
        Includes MAC licensing data (assignedLicenses, hasLicense).
    
    .PARAMETER Users
        Array of user objects from Microsoft Graph API with manager expansion.
    
    .OUTPUTS
        Array of PSCustomObjects with flattened user properties and MAC licensing data.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Users
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
        
        # Organizational Properties
        $flatUser['employeeOrgData_division'] = if ($user.employeeOrgData) { $user.employeeOrgData.division } else { $null }
        $flatUser['employeeOrgData_costCenter'] = if ($user.employeeOrgData) { $user.employeeOrgData.costCenter } else { $null }
        
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
        
        # Handle manager object separately (flatten to individual columns)
        if ($user.manager) {
            $flatUser['manager_id'] = $user.manager.id
            $flatUser['manager_displayName'] = $user.manager.displayName
            $flatUser['manager_userPrincipalName'] = $user.manager.userPrincipalName
            $flatUser['manager_mail'] = $user.manager.mail
            $flatUser['manager_jobTitle'] = $user.manager.jobTitle
        }
        else {
            $flatUser['manager_id'] = $null
            $flatUser['manager_displayName'] = $null
            $flatUser['manager_userPrincipalName'] = $null
            $flatUser['manager_mail'] = $null
            $flatUser['manager_jobTitle'] = $null
        }
        
        # MAC Licensing Columns (assignedLicenses, hasLicense)
        # Two-tier Copilot license detection:
        # 1. Check known Copilot SKU IDs from $script:CopilotSkuIds
        # 2. Pattern match SKU names containing "Copilot" (catches new/promotional variants)
        if ($user.assignedLicenses -and $user.assignedLicenses.Count -gt 0) {
            $skuIds = $user.assignedLicenses | ForEach-Object { $_.skuId } | Where-Object { $_ }
            $flatUser['assignedLicenses'] = if ($skuIds) { ($skuIds -join '; ') } else { $null }
            
            # Check if user has Copilot license
            $hasCopilot = $false
            $copilotSkuIds = $script:CopilotSkuIds.Keys
            
            foreach ($license in $user.assignedLicenses) {
                $skuId = $license.skuId
                
                # Check known Copilot SKU IDs
                $isCopilotSku = $copilotSkuIds -contains $skuId
                
                # Pattern match for new Copilot SKUs not yet in the list
                $isCopilotName = $script:CopilotSkuIds.ContainsKey($skuId) -and ($script:CopilotSkuIds[$skuId] -like "*Copilot*")
                
                if ($isCopilotSku -or $isCopilotName) {
                    $hasCopilot = $true
                    break
                }
            }
            
            $flatUser['hasLicense'] = $hasCopilot
        }
        else {
            $flatUser['assignedLicenses'] = $null
            $flatUser['hasLicense'] = $false
        }
        
        # Convert ordered hashtable to PSCustomObject for proper CSV export
        $flattenedUsers += [PSCustomObject]$flatUser
    }
    
    return $flattenedUsers
}

function Get-EntraUsers {
    <#
    .SYNOPSIS
        Retrieves all Entra ID users.
    
    .DESCRIPTION
        Fetches all users from Entra ID with pagination support.
        Filters via ConvertTo-FlatEntraUsers (removes rooms/resources).
        Returns flattened user objects with MAC licensing columns.
    
    .OUTPUTS
        Array of flattened user objects with MAC licensing data
    #>
    
    try {
        Write-Log "Fetching Entra user directory..." -Level Header
        
        $entraUserSelect = @(
            'userPrincipalName','displayName','id','mail','givenName','surname','jobTitle','department','employeeType','employeeId','employeeHireDate',
            'officeLocation','city','state','country','postalCode','companyName','accountEnabled','userType','createdDateTime','usageLocation',
            'preferredLanguage','onPremisesSyncEnabled','onPremisesImmutableId','externalUserState','employeeOrgData','proxyAddresses','assignedLicenses'
        ) -join ','
        
        $baseUri = "https://graph.microsoft.com/v1.0/users?`$select=$entraUserSelect&`$expand=manager&`$top=999"
        $nextLink = $baseUri
        $rawUsers = @()
        $loops = 0
        
        while ($nextLink) {
            $loops++
            $resp = Invoke-GraphRequestWithRetry -Uri $nextLink
            if ($resp.value) { $rawUsers += $resp.value }
            $nextLink = $resp.'@odata.nextLink'
            if ($loops -gt 2000) { throw "Safety abort: excessive paging (>2000)" }
        }
        
        Write-Log "  Retrieved $($rawUsers.Count) raw user objects" -Level Metric
        $flattened = ConvertTo-FlatEntraUsers -Users $rawUsers
        $filtered = $rawUsers.Count - $flattened.Count
        Write-Log "  Flattened to $($flattened.Count) user rows ($filtered filtered: rooms/resources/non-users)" -Level Metric
        
        return $flattened
    }
    catch {
        Write-Log "WARNING: Failed to collect Entra user directory: $($_.Exception.Message)" -Level Warning
        return @()
    }
}

function Get-EntraUserDetails {
    <#
    .SYNOPSIS
        Retrieves Entra ID user details
    .DESCRIPTION
        Phase 3: Fetches core user properties with manager details.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserPrincipalName
    )
    
    try {
         $selectProps = @(
            'userPrincipalName','displayName','id','mail','givenName','surname','jobTitle','department','employeeType','employeeId','employeeHireDate',
            'officeLocation','city','state','country','postalCode','companyName','accountEnabled','userType','createdDateTime','usageLocation',
            'preferredLanguage','onPremisesSyncEnabled','onPremisesImmutableId','externalUserState','employeeOrgData','proxyAddresses'
        ) -join ','
        
        $uri = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName"
        $uri += "?`$select=$selectProps"
        $uri += "&`$expand=manager(`$select=userPrincipalName,displayName,id,mail,jobTitle)"
        
        $user = Invoke-GraphRequestWithRetry -Uri $uri
        
        $flatUser = [PSCustomObject]@{
            userPrincipalName = $user.userPrincipalName
            displayName = $user.displayName
            id = $user.id
            mail = $user.mail
            givenName = $user.givenName
            surname = $user.surname
            
            jobTitle = $user.jobTitle
            department = $user.department
            employeeType = $user.employeeType
            employeeId = $user.employeeId
            employeeHireDate = $user.employeeHireDate
            
            # Location Properties (6)
            officeLocation = $user.officeLocation
            city = $user.city
            state = $user.state
            country = $user.country
            postalCode = $user.postalCode
            companyName = $user.companyName
            
            # Organizational Properties (2)
            employeeOrgData_division = if ($user.employeeOrgData) { $user.employeeOrgData.division } else { $null }
            employeeOrgData_costCenter = if ($user.employeeOrgData) { $user.employeeOrgData.costCenter } else { $null }
            
            # Status Properties (3)
            accountEnabled = $user.accountEnabled
            userType = $user.userType
            createdDateTime = $user.createdDateTime
            
            # Usage Properties (2)
            usageLocation = $user.usageLocation
            preferredLanguage = $user.preferredLanguage
            
            # Sync Properties (2)
            onPremisesSyncEnabled = $user.onPremisesSyncEnabled
            onPremisesImmutableId = $user.onPremisesImmutableId
            
            # External User Properties (1)
            externalUserState = $user.externalUserState
            
            # Array Properties (8)
            proxyAddresses_0 = if ($user.proxyAddresses -and $user.proxyAddresses.Count -gt 0) { $user.proxyAddresses[0] } else { $null }
            proxyAddresses_1 = if ($user.proxyAddresses -and $user.proxyAddresses.Count -gt 1) { $user.proxyAddresses[1] } else { $null }
            proxyAddresses_2 = if ($user.proxyAddresses -and $user.proxyAddresses.Count -gt 2) { $user.proxyAddresses[2] } else { $null }
            proxyAddresses_3 = if ($user.proxyAddresses -and $user.proxyAddresses.Count -gt 3) { $user.proxyAddresses[3] } else { $null }
            proxyAddresses_4 = if ($user.proxyAddresses -and $user.proxyAddresses.Count -gt 4) { $user.proxyAddresses[4] } else { $null }
            proxyAddresses_5 = if ($user.proxyAddresses -and $user.proxyAddresses.Count -gt 5) { $user.proxyAddresses[5] } else { $null }
            proxyAddresses_6 = if ($user.proxyAddresses -and $user.proxyAddresses.Count -gt 6) { $user.proxyAddresses[6] } else { $null }
            proxyAddresses_7 = if ($user.proxyAddresses -and $user.proxyAddresses.Count -gt 7) { $user.proxyAddresses[7] } else { $null }
            
            # Manager Properties (5)
            manager_userPrincipalName = if ($user.manager) { $user.manager.userPrincipalName } else { $null }
            manager_displayName = if ($user.manager) { $user.manager.displayName } else { $null }
            manager_id = if ($user.manager) { $user.manager.id } else { $null }
            manager_mail = if ($user.manager) { $user.manager.mail } else { $null }
            manager_jobTitle = if ($user.manager) { $user.manager.jobTitle } else { $null }
        }
        
        return $flatUser
        
    } catch {
        Write-Log "  Warning: Could not retrieve Entra details for $UserPrincipalName : $_" -Level Warning
        
        # Return empty object with all user properties
        return [PSCustomObject]@{
            userPrincipalName = $UserPrincipalName
            displayName = $null
            id = $null
            mail = $null
            givenName = $null
            surname = $null
            jobTitle = $null
            department = $null
            employeeType = $null
            employeeId = $null
            employeeHireDate = $null
            officeLocation = $null
            city = $null
            state = $null
            country = $null
            postalCode = $null
            companyName = $null
            employeeOrgData_division = $null
            employeeOrgData_costCenter = $null
            accountEnabled = $null
            userType = $null
            createdDateTime = $null
            usageLocation = $null
            preferredLanguage = $null
            onPremisesSyncEnabled = $null
            onPremisesImmutableId = $null
            externalUserState = $null
            proxyAddresses_0 = $null
            proxyAddresses_1 = $null
            proxyAddresses_2 = $null
            proxyAddresses_3 = $null
            proxyAddresses_4 = $null
            proxyAddresses_5 = $null
            proxyAddresses_6 = $null
            proxyAddresses_7 = $null
            manager_userPrincipalName = $null
            manager_displayName = $null
            manager_id = $null
            manager_mail = $null
            manager_jobTitle = $null
        }
    }
}

function Export-ResultsToExcel {
    <#
    .SYNOPSIS
        Exports results to Excel workbook with multiple tabs.
    .DESCRIPTION
        Phase 3: Creates multi-tab workbook matching.
        If -IncludeUserInfo: Adds separate EntraUsers_MAClicensing tab.
        
        AppendFile Mode:
        - Validates headers match between existing tabs and new data
        - If headers mismatch: Creates timestamped duplicate tabs (preserves both datasets)
        - If headers match: Appends new rows to existing tabs
        - EntraUsers_MAClicensing tab always replaced (never appended)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$AllResults,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputFile,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$EntraCache,
        
        [Parameter(Mandatory=$false)]
        [bool]$AppendMode = $false
    )
    
    try {
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Log "ImportExcel module not found. Installing..." -Level Warning
            try {
                Install-Module -Name ImportExcel -Scope CurrentUser -Force -AllowClobber
                Write-Log "ImportExcel module installed successfully" -Level Success
            } catch {
                Write-Log "Failed to install ImportExcel module: $_" -Level Error
                Write-Log "Skipping Excel export. Install manually with: Install-Module ImportExcel" -Level Warning
                return $false
            }
        }
        
        Import-Module ImportExcel -ErrorAction Stop
        
        $timestamp = $ScriptTimestamp
        
        # Get existing sheets if AppendMode
        $existingSheets = @()
        if ($AppendMode -and (Test-Path $OutputFile)) {
            Write-Log "AppendFile mode: Reading existing workbook structure..." -Level Processing
            try {
                $sheetInfo = Get-ExcelSheetInfo -Path $OutputFile -ErrorAction Stop
                $existingSheets = $sheetInfo | Select-Object -ExpandProperty Name
                Write-Log "Existing tabs: $($existingSheets -join ', ')" -Level Processing
            } catch {
                Write-Log "WARNING: Could not read existing workbook sheets: $_" -Level Warning
            }
        }
        
        # Helper function to check header mismatch
        function Test-HeaderMismatch {
            param([string]$ExcelPath, [string]$TabName, [array]$NewData)
            
            if (-not $NewData -or $NewData.Count -eq 0) {
                return $false  # No new data, no mismatch
            }
            
            try {
                # Read existing headers from Excel tab
                $existing = Import-Excel -Path $ExcelPath -WorksheetName $TabName -StartRow 1 -EndRow 1 -NoHeader -ErrorAction Stop
                $existingHeaders = $existing[0].PSObject.Properties.Value | Where-Object { $_ }
                
                # Get new data headers
                $newHeaders = $NewData[0].PSObject.Properties.Name
                
                # Compare
                if ($existingHeaders.Count -ne $newHeaders.Count) {
                    return $true
                }
                
                for ($i = 0; $i -lt $existingHeaders.Count; $i++) {
                    if ($existingHeaders[$i] -ne $newHeaders[$i]) {
                        return $true
                    }
                }
                
                return $false
            } catch {
                Write-Log "WARNING: Could not validate headers for tab '$TabName': $_" -Level Warning
                return $false
            }
        }
        
        # Helper function to export or append tab
        function Export-ExcelTab {
            param(
                [string]$ExcelPath,
                [string]$TabName,
                [array]$Data,
                [bool]$IsAppendMode,
                [array]$ExistingSheets,
                [string]$Timestamp
            )
            
            if (-not $Data -or $Data.Count -eq 0) {
                return  # Skip empty tabs
            }
            
            if ($IsAppendMode -and $ExistingSheets -contains $TabName) {
                $hasMismatch = Test-HeaderMismatch -ExcelPath $ExcelPath -TabName $TabName -NewData $Data
                
                if ($hasMismatch) {
                    $timestampedTab = "${TabName}_$Timestamp"
                    Write-Log "WARNING: Header mismatch detected for tab '$TabName'" -Level Warning
                    Write-Log "Creating timestamped duplicate tab: $timestampedTab" -Level Warning
                    $Data | Export-Excel -Path $ExcelPath -WorksheetName $timestampedTab -FreezeTopRow -BoldTopRow -NoNumberConversion '*' -ErrorAction Stop
                } else {
                    $Data | Export-Excel -Path $ExcelPath -WorksheetName $TabName -Append -FreezeTopRow -BoldTopRow -NoNumberConversion '*' -ErrorAction Stop
                }
            } else {
                $Data | Export-Excel -Path $ExcelPath -WorksheetName $TabName -FreezeTopRow -BoldTopRow -NoNumberConversion '*' -ErrorAction Stop
            }
        }
        
        # Tab 1: All interactions
        Export-ExcelTab -ExcelPath $OutputFile -TabName "CopilotInteractions_Content" -Data $AllResults -IsAppendMode $AppendMode -ExistingSheets $existingSheets -Timestamp $timestamp
        
        # Stats tabs (only if -IncludeStats switch is used)
        if ($IncludeStats) {
            # Tab 2: Summary Statistics - By User
            $userStats = $AllResults | Group-Object UserId | ForEach-Object {
                $promptLengths = $_.Group | Where-Object { $_.InteractionType -eq 'userPrompt' -and $_.Content } | ForEach-Object { $_.Content.Length }
                $responseLengths = $_.Group | Where-Object { $_.InteractionType -eq 'aiResponse' -and $_.Content } | ForEach-Object { $_.Content.Length }
                [PSCustomObject]@{
                    UserId = $_.Name
                    TotalMessages = $_.Count
                    Prompts = ($_.Group | Where-Object { $_.InteractionType -eq 'userPrompt' }).Count
                    Responses = ($_.Group | Where-Object { $_.InteractionType -eq 'aiResponse' }).Count
                    TotalCharactersPrompts = ($promptLengths | Measure-Object -Sum).Sum
                    TotalCharactersResponses = ($responseLengths | Measure-Object -Sum).Sum
                    AvgCharactersPerPrompt = if ($promptLengths) { [Math]::Round(($promptLengths | Measure-Object -Average).Average, 0) } else { 0 }
                    AvgCharactersPerResponse = if ($responseLengths) { [Math]::Round(($responseLengths | Measure-Object -Average).Average, 0) } else { 0 }
                }
            }
            if ($userStats) {
                Export-ExcelTab -ExcelPath $OutputFile -TabName "StatsByUser" -Data $userStats -IsAppendMode $AppendMode -ExistingSheets $existingSheets -Timestamp $timestamp
            }
            
            # Tab 3: Summary Statistics - By App
            $appStats = $AllResults | Group-Object AppClass | ForEach-Object {
                [PSCustomObject]@{
                    AppClass = $_.Name
                    TotalMessages = $_.Count
                    Prompts = ($_.Group | Where-Object { $_.InteractionType -eq 'userPrompt' }).Count
                    Responses = ($_.Group | Where-Object { $_.InteractionType -eq 'aiResponse' }).Count
                    UniqueUsers = ($_.Group | Select-Object -ExpandProperty UserId -Unique).Count
                }
            }
            if ($appStats) {
                Export-ExcelTab -ExcelPath $OutputFile -TabName "StatsByApp" -Data $appStats -IsAppendMode $AppendMode -ExistingSheets $existingSheets -Timestamp $timestamp
            }
            
            # Tab 4: Summary Statistics - By Date
            $dateStats = $AllResults | ForEach-Object {
                $_ | Add-Member -NotePropertyName InteractionDate -NotePropertyValue ([DateTime]$_.CreationDate).Date -PassThru -Force
            } | Group-Object InteractionDate | ForEach-Object {
                [PSCustomObject]@{
                    Date = $_.Name
                    TotalMessages = $_.Count
                    Prompts = ($_.Group | Where-Object { $_.InteractionType -eq 'userPrompt' }).Count
                    Responses = ($_.Group | Where-Object { $_.InteractionType -eq 'aiResponse' }).Count
                    UniqueUsers = ($_.Group | Select-Object -ExpandProperty UserId -Unique).Count
                }
            } | Sort-Object Date
            if ($dateStats) {
                Export-ExcelTab -ExcelPath $OutputFile -TabName "StatsByDate" -Data $dateStats -IsAppendMode $AppendMode -ExistingSheets $existingSheets -Timestamp $timestamp
            }
        }
        
        # Tab 5 (or 2 if no stats): EntraUsers_MAClicensing (if -IncludeUserInfo was used)
        # NOTE: EntraUsers tab is ALWAYS replaced, never appended (point-in-time snapshot)
        if ($EntraCache -and $EntraCache.Count -gt 0) {
            $entraData = $EntraCache.Values | Sort-Object userPrincipalName -Unique
            
            if ($entraData) {
                # Always create/overwrite this tab (never append)
                $entraData | Export-Excel -Path $OutputFile -WorksheetName "EntraUsers_MAClicensing" -FreezeTopRow -BoldTopRow -NoNumberConversion '*' -ErrorAction Stop
            }
        }
        
        # Clean up temp CSV if in AppendFile mode
        if ($AppendMode -and $script:AppendFileTempCsv -and (Test-Path $script:AppendFileTempCsv)) {
            Remove-Item -Path $script:AppendFileTempCsv -Force -ErrorAction SilentlyContinue
            Write-Log "Removed temporary CSV file: $script:AppendFileTempCsv" -Level Info
        }
        
        return $true
        
    } catch {
        Write-Log "ERROR: Failed to create Excel workbook: $_" -Level Error
        return $false
    }
}

#endregion

#region Main Script

# Trap handler to ensure cleanup on Ctrl+C and other terminations
trap {
    Write-Host ""
    Write-Host "Script interrupted - performing cleanup..." -ForegroundColor Yellow
    
    # Clean up temporary files
    try {
        if ($script:AppendFileTempCsv -and (Test-Path $script:AppendFileTempCsv -ErrorAction SilentlyContinue)) {
            Remove-Item -Path $script:AppendFileTempCsv -Force -ErrorAction SilentlyContinue
            Write-Host "✓ Cleaned up temporary CSV file" -ForegroundColor Green
        }
        if ($WatermarkFile -and (Test-Path "$WatermarkFile.tmp" -ErrorAction SilentlyContinue)) {
            Remove-Item -Path "$WatermarkFile.tmp" -Force -ErrorAction SilentlyContinue
            Write-Host "✓ Cleaned up temporary watermark file" -ForegroundColor Green
        }
    }
    catch {
        # Silently continue
    }
    
    # Force disconnect from Microsoft Graph
    try {
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if ($context) {
            Write-Host "Disconnecting from Microsoft Graph..." -ForegroundColor Yellow
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            Write-Host "✓ Disconnected from Microsoft Graph" -ForegroundColor Green
        }
    }
    catch {
        # Silently continue
    }
    
    Write-Host "Cleanup complete." -ForegroundColor Yellow
    Write-Host ""
    break
}

try {
    # Note: Start time logged after log file is initialized below
    
    if ($AppendFile -and $IncludeUserInfo) {
        Write-Log "ERROR: -AppendFile cannot be used with -IncludeUserInfo" -Level Error
        Write-Log "EntraUsers data is always overwritten (never appended) because it represents" -Level Warning
        Write-Log "a point-in-time snapshot of your tenant's user information, not time-based" -Level Warning
        Write-Log "content data. Each export should create a fresh EntraUsers dataset." -Level Warning
        Write-Log "Solutions:" -Level Info
        Write-Log "  1. Remove -IncludeUserInfo to append content data only" -Level Info
        Write-Log "  2. Run without -AppendFile to create new timestamped files" -Level Info
        throw "Invalid parameter combination: -AppendFile with -IncludeUserInfo"
    }
    
    if ($AppendFile) {
        if ($AppendFile -match '[\\/]$' -or [string]::IsNullOrWhiteSpace([System.IO.Path]::GetFileName($AppendFile))) {
            Write-Log "ERROR: -AppendFile must specify a filename, not a directory path" -Level Error
            Write-Log "Valid examples:" -Level Info
            Write-Log "  -AppendFile 'CopilotInteractions_20251117_120000.csv'" -Level Info
            Write-Log "  -AppendFile 'C:\Data\Report.xlsx'" -Level Info
            throw "Invalid AppendFile parameter: must be a filename"
        }
        
        if ([System.IO.Path]::IsPathRooted($AppendFile)) {
            $resolvedAppendFile = $AppendFile
        } else {
            $resolvedAppendFile = Join-Path $OutputPath $AppendFile
        }
        
        if (-not (Test-Path $resolvedAppendFile)) {
            Write-Log "ERROR: AppendFile target does not exist: $resolvedAppendFile" -Level Error
            Write-Log "The file must exist before using -AppendFile." -Level Warning
            Write-Log "Create it first by running without -AppendFile." -Level Warning
            throw "AppendFile target not found: $resolvedAppendFile"
        }
        
        $fileExtension = [System.IO.Path]::GetExtension($resolvedAppendFile).ToLower()
        if ($ExportWorkbook -and $fileExtension -ne '.xlsx') {
            Write-Log "ERROR: -ExportWorkbook requires .xlsx file, but AppendFile has extension: $fileExtension" -Level Error
            throw "File extension mismatch: Excel mode requires .xlsx"
        }
        if (-not $ExportWorkbook -and $fileExtension -ne '.csv') {
            Write-Log "ERROR: CSV mode requires .csv file, but AppendFile has extension: $fileExtension" -Level Error
            throw "File extension mismatch: CSV mode requires .csv"
        }
        
        # Pre-validate file compatibility using Test-AppendFileCompatibility
        Write-Log "Validating append file compatibility..." -Level Processing
        $compatCheck = Test-AppendFileCompatibility -FilePath $resolvedAppendFile -IsExcel $ExportWorkbook
        
        if (-not $compatCheck.Compatible) {
            Write-Log "ERROR: AppendFile compatibility check failed" -Level Error
            Write-Log "Reason: $($compatCheck.ErrorMessage)" -Level Error
            Write-Log "The file exists but cannot be appended to safely." -Level Warning
            Write-Log "This prevents data corruption and schema mismatches." -Level Warning
            throw "AppendFile incompatible: $($compatCheck.ErrorMessage)"
        }
        
        Write-Log "✓ File compatible: $($compatCheck.ExistingCount) columns detected" -Level Success
        Write-Log "AppendFile mode enabled: Will append to $resolvedAppendFile" -Level Info
    }
    
    # Validate OutputPath is a directory, not a filename
    if ([System.IO.Path]::HasExtension($OutputPath)) {
        Write-Log "ERROR: -OutputPath must be a directory path, not a filename" -Level Error
        Write-Log "Received: $OutputPath" -Level Error
        Write-Log "Use -AppendFile parameter to specify a custom filename" -Level Warning
        throw "Invalid OutputPath: Must be a directory, not a filename"
    }
    
    # Validate and create output directory
    $directoryCreated = $false
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        $directoryCreated = $true
    }
    
    # Initialize log file after directory is created
    $Global:LogFile = Join-Path $OutputPath "CopilotInteractions_Log_$ScriptTimestamp.log"
    
    # Calculate StartDate and EndDate based on provided parameters
    $startDateProvided = $PSBoundParameters.ContainsKey('StartDate')
    $endDateProvided = $PSBoundParameters.ContainsKey('EndDate')
    
    if (-not $endDateProvided) {
        # EndDate not provided - default to today
        $EndDate = Get-Date
    }
    
    if (-not $startDateProvided) {
        # StartDate not provided - calculate from EndDate using DaysBack
        $StartDate = $EndDate.AddDays(-$DaysBack)
        if (-not $endDateProvided) {
            Write-Log "Using default date range: last $DaysBack days" -Level Info
        } else {
            Write-Log "StartDate calculated: $DaysBack days back from EndDate" -Level Info
        }
    }
    
    # Print start time after log file is initialized
    Write-Log "Started: $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')" -Level Info
    if ($directoryCreated) {
        Write-Log "Created output directory: $OutputPath" -Level Info
    } else {
        Write-Log "Output directory: $OutputPath" -Level Info
    }
    
    if ($StartDate -gt $EndDate) {
        throw "StartDate ($StartDate) cannot be after EndDate ($EndDate)"
    }
    
    Write-Log "Date range: $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd')) (both inclusive)" -Level Info
    Write-Log "Note: KQL query uses received>=$($StartDate.ToString('yyyy-MM-dd')) AND received<=$($EndDate.ToString('yyyy-MM-dd'))" -Level Info
    
    # ═══════════════════════════════════════════════════════════════
    # METRICS EXPORT FUNCTION
    # ═══════════════════════════════════════════════════════════════
    
    function Export-MetricsJson {
        <#
        .SYNOPSIS
            Exports structured performance metrics to JSON file.
        #>
        param([string]$OutputPath)
        
        try {
            $duration = (Get-Date) - $Global:Stats.StartTime
            
            $metrics = [ordered]@{
                ScriptName = $ScriptName
                Version = "v$ScriptVersion"
                ExecutionTimestamp = $Global:Stats.StartTime.ToString('o')
                Execution = [ordered]@{
                    DurationSeconds = [math]::Round($duration.TotalSeconds, 2)
                    DurationFormatted = $duration.ToString('hh\:mm\:ss')
                    Status = "Completed"
                }
                Users = [ordered]@{
                    TotalProcessed = $Global:Stats.UsersProcessed
                    WithContent = $Global:Stats.UsersWithContent
                    AverageTimePerUserSeconds = if ($Global:Stats.UsersProcessed -gt 0) { 
                        [math]::Round($duration.TotalSeconds / $Global:Stats.UsersProcessed, 2) 
                    } else { 0 }
                }
                API = [ordered]@{
                    TotalCalls = $Global:Stats.APICallsMade
                    NetworkRetries = $Global:Stats.NetworkRetries
                    Errors = $Global:Stats.Errors
                }
            }
            
            # Determine metrics path (support -MetricsPath override)
            if ($MetricsPath) { 
                $metricsPath = if ($MetricsPath.ToLower().EndsWith('.json')) { $MetricsPath } else { "$MetricsPath.json" } 
            } else {
                $outputDir = Split-Path $OutputPath -Parent
                if (-not $outputDir) { $outputDir = Get-Location }
                $metricsPath = Join-Path $outputDir "CopilotInteractions_Content_Metrics_$ScriptTimestamp.json"
            }
            
            $metrics | ConvertTo-Json -Depth 10 | Set-Content -Path $metricsPath -Encoding UTF8
            Write-Log "✓ Metrics exported: $metricsPath" -Level Success
        } catch {
            Write-Log "Warning: Failed to export metrics JSON: $_" -Level Warning
        }
    }
    
    # ═══════════════════════════════════════════════════════════════
    # INITIALIZE PARALLEL PROCESSING INFRASTRUCTURE
    # ═══════════════════════════════════════════════════════════════
    
    Write-Log "Initializing parallel processing infrastructure..." -Level Info
    
    # Partition status tracking (hash table)
    # Keys: Partition ID (e.g., "Batch_1", "Batch_2")
    # Values: Status string ("NotStarted", "Attempt1", "Attempt2", "Attempt3", "Sent", "Complete", "Failed")
    if (-not $script:partitionStatus) {
        $script:partitionStatus = @{}
    }
    
    # Job result deduplication (HashSet for O(1) lookups)
    # Tracks processed ThreadJob IDs to prevent duplicate result collection
    if (-not $script:processedJobIds) {
        $script:processedJobIds = New-Object System.Collections.Generic.HashSet[int]
    }
    
    # Message deduplication (HashSet for message keys)
    # Prevents showing duplicate [SENT], [ERROR], [NETWORK] messages
    # Format: "JobId:MessageType" (e.g., "123:SENT", "456:ERROR")
    if (-not $script:shownJobMessages) {
        $script:shownJobMessages = New-Object System.Collections.Generic.HashSet[string]
    }
    
    # Active job tracking (HashSet for job IDs created by this script run)
    # Used to filter Get-Job calls to only our jobs, not orphaned jobs from previous runs
    if (-not $script:activeJobIds) {
        $script:activeJobIds = New-Object System.Collections.Generic.HashSet[int]
    }
    
    # Synchronized hashtable for ThreadJob results (thread-safe communication)
    # Keys: BatchId (e.g., "Batch_1")
    # Values: Result objects from completed jobs
    if (-not $script:batchResults) {
        $script:batchResults = [hashtable]::Synchronized(@{})
    }
    
    # Clean up any orphaned jobs from previous runs
    $orphanedJobs = Get-Job -State Completed, Failed -ErrorAction SilentlyContinue
    if ($orphanedJobs) {
        Write-Log "Cleaning up $($orphanedJobs.Count) orphaned jobs from previous runs..." -Level Info
        $orphanedJobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    
    # Last status update timestamp (for 60-second interval updates)
    $script:lastStatusUpdate = [DateTime]::Now
    
    Write-Log "✓ Initialized tracking: partitionStatus, processedJobIds, shownJobMessages, activeJobIds, batchResults (synchronized)" -Level Success
    
    # ═══════════════════════════════════════════════════════════════
    # MODULE DEPENDENCY CHECKS AND AUTO-INSTALLATION
    # ═══════════════════════════════════════════════════════════════
    
    Write-Log "Checking required PowerShell modules..." -Level Info
    
    $requiredModules = @(
        @{
            Name = 'Microsoft.Graph.Authentication'
            MinVersion = '2.0.0'
            Description = 'Microsoft Graph SDK authentication'
            ImportName = 'Microsoft.Graph.Authentication'
        },
        @{
            Name = 'Microsoft.Graph.Security'
            MinVersion = '2.0.0'
            Description = 'Microsoft Graph Copilot Interaction History API'
            ImportName = 'Microsoft.Graph.Security'
        },
        @{
            Name = 'Microsoft.Graph.Users'
            MinVersion = '2.0.0'
            Description = 'Microsoft Graph user enumeration'
            ImportName = 'Microsoft.Graph.Users'
        }
    )
    
    $modulesToInstall = @()
    
    foreach ($moduleInfo in $requiredModules) {
        $moduleName = $moduleInfo.Name
        $minVersion = $moduleInfo.MinVersion
        $description = $moduleInfo.Description
        
        Write-Log "  Checking $moduleName ($description)..." -Level Info
        
        $installedModule = Get-Module -ListAvailable -Name $moduleName | 
            Where-Object { $_.Version -ge [version]$minVersion } | 
            Select-Object -First 1
        
        if ($installedModule) {
            Write-Log "    ✓ Found: v$($installedModule.Version)" -Level Success
            
            # Import if not already loaded
            if (-not (Get-Module -Name $moduleInfo.ImportName)) {
                try {
                    Import-Module $moduleInfo.ImportName -MinimumVersion $minVersion -ErrorAction Stop
                    Write-Log "    ✓ Imported successfully" -Level Success
                } catch {
                    Write-Log "    ⚠ Import warning: $($_.Exception.Message)" -Level Warning
                }
            }
        } else {
            $existingModule = Get-Module -ListAvailable -Name $moduleName | Select-Object -First 1
            if ($existingModule) {
                Write-Log "    ⚠ Found v$($existingModule.Version), but minimum required is v$minVersion" -Level Warning
                $modulesToInstall += $moduleInfo
            } else {
                Write-Log "    ✗ Not found" -Level Warning
                $modulesToInstall += $moduleInfo
            }
        }
    }
    
    if ($modulesToInstall.Count -gt 0) {
        Write-Log "Installing missing or outdated modules..." -Level Info
        Write-Log "This may take a few minutes..." -Level Info
        
        foreach ($moduleInfo in $modulesToInstall) {
            $moduleName = $moduleInfo.Name
            $description = $moduleInfo.Description
            
            Write-Log "  Installing $moduleName ($description)..." -Level Info
            
            try {
                # Check if running as admin for AllUsers scope
                $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                $scope = if ($isAdmin) { 'AllUsers' } else { 'CurrentUser' }
                
                Install-Module -Name $moduleName -Scope $scope -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
                
                $installedVersion = (Get-Module -ListAvailable -Name $moduleName | Select-Object -First 1).Version
                Write-Log "    ✓ Installed v$installedVersion (scope: $scope)" -Level Success
                
                # Import the newly installed module
                Import-Module $moduleInfo.ImportName -ErrorAction Stop
                Write-Log "    ✓ Imported successfully" -Level Success
                
            } catch {
                Write-Log "    ✗ Installation failed: $($_.Exception.Message)" -Level Error
                Write-Log "ERROR: Failed to install required module: $moduleName" -Level Error
                Write-Log "Please install manually with: Install-Module $moduleName -Scope CurrentUser" -Level Error
                throw "Required module installation failed: $moduleName"
            }
        }
        
        Write-Log "✓ All required modules installed and imported" -Level Success
    } else {
        Write-Log "✓ All required modules are available" -Level Success
    }
    
    # ═══════════════════════════════════════════════════════════════
    # GRAPH API AUTHENTICATION (APP-ONLY / CLIENT CREDENTIALS)
    # ═══════════════════════════════════════════════════════════════
    
    Write-Log "Initializing Microsoft Graph authentication..." -Level Header
    
    try {
        # ═══════════════════════════════════════════════════════════════
        # ACQUIRE GRAPH API TOKEN (CLIENT CREDENTIALS FLOW)
        # ═══════════════════════════════════════════════════════════════
        
        Write-Log "  Authenticating with app-only (client credentials)..." -Level Processing
        
        # Build token request
        $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
        $body = @{
            client_id     = $ClientId
            client_secret = $ClientSecret
            scope         = "https://graph.microsoft.com/.default"
            grant_type    = "client_credentials"
        }
        
        Write-Log "  Requesting access token..." -Level Info
        $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $body -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
        
        Write-Log "  ✓ Access token acquired" -Level Success
        
        # ═══════════════════════════════════════════════════════════════
        # CONNECT GRAPH SDK WITH ACCESS TOKEN
        # ═══════════════════════════════════════════════════════════════
        
        Write-Log "  Connecting to Microsoft Graph SDK..." -Level Info
        $secureToken = ConvertTo-SecureString -String $tokenResponse.access_token -AsPlainText -Force
        Connect-MgGraph -AccessToken $secureToken -NoWelcome -ErrorAction Stop
        
        # Get context
        $context = Get-MgContext -ErrorAction Stop
        
        Write-Log "✓ Authentication complete!" -Level Success
        Write-Log "  Tenant ID:      $($context.TenantId)" -Level Info
        Write-Log "  Client ID:      $ClientId" -Level Info
        Write-Log "  Client Secret:  via $ClientSecretSource" -Level Info
        Write-Log "  Auth Type:      Application (Client Credentials)" -Level Info
        
    } catch {
        Write-Log "ERROR: Authentication failed" -Level Error
        Write-Log "Error: $($_.Exception.Message)" -Level Error
        Write-Log "Authentication requires:" -Level Info
        Write-Log "  • Valid Tenant ID, Client ID, and Client Secret" -Level Info
        Write-Log "  • App registration with Application permissions (not Delegated)" -Level Info
        Write-Log "  • Admin consent granted for: AiEnterpriseInteraction.Read.All, User.Read.All" -Level Info
        throw "Microsoft Graph authentication failed"
    }
    
    
    if ($OnlyUserInfo) {
        Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
        Write-Log "-OnlyUserInfo mode: Exporting Entra ID user directory only" -Level Highlight
        Write-Log "Skipping Copilot interaction content retrieval" -Level Processing
        Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
        
        # Retrieve Entra ID users
        Write-Log "Retrieving Entra ID users..." -Level Processing
        $entraStartTime = Get-Date
        
        $entraUsers = Get-EntraUsers
        
        if ($entraUsers.Count -eq 0) {
            Write-Log "WARNING: No Entra ID users retrieved" -Level Warning
        } else {
            Write-Log "✓ Retrieved $($entraUsers.Count) Entra ID users in $([math]::Round((Get-Date).Subtract($entraStartTime).TotalSeconds, 2)) seconds" -Level Success
        }
        
        # Export to file
        $timestamp = $ScriptTimestamp
        
        if ($ExportWorkbook) {
            # Excel mode
            $outputFile = Join-Path $OutputPath "EntraUsers_MAClicensing_$timestamp.xlsx"
            
            try {
                $entraUsers | Export-Excel -Path $outputFile -WorksheetName 'EntraUsers_MAClicensing' -FreezeTopRow -BoldTopRow -NoNumberConversion '*'
                $fileSize = [math]::Round((Get-Item $outputFile).Length / 1MB, 2)
            }
            catch {
                Write-Log "ERROR: Failed to export Excel file: $($_.Exception.Message)" -Level Error
                throw
            }
        } else {
            # CSV mode
            $outputFile = Join-Path $OutputPath "EntraUsers_MAClicensing_$timestamp.csv"
            
            try {
                $entraUsers | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
                $fileSize = [math]::Round((Get-Item $outputFile).Length / 1MB, 2)
            }
            catch {
                Write-Log "ERROR: Failed to export CSV file: $($_.Exception.Message)" -Level Error
                throw
            }
        }
        
        Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
        Write-Log "-OnlyUserInfo mode completed successfully" -Level Success
        Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
        
        # Calculate elapsed time
        $elapsedTime = (Get-Date) - $ScriptStartTime
        $elapsedFormatted = if ($elapsedTime.TotalHours -ge 1) {
            "{0:D2}h {1:D2}m {2:D2}s" -f $elapsedTime.Hours, $elapsedTime.Minutes, $elapsedTime.Seconds
        } elseif ($elapsedTime.TotalMinutes -ge 1) {
            "{0:D2}m {1:D2}s" -f $elapsedTime.Minutes, $elapsedTime.Seconds
        } else {
            "{0:D2}s" -f $elapsedTime.Seconds
        }
        
        Write-Log "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Info
        Write-Log "Elapsed time: $elapsedFormatted" -Level Info
        Write-Log "Script version: v$ScriptVersion" -Level Info
        Write-Log "Output Files Generated:" -Level Info
        Write-Log "─────────────────────────────────────────────────────────────" -Level Info
        
        # List Entra users output file
        if ($outputFile -and (Test-Path $outputFile)) {
            $outputFileSize = [math]::Round((Get-Item $outputFile).Length / 1MB, 2)
            Write-Log "  Entra Users: $outputFile ($outputFileSize MB)" -Level Info
        }
        
        # List log file
        if ($Global:LogFile -and (Test-Path $Global:LogFile)) {
            $logSize = [math]::Round((Get-Item $Global:LogFile).Length / 1KB, 2)
            Write-Log "  Log File: $Global:LogFile ($logSize KB)" -Level Info
        }
        
        Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
        
        return
    }
    
    # Initialize watermark store if enabled
    if ($UseWatermark) {
        Write-Log "Initializing watermark store..." -Level Processing
        $script:watermarkStore = Initialize-WatermarkStore -WatermarkFile $WatermarkFile
        Write-Log "✓ Watermark store initialized: $($script:watermarkStore.Users.Count) users tracked" -Level Success
    }
    else {
        $script:watermarkStore = $null
    }
    
    # Enumerate users
    Write-Log "Enumerating target users..." -Level Header
    $targetUsers = @()
    
    if ($UserPrincipalNames) {
        $targetUsers = $UserPrincipalNames
        Write-Log "✓ Using $($targetUsers.Count) specified user(s)" -Level Success
    }
    elseif ($UserListFile) {
        if (-not (Test-Path $UserListFile)) {
            throw "User list file not found: $UserListFile"
        }
        $targetUsers = Get-Content $UserListFile | Where-Object { $_ -match '\S' }
        Write-Log "✓ Loaded $($targetUsers.Count) user(s) from file" -Level Success
    }
    else {
        # Get all licensed users from Entra
        Write-Log "Retrieving all Copilot-licensed users from Entra ID..." -Level Info
        $entraUsers = Get-EntraUsers
        $licensedUsers = $entraUsers | Where-Object { $_.hasLicense -eq $true }
        $unlicensedCount = ($entraUsers | Where-Object { $_.hasLicense -ne $true }).Count
        
        if ($unlicensedCount -gt 0) {
            Write-Log "  Filtered out $unlicensedCount user(s) without Copilot licenses" -Level Metric
        }
        
        $targetUsers = $licensedUsers | Where-Object { $_.UserPrincipalName } | Select-Object -ExpandProperty UserPrincipalName
        Write-Log "✓ Retrieved $($targetUsers.Count) licensed user(s)" -Level Success
    }
    
    if ($targetUsers.Count -eq 0) {
        throw "No target users identified. Specify -UserPrincipalNames, -UserListFile, or ensure licensed users exist in Entra ID."
    }
    
    # Validate Copilot licenses for explicitly specified users
    if ($UserPrincipalNames -or $UserListFile) {
        Write-Log "Validating Copilot licenses for specified users..." -Level Info
        $licensedTargets = @()
        $unlicensedTargets = @()
        $validationErrors = @()
        
        foreach ($upn in $targetUsers) {
            try {
                # Fetch user's license info from Graph API
                $userLicenseUri = "https://graph.microsoft.com/v1.0/users/$upn`?`$select=userPrincipalName,assignedLicenses"
                $userLicenses = Invoke-MgGraphRequest -Method GET -Uri $userLicenseUri -OutputType PSObject -ErrorAction Stop
                
                # Check for Copilot license using same logic as ConvertTo-FlatEntraUsers
                $hasCopilot = $false
                if ($userLicenses.assignedLicenses -and $userLicenses.assignedLicenses.Count -gt 0) {
                    $copilotSkuIds = $script:CopilotSkuIds.Keys
                    
                    foreach ($license in $userLicenses.assignedLicenses) {
                        $skuId = $license.skuId
                        
                        # Check known Copilot SKU IDs
                        if ($copilotSkuIds -contains $skuId) {
                            $hasCopilot = $true
                            break
                        }
                    }
                }
                
                if ($hasCopilot) {
                    $licensedTargets += $upn
                } else {
                    $unlicensedTargets += $upn
                }
            }
            catch {
                $validationErrors += [PSCustomObject]@{
                    User = $upn
                    Error = $_.Exception.Message
                }
                Write-Log "  WARNING: Failed to validate license for $upn : $($_.Exception.Message)" -Level Warning
            }
        }
        
        # Log filtering results
        if ($unlicensedTargets.Count -gt 0) {
            Write-Log "  ⚠ Filtered out $($unlicensedTargets.Count) unlicensed user(s):" -Level Warning
            foreach ($u in $unlicensedTargets) {
                Write-Log "    - $(Get-MaskedUsername -Username $u)" -Level Warning
            }
        }
        
        if ($validationErrors.Count -gt 0) {
            Write-Log "  ⚠ $($validationErrors.Count) user(s) could not be validated (see warnings above)" -Level Warning
        }
        
        if ($licensedTargets.Count -eq 0) {
            throw "No licensed Copilot users found in the specified list. All users either lack Copilot licenses or could not be validated."
        }
        
        # Update targetUsers to only licensed users
        $originalCount = $targetUsers.Count
        $targetUsers = $licensedTargets
        Write-Log "✓ License validation complete: $($targetUsers.Count) licensed user(s) (filtered $($originalCount - $targetUsers.Count) unlicensed)" -Level Success
    }
    
    # Initialize Entra cache if -IncludeUserInfo is specified
    if ($IncludeUserInfo) {
        Write-Log "Entra user data will be exported to output files" -Level Info
        
        # Convert entraUsers array to hashtable for efficient lookups
        $script:EntraCache = @{}
        if ($entraUsers -and $entraUsers.Count -gt 0) {
            foreach ($user in $entraUsers) {
                if ($user.userPrincipalName) {
                    $script:EntraCache[$user.userPrincipalName] = $user
                }
            }
            Write-Log "  Cached $($script:EntraCache.Count) Entra user record(s)" -Level Info
        }
    } else {
        Write-Log "Entra user data will NOT be exported (use -IncludeUserInfo to include)" -Level Info
        $script:EntraCache = $null
    }
    Write-Log "Processing $($targetUsers.Count) user(s) from $(Get-Date $StartDate -Format 'yyyy-MM-dd') to $(Get-Date $EndDate -Format 'yyyy-MM-dd')" -Level Highlight
    
    Write-Log "Testing server-side filter support in this tenant..." -Level Info
    $testUser = $targetUsers[0]
    $filterSupport = Test-FilterSupport -UserIdOrUpn $testUser
    
    Write-Log "Filter capability detection results:" -Level Info
    foreach ($detail in $filterSupport.Details) {
        Write-Log "  • $detail" -Level Info
    }
    Write-Log "Strategy: $($filterSupport.RecommendedApproach)" -Level Info
    
    # Store filter support flags for use throughout execution
    $script:serverSideAppClassSupported = ($filterSupport.AppClassFilterSupported -eq $true)
    $script:serverSideDateFilterSupported = ($filterSupport.DateFilterSupported -eq $true)
    
    # Determine parallel processing capability
    $psVersion = $PSVersionTable.PSVersion.Major
    $useParallel = $false
    
    if ($ParallelMode -eq 'Off') {
        Write-Log "Parallel mode: OFF (forced sequential processing)" -Level Highlight
        $useParallel = $false
    }
    elseif ($ParallelMode -eq 'On') {
        if ($psVersion -ge 7) {
            Write-Log "Parallel mode: ON (PowerShell $psVersion detected)" -Level Highlight
            $useParallel = $true
        }
        else {
            Write-Log "ERROR: -ParallelMode 'On' requires PowerShell 7+, but detected PowerShell $psVersion" -Level Error
            throw "Parallel processing requires PowerShell 7 or higher. Current version: $psVersion"
        }
    }
    else { # Auto
        if ($psVersion -ge 7) {
            Write-Log "Parallel mode: AUTO (PowerShell $psVersion detected, parallel enabled)" -Level Highlight
            $useParallel = $true
        }
        else {
            Write-Log "Parallel mode: AUTO (PowerShell $psVersion detected, falling back to sequential)" -Level Warning
            $useParallel = $false
        }
    }
    
    if ($useParallel) {
        Write-Log "Using parallel JSON batch processing (20 users per batch, $ParallelBatchThrottle concurrent batches)" -Level Info
    }
    else {
        Write-Log "Using sequential processing" -Level Info
    }
    
    # Initialize user status CSV file for tracking per-user results
    $userStatusFile = Join-Path $OutputPath "CopilotInteractions_UserStatus_$ScriptTimestamp.csv"
    $userStatusCsvHeaders = "UserPrincipalName,Status,InteractionCount,ErrorMessage,ProcessedTimestamp"
    $userStatusCsvHeaders | Out-File -FilePath $userStatusFile -Encoding UTF8
    Write-Log "Per-user processing status will be logged to a separate output file." -Level Info
    
    # Collect all interactions across all users
    $allInteractions = @()
    $successCount = 0
    $errorCount = 0
    $noDataCount = 0
    
    if ($useParallel) {
        # Parallel JSON batch processing using ForEach-Object -Parallel (PS7+)
        Write-Log "Starting parallel JSON batch processing for $($targetUsers.Count) users..." -Level Header
        
        # Split users into batches of 20 (Microsoft Graph batch limit)
        $batchSize = 20
        $batches = @()
        for ($i = 0; $i -lt $targetUsers.Count; $i += $batchSize) {
            $end = [Math]::Min($i + $batchSize - 1, $targetUsers.Count - 1)
            $batches += ,@($targetUsers[$i..$end])
        }
        
        Write-Log "Created $($batches.Count) batches ($batchSize users per batch) for parallel processing" -Level Info
        
        # Process batches in parallel (25 concurrent batches)
        $results = $batches | ForEach-Object -ThrottleLimit $ParallelBatchThrottle -Parallel {
            $batchUsers = $_
            $watermarkStore = $using:script:watermarkStore
            $UseWatermark = $using:UseWatermark
            $CopilotApps = $using:CopilotApps
            $StartDate = $using:StartDate
            $EndDate = $using:EndDate
            $serverSideAppClassSupported = $using:script:serverSideAppClassSupported
            $serverSideDateFilterSupported = $using:script:serverSideDateFilterSupported
            
            # Build JSON batch request (up to 20 individual requests)
            $batchRequests = @()
            $requestId = 1
            
            foreach ($upn in $batchUsers) {
                # Get watermark
                $watermark = $null
                if ($UseWatermark -and $watermarkStore.ContainsKey($upn)) {
                    $wmValue = $watermarkStore[$upn]
                    # Validate it's a DateTime, or try parsing if it's a string
                    if ($wmValue -is [DateTime]) {
                        $watermark = $wmValue
                    }
                    elseif ($wmValue -is [string]) {
                        try {
                            $watermark = [DateTime]::Parse($wmValue)
                        }
                        catch {
                            # Invalid string format, skip watermark for this user
                        }
                    }
                }
                
                # Build relative URL with server-side filters (if supported)
                $relativeUrl = "/copilot/users/$upn/interactionHistory/getAllEnterpriseInteractions"
                $filterParts = @()
                
                # Server-side date filter (if supported and not using watermark)
                if ($serverSideDateFilterSupported -and -not $watermark) {
                    $startIso = $StartDate.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $endIso = $EndDate.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $filterParts += "createdDateTime ge $startIso and createdDateTime le $endIso"
                }
                
                # Watermark filter takes precedence over date filter (only if server-side date filtering supported)
                if ($watermark -and $serverSideDateFilterSupported) {
                    $watermarkIso = $watermark.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $filterParts += "createdDateTime gt $watermarkIso"
                }
                
                # Server-side appClass filter (if supported and specific apps requested)
                if ($serverSideAppClassSupported -and $CopilotApps -and $CopilotApps -notcontains 'All') {
                    # Build OR condition for multiple apps
                    $appClassConditions = $CopilotApps | ForEach-Object { 
                        "appClass eq 'IPM.SkypeTeams.Message.Copilot.$_'" 
                    }
                    if ($appClassConditions.Count -eq 1) {
                        $filterParts += $appClassConditions[0]
                    } else {
                        $filterParts += "(" + ($appClassConditions -join ' or ') + ")"
                    }
                }
                
                # Apply filters to relative URL
                if ($filterParts.Count -gt 0) {
                    $filter = $filterParts -join ' and '
                    $filterEncoded = [System.Web.HttpUtility]::UrlEncode($filter)
                    $relativeUrl += "?`$filter=$filterEncoded"
                }
                
                # Add request to batch
                $batchRequests += @{
                    id = $requestId.ToString()
                    method = "GET"
                    url = $relativeUrl
                }
                $requestId++
            }
            
            # Send batch request to Graph API
            $batchResults = @()
            try {
                $batchPayload = @{
                    requests = $batchRequests
                } | ConvertTo-Json -Depth 10
                
                $batchResponse = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/`$batch" -Body $batchPayload -ContentType "application/json" -OutputType PSObject -ErrorAction Stop
                
                # Process each response in the batch
                foreach ($response in $batchResponse.responses) {
                    $requestIdNum = [int]$response.id
                    $upn = $batchUsers[$requestIdNum - 1]
                    
                    $result = [PSCustomObject]@{
                        User = $upn
                        Success = $false
                        Interactions = @()
                        Error = $null
                    }
                    
                    if ($response.status -eq 200) {
                        try {
                            $interactions = @()
                            
                            # Get initial page of interactions
                            if ($response.body.value) {
                                $interactions += $response.body.value
                            }
                            
                            # Handle pagination (nextLink in batch response)
                            $nextLink = $response.body.'@odata.nextLink'
                            while ($nextLink) {
                                $pageResponse = Invoke-MgGraphRequest -Method GET -Uri $nextLink -OutputType PSObject -ErrorAction Stop
                                if ($pageResponse.value) {
                                    $interactions += $pageResponse.value
                                }
                                $nextLink = $pageResponse.'@odata.nextLink'
                            }
                            
                            # Apply client-side date filtering if server-side not supported
                            if (-not $serverSideDateFilterSupported -and $interactions.Count -gt 0) {
                                # Get watermark for this user
                                $userWatermark = $null
                                if ($UseWatermark -and $watermarkStore.ContainsKey($upn)) {
                                    $wmValue = $watermarkStore[$upn]
                                    if ($wmValue -is [DateTime]) {
                                        $userWatermark = $wmValue
                                    }
                                    elseif ($wmValue -is [string]) {
                                        try { $userWatermark = [DateTime]::Parse($wmValue) } catch { }
                                    }
                                }
                                
                                $interactions = $interactions | Where-Object {
                                    $created = [DateTime]::Parse($_.createdDateTime)
                                    # If watermark exists, only get interactions after it; otherwise use date range
                                    if ($userWatermark) {
                                        $created -gt $userWatermark
                                    }
                                    else {
                                        $created -ge $StartDate -and $created -le $EndDate
                                    }
                                }
                            }
                            
                            # Apply client-side appClass filtering if server-side not supported
                            if (-not $serverSideAppClassSupported -and $CopilotApps -and $CopilotApps -notcontains 'All' -and $interactions.Count -gt 0) {
                                $appClassList = $CopilotApps | ForEach-Object { "IPM.SkypeTeams.Message.Copilot.$_" }
                                $interactions = $interactions | Where-Object { $appClassList -contains $_.appClass }
                            }
                            
                            $result.Interactions = $interactions
                            $result.Success = $true
                        }
                        catch {
                            $result.Error = "Pagination error: $($_.Exception.Message)"
                        }
                    }
                    else {
                        # Handle error response from batch
                        $errorMsg = "HTTP $($response.status)"
                        if ($response.body.error) {
                            $errorMsg += ": $($response.body.error.message)"
                        }
                        $result.Error = $errorMsg
                    }
                    
                    $batchResults += $result
                }
            }
            catch {
                # Entire batch failed - create error results for all users in batch
                foreach ($upn in $batchUsers) {
                    $batchResults += [PSCustomObject]@{
                        User = $upn
                        Success = $false
                        Interactions = @()
                        Error = "Batch request failed: $($_.Exception.Message)"
                    }
                }
            }
            
            return $batchResults
        }
        
        # Process results with progress summarization
        $userIndex = 0
        $lastProgressUpdate = 0
        $lastReportedIndex = 0
        
        foreach ($result in $results) {
            $userIndex++
            $statusTimestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            
            if ($result.Success) {
                if ($result.Interactions.Count -gt 0) {
                    # Write to user status CSV
                    $statusLine = "$($result.User),Success,$($result.Interactions.Count),,$statusTimestamp"
                    $statusLine | Out-File -FilePath $userStatusFile -Append -Encoding UTF8
                    
                    # Add userPrincipalName to each interaction (API doesn't always return it)
                    $result.Interactions | ForEach-Object {
                        if (-not $_.userPrincipalName) {
                            $_ | Add-Member -NotePropertyName 'userPrincipalName' -NotePropertyValue $result.User -Force
                        }
                    }
                    
                    $allInteractions += $result.Interactions
                    
                    # Update watermark (in-memory only - will save after successful export)
                    if ($UseWatermark -and $result.Interactions.Count -gt 0) {
                        $latestTimestamp = ($result.Interactions | Sort-Object -Property @{Expression={[DateTime]$_.createdDateTime}} -Descending | Select-Object -First 1).createdDateTime
                        Update-UserWatermark -WatermarkStore $script:watermarkStore -UserUpn $result.User -NewTimestamp ([DateTime]::Parse($latestTimestamp)) | Out-Null
                    }
                    
                    $successCount++
                }
                else {
                    # Write to user status CSV
                    $statusLine = "$($result.User),NoData,0,,$statusTimestamp"
                    $statusLine | Out-File -FilePath $userStatusFile -Append -Encoding UTF8
                    
                    $noDataCount++
                }
            }
            else {
                # Escape quotes in error message for CSV
                $errorMsg = $result.Error -replace '"', '""'
                $statusLine = "$($result.User),Error,0,""$errorMsg"",$statusTimestamp"
                $statusLine | Out-File -FilePath $userStatusFile -Append -Encoding UTF8
                
                $errorCount++
            }
            
            # Progress summarization (every 5% or minimum every 100 users) - show counts for THIS interval
            $percentComplete = [int](($userIndex / $targetUsers.Count) * 100)
            $shouldUpdate = ($percentComplete -ge ($lastProgressUpdate + 5)) -or 
                            ($userIndex % 100 -eq 0) -or 
                            ($userIndex -eq $targetUsers.Count)
            
            if ($shouldUpdate) {
                # Calculate counts since last progress report (interval counts, not cumulative)
                $usersInInterval = $userIndex - $lastReportedIndex
                $startIdx = $lastReportedIndex
                $endIdx = $userIndex - 1
                
                $intervalWithData = 0
                $intervalNoData = 0
                $intervalErrors = 0
                
                for ($i = $startIdx; $i -le $endIdx; $i++) {
                    $res = $results[$i]
                    if ($res.Success) {
                        if ($res.Interactions.Count -gt 0) {
                            $intervalWithData++
                        } else {
                            $intervalNoData++
                        }
                    } else {
                        $intervalErrors++
                    }
                }
                
                $lastProgressUpdate = $percentComplete
                $lastReportedIndex = $userIndex
                Write-Log "  [$percentComplete%] Processed $userIndex/$($targetUsers.Count) users (batch: $intervalWithData with data, $intervalNoData no data, $intervalErrors errors)" -Level Metric
            }
        }
    }
    else {
        # Sequential processing (PS 5.1 fallback or forced via -ParallelMode Off)
        $userIndex = 0
        $lastProgressUpdate = 0
        
        foreach ($upn in $targetUsers) {
            $userIndex++
            $statusTimestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            
            try {
                # Get watermark for this user if enabled
                $watermark = $null
                if ($UseWatermark) {
                    $wmValue = Get-UserWatermark -WatermarkStore $script:watermarkStore -UserPrincipalName $upn
                    # Validate it's a DateTime, or try parsing if it's a string
                    if ($wmValue -and $wmValue -is [DateTime]) {
                        $watermark = $wmValue
                    }
                    elseif ($wmValue -and $wmValue -is [string]) {
                        try {
                            $watermark = [DateTime]::Parse($wmValue)
                        }
                        catch {
                            # Invalid string format, skip watermark for this user
                        }
                    }
                }
                
                # Build URI with server-side filters (if supported)
                $uri = "https://graph.microsoft.com/v1.0/copilot/users/$upn/interactionHistory/getAllEnterpriseInteractions"
                $filterParts = @()
                
                # Server-side date filter (if supported and not using watermark)
                if ($script:serverSideDateFilterSupported -and -not $watermark) {
                    $startIso = $StartDate.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $endIso = $EndDate.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $filterParts += "createdDateTime ge $startIso and createdDateTime le $endIso"
                }
                
                # Watermark filter takes precedence over date filter (only if server-side date filtering supported)
                if ($watermark -and $script:serverSideDateFilterSupported) {
                    $watermarkIso = $watermark.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    $filterParts += "createdDateTime gt $watermarkIso"
                }
                
                # Server-side appClass filter (if supported and specific apps requested)
                if ($script:serverSideAppClassSupported -and $CopilotApps -and $CopilotApps -notcontains 'All') {
                    # Build OR condition for multiple apps
                    $appClassConditions = $CopilotApps | ForEach-Object { 
                        "appClass eq 'IPM.SkypeTeams.Message.Copilot.$_'" 
                    }
                    if ($appClassConditions.Count -eq 1) {
                        $filterParts += $appClassConditions[0]
                    } else {
                        $filterParts += "(" + ($appClassConditions -join ' or ') + ")"
                    }
                }
                
                # Apply filters to URI
                if ($filterParts.Count -gt 0) {
                    $filter = $filterParts -join ' and '
                    $filterEncoded = [System.Web.HttpUtility]::UrlEncode($filter)
                    $uri += "?`$filter=$filterEncoded"
                }
                
                # Paginate through all results
                $userInteractions = @()
                do {
                    $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject -ErrorAction Stop
                    if ($response.value) {
                        $userInteractions += $response.value
                    }
                    $uri = $response.'@odata.nextLink'
                } while ($uri)
                
                # Apply client-side date filtering if server-side not supported
                if (-not $script:serverSideDateFilterSupported -and $userInteractions.Count -gt 0) {
                    $userInteractions = $userInteractions | Where-Object {
                        $created = [DateTime]::Parse($_.createdDateTime)
                        # If watermark exists, only get interactions after it; otherwise use date range
                        if ($watermark) {
                            $created -gt $watermark
                        }
                        else {
                            $created -ge $StartDate -and $created -le $EndDate
                        }
                    }
                }
                
                # Apply client-side appClass filtering if server-side not supported
                if (-not $script:serverSideAppClassSupported -and $CopilotApps -and $CopilotApps -notcontains 'All' -and $userInteractions.Count -gt 0) {
                    $appClassList = $CopilotApps | ForEach-Object { "IPM.SkypeTeams.Message.Copilot.$_" }
                    $userInteractions = $userInteractions | Where-Object { $appClassList -contains $_.appClass }
                }
                
                if ($userInteractions.Count -gt 0) {
                    # Write to user status CSV
                    $statusLine = "$upn,Success,$($userInteractions.Count),,$statusTimestamp"
                    $statusLine | Out-File -FilePath $userStatusFile -Append -Encoding UTF8
                    
                    # Add userPrincipalName to each interaction (API doesn't always return it)
                    $userInteractions | ForEach-Object {
                        if (-not $_.userPrincipalName) {
                            $_ | Add-Member -NotePropertyName 'userPrincipalName' -NotePropertyValue $upn -Force
                        }
                    }
                    
                    $allInteractions += $userInteractions
                    
                    # Update watermark if enabled (in-memory only - will save after successful export)
                    if ($UseWatermark) {
                        $latestTimestamp = ($userInteractions | Sort-Object -Property @{Expression={[DateTime]$_.createdDateTime}} -Descending | Select-Object -First 1).createdDateTime
                        Update-UserWatermark -WatermarkStore $script:watermarkStore -UserPrincipalName $upn -LastTimestamp ([DateTime]::Parse($latestTimestamp))
                    }
                    
                    $successCount++
                }
                else {
                    # Write to user status CSV
                    $statusLine = "$upn,NoData,0,,$statusTimestamp"
                    $statusLine | Out-File -FilePath $userStatusFile -Append -Encoding UTF8
                    
                    $noDataCount++
                }
            }
            catch {
                # Escape quotes in error message for CSV
                $errorMsg = $_.Exception.Message -replace '"', '""'
                $statusLine = "$upn,Error,0,""$errorMsg"",$statusTimestamp"
                $statusLine | Out-File -FilePath $userStatusFile -Append -Encoding UTF8
                
                $errorCount++
            }
            
            # Progress summarization (every 5% or minimum every 100 users)
            $percentComplete = [int](($userIndex / $targetUsers.Count) * 100)
            $shouldUpdate = ($percentComplete -ge ($lastProgressUpdate + 5)) -or 
                            ($userIndex % 100 -eq 0) -or 
                            ($userIndex -eq $targetUsers.Count)
            
            if ($shouldUpdate) {
                $lastProgressUpdate = $percentComplete
                $withDataCount = $successCount
                Write-Log "  [$percentComplete%] Processed $userIndex/$($targetUsers.Count) users ($withDataCount with data, $noDataCount no data, $errorCount errors)" -Level Metric
            }
        }
    }
    
    # Summary
    Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
    Write-Log "COLLECTION SUMMARY" -Level Header
    Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
    Write-Log "Total users processed: $($targetUsers.Count)" -Level Metric
    Write-Log "With interactions: $successCount" -Level Success
    Write-Log "No interactions: $noDataCount" -Level Metric
    Write-Log "Errors: $errorCount" -Level $(if ($errorCount -gt 0) { 'Error' } else { 'Metric' })
    Write-Log "Total interactions collected: $($allInteractions.Count)" -Level Highlight
    
    # Display watermark information if used (show even when no data collected)
    if ($UseWatermark -and $script:watermarkStore -and $script:watermarkStore.Count -gt 0) {
        Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
        Write-Log "Watermark Information:" -Level Highlight
        
        # Check if watermark file existed before this run (indicates filtering was active)
        $watermarkFileExistedBefore = $false
        if (Test-Path $WatermarkFile) {
            $watermarkFileAge = (Get-Date) - (Get-Item $WatermarkFile).LastWriteTime
            # If file was written more than 10 seconds ago, it existed before this run
            if ($watermarkFileAge.TotalSeconds -gt 10) {
                $watermarkFileExistedBefore = $true
            }
        }
        
        if ($watermarkFileExistedBefore) {
            Write-Log "  Watermark filtering: ACTIVE (incremental data retrieval)" -Level Metric
        }
        else {
            Write-Log "  Watermark tracking: ENABLED (first run - full data retrieval)" -Level Metric
        }
        
        Write-Log "  Users tracked: $($script:watermarkStore.Count)" -Level Metric
        
        # Find earliest and latest watermark timestamps
        $timestamps = $script:watermarkStore.Values | Where-Object { $_ -is [DateTime] }
        if ($timestamps) {
            $earliestWatermark = ($timestamps | Measure-Object -Minimum).Minimum
            $latestWatermark = ($timestamps | Measure-Object -Maximum).Maximum
            Write-Log "  Earliest watermark: $($earliestWatermark.ToString('yyyy-MM-dd HH:mm:ss'))" -Level Metric
            Write-Log "  Latest watermark: $($latestWatermark.ToString('yyyy-MM-dd HH:mm:ss'))" -Level Metric
            
            if ($watermarkFileExistedBefore) {
                Write-Log "  → Data retrieved: Records AFTER each user's watermark timestamp" -Level Info
            }
            else {
                Write-Log "  → Next run will retrieve only records AFTER these timestamps" -Level Info
            }
        }
    }
    
    if ($allInteractions.Count -eq 0) {
        if ($UseWatermark) {
            Write-Log "No new interactions found beyond existing watermark timestamps. All data is up to date." -Level Info
        } else {
            Write-Log "No interactions found for the specified date range and users." -Level Info
        }
        Write-Log "Exiting (no data to export)." -Level Info
        return
    }
    
    # Check if oldest returned data is newer than requested StartDate (skip when using watermarks)
    if ($allInteractions.Count -gt 0 -and -not $UseWatermark) {
        $oldestInteraction = ($allInteractions | Sort-Object { [DateTime]$_.createdDateTime } | Select-Object -First 1).createdDateTime
        $oldestDate = [DateTime]$oldestInteraction
        
        if ($oldestDate -gt $StartDate) {
            $daysDifference = [math]::Round(($oldestDate - $StartDate).TotalDays, 1)
            Write-Log "NOTICE: Oldest data returned is from $($oldestDate.ToString('yyyy-MM-dd')), which is $daysDifference days newer than requested StartDate ($($StartDate.ToString('yyyy-MM-dd'))). This may be due to tenant data retention limits (licensing/configuration) or no Copilot usage occurred before $($oldestDate.ToString('yyyy-MM-dd'))." -Level Highlight
        }
    }
    
    # Transform JSON to output schema
    Write-Log "Transforming data to output schema..." -Level Processing
    Write-Log "  Exploding body content into ContentType and Content columns" -Level Info
    $transformedData = @()
    
    foreach ($interaction in $allInteractions) {
        $paxRecord = [PSCustomObject]@{
            # Core identifiers
            RecordId = $interaction.id
            SessionId = $interaction.sessionId
            RequestId = $interaction.requestId
            
            # Timestamps
            CreationDate = $interaction.createdDateTime
            LastModifiedDate = $interaction.lastModifiedDateTime
            
            # User and app context
            UserId = $interaction.userPrincipalName
            InteractionType = $interaction.interactionType
            ConversationType = $interaction.conversationType
            
            # Content - explode body object into separate columns
            ContentType = if ($IncludeBody -and $interaction.body -and $interaction.body.contentType) {
                $interaction.body.contentType
            } else {
                ""
            }
            
            Content = if ($IncludeBody -and $interaction.body -and $interaction.body.content) {
                $contentText = $interaction.body.content
                if ($MaxBodyLength -gt 0 -and $contentText.Length -gt $MaxBodyLength) {
                    $contentText.Substring(0, $MaxBodyLength)
                } else {
                    $contentText
                }
            } else {
                ""
            }
            
            # Contexts (joined as string)
            Contexts = if ($interaction.contexts) {
                ($interaction.contexts | ForEach-Object { "$($_.contextType): $($_.contextReference)" }) -join "; "
            } else {
                ""
            }
            
            # Metadata
            Operation = 'CopilotInteraction'
            AppClass = $interaction.appClass
        }
        
        $transformedData += $paxRecord
    }
    
    Write-Log "✓ Transformed $($transformedData.Count) record(s)" -Level Success
    
    # Export results (unified path for CSV and Excel)
    $timestamp = $ScriptTimestamp
    
    if ($ExportWorkbook) {
        # Excel export: First export to CSV, then convert to Excel (matches Purview pattern)
        $outputFile = if ($AppendFile) {
            if ([System.IO.Path]::IsPathRooted($AppendFile)) { $AppendFile } else { Join-Path $OutputPath $AppendFile }
        } else {
            Join-Path $OutputPath "CopilotInteractions_Content_$timestamp.xlsx"
        }
        
        try {
            # Step 1: Export to temporary CSV
            $tempCsvFile = Join-Path $OutputPath "CopilotInteractions_Content_$timestamp.csv"
            Write-Log "  Exporting to temporary CSV for Excel conversion..." -Level Info
            $transformedData | Export-Csv -Path $tempCsvFile -NoTypeInformation -Encoding UTF8 -Force
            
            # Step 2: Import CSV data
            $csvData = Import-Csv -Path $tempCsvFile -ErrorAction Stop
            
            # Step 3: Export to Excel
            $exportParams = @{
                AllResults = $csvData
                OutputFile = $outputFile
                AppendMode = ($null -ne $AppendFile)
            }
            if ($script:EntraCache) {
                $exportParams['EntraCache'] = $script:EntraCache
            }
            Export-ResultsToExcel @exportParams | Out-Null
            
            # Step 4: Clean up temporary CSV
            Remove-Item -Path $tempCsvFile -Force -ErrorAction SilentlyContinue
            
            $fileSize = [math]::Round((Get-Item $outputFile).Length / 1MB, 2)
        }
        catch {
            Write-Log "✗ Excel export failed: $($_.Exception.Message)" -Level Error
            throw
        }
    }
    else {
        # CSV export
        $outputFile = if ($AppendFile) {
            if ([System.IO.Path]::IsPathRooted($AppendFile)) { $AppendFile } else { Join-Path $OutputPath $AppendFile }
        } else {
            Join-Path $OutputPath "CopilotInteractions_Content_$timestamp.csv"
        }
        
        try {
            if ($AppendFile) {
                # Append mode: validate and append
                if (Test-Path $outputFile) {
                    $existingHeaders = (Get-Content $outputFile -First 1) -split ',' | ForEach-Object { $_.Trim('"') }
                    $newHeaders = $transformedData[0].PSObject.Properties.Name
                    
                    $headerMismatch = $false
                    if ($existingHeaders.Count -ne $newHeaders.Count) {
                        $headerMismatch = $true
                    } else {
                        for ($i = 0; $i -lt $existingHeaders.Count; $i++) {
                            if ($existingHeaders[$i] -ne $newHeaders[$i]) {
                                $headerMismatch = $true
                                break
                            }
                        }
                    }
                    
                    if ($headerMismatch) {
                        $timestampedFile = Join-Path $OutputPath "CopilotInteractions_Content_$timestamp.csv"
                        Write-Log "⚠ CSV header mismatch detected. Creating new timestamped file instead of appending." -Level Warning
                        Write-Log "Existing columns: $($existingHeaders.Count), New data columns: $($newHeaders.Count)" -Level Warning
                        Write-Log "New file: $timestampedFile" -Level Info
                        $outputFile = $timestampedFile
                        $transformedData | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
                        Write-Log "✓ Created new CSV with $($transformedData.Count) rows" -Level Success
                    } else {
                        # Append without headers
                        $transformedData | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8 -Append
                        Write-Log "✓ Appended $($transformedData.Count) rows to existing CSV" -Level Success
                    }
                } else {
                    Write-Log "✗ AppendFile target does not exist: $outputFile" -Level Error
                    throw "AppendFile target not found"
                }
            } else {
                # New file mode
                $transformedData | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
            }
            
            $fileSize = [math]::Round((Get-Item $outputFile).Length / 1MB, 2)
            Write-Log "✓ CSV export complete ($fileSize MB)" -Level Success
            
            # Generate CSV stats files if requested
            if ($IncludeStats) {
                Write-Log "Generating statistics files..." -Level Processing
                
                # Stats by User
                $userStats = $transformedData | Where-Object { $_.UserId } | Group-Object UserId | ForEach-Object {
                    $promptLengths = $_.Group | Where-Object { $_.InteractionType -eq 'userPrompt' -and $_.Content } | ForEach-Object { $_.Content.Length }
                    $responseLengths = $_.Group | Where-Object { $_.InteractionType -eq 'aiResponse' -and $_.Content } | ForEach-Object { $_.Content.Length }
                    [PSCustomObject]@{
                        UserId = $_.Name
                        TotalMessages = $_.Count
                        Prompts = ($_.Group | Where-Object { $_.InteractionType -eq 'userPrompt' }).Count
                        Responses = ($_.Group | Where-Object { $_.InteractionType -eq 'aiResponse' }).Count
                        TotalCharactersPrompts = ($promptLengths | Measure-Object -Sum).Sum
                        TotalCharactersResponses = ($responseLengths | Measure-Object -Sum).Sum
                        AvgCharactersPerPrompt = if ($promptLengths) { [Math]::Round(($promptLengths | Measure-Object -Average).Average, 0) } else { 0 }
                        AvgCharactersPerResponse = if ($responseLengths) { [Math]::Round(($responseLengths | Measure-Object -Average).Average, 0) } else { 0 }
                    }
                }
                $userStatsFile = Join-Path $OutputPath "CopilotInteractions_StatsByUser_$timestamp.csv"
                $userStats | Export-Csv -Path $userStatsFile -NoTypeInformation -Encoding UTF8
                
                # Stats by App
                $appStats = $transformedData | Group-Object AppClass | ForEach-Object {
                    [PSCustomObject]@{
                        AppClass = $_.Name
                        TotalMessages = $_.Count
                        Prompts = ($_.Group | Where-Object { $_.InteractionType -eq 'userPrompt' }).Count
                        Responses = ($_.Group | Where-Object { $_.InteractionType -eq 'aiResponse' }).Count
                        UniqueUsers = ($_.Group | Select-Object -ExpandProperty UserId -Unique).Count
                    }
                }
                $appStatsFile = Join-Path $OutputPath "CopilotInteractions_StatsByApp_$timestamp.csv"
                $appStats | Export-Csv -Path $appStatsFile -NoTypeInformation -Encoding UTF8
                
                # Stats by Date
                $dateStats = $transformedData | Where-Object { $_.CreationDate } | ForEach-Object {
                    $_ | Add-Member -NotePropertyName 'InteractionDate' -NotePropertyValue ([DateTime]::Parse($_.CreationDate).ToString('yyyy-MM-dd')) -Force -PassThru
                } | Group-Object InteractionDate | ForEach-Object {
                    [PSCustomObject]@{
                        Date = $_.Name
                        TotalMessages = $_.Count
                        Prompts = ($_.Group | Where-Object { $_.InteractionType -eq 'userPrompt' }).Count
                        Responses = ($_.Group | Where-Object { $_.InteractionType -eq 'aiResponse' }).Count
                        UniqueUsers = ($_.Group | Select-Object -ExpandProperty UserId -Unique).Count
                    }
                }
                $dateStatsFile = Join-Path $OutputPath "CopilotInteractions_StatsByDate_$timestamp.csv"
                $dateStats | Export-Csv -Path $dateStatsFile -NoTypeInformation -Encoding UTF8
            }
            
            # Export EntraUsers_MAClicensing CSV if -IncludeUserInfo was used
            if ($IncludeUserInfo -and $script:EntraCache -and $script:EntraCache.Count -gt 0) {
                Write-Log "Exporting Entra users with MAC licensing data..." -Level Processing
                $entraData = $script:EntraCache.Values | Sort-Object userPrincipalName -Unique
                if ($entraData) {
                    $entraUsersFile = Join-Path $OutputPath "EntraUsers_MAClicensing_$timestamp.csv"
                    $entraData | Export-Csv -Path $entraUsersFile -NoTypeInformation -Encoding UTF8
                }
            }
        }
        catch {
            Write-Log "✗ CSV export failed: $($_.Exception.Message)" -Level Error
            throw
        }
    }
    
    # Save watermark store (after successful export, regardless of CSV or Excel)
    if ($UseWatermark) {
        Export-WatermarkStore -WatermarkStore $script:watermarkStore -WatermarkFile $WatermarkFile | Out-Null
    }
    
    # Emit metrics JSON if requested
    if ($EmitMetricsJson) {
        $metricsFile = if ($MetricsPath) { $MetricsPath } else { Join-Path $OutputPath "metrics_$timestamp.json" }
        Write-Log "Exporting metrics JSON: $metricsFile" -Level Info
        
        $metrics = @{
            ScriptVersion = $ScriptVersion
            ExecutionTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            Parameters = @{
                StartDate = $StartDate.ToString('yyyy-MM-dd')
                EndDate = $EndDate.ToString('yyyy-MM-dd')
                CopilotApps = $CopilotApps
                UseWatermark = $UseWatermark.IsPresent
            }
            Results = @{
                TotalUsers = $userIndex
                SuccessfulUsers = $successCount
                FailedUsers = $errorCount
                TotalInteractions = $transformedData.Count
                UniqueUsers = ($transformedData | Select-Object -ExpandProperty UserId -Unique).Count
                UniqueSessions = ($transformedData | Select-Object -ExpandProperty SessionId -Unique).Count
            }
            OutputFile = $outputFile
        }
        
        $metrics | ConvertTo-Json -Depth 10 | Out-File -FilePath $metricsFile -Encoding UTF8
        Write-Log "✓ Metrics exported: $metricsFile" -Level Success
    }

    # Disconnect from Graph
    try {
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if ($context) {
            Write-Log "Disconnecting from Microsoft Graph..." -Level Info
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            Write-Log "✓ Disconnected from Microsoft Graph" -Level Success
        }
    }
    catch {
        # Silently ignore disconnection errors
    }
    
    Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
    Write-Log "SCRIPT EXECUTION COMPLETED" -Level Header
    Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
    
    # Calculate elapsed time
    $elapsedTime = (Get-Date) - $ScriptStartTime
    $elapsedFormatted = if ($elapsedTime.TotalHours -ge 1) {
        "{0:D2}h {1:D2}m {2:D2}s" -f $elapsedTime.Hours, $elapsedTime.Minutes, $elapsedTime.Seconds
    } elseif ($elapsedTime.TotalMinutes -ge 1) {
        "{0:D2}m {1:D2}s" -f $elapsedTime.Minutes, $elapsedTime.Seconds
    } else {
        "{0:D2}s" -f $elapsedTime.Seconds
    }
    
    Write-Log "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Metric
    Write-Log "Elapsed time: $elapsedFormatted" -Level Metric
    Write-Log "Script version: v$ScriptVersion" -Level Metric
    Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
    Write-Log "Output Files Generated:" -Level Highlight
    
    # List main output file
    if ($outputFile -and (Test-Path $outputFile)) {
        $outputFileSize = [math]::Round((Get-Item $outputFile).Length / 1MB, 2)
        Write-Log "  Main Output: $outputFile ($outputFileSize MB)" -Level Highlight
        
        # If Excel workbook, list worksheet tabs
        if ($ExportWorkbook) {
            Write-Log "    Worksheets:" -Level Highlight
            Write-Log "      - CopilotInteractions_Content" -Level Highlight
            if ($IncludeStats) {
                Write-Log "      - StatsByUser" -Level Highlight
                Write-Log "      - StatsByApp" -Level Highlight
                Write-Log "      - StatsByDate" -Level Highlight
            }
            if ($IncludeUserInfo -and $EntraCache -and $EntraCache.Count -gt 0) {
                Write-Log "      - EntraUsers_MAClicensing" -Level Highlight
            }
        }
    }
    
    # List stats files if generated
    if ($IncludeStats) {
        if ($userStatsFile -and (Test-Path $userStatsFile)) {
            $statsSize = [math]::Round((Get-Item $userStatsFile).Length / 1KB, 2)
            Write-Log "  User Stats: $userStatsFile ($statsSize KB)" -Level Highlight
        }
        if ($appStatsFile -and (Test-Path $appStatsFile)) {
            $statsSize = [math]::Round((Get-Item $appStatsFile).Length / 1KB, 2)
            Write-Log "  App Stats: $appStatsFile ($statsSize KB)" -Level Highlight
        }
        if ($dateStatsFile -and (Test-Path $dateStatsFile)) {
            $statsSize = [math]::Round((Get-Item $dateStatsFile).Length / 1KB, 2)
            Write-Log "  Date Stats: $dateStatsFile ($statsSize KB)" -Level Highlight
        }
    }
    
    # List metrics file if generated
    if ($EmitMetricsJson -and $metricsFile -and (Test-Path $metricsFile)) {
        $metricsSize = [math]::Round((Get-Item $metricsFile).Length / 1KB, 2)
        Write-Log "  Metrics JSON: $metricsFile ($metricsSize KB)" -Level Highlight
    }
    
    # List Entra users file if generated (only when -IncludeUserInfo is used)
    if (($IncludeUserInfo -or $OnlyUserInfo) -and $entraUsersFile -and (Test-Path $entraUsersFile)) {
        $entraSize = [math]::Round((Get-Item $entraUsersFile).Length / 1KB, 2)
        Write-Log "  Entra Users (MAC Licensing): $entraUsersFile ($entraSize KB)" -Level Highlight
    }
    
    # List user status CSV
    if ($userStatusFile -and (Test-Path $userStatusFile)) {
        $userStatusSize = [math]::Round((Get-Item $userStatusFile).Length / 1KB, 2)
        Write-Log "  User Status CSV: $userStatusFile ($userStatusSize KB)" -Level Highlight
    }
    
    # List watermark file if -UseWatermark was used
    if ($UseWatermark -and $WatermarkFile -and (Test-Path $WatermarkFile)) {
        $watermarkSize = [math]::Round((Get-Item $WatermarkFile).Length / 1KB, 2)
        Write-Log "  Watermark File: $WatermarkFile ($watermarkSize KB)" -Level Highlight
    }
    
    # List log file
    if ($Global:LogFile -and (Test-Path $Global:LogFile)) {
        $logSize = [math]::Round((Get-Item $Global:LogFile).Length / 1KB, 2)
        Write-Log "  Log File: $Global:LogFile ($logSize KB)" -Level Highlight
    }
    
    Write-Log "═══════════════════════════════════════════════════════════════" -Level Header
}
catch {
    Write-Log "═══════════════════════════════════════════════════════════════" -Level Error
    Write-Log "FATAL ERROR" -Level Error
    Write-Log "═══════════════════════════════════════════════════════════════" -Level Error
    Write-Log "Error: $($_.Exception.Message)" -Level Error
    
    if ($_.ScriptStackTrace) {
        Write-Log "Stack Trace:" -Level Error
        Write-Log $_.ScriptStackTrace -Level Error
    }
    
    Write-Log "═══════════════════════════════════════════════════════════════" -Level Error
    
    # Clean up temporary files
    try {
        if ($script:AppendFileTempCsv -and (Test-Path $script:AppendFileTempCsv -ErrorAction SilentlyContinue)) {
            Remove-Item -Path $script:AppendFileTempCsv -Force -ErrorAction SilentlyContinue
        }
        if ($WatermarkFile -and (Test-Path "$WatermarkFile.tmp" -ErrorAction SilentlyContinue)) {
            Remove-Item -Path "$WatermarkFile.tmp" -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        # Silently ignore
    }
    
    # Try to disconnect from Graph
    try {
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if ($context) {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        }
    }
    catch {
        # Silently ignore
    }
    
    throw
}

#endregion
