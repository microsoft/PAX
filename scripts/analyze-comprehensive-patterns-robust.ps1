# Robust Comprehensive Pattern Analysis Script
# Handles CSV with embedded JSON properly
# Analyzes all 367k+ records in Sample_Purview_Copilot_Usage_Export.csv

param(
    [string]$InputFile = "..\output\Sample_Purview_Copilot_Usage_Export.csv",
    [string]$OutputFile = "comprehensive-patterns.json"
)

Write-Host "Starting robust comprehensive analysis of all records..." -ForegroundColor Green

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
    UrlPatterns = @{}
    SiteUrlDomains = @{}
}

function Parse-CsvLineWithEmbeddedJson {
    param([string]$Line)
    
    # Handle CSV with embedded JSON - split carefully
    $parts = @()
    $inQuotes = $false
    $current = ""
    $i = 0
    
    while ($i -lt $Line.Length) {
        $char = $Line[$i]
        
        if ($char -eq '"') {
            $inQuotes = -not $inQuotes
            $current += $char
        } elseif ($char -eq ',' -and -not $inQuotes) {
            $parts += $current
            $current = ""
        } else {
            $current += $char
        }
        $i++
    }
    $parts += $current
    
    return $parts
}

# Read file line by line to handle large size
$lineCount = 0
$batchSize = 5000
$startTime = Get-Date
$totalLines = 367797  # We know this from earlier

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
        # Parse CSV line more carefully
        $fields = Parse-CsvLineWithEmbeddedJson $_
        if ($fields.Length -lt 5) { return }
        
        $auditData = $fields[4]  # AuditData is the 5th column (index 4)
        $patterns.TotalRecords++
        
        # Only process CopilotInteraction records
        if ($auditData -notlike '*CopilotInteraction*') { return }
        
        $patterns.CopilotRecords++
        
        # Clean up JSON - remove outer quotes if present
        if ($auditData.StartsWith('"') -and $auditData.EndsWith('"')) {
            $auditData = $auditData.Substring(1, $auditData.Length - 2)
        }
        
        # Unescape JSON
        $auditData = $auditData -replace '""', '"'
        
        # Parse JSON
        $json = $auditData | ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not $json) { 
            $patterns.ProcessingErrors++
            return 
        }
        
        # Extract CopilotEventData
        $copilotData = $json.CopilotEventData
        if (-not $copilotData) { return }
        
        # Extract AppHost
        if ($copilotData.AppHost) {
            $patterns.AppHost[$copilotData.AppHost] = ($patterns.AppHost[$copilotData.AppHost] ?? 0) + 1
        }
        
        # Extract Agent details (if they exist)
        if ($copilotData.AgentId) {
            $patterns.AgentId[$copilotData.AgentId] = ($patterns.AgentId[$copilotData.AgentId] ?? 0) + 1
        }
        if ($copilotData.AgentName) {
            $patterns.AgentName[$copilotData.AgentName] = ($patterns.AgentName[$copilotData.AgentName] ?? 0) + 1
        }
        
        # Extract CorrelationId patterns (if they exist)
        if ($copilotData.CorrelationId) {
            # Extract pattern (preserve format but anonymize)
            $pattern = $copilotData.CorrelationId -replace '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', 'GUID'
            $pattern = $pattern -replace '\d+', 'NUM'
            $patterns.CorrelationId[$pattern] = ($patterns.CorrelationId[$pattern] ?? 0) + 1
        }
        
        # Extract nested arrays and objects
        if ($copilotData.ModelTransparencyDetails) {
            $copilotData.ModelTransparencyDetails | ForEach-Object {
                if ($_.ModelName) {
                    $patterns.ModelTransparencyDetails[$_.ModelName] = ($patterns.ModelTransparencyDetails[$_.ModelName] ?? 0) + 1
                }
            }
        }
        
        if ($copilotData.AISystemPlugin) {
            $copilotData.AISystemPlugin | ForEach-Object {
                if ($_.Id) {
                    $patterns.AISystemPlugin[$_.Id] = ($patterns.AISystemPlugin[$_.Id] ?? 0) + 1
                }
                if ($_.Name) {
                    $patterns.AISystemPlugin[$_.Name] = ($patterns.AISystemPlugin[$_.Name] ?? 0) + 1
                }
            }
        }
        
        if ($copilotData.AccessedResources) {
            $copilotData.AccessedResources | ForEach-Object {
                if ($_.SensitivityLabelId) {
                    $patterns.SensitivityLabelId[$_.SensitivityLabelId] = ($patterns.SensitivityLabelId[$_.SensitivityLabelId] ?? 0) + 1
                }
                # Extract URL patterns
                if ($_.SiteUrl) {
                    # Extract domain
                    if ($_.SiteUrl -match 'https?://([^/]+)') {
                        $domain = $matches[1]
                        $patterns.SiteUrlDomains[$domain] = ($patterns.SiteUrlDomains[$domain] ?? 0) + 1
                    }
                    
                    # Create anonymized URL pattern
                    $urlPattern = $_.SiteUrl -replace 'https://[^/]+', 'https://DOMAIN'
                    $urlPattern = $urlPattern -replace '/[a-f0-9-]{36}', '/GUID'
                    $urlPattern = $urlPattern -replace '\d+', 'NUM'
                    $patterns.UrlPatterns[$urlPattern] = ($patterns.UrlPatterns[$urlPattern] ?? 0) + 1
                }
                if ($_.Action) {
                    $patterns.AccessedResources[$_.Action] = ($patterns.AccessedResources[$_.Action] ?? 0) + 1
                }
            }
        }
        
        # Extract Context arrays
        if ($copilotData.Contexts) {
            $copilotData.Contexts | ForEach-Object {
                if ($_.Type) {
                    $patterns.ContextType[$_.Type] = ($patterns.ContextType[$_.Type] ?? 0) + 1
                }
                if ($_.Id) {
                    # Anonymize IDs but keep pattern
                    $idPattern = $_.Id -replace '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', 'GUID'
                    $idPattern = $idPattern -replace '\d+', 'NUM'
                    $patterns.ContextId[$idPattern] = ($patterns.ContextId[$idPattern] ?? 0) + 1
                }
            }
        }
        
        # Extract Scenarios
        if ($copilotData.Scenarios) {
            $copilotData.Scenarios | ForEach-Object {
                $patterns.Scenarios[$_] = ($patterns.Scenarios[$_] ?? 0) + 1
            }
        }
        
        # Extract various ID patterns
        @('ThreadId', 'MessageId', 'ChatId', 'ConversationId', 'RequestId') | ForEach-Object {
            $field = $_
            if ($copilotData.$field) {
                # Keep actual values for ThreadId patterns as they show structure
                if ($field -eq 'ThreadId') {
                    $patterns.$field[$copilotData.$field] = ($patterns.$field[$copilotData.$field] ?? 0) + 1
                } else {
                    # For other IDs, just count occurrences
                    $patterns.$field['HasValue'] = ($patterns.$field['HasValue'] ?? 0) + 1
                }
            }
        }
        
        # Extract enum-like fields
        @('MessageType', 'AppName', 'ModuleName', 'Outcome', 'ActionType', 'Type', 'InteractionType') | ForEach-Object {
            $field = $_
            if ($copilotData.$field) {
                $patterns.$field[$copilotData.$field] = ($patterns.$field[$copilotData.$field] ?? 0) + 1
            }
        }
        
        # Extract Messages array patterns
        if ($copilotData.Messages) {
            $copilotData.Messages | ForEach-Object {
                if ($_.isPrompt -ne $null) {
                    $promptType = if ($_.isPrompt) { "IsPrompt" } else { "IsResponse" }
                    $patterns.MessageType[$promptType] = ($patterns.MessageType[$promptType] ?? 0) + 1
                }
            }
        }
        
    } catch {
        $patterns.ProcessingErrors++
        if ($patterns.ProcessingErrors -le 10) {
            Write-Warning "Error processing line $lineCount : $_"
        }
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
    $data.Distribution | Select-Object -First 15 | ForEach-Object {
        Write-Host "  $($_.Value): $($_.Count) ($($_.Percentage)%)" -ForegroundColor White
    }
    if ($data.UniqueValues -gt 15) {
        Write-Host "  ... and $($data.UniqueValues - 15) more" -ForegroundColor Gray
    }
}

Write-Host "`nComprehensive analysis complete! All patterns extracted for maximum authenticity." -ForegroundColor Green