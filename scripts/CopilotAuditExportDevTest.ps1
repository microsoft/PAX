#Requires -Modules ExchangeOnlineManagement

param(
    [Parameter(Mandatory = $false)]
    [string]$StartDate,
    [Parameter(Mandatory = $false)]
    [string]$EndDate,
    [Parameter(Mandatory = $false)]
    [string[]]$ActivityTypes = @("CopilotInteraction"),
    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "$([System.IO.Path]::GetTempPath())PAX_DevTest_Export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
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
    [string]$LogFile,
    [Parameter(Mandatory = $false)]
    [switch]$Help,
    [Parameter(Mandatory = $false)]
    [switch]$InHelper
)

function Show-Help {
    @"
Microsoft 365 Dev Test Mode - CopilotInteraction Simulator
----------------------------------------------------------
This is a DEVELOPMENT TEST script that simulates CopilotInteraction data by:
1. Filtering for Operation='Create' instead of CopilotInteraction 
2. Replacing Operation values with 'CopilotInteraction' in output
3. Setting RecordType=261 and Workload='MicrosoftCopilot'
4. Generating synthetic CopilotEventData JSON structures

WARNING: This is for testing only and will be removed in production.

USAGE EXAMPLES:
---------------
  .\CopilotAuditExportDevTest.ps1 -StartDate "2025-09-01" -EndDate "2025-09-02"

PARAMETERS:
-----------
Same as main CopilotAuditExport.ps1 script.
"@
}

# Generate synthetic CopilotEventData for dev test
function New-SyntheticCopilotEventData {
    param(
        [string]$UserId,
        [string]$RecordId
    )
    
    # Generate consistent IDs based on user and record
    $userHash = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($UserId))
    $userSeed = [BitConverter]::ToUInt32($userHash, 0) % 1000000
    
    $recordHash = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RecordId))
    $recordSeed = [BitConverter]::ToUInt32($recordHash, 0) % 1000000
    
    # Generate consistent ThreadId per user
    $threadId = "19:$(($userSeed.ToString("X8") + $recordSeed.ToString("X4")).ToLower())@thread.v2"
    
    # Vary AppHost based on record
    $appHosts = @("Teams", "Word", "Office", "Outlook")
    $appHost = $appHosts[$recordSeed % $appHosts.Count]
    
    # Generate realistic MessageIds
    $messageCount = ($recordSeed % 3) + 1
    $messages = @()
    for ($i = 0; $i -lt $messageCount; $i++) {
        $isPrompt = ($i % 2) -eq 0
        $messageId = "$((Get-Date).Ticks + $i)000"
        $messages += @{ "Id" = $messageId; "isPrompt" = $isPrompt }
    }
    
    # Generate realistic AccessedResources
    $resources = @()
    if ($appHost -eq "Teams") {
        $resources += @{
            "Action"        = "Read"
            "PolicyDetails" = "[{`"PolicyType`":`"Purview`",`"PolicyOutcomes`":[`"None`"],`"AuditLog`":`"`"}]"
            "SiteUrl"       = "https://teams.microsoft.com/l/message/19:$($userSeed.ToString("x8"))@thread.v2/$((Get-Date).Ticks)?context=%7B%22contextType%22:%22chat%22%7D"
            "Type"          = "TeamsMessage"
        }
    }
    elseif ($appHost -eq "Word") {
        $resources += @{
            "Action"           = "Read"
            "Id"               = "https://contoso.sharepoint.com/sites/TestSite/_layouts/15/Doc.aspx?sourcedoc=%7B$($recordSeed.ToString("X8"))-0000-0000-0000-000000000000%7D&file=Test%20Document.docx&action=edit"
            "Name"             = "Test Document.docx"
            "PolicyDetails"    = "[{`"PolicyType`":`"Purview`",`"PolicyOutcomes`":[`"None`"],`"AuditLog`":`"`"}]"
            "Type"             = "docx"
            "listItemUniqueId" = "$($recordSeed.ToString("x8"))-0000-0000-0000-000000000000"
        }
    }
    
    $copilotEventData = @{
        "AISystemPlugin"           = @(@{ "Id" = "BingWebSearch"; "Name" = "BuiltIn" })
        "AccessedResources"        = $resources
        "AppHost"                  = $appHost
        "Contexts"                 = @()
        "MessageIds"               = @()
        "Messages"                 = $messages
        "ModelTransparencyDetails" = @(@{ "ModelName" = "DEEP_LEO" })
        "ThreadId"                 = $threadId
    }
    
    return $copilotEventData | ConvertTo-Json -Depth 10 -Compress
}

# Import the main script functions by dot-sourcing (exclude the main execution)
$mainScriptPath = Join-Path $PSScriptRoot "CopilotAuditExport.ps1"
if (Test-Path $mainScriptPath) {
    # Read the main script content but skip execution
    $mainScriptContent = Get-Content $mainScriptPath -Raw
    
    # Extract only the functions (everything between function definitions and before the main execution)
    $functionsOnly = $mainScriptContent -replace '(?s)^.*?(?=function\s)', '' -replace '(?s)# Main execution.*$', ''
    
    # Execute the functions
    Invoke-Expression $functionsOnly
}

# Override the main execution for dev test mode
if (-not $InHelper) {
    if ($Help) {
        Show-Help
        return
    }

    Write-Host "🧪 DEV TEST MODE - CopilotInteraction Simulator" -ForegroundColor Yellow
    Write-Host "   Filtering for Operation='Create' and converting to synthetic CopilotInteraction data" -ForegroundColor Yellow
    
    # Force specific settings for dev test
    $originalActivityTypes = $ActivityTypes
    $ActivityTypes = @("Create")  # Override to search for Create operations
    
    # Call main script logic with Create filter
    try {
        # Set up the same initialization as main script
        $startDateObj = if ($StartDate) { [DateTime]::Parse($StartDate) } else { (Get-Date).AddDays(-1).Date }
        $endDateObj = if ($EndDate) { [DateTime]::Parse($EndDate) } else { (Get-Date).Date }
        
        Write-Host "Dev Test: Searching for Operation='Create' from $($startDateObj.ToString('yyyy-MM-dd')) to $($endDateObj.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
        
        # Execute the main audit search logic with Create operation filter
        # This will call the same functions but search for "Create" operations
        $results = @()
        
        # Call the search with "Create" as operation filter
        foreach ($timeBlock in @($startDateObj..$endDateObj)) {
            $blockEnd = $timeBlock.AddHours($BlockHours)
            $logs = Invoke-SearchUnifiedAuditLogWithRetry -Start $timeBlock -End $blockEnd -Operation "Create" -ResultSize $ResultSize -PacingMs $PacingMs
            
            if ($logs) {
                foreach ($log in $logs) {
                    # Transform the log to simulate CopilotInteraction
                    $auditData = $log.AuditData | ConvertFrom-Json
                    
                    # Override key fields to simulate CopilotInteraction
                    $auditData.Operation = "CopilotInteraction"
                    $auditData.RecordType = 261
                    $auditData.Workload = "MicrosoftCopilot"
                    
                    # Generate synthetic CopilotEventData
                    $syntheticEventData = New-SyntheticCopilotEventData -UserId $auditData.UserId -RecordId $auditData.Id
                    $copilotEventData = $syntheticEventData | ConvertFrom-Json
                    $auditData | Add-Member -MemberType NoteProperty -Name "CopilotEventData" -Value $copilotEventData -Force
                    $auditData | Add-Member -MemberType NoteProperty -Name "CopilotLogVersion" -Value "1.0.0.0" -Force
                    
                    # Convert back to JSON
                    $log.AuditData = $auditData | ConvertTo-Json -Depth 10 -Compress
                    $results += $log
                }
            }
        }
        
        Write-Host "Dev Test: Found $($results.Count) Create operations, converted to CopilotInteraction format" -ForegroundColor Green
        
        # Export the results
        if ($results.Count -gt 0) {
            if ($NoExplodeArrays) {
                # Keep AuditData as single JSON column
                $results | Export-Csv -Path $OutputFile -NoTypeInformation
            }
            else {
                # Explode arrays (default behavior)
                $exploded = @()
                foreach ($result in $results) {
                    $auditObj = $result.AuditData | ConvertFrom-Json
                    $flattened = Expand-AuditDataProperties -AuditData $auditObj -BaseRecord $result
                    $exploded += $flattened
                }
                $exploded | Export-Csv -Path $OutputFile -NoTypeInformation
            }
            
            Write-Host "✅ Dev test export completed: $OutputFile" -ForegroundColor Green
            Write-Host "📊 Records exported: $($results.Count)" -ForegroundColor Green
        }
        else {
            Write-Host "⚠️  No Create operations found in the specified time range" -ForegroundColor Yellow
        }
        
    }
    catch {
        Write-Error "Dev test failed: $($_.Exception.Message)"
        Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    }
}