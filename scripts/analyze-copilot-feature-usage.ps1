# Script to analyze Copilot feature usage distribution from CopilotUsageUserDetail.csv
# This recreates the "Feature Usage Distribution" metric without using Viva Insights

param(
    [string]$CsvPath = "C:\Users\bmiddendorf\OneDrive - Microsoft\Documents\Copilot Analytics Team\PurviewAPI\output\CopilotUsageUserDetail.csv"
)

Write-Host "Analyzing Copilot Feature Usage Distribution..." -ForegroundColor Green
Write-Host "Reading data from: $CsvPath" -ForegroundColor Yellow

# Read the CSV data
$data = Import-Csv $CsvPath

Write-Host "Total records found: $($data.Count)" -ForegroundColor Cyan

# Initialize counters for each Copilot feature
$featureUsage = @{
    "Chat" = 0
    "Teams" = 0
    "Word" = 0
    "Excel" = 0
    "PowerPoint" = 0
    "Outlook" = 0
    "OneNote" = 0
    "Loop" = 0
}

$totalActiveUsers = 0

# Analyze each user record
foreach ($record in $data) {
    $hasAnyActivity = $false
    
    # Check each Copilot feature for activity (non-empty date means usage)
    if (![string]::IsNullOrWhiteSpace($record."Copilot Chat Last Activity Date")) {
        $featureUsage["Chat"]++
        $hasAnyActivity = $true
    }
    
    if (![string]::IsNullOrWhiteSpace($record."Microsoft Teams Copilot Last Activity Date")) {
        $featureUsage["Teams"]++
        $hasAnyActivity = $true
    }
    
    if (![string]::IsNullOrWhiteSpace($record."Word Copilot Last Activity Date")) {
        $featureUsage["Word"]++
        $hasAnyActivity = $true
    }
    
    if (![string]::IsNullOrWhiteSpace($record."Excel Copilot Last Activity Date")) {
        $featureUsage["Excel"]++
        $hasAnyActivity = $true
    }
    
    if (![string]::IsNullOrWhiteSpace($record."PowerPoint Copilot Last Activity Date")) {
        $featureUsage["PowerPoint"]++
        $hasAnyActivity = $true
    }
    
    if (![string]::IsNullOrWhiteSpace($record."Outlook Copilot Last Activity Date")) {
        $featureUsage["Outlook"]++
        $hasAnyActivity = $true
    }
    
    if (![string]::IsNullOrWhiteSpace($record."OneNote Copilot Last Activity Date")) {
        $featureUsage["OneNote"]++
        $hasAnyActivity = $true
    }
    
    if (![string]::IsNullOrWhiteSpace($record."Loop Copilot Last Activity Date")) {
        $featureUsage["Loop"]++
        $hasAnyActivity = $true
    }
    
    if ($hasAnyActivity) {
        $totalActiveUsers++
    }
}

Write-Host "`nFeature Usage Analysis Results:" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host "Total Active Copilot Users: $totalActiveUsers" -ForegroundColor Cyan

# Calculate percentages and display results
$results = @()
foreach ($feature in $featureUsage.Keys) {
    $count = $featureUsage[$feature]
    $percentage = if ($totalActiveUsers -gt 0) { [Math]::Round(($count / $totalActiveUsers) * 100, 1) } else { 0 }
    
    $results += [PSCustomObject]@{
        Feature = $feature
        Users = $count
        Percentage = "$percentage%"
        PercentageValue = $percentage
    }
    
    Write-Host "$feature`: $count users ($percentage%)" -ForegroundColor White
}

# Sort by usage percentage (descending)
$sortedResults = $results | Sort-Object PercentageValue -Descending

Write-Host "`nTop Features by Usage:" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
foreach ($result in $sortedResults) {
    Write-Host "$($result.Feature): $($result.Percentage)" -ForegroundColor Yellow
}

# Create a summary similar to Viva Insights format
Write-Host "`nViva Insights Style Summary:" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green
$top3 = $sortedResults | Select-Object -First 3
$summary = ($top3 | ForEach-Object { "$($_.Feature): $($_.Percentage)" }) -join ", "
Write-Host $summary -ForegroundColor Cyan

# Additional analysis: Users by feature combination
Write-Host "`nDetailed Feature Combination Analysis:" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

$multiFeatureUsers = 0
$singleFeatureUsers = 0

foreach ($record in $data) {
    $featuresUsed = 0
    
    if (![string]::IsNullOrWhiteSpace($record."Copilot Chat Last Activity Date")) { $featuresUsed++ }
    if (![string]::IsNullOrWhiteSpace($record."Microsoft Teams Copilot Last Activity Date")) { $featuresUsed++ }
    if (![string]::IsNullOrWhiteSpace($record."Word Copilot Last Activity Date")) { $featuresUsed++ }
    if (![string]::IsNullOrWhiteSpace($record."Excel Copilot Last Activity Date")) { $featuresUsed++ }
    if (![string]::IsNullOrWhiteSpace($record."PowerPoint Copilot Last Activity Date")) { $featuresUsed++ }
    if (![string]::IsNullOrWhiteSpace($record."Outlook Copilot Last Activity Date")) { $featuresUsed++ }
    if (![string]::IsNullOrWhiteSpace($record."OneNote Copilot Last Activity Date")) { $featuresUsed++ }
    if (![string]::IsNullOrWhiteSpace($record."Loop Copilot Last Activity Date")) { $featuresUsed++ }
    
    if ($featuresUsed -eq 1) { $singleFeatureUsers++ }
    elseif ($featuresUsed -gt 1) { $multiFeatureUsers++ }
}

Write-Host "Users using only 1 feature: $singleFeatureUsers" -ForegroundColor White
Write-Host "Users using multiple features: $multiFeatureUsers" -ForegroundColor White

# Calculate adoption metrics
$totalLicensedUsers = $data.Count
$adoptionRate = if ($totalLicensedUsers -gt 0) { [Math]::Round(($totalActiveUsers / $totalLicensedUsers) * 100, 1) } else { 0 }

Write-Host "`nAdoption Metrics:" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "Total Licensed Users: $totalLicensedUsers" -ForegroundColor White
Write-Host "Active Copilot Users: $totalActiveUsers" -ForegroundColor White
Write-Host "Overall Adoption Rate: $adoptionRate%" -ForegroundColor Cyan