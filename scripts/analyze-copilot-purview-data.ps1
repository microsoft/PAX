# Analyze Copilot Activities in Purview Data
# Examines what Copilot-related data is actually available in the Purview export

Write-Host "🔍 COPILOT ACTIVITY ANALYSIS IN PURVIEW DATA" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# File paths
$outputPath = Join-Path (Get-Location) "output"
$purviewFile = Join-Path $outputPath "PurviewUserActivityDetail.csv"

Write-Host "📂 Loading Purview data..." -ForegroundColor Yellow

# Check if file exists
if (-not (Test-Path $purviewFile)) {
    Write-Host "❌ Error: PurviewUserActivityDetail.csv not found in output folder" -ForegroundColor Red
    Write-Host "Available files:" -ForegroundColor Yellow
    if (Test-Path $outputPath) {
        Get-ChildItem $outputPath -Name "*.csv" | ForEach-Object { Write-Host "- $_" -ForegroundColor White }
    }
    exit 1
}

# Get file size info
$fileInfo = Get-Item $purviewFile
$fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
Write-Host "📊 File size: $fileSizeMB MB" -ForegroundColor White

Write-Host "Loading Purview audit data (this may take a moment due to size)..." -ForegroundColor White

try {
    # Load first 1000 rows to analyze structure quickly
    $sampleData = Get-Content $purviewFile | Select-Object -First 1001 | ConvertFrom-Csv
    Write-Host "✅ Loaded sample of $($sampleData.Count) records for analysis" -ForegroundColor Green
} catch {
    Write-Host "❌ Error loading Purview data: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n📋 COLUMN STRUCTURE ANALYSIS:" -ForegroundColor Yellow
$columns = $sampleData[0].PSObject.Properties.Name | Sort-Object
Write-Host "Total columns: $($columns.Count)" -ForegroundColor White
Write-Host "Available columns:" -ForegroundColor Gray
$columns | ForEach-Object { Write-Host "- $_" -ForegroundColor Gray }

Write-Host "`n🔍 SEARCHING FOR COPILOT-RELATED ACTIVITIES:" -ForegroundColor Yellow

# Check for Copilot-related activity types
if ($sampleData[0].PSObject.Properties.Name -contains "Operation") {
    $operations = $sampleData | Group-Object Operation | Sort-Object Count -Descending
    
    Write-Host "`nTop 20 Operation types:" -ForegroundColor Cyan
    $operations | Select-Object -First 20 | ForEach-Object {
        Write-Host "- $($_.Name) ($($_.Count) occurrences)" -ForegroundColor White
    }
    
    # Look for Copilot-specific operations
    $copilotOperations = $operations | Where-Object { $_.Name -like "*Copilot*" -or $_.Name -like "*AI*" -or $_.Name -like "*Assistant*" }
    
    if ($copilotOperations) {
        Write-Host "`n🎯 COPILOT-RELATED OPERATIONS FOUND:" -ForegroundColor Green
        $copilotOperations | ForEach-Object {
            Write-Host "✅ $($_.Name) ($($_.Count) occurrences)" -ForegroundColor Green
        }
    } else {
        Write-Host "`n❌ No obvious Copilot-related operations found in sample" -ForegroundColor Red
    }
}

# Check for other potential Copilot indicators
Write-Host "`n🔍 CHECKING FOR COPILOT INDICATORS IN OTHER FIELDS:" -ForegroundColor Yellow

$copilotKeywords = @("Copilot", "AI", "Assistant", "Chat", "GPT", "LLM", "Microsoft.Copilot")
$foundIndicators = @{}

foreach ($keyword in $copilotKeywords) {
    foreach ($column in $columns) {
        $matchingRecords = $sampleData | Where-Object { $_.$column -like "*$keyword*" }
        if ($matchingRecords) {
            if (-not $foundIndicators.ContainsKey($keyword)) {
                $foundIndicators[$keyword] = @{}
            }
            $foundIndicators[$keyword][$column] = $matchingRecords.Count
        }
    }
}

if ($foundIndicators.Count -gt 0) {
    Write-Host "🎯 COPILOT INDICATORS FOUND:" -ForegroundColor Green
    foreach ($keyword in $foundIndicators.Keys) {
        Write-Host "`nKeyword: '$keyword'" -ForegroundColor Cyan
        foreach ($column in $foundIndicators[$keyword].Keys) {
            Write-Host "- Column '$column': $($foundIndicators[$keyword][$column]) matches" -ForegroundColor White
        }
    }
} else {
    Write-Host "❌ No Copilot indicators found in sample data" -ForegroundColor Red
}

# Check date range of data
if ($sampleData[0].PSObject.Properties.Name -contains "CreationTime") {
    $dates = $sampleData | Where-Object { ![string]::IsNullOrWhiteSpace($_.CreationTime) } | ForEach-Object {
        try { [DateTime]::Parse($_.CreationTime) } catch { $null }
    } | Where-Object { $_ -ne $null }
    
    if ($dates) {
        $minDate = ($dates | Measure-Object -Minimum).Minimum
        $maxDate = ($dates | Measure-Object -Maximum).Maximum
        Write-Host "`n📅 DATA DATE RANGE (from sample):" -ForegroundColor Yellow
        Write-Host "Earliest: $($minDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        Write-Host "Latest: $($maxDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        Write-Host "Span: $(($maxDate - $minDate).Days) days" -ForegroundColor White
    }
}

Write-Host "`n💡 RECOMMENDATIONS:" -ForegroundColor Cyan
Write-Host "1. Check if Copilot audit logging is enabled in your tenant" -ForegroundColor White
Write-Host "2. Verify the date range covers your Copilot rollout period (April 2025+)" -ForegroundColor White
Write-Host "3. Consider looking for indirect indicators (Office app usage changes)" -ForegroundColor White
Write-Host "4. Check if different Purview search queries are needed for Copilot events" -ForegroundColor White

Write-Host "`n✅ Analysis complete!" -ForegroundColor Green