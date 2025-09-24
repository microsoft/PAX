# Comprehensive Copilot Analytics Script
# Recreates Viva Insights "Feature Usage Distribution" metric using only MS Graph data sources
# This avoids dependency on Viva Insights and provides additional audit trail insights

param(
    [string]$CopilotUsageCSV = "C:\Users\bmiddendorf\OneDrive - Microsoft\Documents\Copilot Analytics Team\PurviewAPI\output\CopilotUsageUserDetail.csv",
    [string]$PurviewCSV = "C:\Users\bmiddendorf\OneDrive - Microsoft\Documents\Copilot Analytics Team\PurviewAPI\output\PurviewUserActivityDetail.csv",
    [string]$OutputPath = "C:\Users\bmiddendorf\OneDrive - Microsoft\Documents\Copilot Analytics Team\PurviewAPI\output\copilot_feature_analysis.json"
)

Write-Host "=== Comprehensive Copilot Feature Usage Analysis ===" -ForegroundColor Green
Write-Host "Recreating Viva Insights metrics using MS Graph data sources only" -ForegroundColor Yellow
Write-Host ""

# ===== PART 1: MS Graph Copilot Usage Analysis =====
Write-Host "PART 1: Analyzing MS Graph Copilot Usage Data" -ForegroundColor Cyan
Write-Host "Source: Microsoft 365 Admin Center -> Reports -> Copilot usage" -ForegroundColor Gray

$copilotData = Import-Csv $CopilotUsageCSV
Write-Host "Loaded $($copilotData.Count) user records from Copilot usage report" -ForegroundColor Green

# Feature usage analysis
$features = @{
    "Chat" = @{ Column = "Copilot Chat Last Activity Date"; Count = 0 }
    "Teams" = @{ Column = "Microsoft Teams Copilot Last Activity Date"; Count = 0 }
    "Word" = @{ Column = "Word Copilot Last Activity Date"; Count = 0 }
    "Excel" = @{ Column = "Excel Copilot Last Activity Date"; Count = 0 }
    "PowerPoint" = @{ Column = "PowerPoint Copilot Last Activity Date"; Count = 0 }
    "Outlook" = @{ Column = "Outlook Copilot Last Activity Date"; Count = 0 }
    "OneNote" = @{ Column = "OneNote Copilot Last Activity Date"; Count = 0 }
    "Loop" = @{ Column = "Loop Copilot Last Activity Date"; Count = 0 }
}

$totalActiveUsers = 0
$userFeatureCombinations = @{}

foreach ($record in $copilotData) {
    $userFeatures = @()
    $hasAnyActivity = $false
    
    foreach ($featureName in $features.Keys) {
        $columnName = $features[$featureName].Column
        if (![string]::IsNullOrWhiteSpace($record.$columnName)) {
            $features[$featureName].Count++
            $userFeatures += $featureName
            $hasAnyActivity = $true
        }
    }
    
    if ($hasAnyActivity) {
        $totalActiveUsers++
        $combinationKey = ($userFeatures | Sort-Object) -join "+"
        if ($userFeatureCombinations.ContainsKey($combinationKey)) {
            $userFeatureCombinations[$combinationKey]++
        } else {
            $userFeatureCombinations[$combinationKey] = 1
        }
    }
}

# Calculate percentages and create results
$featureResults = @()
foreach ($featureName in $features.Keys) {
    $count = $features[$featureName].Count
    $percentage = if ($totalActiveUsers -gt 0) { [Math]::Round(($count / $totalActiveUsers) * 100, 1) } else { 0 }
    
    $featureResults += [PSCustomObject]@{
        Feature = $featureName
        Users = $count
        Percentage = $percentage
        PercentageText = "$percentage%"
    }
}

# Sort by usage
$sortedFeatures = $featureResults | Sort-Object Percentage -Descending

Write-Host "`nFeature Usage Distribution (Recreated Viva Insights Metric):" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Green
foreach ($feature in $sortedFeatures) {
    Write-Host "$($feature.Feature): $($feature.Users) users ($($feature.PercentageText))" -ForegroundColor White
}

# Create Viva Insights style summary
$top3Features = $sortedFeatures | Select-Object -First 3
$vivaInsightsSummary = ($top3Features | ForEach-Object { "$($_.Feature): $($_.PercentageText)" }) -join ", "

Write-Host "`n🎯 VIVA INSIGHTS RECREATION:" -ForegroundColor Yellow
Write-Host "Feature Usage Distribution: $vivaInsightsSummary" -ForegroundColor Cyan

# ===== PART 2: Purview Audit Analysis (if available) =====
Write-Host "`nPART 2: Analyzing Purview Audit Data for Additional Insights" -ForegroundColor Cyan

try {
    # Sample just the first 1000 lines of Purview data to avoid memory issues
    Write-Host "Sampling Purview audit data (first 1000 records)..." -ForegroundColor Gray
    $purviewSample = Get-Content $PurviewCSV -Head 1001 | ConvertFrom-Csv
    
    $copilotInteractions = $purviewSample | Where-Object { $_.Operation -eq "CopilotInteraction" }
    
    if ($copilotInteractions) {
        Write-Host "Found $($copilotInteractions.Count) CopilotInteraction records in sample" -ForegroundColor Green
        
        # Analyze application usage from Purview
        $appUsage = $copilotInteractions | Group-Object ApplicationName | Sort-Object Count -Descending
        
        Write-Host "`nCopilot Interactions by Application (from Purview):" -ForegroundColor Green
        foreach ($app in $appUsage) {
            if ($app.Name -and $app.Name -ne "TRUE") {
                Write-Host "$($app.Name): $($app.Count) interactions" -ForegroundColor White
            }
        }
        
        # Analyze by client type
        $clientTypes = $copilotInteractions | Group-Object AppHost | Sort-Object Count -Descending
        
        Write-Host "`nCopilot Usage by Client Type:" -ForegroundColor Green
        foreach ($client in $clientTypes) {
            if ($client.Name -and $client.Name -ne "TRUE") {
                Write-Host "$($client.Name): $($client.Count) interactions" -ForegroundColor White
            }
        }
    } else {
        Write-Host "No CopilotInteraction records found in sample" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not analyze Purview data: $($_.Exception.Message)" -ForegroundColor Red
}

# ===== PART 3: Create Output Report =====
Write-Host "`nPART 3: Creating Analysis Report" -ForegroundColor Cyan

$analysisReport = @{
    GeneratedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    DataSources = @{
        CopilotUsage = $CopilotUsageCSV
        PurviewAudit = $PurviewCSV
    }
    Summary = @{
        TotalLicensedUsers = $copilotData.Count
        TotalActiveUsers = $totalActiveUsers
        AdoptionRate = [Math]::Round(($totalActiveUsers / $copilotData.Count) * 100, 1)
        VivaInsightsRecreation = $vivaInsightsSummary
    }
    FeatureUsage = $sortedFeatures
    TopFeatureCombinations = ($userFeatureCombinations.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10)
    Methodology = @{
        Description = "This analysis recreates the Viva Insights 'Feature Usage Distribution' metric using only MS Graph data sources (Microsoft 365 usage reports and Purview audit logs). No direct Viva Insights data required."
        DataSource = "Microsoft Graph API via Microsoft 365 Admin Center Reports"
        Calculation = "Percentage = (Users with activity in feature / Total active Copilot users) * 100"
        Features = @($features.Keys)
    }
}

# Save to JSON
$analysisReport | ConvertTo-Json -Depth 10 | Out-File $OutputPath -Encoding UTF8
Write-Host "Analysis report saved to: $OutputPath" -ForegroundColor Green

# ===== PART 4: Recommendations =====
Write-Host "`nPART 4: Implementation Recommendations" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Green

Write-Host "✅ To recreate this metric without Viva Insights:" -ForegroundColor Yellow
Write-Host "1. Use Microsoft Graph API: /reports/getM365AppUserDetail(period='D30')" -ForegroundColor White
Write-Host "2. Alternative: Microsoft 365 Admin Center > Reports > Usage > Microsoft 365 Copilot usage" -ForegroundColor White
Write-Host "3. Parse the 'Last Activity Date' columns for each Copilot feature" -ForegroundColor White
Write-Host "4. Calculate percentages based on total active users (not total licensed)" -ForegroundColor White

Write-Host "`n🔍 Additional insights available from Purview:" -ForegroundColor Yellow
Write-Host "- Real-time Copilot interaction events (CopilotInteraction operation)" -ForegroundColor White
Write-Host "- Client type usage (Desktop, Mobile, Web)" -ForegroundColor White
Write-Host "- Geographic usage patterns" -ForegroundColor White
Write-Host "- Security and compliance context" -ForegroundColor White

Write-Host "`n📊 Current Results Summary:" -ForegroundColor Yellow
Write-Host "Top 3 Features: $vivaInsightsSummary" -ForegroundColor Cyan
Write-Host "Overall Adoption: $($analysisReport.Summary.AdoptionRate)% of licensed users" -ForegroundColor Cyan

Write-Host "`n✨ Analysis Complete!" -ForegroundColor Green