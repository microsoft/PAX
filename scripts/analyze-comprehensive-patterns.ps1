# Comprehensive Pattern Analysis Script
# Analyzes all 367k+ records in Sample_Purview_Copilot_Usage_Export.csv
# Extracts every unique pattern for maximum synthetic data authenticity

param(
    [string]$InputFile = "..\output\Sample_Purview_Copilot_Usage_Export.csv",
    [string]$OutputFile = "comprehensive-patterns.json"
)

Write-Host "Starting comprehensive analysis of all records..." -ForegroundColor Green

# Initialize pattern collections
$patterns = @{
    AppHost = @{}
    AgentId = @{}
    AgentName = @{}
    CorrelationId = @{}
    ModelTransparencyDetails = @{}
    AISystemPlugin = @{}
    AccessedResources = @{}
    SensitivityLabelId = @{}
    ThreadId = @{}
    MessageId = @{}
    ChatId = @{}
    ConversationId = @{}
    RequestId = @{}
    ContextType = @{}
    ContextValue = @{}
    ContextId = @{}
    Scenarios = @{}
    MessageType = @{}
    AppName = @{}
    ModuleName = @{}
    Outcome = @{}
    ActionType = @{}
    Type = @{}
    Context = @{}
    InteractionType = @{}
    TotalRecords = 0
    CopilotRecords = 0
    ProcessingErrors = 0
}

# Read file line by line to handle large size
$lineCount = 0
$batchSize = 1000
$startTime = Get-Date

Write-Host "Reading file: $InputFile"
Get-Content $InputFile | ForEach-Object {
    $lineCount++
    
    # Skip header
    if ($lineCount -eq 1) { return }
    
    # Progress indicator
    if ($lineCount % $batchSize -eq 0) {
        $elapsed = (Get-Date) - $startTime
        $rate = $lineCount / $elapsed.TotalSeconds
        $eta = [TimeSpan]::FromSeconds(($totalLines - $lineCount) / $rate)
        Write-Host "Processed $lineCount lines... Rate: $([math]::Round($rate, 0)) lines/sec, ETA: $($eta.ToString('hh\:mm\:ss'))" -ForegroundColor Yellow
    }
    
    try {
        # Split CSV line (handle embedded commas in JSON)
        $fields = $_ -split ',', 7
        if ($fields.Length -lt 7) { return }
        
        $auditData = $fields[6]
        $patterns.TotalRecords++
        
        # Only process CopilotInteraction records
        if ($auditData -notlike '*CopilotInteraction*') { return }
        
        $patterns.CopilotRecords++
        
        # Parse JSON
        $json = $auditData | ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not $json) { 
            $patterns.ProcessingErrors++
            return 
        }
        
        # Extract AppHost
        if ($json.AppHost) {
            $patterns.AppHost[$json.AppHost] = ($patterns.AppHost[$json.AppHost] ?? 0) + 1
        }
        
        # Extract Agent details
        if ($json.AgentId) {
            $patterns.AgentId[$json.AgentId] = ($patterns.AgentId[$json.AgentId] ?? 0) + 1
        }
        if ($json.AgentName) {
            $patterns.AgentName[$json.AgentName] = ($patterns.AgentName[$json.AgentName] ?? 0) + 1
        }
        
        # Extract CorrelationId patterns
        if ($json.CorrelationId) {
            # Extract pattern (preserve format but anonymize)
            $pattern = $json.CorrelationId -replace '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', 'GUID'
            $pattern = $pattern -replace '\d+', 'NUM'
            $patterns.CorrelationId[$pattern] = ($patterns.CorrelationId[$pattern] ?? 0) + 1
        }
        
        # Extract nested arrays and objects
        if ($json.ModelTransparencyDetails) {
            $json.ModelTransparencyDetails | ForEach-Object {
                if ($_.Model) {
                    $patterns.ModelTransparencyDetails[$_.Model] = ($patterns.ModelTransparencyDetails[$_.Model] ?? 0) + 1
                }
            }
        }
        
        if ($json.AISystemPlugin) {
            $json.AISystemPlugin | ForEach-Object {
                if ($_.Name) {
                    $patterns.AISystemPlugin[$_.Name] = ($patterns.AISystemPlugin[$_.Name] ?? 0) + 1
                }
            }
        }
        
        if ($json.AccessedResources) {
            $json.AccessedResources | ForEach-Object {
                if ($_.SensitivityLabelId) {
                    $patterns.SensitivityLabelId[$_.SensitivityLabelId] = ($patterns.SensitivityLabelId[$_.SensitivityLabelId] ?? 0) + 1
                }
                # Extract URL patterns
                if ($_.Url) {
                    $urlPattern = $_.Url -replace 'https://[^/]+', 'https://DOMAIN'
                    $urlPattern = $urlPattern -replace '/[a-f0-9-]{36}', '/GUID'
                    $urlPattern = $urlPattern -replace '\d+', 'NUM'
                    $patterns.AccessedResources[$urlPattern] = ($patterns.AccessedResources[$urlPattern] ?? 0) + 1
                }
            }
        }
        
        # Extract Context arrays
        if ($json.Context) {
            $json.Context | ForEach-Object {
                if ($_.Type) {
                    $patterns.ContextType[$_.Type] = ($patterns.ContextType[$_.Type] ?? 0) + 1
                }
                if ($_.Value) {
                    $valuePattern = $_.Value -replace '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', 'GUID'
                    $valuePattern = $valuePattern -replace '\d+', 'NUM'
                    $patterns.ContextValue[$valuePattern] = ($patterns.ContextValue[$valuePattern] ?? 0) + 1
                }
                if ($_.Id) {
                    $patterns.ContextId[$_.Id] = ($patterns.ContextId[$_.Id] ?? 0) + 1
                }
            }
        }
        
        # Extract Scenarios
        if ($json.Scenarios) {
            $json.Scenarios | ForEach-Object {
                $patterns.Scenarios[$_] = ($patterns.Scenarios[$_] ?? 0) + 1
            }
        }
        
        # Extract various ID patterns
        @('ThreadId', 'MessageId', 'ChatId', 'ConversationId', 'RequestId') | ForEach-Object {
            $field = $_
            if ($json.$field) {
                $patterns.$field[$json.$field] = ($patterns.$field[$json.$field] ?? 0) + 1
            }
        }
        
        # Extract enum-like fields
        @('MessageType', 'AppName', 'ModuleName', 'Outcome', 'ActionType', 'Type', 'InteractionType') | ForEach-Object {
            $field = $_
            if ($json.$field) {
                $patterns.$field[$json.$field] = ($patterns.$field[$json.$field] ?? 0) + 1
            }
        }
        
    } catch {
        $patterns.ProcessingErrors++
        Write-Warning "Error processing line $lineCount : $_"
    }
}

$endTime = Get-Date
$totalTime = $endTime - $startTime

Write-Host "`nAnalysis Complete!" -ForegroundColor Green
Write-Host "Total Records Processed: $($patterns.TotalRecords)" -ForegroundColor Cyan
Write-Host "CopilotInteraction Records: $($patterns.CopilotRecords)" -ForegroundColor Cyan
Write-Host "Processing Errors: $($patterns.ProcessingErrors)" -ForegroundColor Yellow
Write-Host "Total Processing Time: $($totalTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan

# Convert to percentages and sort by frequency
$results = @{}
foreach ($category in $patterns.Keys) {
    if ($category -in @('TotalRecords', 'CopilotRecords', 'ProcessingErrors')) { 
        $results[$category] = $patterns[$category]
        continue 
    }
    
    $total = ($patterns[$category].Values | Measure-Object -Sum).Sum
    if ($total -eq 0) { continue }
    
    $results[$category] = @{
        TotalOccurrences = $total
        UniqueValues = $patterns[$category].Count
        Distribution = @()
    }
    
    $patterns[$category].GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        $percentage = [math]::Round(($_.Value / $total) * 100, 2)
        $results[$category].Distribution += @{
            Value = $_.Key
            Count = $_.Value
            Percentage = $percentage
        }
    }
}

# Save comprehensive results
$results | ConvertTo-Json -Depth 10 | Out-File $OutputFile -Encoding UTF8
Write-Host "Results saved to: $OutputFile" -ForegroundColor Green

# Display summary
Write-Host "`n=== COMPREHENSIVE PATTERN SUMMARY ===" -ForegroundColor Magenta
foreach ($category in $results.Keys | Sort-Object) {
    if ($category -in @('TotalRecords', 'CopilotRecords', 'ProcessingErrors')) { continue }
    
    $data = $results[$category]
    if ($data.UniqueValues -eq 0) { continue }
    
    Write-Host "`n$category ($($data.UniqueValues) unique values, $($data.TotalOccurrences) total):" -ForegroundColor Yellow
    $data.Distribution | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $($_.Value): $($_.Count) ($($_.Percentage)%)" -ForegroundColor White
    }
    if ($data.UniqueValues -gt 10) {
        Write-Host "  ... and $($data.UniqueValues - 10) more" -ForegroundColor Gray
    }
}

Write-Host "`nComprehensive analysis complete! All patterns extracted for maximum authenticity." -ForegroundColor Green