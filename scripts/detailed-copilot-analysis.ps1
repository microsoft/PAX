# Analyze Full Copilot Interactions in Purview Data
# Focuses specifically on CopilotInteraction records to extract detailed insights

Write-Host "🤖 DETAILED COPILOT INTERACTION ANALYSIS" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

$outputPath = Join-Path (Get-Location) "output"
$purviewFile = Join-Path $outputPath "PurviewUserActivityDetail.csv"

Write-Host "📂 Loading Purview data to analyze Copilot interactions..." -ForegroundColor Yellow

# Load data and filter for Copilot interactions
Write-Host "Filtering for CopilotInteraction records..." -ForegroundColor White

# Use Import-Csv with streaming to handle large file
$copilotInteractions = @()
$totalRecords = 0
$copilotCount = 0

# Read file line by line to avoid memory issues
$reader = [System.IO.StreamReader]::new($purviewFile)
$header = $reader.ReadLine()
$headerFields = $header -split ','

Write-Host "Processing large file (this may take a few minutes)..." -ForegroundColor White

while ($null -ne ($line = $reader.ReadLine())) {
    $totalRecords++
    
    # Check if this line contains CopilotInteraction
    if ($line -like "*CopilotInteraction*") {
        $fields = $line -split ','
        $record = @{}
        
        for ($i = 0; $i -lt $headerFields.Length; $i++) {
            if ($i -lt $fields.Length) {
                $record[$headerFields[$i]] = $fields[$i]
            }
        }
        
        $copilotInteractions += [PSCustomObject]$record
        $copilotCount++
        
        # Progress indicator
        if ($copilotCount % 50 -eq 0) {
            Write-Host "Found $copilotCount Copilot interactions..." -ForegroundColor Gray
        }
    }
    
    # Progress for total records
    if ($totalRecords % 50000 -eq 0) {
        Write-Host "Processed $totalRecords total records..." -ForegroundColor Gray
    }
}

$reader.Close()

Write-Host "`n✅ PROCESSING COMPLETE:" -ForegroundColor Green
Write-Host "Total records processed: $totalRecords" -ForegroundColor White
Write-Host "Copilot interactions found: $copilotCount" -ForegroundColor Cyan

if ($copilotCount -eq 0) {
    Write-Host "❌ No CopilotInteraction records found in the full dataset" -ForegroundColor Red
    Write-Host "This could mean:" -ForegroundColor Yellow
    Write-Host "- Copilot audit logging isn't enabled" -ForegroundColor White
    Write-Host "- The data export doesn't cover the Copilot rollout period" -ForegroundColor White
    Write-Host "- Different search parameters are needed" -ForegroundColor White
    exit 1
}

Write-Host "`n🔍 COPILOT INTERACTION ANALYSIS:" -ForegroundColor Yellow

# Analyze date range of Copilot interactions
$copilotDates = $copilotInteractions | Where-Object { ![string]::IsNullOrWhiteSpace($_.CreationTime) } | ForEach-Object {
    try { [DateTime]::Parse($_.CreationTime) } catch { $null }
} | Where-Object { $_ -ne $null }

if ($copilotDates) {
    $minDate = ($copilotDates | Measure-Object -Minimum).Minimum
    $maxDate = ($copilotDates | Measure-Object -Maximum).Maximum
    Write-Host "📅 Copilot interaction date range:" -ForegroundColor Cyan
    Write-Host "First interaction: $($minDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    Write-Host "Last interaction: $($maxDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    Write-Host "Duration: $(($maxDate - $minDate).Days) days" -ForegroundColor White
}

# Analyze users
$uniqueUsers = $copilotInteractions | Where-Object { ![string]::IsNullOrWhiteSpace($_.UserId) } | Select-Object UserId -Unique
Write-Host "`n👥 Users with Copilot interactions: $($uniqueUsers.Count)" -ForegroundColor Cyan

# Analyze AI plugins/features
$plugins = $copilotInteractions | Where-Object { ![string]::IsNullOrWhiteSpace($_.'AISystemPlugin_Name') } | Group-Object 'AISystemPlugin_Name' | Sort-Object Count -Descending
if ($plugins) {
    Write-Host "`n🔌 Top Copilot plugins/features:" -ForegroundColor Cyan
    $plugins | Select-Object -First 10 | ForEach-Object {
        Write-Host "- $($_.Name): $($_.Count) interactions" -ForegroundColor White
    }
}

# Analyze prompts vs responses
$prompts = $copilotInteractions | Where-Object { $_.'Message_isPrompt' -eq 'True' }
$responses = $copilotInteractions | Where-Object { $_.'Message_isPrompt' -eq 'False' }

Write-Host "`n💬 Interaction breakdown:" -ForegroundColor Cyan
Write-Host "Prompts (user input): $($prompts.Count)" -ForegroundColor White
Write-Host "Responses (Copilot output): $($responses.Count)" -ForegroundColor White

# Show sample interactions (first 5 prompts)
if ($prompts.Count -gt 0) {
    Write-Host "`n📝 Sample Copilot prompts (first 5):" -ForegroundColor Cyan
    $prompts | Select-Object -First 5 | ForEach-Object {
        $timestamp = try { [DateTime]::Parse($_.CreationTime).ToString('yyyy-MM-dd HH:mm') } catch { $_.CreationTime }
        Write-Host "[$timestamp] User: $($_.UserId)" -ForegroundColor Gray
        Write-Host "Plugin: $($_.'AISystemPlugin_Name')" -ForegroundColor White
        Write-Host "Context: $($_.'Context_Type')" -ForegroundColor White
        Write-Host "---" -ForegroundColor Gray
    }
}

Write-Host "`n✅ Detailed Copilot analysis complete!" -ForegroundColor Green